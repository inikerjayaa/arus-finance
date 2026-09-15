import 'package:arus_finance/domain/enums.dart';
import 'package:arus_finance/features/home/category_donut_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('donut groups categories after top five into Kategori lain', (
    tester,
  ) async {
    CategoryType selected = CategoryType.expense;
    final slices = <CategoryDonutSlice>[
      const CategoryDonutSlice(
        label: 'Makanan',
        amountMinor: 500000,
        color: Colors.red,
      ),
      const CategoryDonutSlice(
        label: 'Transport',
        amountMinor: 400000,
        color: Colors.blue,
      ),
      const CategoryDonutSlice(
        label: 'Belanja',
        amountMinor: 300000,
        color: Colors.purple,
      ),
      const CategoryDonutSlice(
        label: 'Rumah',
        amountMinor: 200000,
        color: Colors.green,
      ),
      const CategoryDonutSlice(
        label: 'Tagihan',
        amountMinor: 100000,
        color: Colors.amber,
      ),
      const CategoryDonutSlice(
        label: 'Hiburan',
        amountMinor: 90000,
        color: Colors.pink,
      ),
      const CategoryDonutSlice(
        label: 'Travel',
        amountMinor: 10000,
        color: Colors.cyan,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CategoryDonutCard(
              selectedType: selected,
              onTypeChanged: (value) => selected = value,
              netTotalMinor: 1600000,
              positiveTotalMinor: 1600000,
              refundOffsetMinor: 0,
              currency: 'IDR',
              slices: slices,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Komposisi Pengeluaran'), findsOneWidget);
    expect(find.text('Makanan'), findsOneWidget);
    expect(find.text('Tagihan'), findsOneWidget);
    expect(find.text('Kategori lain'), findsOneWidget);
    expect(find.text('Hiburan'), findsNothing);
    expect(find.text('Travel'), findsNothing);

    await tester.tap(find.text('Masuk'));
    await tester.pump();
    expect(selected, CategoryType.income);
  });

  testWidgets('donut explains refund offsets instead of drawing negative slices', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CategoryDonutCard(
              selectedType: CategoryType.expense,
              onTypeChanged: (_) {},
              netTotalMinor: 75000,
              positiveTotalMinor: 100000,
              refundOffsetMinor: 25000,
              currency: 'IDR',
              slices: const [
                CategoryDonutSlice(
                  label: 'Makanan',
                  amountMinor: 100000,
                  color: Colors.orange,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Refund bulan ini mengurangi total'), findsOneWidget);
    expect(find.textContaining('25.000'), findsWidgets);
    expect(find.textContaining('75.000'), findsWidgets);
  });
}
