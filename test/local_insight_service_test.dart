import 'package:arus_finance/core/db/app_database.dart';
import 'package:arus_finance/core/services/local_insight_service.dart';
import 'package:arus_finance/data/local_finance_repository.dart';
import 'package:arus_finance/domain/enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late LocalFinanceRepository repo;
  late LocalInsightService service;

  setUp(() async {
    db = AppDatabase.inMemory();
    repo = LocalFinanceRepository(
      db,
      clock: () => DateTime(2026, 9, 16, 9),
    );
    await repo.initialize();
    service = LocalInsightService(db);
  });

  tearDown(() => db.close());

  Future<String> expenseCategory(String name) async =>
      (await repo.listCategories(type: CategoryType.expense))
          .firstWhere((category) => category.name == name)
          .id;

  test('daily category spike only appears with enough comparison evidence', () async {
    final bank = await repo.createAccount(
      name: 'Insight Bank',
      accountClass: AccountClass.asset,
      accountType: AccountType.bank,
      openingBalanceMinor: 5000000,
    );
    final food = await expenseCategory('Makanan');

    for (final day in [2, 5, 8, 12]) {
      await repo.createExpense(
        amountMinor: 50000,
        accountId: bank,
        categoryId: food,
        occurredAt: DateTime(2026, 9, day, 12),
      );
    }
    await repo.createExpense(
      amountMinor: 150000,
      accountId: bank,
      categoryId: food,
      occurredAt: DateTime(2026, 9, 16, 8),
    );

    final insight = await service.build(now: DateTime(2026, 9, 16, 15));

    expect(insight, isNotNull);
    expect(insight!.kind, 'daily_category_spike');
    expect(insight.title, contains('Makanan'));
    expect(insight.message, contains('3.0×'));
  });

  test('monthly category insight is descriptive when there is no daily spike', () async {
    final bank = await repo.createAccount(
      name: 'Monthly Bank',
      accountClass: AccountClass.asset,
      accountType: AccountType.bank,
      openingBalanceMinor: 5000000,
    );
    final bills = await expenseCategory('Tagihan');
    final food = await expenseCategory('Makanan');

    await repo.createExpense(
      amountMinor: 700000,
      accountId: bank,
      categoryId: bills,
      occurredAt: DateTime(2026, 9, 3),
    );
    await repo.createExpense(
      amountMinor: 300000,
      accountId: bank,
      categoryId: food,
      occurredAt: DateTime(2026, 9, 4),
    );

    final insight = await service.build(now: DateTime(2026, 9, 16, 15));

    expect(insight, isNotNull);
    expect(insight!.kind, 'monthly_dominant_category');
    expect(insight.title, contains('Tagihan'));
    expect(insight.message, contains('70%'));
  });

  test('transfers do not become fake spending insight', () async {
    final source = await repo.createAccount(
      name: 'Source Bank',
      accountClass: AccountClass.asset,
      accountType: AccountType.bank,
      openingBalanceMinor: 5000000,
    );
    final target = await repo.createAccount(
      name: 'Target Bank',
      accountClass: AccountClass.asset,
      accountType: AccountType.bank,
    );

    await repo.createTransfer(
      amountMinor: 3000000,
      sourceAccountId: source,
      destinationAccountId: target,
      occurredAt: DateTime(2026, 9, 16, 8),
    );

    final insight = await service.build(now: DateTime(2026, 9, 16, 15));

    expect(insight, isNull);
  });
}
