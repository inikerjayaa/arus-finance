import 'package:arus_finance/domain/enums.dart';
import 'package:arus_finance/domain/models.dart';
import 'package:arus_finance/shared/category_choice_tile.dart';
import 'package:arus_finance/shared/category_visuals.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('category choice keeps canonical icon when selected', (tester) async {
    final category = Category(
      id: 'food',
      name: 'Makan',
      type: CategoryType.expense,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CategoryChoiceTile(
            category: category,
            selected: true,
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.byIcon(CategoryVisuals.iconFor(category)), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
    expect(find.text('Makan'), findsOneWidget);
  });
}
