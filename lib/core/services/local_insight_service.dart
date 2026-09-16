import '../db/app_database.dart';

/// Small, deterministic on-device assistant for the Home screen.
///
/// This is deliberately not a cloud/LLM dependency. It reads the encrypted
/// local ledger and only emits an insight when the evidence is strong enough.
class LocalInsight {
  const LocalInsight({
    required this.kind,
    required this.title,
    required this.message,
  });

  final String kind;
  final String title;
  final String message;
}

class LocalInsightService {
  LocalInsightService(this._database);

  final AppDatabase _database;

  Future<LocalInsight?> build({DateTime? now}) async {
    await _database.open();
    final current = (now ?? DateTime.now()).toLocal();
    final today = _localDate(current);

    final dailyCategory = _dailyCategorySpike(current, today);
    if (dailyCategory != null) return dailyCategory;

    final dailyTotal = _dailyTotalSpike(current, today);
    if (dailyTotal != null) return dailyTotal;

    final monthlyCategory = _monthlyDominantCategory(current, today);
    if (monthlyCategory != null) return monthlyCategory;

    return _monthlyCashFlow(current, today);
  }

  LocalInsight? _dailyCategorySpike(DateTime current, String today) {
    final todayRows = _database.readSnapshot(
      (db) => db.select(
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
             AND t.local_date=?
             AND t.type IN ('EXPENSE','REFUND')
           GROUP BY c.id
           HAVING total > 0
           ORDER BY total DESC,c.name COLLATE NOCASE''',
        [today],
      ),
    );
    if (todayRows.isEmpty) return null;

    final historyStart = _localDate(current.subtract(const Duration(days: 14)));
    for (final row in todayRows) {
      final categoryId = row['category_id'] as String;
      final name = row['name'] as String;
      final todayAmount = row['total'] as int;
      final history = _database.readSnapshot(
        (db) => db.select(
          '''SELECT t.local_date AS day,
                    SUM(CASE
                      WHEN t.type='EXPENSE' THEN s.amount_minor
                      WHEN t.type='REFUND' THEN -s.amount_minor
                      ELSE 0
                    END) AS total
             FROM transactions t
             JOIN transaction_splits s ON s.transaction_id=t.id
             WHERE s.category_id=?
               AND t.status='POSTED'
               AND t.deleted_at IS NULL
               AND t.local_date>=?
               AND t.local_date<?
               AND t.type IN ('EXPENSE','REFUND')
             GROUP BY t.local_date
             HAVING total > 0
             ORDER BY t.local_date DESC''',
          [categoryId, historyStart, today],
        ),
      );
      if (history.length < 4) continue;
      final total = history.fold<int>(
        0,
        (sum, item) => sum + (item['total'] as int),
      );
      final average = total / history.length;
      if (average <= 0 || todayAmount < average * 2) continue;
      final ratio = todayAmount / average;
      return LocalInsight(
        kind: 'daily_category_spike',
        title: 'Pengeluaran $name sedang tinggi',
        message:
            'Hari ini sekitar ${ratio.toStringAsFixed(1)}× rata-rata hari aktifmu untuk $name dalam 14 hari terakhir.',
      );
    }
    return null;
  }

  LocalInsight? _dailyTotalSpike(DateTime current, String today) {
    final todayAmount = _expenseNetForDay(today);
    if (todayAmount <= 0) return null;
    final start = _localDate(current.subtract(const Duration(days: 7)));
    final history = _database.readSnapshot(
      (db) => db.select(
        '''SELECT t.local_date AS day,
                  SUM(CASE
                    WHEN t.type='EXPENSE' THEN s.amount_minor
                    WHEN t.type='REFUND' THEN -s.amount_minor
                    ELSE 0
                  END) AS total
           FROM transactions t
           JOIN transaction_splits s ON s.transaction_id=t.id
           WHERE t.status='POSTED'
             AND t.deleted_at IS NULL
             AND t.local_date>=?
             AND t.local_date<?
             AND t.type IN ('EXPENSE','REFUND')
           GROUP BY t.local_date
           HAVING total > 0
           ORDER BY t.local_date DESC''',
        [start, today],
      ),
    );
    if (history.length < 4) return null;
    final total = history.fold<int>(
      0,
      (sum, item) => sum + (item['total'] as int),
    );
    final average = total / history.length;
    if (average <= 0 || todayAmount < average * 1.75) return null;
    final ratio = todayAmount / average;
    return LocalInsight(
      kind: 'daily_total_spike',
      title: 'Hari ini pengeluaranmu lebih tinggi',
      message:
          'Total hari ini sekitar ${ratio.toStringAsFixed(1)}× rata-rata hari aktif dalam 7 hari terakhir.',
    );
  }

  LocalInsight? _monthlyDominantCategory(DateTime current, String today) {
    final monthStart = _localDate(DateTime(current.year, current.month, 1));
    final rows = _database.readSnapshot(
      (db) => db.select(
        '''SELECT c.name,
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
           HAVING total > 0
           ORDER BY total DESC,c.name COLLATE NOCASE''',
        [monthStart, today],
      ),
    );
    if (rows.isEmpty) return null;
    final total = rows.fold<int>(
      0,
      (sum, row) => sum + (row['total'] as int),
    );
    if (total <= 0) return null;
    final top = rows.first;
    final topAmount = top['total'] as int;
    final share = topAmount / total;
    if (share < .35) return null;
    final percent = (share * 100).round();
    return LocalInsight(
      kind: 'monthly_dominant_category',
      title: '${top['name']} paling besar bulan ini',
      message: '$percent% pengeluaran bulan ini ada di kategori ${top['name']}.',
    );
  }

  LocalInsight? _monthlyCashFlow(DateTime current, String today) {
    final monthStart = _localDate(DateTime(current.year, current.month, 1));
    final spending = _database.readSnapshot(
      (db) => db.select(
        '''SELECT COALESCE(SUM(CASE
                  WHEN t.type='EXPENSE' THEN s.amount_minor
                  WHEN t.type='REFUND' THEN -s.amount_minor
                  ELSE 0
                END),0) AS total
           FROM transactions t
           JOIN transaction_splits s ON s.transaction_id=t.id
           WHERE t.status='POSTED'
             AND t.deleted_at IS NULL
             AND t.local_date>=?
             AND t.local_date<=?
             AND t.type IN ('EXPENSE','REFUND')''',
        [monthStart, today],
      ).first['total'] as int,
    );
    final income = _database.readSnapshot(
      (db) => db.select(
        '''SELECT COALESCE(SUM(s.amount_minor),0) AS total
           FROM transactions t
           JOIN transaction_splits s ON s.transaction_id=t.id
           WHERE t.status='POSTED'
             AND t.deleted_at IS NULL
             AND t.local_date>=?
             AND t.local_date<=?
             AND t.type='INCOME' ''',
        [monthStart, today],
      ).first['total'] as int,
    );
    if (income <= 0 || spending <= income) return null;
    final percent = ((spending / income) * 100).round();
    return LocalInsight(
      kind: 'monthly_cash_flow',
      title: 'Pengeluaran melampaui pemasukan bulan ini',
      message:
          'Pengeluaran bulan berjalan sudah sekitar $percent% dari pemasukan yang tercatat.',
    );
  }

  int _expenseNetForDay(String day) {
    return _database.readSnapshot(
      (db) => db.select(
        '''SELECT COALESCE(SUM(CASE
                  WHEN t.type='EXPENSE' THEN s.amount_minor
                  WHEN t.type='REFUND' THEN -s.amount_minor
                  ELSE 0
                END),0) AS total
           FROM transactions t
           JOIN transaction_splits s ON s.transaction_id=t.id
           WHERE t.status='POSTED'
             AND t.deleted_at IS NULL
             AND t.local_date=?
             AND t.type IN ('EXPENSE','REFUND')''',
        [day],
      ).first['total'] as int,
    );
  }

  String _localDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
