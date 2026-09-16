import 'package:arus_finance/app_controller.dart';
import 'package:arus_finance/core/db/app_database.dart';
import 'package:arus_finance/data/local_finance_repository.dart';
import 'package:arus_finance/domain/enums.dart';
import 'package:arus_finance/features/home/home_screen.dart';
import 'package:arus_finance/shared/app_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'primary highlight shows total active assets with only income and spending below',
    (tester) async {
      final database = AppDatabase.inMemory();
      addTearDown(database.close);
      final repository = LocalFinanceRepository(
        database,
        clock: () => DateTime(2026, 9, 15, 12),
      );
      await repository.initialize();

      final cash = (await repository.listAccounts()).first;
      await repository.createAccount(
        name: 'Bank Utama',
        accountClass: AccountClass.asset,
        accountType: AccountType.bank,
        openingBalanceMinor: 1000000,
      );
      await repository.createAccount(
        name: 'Investasi',
        accountClass: AccountClass.asset,
        accountType: AccountType.investment,
        openingBalanceMinor: 2000000,
      );
      final expense = (await repository.listCategories(
        type: CategoryType.expense,
      ))
          .firstWhere((category) => category.name == 'Makanan');
      final income = (await repository.listCategories(
        type: CategoryType.income,
      ))
          .firstWhere((category) => category.name == 'Gaji');
      await repository.createIncome(
        amountMinor: 500000,
        accountId: cash.id,
        categoryId: income.id,
        occurredAt: DateTime(2026, 9, 15, 9),
      );
      await repository.createExpense(
        amountMinor: 35000,
        accountId: cash.id,
        categoryId: expense.id,
        occurredAt: DateTime(2026, 9, 15, 10),
      );

      final controller = AppController(repository);
      await controller.refresh();

      await tester.pumpWidget(
        MaterialApp(
          home: AppScope(
            controller: controller,
            child: const HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Total Saldo'), findsOneWidget);
      expect(find.text('Pemasukan'), findsOneWidget);
      expect(find.text('Pengeluaran'), findsOneWidget);
      expect(find.textContaining('3.465.000'), findsWidgets);
      expect(find.textContaining('500.000'), findsWidgets);
      expect(find.textContaining('35.000'), findsWidgets);

      // Available-to-spend remains an accounting concept, but it must not
      // compete with the three headline numbers in the primary Home card.
      expect(find.textContaining('1.465.000'), findsNothing);
      expect(find.textContaining('Tersedia untuk dibelanjakan'), findsNothing);
      expect(find.text('Saldo tersedia'), findsNothing);
    },
  );
}
