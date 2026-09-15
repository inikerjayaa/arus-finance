import 'package:arus_finance/core/db/app_database.dart';
import 'package:arus_finance/core/services/category_maintenance_service.dart';
import 'package:arus_finance/core/services/visual_identity_store.dart';
import 'package:arus_finance/data/local_finance_repository.dart';
import 'package:arus_finance/domain/enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rename preserves stable identity, visuals, history search and engine fee use', () async {
    final database = AppDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalFinanceRepository(
      database,
      clock: () => DateTime(2026, 9, 15, 12),
    );
    await repository.initialize();

    final maintenance = CategoryMaintenanceService(
      database,
      clock: () => DateTime.utc(2026, 9, 15, 5),
    );
    final visuals = VisualIdentityStore(database);
    final source = (await repository.listAccounts()).single;
    final feeCategoryId = database.db.select(
      "SELECT id FROM categories WHERE system_key='expense.transfer_fee'",
    ).single['id'] as String;

    await visuals.setCategory(
      categoryId: feeCategoryId,
      iconKey: 'finance.fee',
      colorKey: 'red',
    );
    final historyId = await repository.createExpense(
      amountMinor: 5000,
      accountId: source.id,
      categoryId: feeCategoryId,
      occurredAt: DateTime(2026, 9, 15, 9),
      note: 'Riwayat lama',
    );

    await maintenance.renameCategory(
      categoryId: feeCategoryId,
      name: '  Administrasi Transfer  ',
    );

    final renamed = database.db.select(
      '''SELECT name,system_key,visual_icon_key,visual_color_key,version
         FROM categories WHERE id=?''',
      [feeCategoryId],
    ).single;
    expect(renamed['name'], 'Administrasi Transfer');
    expect(renamed['system_key'], 'expense.transfer_fee');
    expect(renamed['visual_icon_key'], 'finance.fee');
    expect(renamed['visual_color_key'], 'red');
    expect(renamed['version'], 2);

    final searched = await repository.listTransactions(query: 'Administrasi');
    expect(searched.map((tx) => tx.id), contains(historyId));
    expect(await repository.listTransactions(query: 'Biaya Transfer'), isEmpty);

    final destinationId = await repository.createAccount(
      name: 'Bank tujuan',
      accountClass: AccountClass.asset,
      accountType: AccountType.bank,
    );
    await repository.createTransfer(
      amountMinor: 100000,
      sourceAccountId: source.id,
      destinationAccountId: destinationId,
      feeMinor: 2500,
      occurredAt: DateTime(2026, 9, 15, 10),
    );

    final feeSplit = database.db.select(
      '''SELECT s.category_id,c.name
         FROM transactions t
         JOIN transaction_splits s ON s.transaction_id=t.id
         JOIN categories c ON c.id=s.category_id
         WHERE t.type='EXPENSE' AND t.primary_amount_minor=2500''',
    ).single;
    expect(feeSplit['category_id'], feeCategoryId);
    expect(feeSplit['name'], 'Administrasi Transfer');
  });

  test('rename rejects duplicate active name in the same category type', () async {
    final database = AppDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalFinanceRepository(database);
    await repository.initialize();
    final maintenance = CategoryMaintenanceService(database);

    final expense = await repository.listCategories(type: CategoryType.expense);
    final food = expense.firstWhere((category) => category.name == 'Makanan');

    await expectLater(
      maintenance.renameCategory(categoryId: food.id, name: 'transport'),
      throwsA(isA<StateError>()),
    );

    final row = database.db.select(
      'SELECT name,system_key FROM categories WHERE id=?',
      [food.id],
    ).single;
    expect(row['name'], 'Makanan');
    expect(row['system_key'], 'expense.food');
  });

  test('archived category cannot be renamed through active maintenance flow', () async {
    final database = AppDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalFinanceRepository(database);
    await repository.initialize();
    final maintenance = CategoryMaintenanceService(database);

    final id = await repository.createCategory(
      name: 'Sementara',
      type: CategoryType.expense,
    );
    await repository.archiveCategory(id);

    await expectLater(
      maintenance.renameCategory(categoryId: id, name: 'Nama Baru'),
      throwsA(isA<StateError>()),
    );
  });
}
