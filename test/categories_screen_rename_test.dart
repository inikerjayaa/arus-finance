import 'package:arus_finance/app_controller.dart';
import 'package:arus_finance/core/db/app_database.dart';
import 'package:arus_finance/core/services/category_maintenance_controller_access.dart';
import 'package:arus_finance/core/services/category_maintenance_service.dart';
import 'package:arus_finance/data/local_finance_repository.dart';
import 'package:arus_finance/features/settings/categories_screen.dart';
import 'package:arus_finance/shared/app_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('category menu renames the same category entity', (tester) async {
    final database = AppDatabase.inMemory();
    final repository = LocalFinanceRepository(database);
    await repository.initialize();
    addTearDown(database.close);

    final controller = AppController(repository);
    controller.categoryMaintenanceService = CategoryMaintenanceService(database);
    await controller.refresh();

    final original = database.db.select(
      "SELECT id,system_key FROM categories WHERE system_key='expense.food'",
    ).single;
    final originalId = original['id'] as String;

    await tester.pumpWidget(
      MaterialApp(
        home: AppScope(
          controller: controller,
          child: const CategoriesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final food = find.text('Makanan');
    expect(food, findsOneWidget);
    await tester.ensureVisible(food);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Aksi kategori Makanan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ubah nama'));
    await tester.pumpAndSettle();

    final field = find.byType(TextFormField);
    expect(field, findsOneWidget);
    await tester.enterText(field, 'Kuliner Harian');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(find.text('Kuliner Harian'), findsOneWidget);
    expect(find.text('Makanan'), findsNothing);

    final renamed = database.db.select(
      'SELECT id,name,system_key FROM categories WHERE id=?',
      [originalId],
    ).single;
    expect(renamed['id'], originalId);
    expect(renamed['name'], 'Kuliner Harian');
    expect(renamed['system_key'], 'expense.food');
  });

  testWidgets('category FAB opens add dialog for the active tab', (tester) async {
    final database = AppDatabase.inMemory();
    final repository = LocalFinanceRepository(database);
    await repository.initialize();
    addTearDown(database.close);

    final controller = AppController(repository);
    await controller.refresh();

    await tester.pumpWidget(
      MaterialApp(
        home: AppScope(
          controller: controller,
          child: const CategoriesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('Kategori pengeluaran'), findsOneWidget);
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pemasukan'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('Kategori pemasukan'), findsOneWidget);
  });
}
