import 'package:arus_finance/core/db/app_database.dart';
import 'package:arus_finance/core/services/category_composition_service.dart';
import 'package:arus_finance/data/local_finance_repository.dart';
import 'package:arus_finance/domain/enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late LocalFinanceRepository repo;
  late CategoryCompositionService service;

  setUp(() async {
    db = AppDatabase.inMemory();
    repo = LocalFinanceRepository(
      db,
      clock: () => DateTime(2026, 9, 30, 12),
    );
    await repo.initialize();
    service = CategoryCompositionService(db);
  });

  tearDown(() => db.close());

  Future<String> expenseCategory(String name) async =>
      (await repo.listCategories(type: CategoryType.expense))
          .firstWhere((category) => category.name == name)
          .id;

  Future<String> incomeCategory(String name) async =>
      (await repo.listCategories(type: CategoryType.income))
          .firstWhere((category) => category.name == name)
          .id;

  test('expense composition net equals dashboard spending after refunds', () async {
    final bank = await repo.createAccount(
      name: 'Composition Bank',
      accountClass: AccountClass.asset,
      accountType: AccountType.bank,
      openingBalanceMinor: 1000000,
    );
    final food = await expenseCategory('Makanan');
    final shopping = await expenseCategory('Belanja');
    await repo.createExpense(
      amountMinor: 100000,
      accountId: bank,
      categoryId: food,
      occurredAt: DateTime(2026, 9, 5),
    );
    final purchase = await repo.createExpense(
      amountMinor: 200000,
      accountId: bank,
      categoryId: shopping,
      occurredAt: DateTime(2026, 9, 6),
    );
    await repo.createRefund(
      originalTransactionId: purchase,
      amountMinor: 50000,
      destinationAccountId: bank,
      occurredAt: DateTime(2026, 9, 8),
    );

    final dashboard = await repo.dashboard(now: DateTime(2026, 9, 8));
    final composition = await service.month(
      CategoryType.expense,
      now: DateTime(2026, 9, 8),
    );

    expect(composition.netTotalMinor, dashboard.spendingPeriodMinor);
    expect(composition.netTotalMinor, 250000);
    expect(composition.positiveTotalMinor, 250000);
    expect(composition.negativeOffsetMinor, 0);
    expect(
      composition.entries.firstWhere((entry) => entry.name == 'Belanja').amountMinor,
      150000,
    );
  });

  test('prior-period refund is represented as negative offset, not a fake donut slice', () async {
    final bank = await repo.createAccount(
      name: 'Refund Bank',
      accountClass: AccountClass.asset,
      accountType: AccountType.bank,
      openingBalanceMinor: 1000000,
    );
    final food = await expenseCategory('Makanan');
    final shopping = await expenseCategory('Belanja');
    final augustPurchase = await repo.createExpense(
      amountMinor: 80000,
      accountId: bank,
      categoryId: shopping,
      occurredAt: DateTime(2026, 8, 20),
    );
    await repo.createExpense(
      amountMinor: 100000,
      accountId: bank,
      categoryId: food,
      occurredAt: DateTime(2026, 9, 2),
    );
    await repo.createRefund(
      originalTransactionId: augustPurchase,
      amountMinor: 50000,
      destinationAccountId: bank,
      occurredAt: DateTime(2026, 9, 4),
    );

    final dashboard = await repo.dashboard(now: DateTime(2026, 9, 4));
    final composition = await service.month(
      CategoryType.expense,
      now: DateTime(2026, 9, 4),
    );

    expect(composition.netTotalMinor, dashboard.spendingPeriodMinor);
    expect(composition.netTotalMinor, 50000);
    expect(composition.positiveTotalMinor, 100000);
    expect(composition.negativeOffsetMinor, 50000);
    expect(composition.chartEntries.map((entry) => entry.name), ['Makanan']);
    expect(
      composition.entries.firstWhere((entry) => entry.name == 'Belanja').amountMinor,
      -50000,
    );
  });

  test('income composition equals dashboard monthly income', () async {
    final bank = await repo.createAccount(
      name: 'Income Bank',
      accountClass: AccountClass.asset,
      accountType: AccountType.bank,
    );
    final salary = await incomeCategory('Gaji');
    final bonus = await incomeCategory('Bonus');
    await repo.createIncome(
      amountMinor: 5000000,
      accountId: bank,
      categoryId: salary,
      occurredAt: DateTime(2026, 9, 1),
    );
    await repo.createIncome(
      amountMinor: 750000,
      accountId: bank,
      categoryId: bonus,
      occurredAt: DateTime(2026, 9, 3),
    );

    final dashboard = await repo.dashboard(now: DateTime(2026, 9, 3));
    final composition = await service.month(
      CategoryType.income,
      now: DateTime(2026, 9, 3),
    );

    expect(composition.netTotalMinor, dashboard.incomePeriodMinor);
    expect(composition.netTotalMinor, 5750000);
    expect(composition.negativeOffsetMinor, 0);
  });
}
