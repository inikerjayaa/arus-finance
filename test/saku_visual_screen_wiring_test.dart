import 'package:arus_finance/app_controller.dart';
import 'package:arus_finance/core/db/app_database.dart';
import 'package:arus_finance/core/services/visual_identity_controller_access.dart';
import 'package:arus_finance/core/services/visual_identity_store.dart';
import 'package:arus_finance/data/local_finance_repository.dart';
import 'package:arus_finance/domain/enums.dart';
import 'package:arus_finance/features/accounts/accounts_screen.dart';
import 'package:arus_finance/features/settings/categories_screen.dart';
import 'package:arus_finance/shared/app_scope.dart';
import 'package:arus_finance/shared/saku_visual_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('account list renders persisted SAKU brand visual identity', (
    tester,
  ) async {
    final database = AppDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalFinanceRepository(database);
    await repository.initialize();
    final controller = AppController(repository);
    final visuals = VisualIdentityStore(database);
    controller.visualIdentityStore = visuals;
    await controller.refresh();

    final cash = controller.accounts.firstWhere(
      (account) => account.accountType == AccountType.cash,
    );
    await visuals.setAccount(
      accountId: cash.id,
      iconKey: 'brand:bca',
      colorKey: 'blue',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AppScope(
          controller: controller,
          child: const AccountsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final rendered = tester.widgetList<SakuVisualIcon>(
      find.byType(SakuVisualIcon),
    );
    expect(rendered.any((widget) => widget.iconKey == 'brand:bca'), isTrue);
  });

  testWidgets('category list renders persisted SAKU brand visual identity', (
    tester,
  ) async {
    final database = AppDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalFinanceRepository(database);
    await repository.initialize();
    final controller = AppController(repository);
    final visuals = VisualIdentityStore(database);
    controller.visualIdentityStore = visuals;
    await controller.refresh();

    final food = controller.expenseCategories.firstWhere(
      (category) => category.name == 'Makanan',
    );
    await visuals.setCategory(
      categoryId: food.id,
      iconKey: 'brand:gojek',
      colorKey: 'green',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AppScope(
          controller: controller,
          child: const CategoriesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final rendered = tester.widgetList<SakuVisualIcon>(
      find.byType(SakuVisualIcon),
    );
    expect(rendered.any((widget) => widget.iconKey == 'brand:gojek'), isTrue);
  });
}
