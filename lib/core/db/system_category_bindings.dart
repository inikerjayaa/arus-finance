import 'package:sqlite3/sqlite3.dart';

class SystemCategoryDefinition {
  const SystemCategoryDefinition({
    required this.key,
    required this.type,
    required this.defaultName,
  });

  final String key;
  final String type;
  final String defaultName;
}

const List<SystemCategoryDefinition> kSystemCategoryDefinitions = [
  SystemCategoryDefinition(
    key: 'expense.food',
    type: 'EXPENSE',
    defaultName: 'Makanan',
  ),
  SystemCategoryDefinition(
    key: 'expense.transport',
    type: 'EXPENSE',
    defaultName: 'Transport',
  ),
  SystemCategoryDefinition(
    key: 'expense.shopping',
    type: 'EXPENSE',
    defaultName: 'Belanja',
  ),
  SystemCategoryDefinition(
    key: 'expense.home',
    type: 'EXPENSE',
    defaultName: 'Rumah',
  ),
  SystemCategoryDefinition(
    key: 'expense.bills',
    type: 'EXPENSE',
    defaultName: 'Tagihan',
  ),
  SystemCategoryDefinition(
    key: 'expense.health',
    type: 'EXPENSE',
    defaultName: 'Kesehatan',
  ),
  SystemCategoryDefinition(
    key: 'expense.entertainment',
    type: 'EXPENSE',
    defaultName: 'Hiburan',
  ),
  SystemCategoryDefinition(
    key: 'expense.education',
    type: 'EXPENSE',
    defaultName: 'Pendidikan',
  ),
  SystemCategoryDefinition(
    key: 'expense.travel',
    type: 'EXPENSE',
    defaultName: 'Travel',
  ),
  SystemCategoryDefinition(
    key: 'expense.transfer_fee',
    type: 'EXPENSE',
    defaultName: 'Biaya Transfer',
  ),
  SystemCategoryDefinition(
    key: 'expense.loan_interest',
    type: 'EXPENSE',
    defaultName: 'Bunga Pinjaman',
  ),
  SystemCategoryDefinition(
    key: 'expense.loan_fee',
    type: 'EXPENSE',
    defaultName: 'Biaya Pinjaman',
  ),
  SystemCategoryDefinition(
    key: 'expense.other',
    type: 'EXPENSE',
    defaultName: 'Lainnya',
  ),
  SystemCategoryDefinition(
    key: 'income.salary',
    type: 'INCOME',
    defaultName: 'Gaji',
  ),
  SystemCategoryDefinition(
    key: 'income.bonus',
    type: 'INCOME',
    defaultName: 'Bonus',
  ),
  SystemCategoryDefinition(
    key: 'income.sales',
    type: 'INCOME',
    defaultName: 'Penjualan',
  ),
  SystemCategoryDefinition(
    key: 'income.gift',
    type: 'INCOME',
    defaultName: 'Hadiah',
  ),
  SystemCategoryDefinition(
    key: 'income.other',
    type: 'INCOME',
    defaultName: 'Lainnya',
  ),
];

void backfillSystemCategoryBindings(Database db) {
  for (final definition in kSystemCategoryDefinitions) {
    final existing = db.select(
      'SELECT category_id FROM system_category_bindings WHERE system_key=? LIMIT 1',
      [definition.key],
    );
    if (existing.isNotEmpty) continue;

    // Before rename support existed, seeded names were immutable. Choosing the
    // oldest exact built-in name makes legacy upgrades deterministic even if a
    // user archived the seed and later created another category with that name.
    final candidates = db.select(
      '''SELECT id FROM categories
         WHERE type=? AND lower(trim(name))=lower(?)
         ORDER BY created_at ASC, rowid ASC
         LIMIT 1''',
      [definition.type, definition.defaultName],
    );
    if (candidates.isEmpty) continue;

    db.execute(
      '''INSERT OR IGNORE INTO system_category_bindings(system_key,category_id)
         VALUES (?,?)''',
      [definition.key, candidates.first['id'] as String],
    );
  }
}

SystemCategoryDefinition? systemCategoryDefinition(
  String type,
  String defaultName,
) {
  final normalizedName = defaultName.trim().toLowerCase();
  for (final definition in kSystemCategoryDefinitions) {
    if (definition.type == type &&
        definition.defaultName.toLowerCase() == normalizedName) {
      return definition;
    }
  }
  return null;
}
