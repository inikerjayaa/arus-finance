import 'package:arus_finance/app_controller.dart';
import 'package:arus_finance/core/db/app_database.dart';
import 'package:arus_finance/core/services/category_composition_controller_access.dart';
import 'package:arus_finance/core/services/category_composition_service.dart';
import 'package:arus_finance/core/services/visual_identity_controller_access.dart';
import 'package:arus_finance/core/services/visual_identity_store.dart';
import 'package:arus_finance/data/local_finance_repository.dart';
import 'package:arus_finance/domain/enums.dart';
import 'package:arus_finance/features/home/home_category_composition_card.dart';
import 'package:arus_finance/shared/app_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Home donut reads ledger and category visual identity', (tester) async {
    final db = AppDatabase.inMemory();
    final repository = LocalFinanceRepository(db);
    await repository.initialize();

    final accounts = await repository.listAccounts();
    final categories = await repository.listCategories(
      type: CategoryType.expense,
    );
    final food = categories.firstWhere((category) => category.name == 'Makanan');

    await repository.createExpense(
      amountMinor: 125000,
      accountId: accounts.first.id,
      categoryId: food.id,
      occurredAt: DateTime.now(),
      note: 'Makan siang',
    );

    final controller = AppController(repository);
    final visuals = VisualIdentityStore(db);
    await visuals.ensureBuiltInDefaults();
    controller.visualIdentityStore = visuals;
    controller.categoryCompositionService = CategoryCompositionService(db);
    await controller.refresh();

    await tester.pumpWidget(
      MaterialApp(
        home: AppScope(
          controller: controller,
          child: Scaffold(
            body: HomeCategoryCompositionCard(
              controller: controller,
              currency: 'IDR',
              refreshMarker: controller.dashboardData!,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Komposisi Pengeluaran'), findsOneWidget);
    expect(find.text('Makanan'), findsOneWidget);
    expect(find.byIcon(Icons.restaurant_rounded), findsOneWidget);

    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();

    expect(find.text('Komposisi Pemasukan'), findsOneWidget);
    expect(find.text('Belum ada pemasukan bulan ini.'), findsOneWidget);

    db.close();
  });
}
