import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arus_finance/domain/enums.dart';
import 'package:arus_finance/shared/category_visuals.dart';

void main() {
  test('expense category names resolve to stable canonical icons', () {
    expect(
      CategoryVisuals.iconForName('Makanan', type: CategoryType.expense),
      Icons.restaurant_rounded,
    );
    expect(
      CategoryVisuals.iconForName('Transportasi', type: CategoryType.expense),
      Icons.directions_car_rounded,
    );
    expect(
      CategoryVisuals.iconForName('Tagihan listrik', type: CategoryType.expense),
      Icons.receipt_long_rounded,
    );
  });

  test('income and expense fallbacks remain visually distinct', () {
    expect(
      CategoryVisuals.iconForName('Lainnya', type: CategoryType.income),
      Icons.south_west_rounded,
    );
    expect(
      CategoryVisuals.iconForName('Lainnya', type: CategoryType.expense),
      Icons.category_rounded,
    );
  });
}
