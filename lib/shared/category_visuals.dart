import 'package:flutter/material.dart';

import '../domain/enums.dart';
import '../domain/models.dart';

/// Single lightweight icon resolver for category surfaces.
///
/// Categories intentionally keep their existing persistence shape; icon choice
/// is derived locally from stable category identity/name so Quick Add, filters,
/// activity and other category surfaces can render the same visual without a
/// schema migration, network lookup, or extra dependency.
abstract final class CategoryVisuals {
  static IconData iconFor(Category category) => iconForName(
        category.name,
        type: category.type,
      );

  static IconData iconForName(String name, {required CategoryType type}) {
    final value = name.trim().toLowerCase();

    if (_has(value, const ['makan', 'food', 'restoran', 'restaurant'])) {
      return Icons.restaurant_rounded;
    }
    if (_has(value, const ['belanja', 'shopping', 'market', 'grocer'])) {
      return Icons.shopping_bag_rounded;
    }
    if (_has(value, const ['transport', 'bensin', 'fuel', 'parkir', 'tol'])) {
      return Icons.directions_car_rounded;
    }
    if (_has(value, const ['rumah', 'home', 'sewa', 'rent'])) {
      return Icons.home_rounded;
    }
    if (_has(value, const ['tagihan', 'bill', 'listrik', 'air', 'internet'])) {
      return Icons.receipt_long_rounded;
    }
    if (_has(value, const ['kesehatan', 'health', 'obat', 'medical'])) {
      return Icons.health_and_safety_rounded;
    }
    if (_has(value, const ['hiburan', 'entertainment', 'game', 'film'])) {
      return Icons.movie_rounded;
    }
    if (_has(value, const ['pendidikan', 'education', 'sekolah', 'kursus'])) {
      return Icons.school_rounded;
    }
    if (_has(value, const ['gaji', 'salary', 'upah'])) {
      return Icons.payments_rounded;
    }
    if (_has(value, const ['bonus', 'hadiah', 'gift'])) {
      return Icons.card_giftcard_rounded;
    }
    if (_has(value, const ['invest', 'dividen', 'interest', 'bunga'])) {
      return Icons.trending_up_rounded;
    }

    return type == CategoryType.income
        ? Icons.south_west_rounded
        : Icons.category_rounded;
  }

  static bool _has(String value, List<String> needles) =>
      needles.any(value.contains);
}
