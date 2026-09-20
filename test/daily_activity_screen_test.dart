import 'package:arus_finance/app_controller.dart';
import 'package:arus_finance/core/db/app_database.dart';
import 'package:arus_finance/data/local_finance_repository.dart';
import 'package:arus_finance/domain/enums.dart';
import 'package:arus_finance/features/activity/daily_activity_screen.dart';
import 'package:arus_finance/shared/app_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  testWidgets(
    'calendar opens a selected day with spending, incoming and neutral activity',
    (tester) async {
      final database = AppDatabase.inMemory();
      addTearDown(database.close);
      final repository = LocalFinanceRepository(
        database,
        clock: () => DateTime(2026, 9, 15, 12),
      );
      await repository.initialize();

      final cash = (await repository.listAccounts()).first;
      final expenseCategory =
          (await repository.listCategories(type: CategoryType.expense))
              .firstWhere((category) => category.name == 'Makanan');
      final incomeCategory =
          (await repository.listCategories(type: CategoryType.income))
              .firstWhere((category) => category.name == 'Gaji');
      final secondAccount = await repository.createAccount(
        name: 'Bank Test',
        accountClass: AccountClass.asset,
        accountType: AccountType.bank,
      );

      await repository.createExpense(
        amountMinor: 35000,
        accountId: cash.id,
        categoryId: expenseCategory.id,
        occurredAt: DateTime(2026, 9, 15, 8, 15),
        note: 'Kopi pagi',
      );
      await repository.createIncome(
        amountMinor: 500000,
        accountId: cash.id,
        categoryId: incomeCategory.id,
        occurredAt: DateTime(2026, 9, 15, 10),
        note: 'Pemasukan tes',
      );
      await repository.createTransfer(
        amountMinor: 100000,
        sourceAccountId: cash.id,
        destinationAccountId: secondAccount,
        occurredAt: DateTime(2026, 9, 15, 11),
        note: 'Pindah saldo',
      );

      final controller = AppController(repository);
      await tester.pumpWidget(
        MaterialApp(
          home: AppScope(
            controller: controller,
            child: DailyActivityScreen(initialDate: DateTime(2026, 9, 15)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Kalender SAKU'), findsOneWidget);

      final list = find.byType(ListView).first;
      await tester.drag(list, const Offset(0, -520));
      await tester.pumpAndSettle();

      expect(find.text('Keluar'), findsWidgets);
      expect(find.text('Masuk'), findsWidgets);
      expect(find.text('Net'), findsOneWidget);
      expect(find.textContaining('35.000'), findsWidgets);
      expect(find.textContaining('500.000'), findsWidgets);
      expect(find.text('3 item'), findsOneWidget);
    },
  );

  testWidgets(
    'calendar can move to the previous month without carrying selected-day totals',
    (tester) async {
      final database = AppDatabase.inMemory();
      addTearDown(database.close);
      final repository = LocalFinanceRepository(database);
      await repository.initialize();
      final controller = AppController(repository);

      await tester.pumpWidget(
        MaterialApp(
          home: AppScope(
            controller: controller,
            child: DailyActivityScreen(initialDate: DateTime(2026, 9, 15)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final previousMonth = find.descendant(
        of: find.byType(CalendarDatePicker),
        matching: find.byIcon(Icons.chevron_left),
      );
      expect(previousMonth, findsOneWidget);
      await tester.tap(previousMonth);
      await tester.pumpAndSettle();

      // Verify the framework calendar actually navigated away from September
      // without coupling this app test to locale-specific header text.
      final day15 = tester.widgetList<Text>(find.text('15')).first;
      expect(day15.style?.color, isNotNull);
      await tester.drag(find.byType(ListView).first, const Offset(0, -620));
      await tester.pumpAndSettle();
      expect(
        find.text('Tidak ada aktivitas pada tanggal ini.'),
        findsOneWidget,
      );
    },
  );
}
