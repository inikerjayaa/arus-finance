import '../../domain/enums.dart';
import '../db/app_database.dart';

class CategoryCompositionEntry {
  const CategoryCompositionEntry({
    required this.categoryId,
    required this.name,
    required this.amountMinor,
  });

  final String categoryId;
  final String name;

  /// Signed net amount for this category in the selected period.
  /// Expense refunds can make this negative when a prior-period expense is
  /// refunded in the current month.
  final int amountMinor;

  bool get isPositive => amountMinor > 0;
  bool get isNegative => amountMinor < 0;
}

class CategoryComposition {
  const CategoryComposition({
    required this.type,
    required this.periodStart,
    required this.periodEnd,
    required this.entries,
  });

  final CategoryType type;
  final DateTime periodStart;
  final DateTime periodEnd;
  final List<CategoryCompositionEntry> entries;

  int get netTotalMinor =>
      entries.fold(0, (total, entry) => total + entry.amountMinor);

  int get positiveTotalMinor => entries
      .where((entry) => entry.isPositive)
      .fold(0, (total, entry) => total + entry.amountMinor);

  int get negativeOffsetMinor => entries
      .where((entry) => entry.isNegative)
      .fold(0, (total, entry) => total + entry.amountMinor.abs());

  List<CategoryCompositionEntry> get chartEntries =>
      entries.where((entry) => entry.isPositive).toList(growable: false);
}

class CategoryCompositionService {
  CategoryCompositionService(this._database);

  final AppDatabase _database;

  Future<CategoryComposition> month(
    CategoryType type, {
    DateTime? now,
  }) async {
    await _database.open();
    final current = (now ?? DateTime.now()).toLocal();
    final start = DateTime(current.year, current.month, 1);
    final end = DateTime(current.year, current.month, current.day);
    final startKey = _localDate(start);
    final endKey = _localDate(end);

    final entries = _database.readSnapshot((db) {
      final rows = type == CategoryType.expense
          ? db.select(
              '''SELECT c.id AS category_id,c.name,
                        SUM(CASE
                          WHEN t.type='EXPENSE' THEN s.amount_minor
                          WHEN t.type='REFUND' THEN -s.amount_minor
                          ELSE 0
                        END) AS total
                 FROM transactions t
                 JOIN transaction_splits s ON s.transaction_id=t.id
                 JOIN categories c ON c.id=s.category_id
                 WHERE t.status='POSTED'
                   AND t.deleted_at IS NULL
                   AND t.local_date>=?
                   AND t.local_date<=?
                   AND t.type IN ('EXPENSE','REFUND')
                 GROUP BY c.id
                 HAVING total != 0
                 ORDER BY total DESC,c.name COLLATE NOCASE''',
              [startKey, endKey],
            )
          : db.select(
              '''SELECT c.id AS category_id,c.name,
                        SUM(s.amount_minor) AS total
                 FROM transactions t
                 JOIN transaction_splits s ON s.transaction_id=t.id
                 JOIN categories c ON c.id=s.category_id
                 WHERE t.status='POSTED'
                   AND t.deleted_at IS NULL
                   AND t.local_date>=?
                   AND t.local_date<=?
                   AND t.type='INCOME'
                 GROUP BY c.id
                 HAVING total != 0
                 ORDER BY total DESC,c.name COLLATE NOCASE''',
              [startKey, endKey],
            );
      return rows
          .map(
            (row) => CategoryCompositionEntry(
              categoryId: row['category_id'] as String,
              name: row['name'] as String,
              amountMinor: row['total'] as int,
            ),
          )
          .toList(growable: false);
    });

    return CategoryComposition(
      type: type,
      periodStart: start,
      periodEnd: end,
      entries: List.unmodifiable(entries),
    );
  }

  String _localDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
