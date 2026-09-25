import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Quick Add uses the canonical category picker', () {
    final source = File('lib/features/quick_add/quick_add_sheet.dart').readAsStringSync();

    expect(source, contains("import '../../shared/category_choice_tile.dart';"));
    expect(source, contains('showCategoryChoicePicker('));
    expect(source, contains('categories: categories'));
    expect(source, contains('selectedId: _categoryId'));

    final categoryBlockStart = source.indexOf("label: 'Kategori'");
    expect(categoryBlockStart, greaterThanOrEqualTo(0));
    final categoryBlockEnd = source.indexOf('OutlinedButton.icon(', categoryBlockStart);
    expect(categoryBlockEnd, greaterThan(categoryBlockStart));
    final categoryBlock = source.substring(categoryBlockStart, categoryBlockEnd);
    expect(categoryBlock, isNot(contains('_pickChoice(')));
  });
}
