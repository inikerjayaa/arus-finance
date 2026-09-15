import 'package:arus_finance/core/db/app_database.dart';
import 'package:arus_finance/core/db/schema.dart';
import 'package:arus_finance/core/services/visual_identity_store.dart';
import 'package:arus_finance/data/local_finance_repository.dart';
import 'package:arus_finance/domain/enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late LocalFinanceRepository repo;
  late VisualIdentityStore store;

  setUp(() async {
    db = AppDatabase.inMemory();
    repo = LocalFinanceRepository(
      db,
      clock: () => DateTime.utc(2026, 9, 15, 8),
    );
    await repo.initialize();
    store = VisualIdentityStore(db);
    await store.initialize();
  });

  tearDown(() => db.close());

  test('schema v10 keeps visual identity on backed-up account/category rows', () {
    expect(kSchemaVersion, 10);
    final accountColumns = db.db
        .select('PRAGMA table_info(accounts)')
        .map((row) => row['name'] as String)
        .toSet();
    final categoryColumns = db.db
        .select('PRAGMA table_info(categories)')
        .map((row) => row['name'] as String)
        .toSet();
    expect(accountColumns, containsAll(['visual_icon_key', 'visual_color_key']));
    expect(categoryColumns, containsAll(['visual_icon_key', 'visual_color_key']));
  });

  test('built-in category and account visuals are seeded without touching ledger data', () async {
    await store.ensureBuiltInDefaults();

    final food = (await repo.listCategories(type: CategoryType.expense))
        .firstWhere((category) => category.name == 'Makanan');
    final cash = (await repo.listAccounts())
        .firstWhere((account) => account.name == 'Cash');

    final foodVisual = await store.category(food.id);
    final cashVisual = await store.account(cash.id);
    expect(foodVisual?.iconKey, 'food.meal');
    expect(foodVisual?.colorKey, 'orange');
    expect(cashVisual?.iconKey, 'finance.cash');
    expect(cashVisual?.colorKey, 'green');

    final dashboard = await repo.dashboard(now: DateTime(2026, 9, 15));
    expect(dashboard.spendingPeriodMinor, 0);
    expect(dashboard.incomePeriodMinor, 0);
  });

  test('bank and manual category names receive useful local suggestions', () async {
    final bca = await repo.createAccount(
      name: 'BCA',
      accountClass: AccountClass.asset,
      accountType: AccountType.bank,
    );
    final shoes = await repo.createCategory(
      name: 'Sepatu',
      type: CategoryType.expense,
    );

    await store.ensureBuiltInDefaults();

    expect((await store.account(bca))?.iconKey, 'bank.bca');
    expect((await store.category(shoes))?.iconKey, 'shopping.shoes');
    expect((await store.category(shoes))?.colorKey, 'purple');
  });

  test('explicit visual assignment persists on the entity row by stable id', () async {
    final categoryId = await repo.createCategory(
      name: 'Streaming',
      type: CategoryType.expense,
    );

    await store.setCategory(
      categoryId: categoryId,
      iconKey: 'subscription.netflix',
      colorKey: 'red',
    );
    await store.setCategory(
      categoryId: categoryId,
      iconKey: 'subscription.chatgpt',
      colorKey: 'purple',
    );

    final visual = await store.category(categoryId);
    expect(visual?.iconKey, 'subscription.chatgpt');
    expect(visual?.colorKey, 'purple');

    final raw = db.db.select(
      '''SELECT visual_icon_key,visual_color_key
         FROM categories WHERE id=?''',
      [categoryId],
    ).single;
    expect(raw['visual_icon_key'], 'subscription.chatgpt');
    expect(raw['visual_color_key'], 'purple');
  });

  test('unknown visual keys are rejected before metadata is written', () async {
    final categoryId = await repo.createCategory(
      name: 'Unknown Visual',
      type: CategoryType.expense,
    );

    await expectLater(
      store.setCategory(
        categoryId: categoryId,
        iconKey: 'brand.does-not-exist',
        colorKey: 'purple',
      ),
      throwsA(isA<ArgumentError>()),
    );
    await expectLater(
      store.setCategory(
        categoryId: categoryId,
        iconKey: 'food.meal',
        colorKey: 'ultraviolet',
      ),
      throwsA(isA<ArgumentError>()),
    );
    expect(await store.category(categoryId), isNull);
  });

  test('visual metadata disappears naturally when its entity is deleted', () async {
    final categoryId = await repo.createCategory(
      name: 'Disposable Visual',
      type: CategoryType.expense,
    );
    await store.setCategory(
      categoryId: categoryId,
      iconKey: 'shopping.cart',
      colorKey: 'orange',
    );
    expect(await store.category(categoryId), isNotNull);

    db.db.execute('DELETE FROM categories WHERE id=?', [categoryId]);
    expect(await store.category(categoryId), isNull);
  });
}
