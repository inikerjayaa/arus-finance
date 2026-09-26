import '../db/app_database.dart';
import 'local_insight_service.dart';

/// V50 extension of the deterministic local insight engine.
///
/// Keeps the existing proven anomaly/cash-flow logic while adding recurring
/// expense detection. This remains read-only and performs no network I/O.
class EnhancedLocalInsightService extends LocalInsightService {
  EnhancedLocalInsightService(this._database) : super(_database);

  final AppDatabase _database;

  @override
  Future<LocalInsight?> build({DateTime? now}) async {
    await _database.open();
    final current = (now ?? DateTime.now()).toLocal();
    final recurring = _recurringExpensePattern(current);
    if (recurring != null) return recurring;
    return super.build(now: current);
  }

  LocalInsight? _recurringExpensePattern(DateTime current) {
    final start = _localDate(current.subtract(const Duration(days: 120)));
    final rows = _database.readSnapshot(
      (db) => db.select(
        '''SELECT c.name AS category_name,
                  s.amount_minor AS amount_minor,
                  COUNT(*) AS occurrences,
                  MIN(t.local_date) AS first_day,
                  MAX(t.local_date) AS last_day
           FROM transactions t
           JOIN transaction_splits s ON s.transaction_id=t.id
           JOIN categories c ON c.id=s.category_id
           WHERE t.status='POSTED'
             AND t.deleted_at IS NULL
             AND t.type='EXPENSE'
             AND t.local_date>=?
             AND s.amount_minor>0
           GROUP BY c.id,s.amount_minor
           HAVING occurrences>=3
           ORDER BY occurrences DESC,last_day DESC
           LIMIT 8''',
        [start],
      ),
    );

    for (final row in rows) {
      final first = DateTime.tryParse(row['first_day'] as String? ?? '');
      final last = DateTime.tryParse(row['last_day'] as String? ?? '');
      if (first == null || last == null) continue;
      final occurrences = row['occurrences'] as int;
      final spanDays = last.difference(first).inDays;
      if (spanDays < 14 || occurrences < 3) continue;
      final averageGap = spanDays / (occurrences - 1);
      // Recurring behavior should be plausibly weekly through monthly. Very
      // dense purchases are ordinary habits, while very sparse matches are too
      // weak to call recurring.
      if (averageGap < 5 || averageGap > 45) continue;
      final category = row['category_name'] as String;
      final cadence = averageGap >= 20
          ? 'sekitar bulanan'
          : averageGap >= 10
              ? 'sekitar dua-mingguan'
              : 'sekitar mingguan';
      return LocalInsight(
        kind: 'recurring_expense_pattern',
        title: 'Ada pola pengeluaran rutin di $category',
        message:
            'SAKU menemukan $occurrences transaksi dengan nominal sama dalam 120 hari terakhir, dengan pola $cadence. Ini hanya deteksi lokal; transaksi tidak diubah otomatis.',
      );
    }
    return null;
  }

  String _localDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
