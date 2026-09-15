import 'package:arus_finance/core/db/app_database.dart';
import 'package:arus_finance/core/db/system_category_bindings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('system category backfill binds the oldest exact built-in category', () async {
    final db = AppDatabase.inMemory();
    addTearDown(db.close);
    await db.open();

    const oldId = '00000000-0000-0000-0000-000000000001';
    const newerId = '00000000-0000-0000-0000-000000000002';
    db.db.execute(
      '''INSERT INTO categories(id,type,name,created_at,updated_at,version)
         VALUES (?,?,?,?,?,1)''',
      [oldId, 'EXPENSE', 'Biaya Transfer', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z'],
    );
    db.db.execute(
      '''INSERT INTO categories(id,type,name,created_at,updated_at,version)
         VALUES (?,?,?,?,?,1)''',
      [newerId, 'EXPENSE', 'Biaya Transfer', '2026-02-01T00:00:00Z', '2026-02-01T00:00:00Z'],
    );

    backfillSystemCategoryBindings(db.db);

    final row = db.db.select(
      "SELECT category_id FROM system_category_bindings WHERE system_key='expense.transfer_fee'",
    ).single;
    expect(row['category_id'], oldId);
  });

  test('system category backfill never replaces an existing stable binding', () async {
    final db = AppDatabase.inMemory();
    addTearDown(db.close);
    await db.open();

    const originalId = '00000000-0000-0000-0000-000000000010';
    const duplicateId = '00000000-0000-0000-0000-000000000011';
    for (final values in <List<Object?>>[
      [originalId, 'EXPENSE', 'Biaya Transfer', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z'],
      [duplicateId, 'EXPENSE', 'Biaya Transfer', '2026-02-01T00:00:00Z', '2026-02-01T00:00:00Z'],
    ]) {
      db.db.execute(
        '''INSERT INTO categories(id,type,name,created_at,updated_at,version)
           VALUES (?,?,?,?,?,1)''',
        values,
      );
    }
    db.db.execute(
      'INSERT INTO system_category_bindings(system_key,category_id) VALUES (?,?)',
      ['expense.transfer_fee', duplicateId],
    );

    backfillSystemCategoryBindings(db.db);

    final row = db.db.select(
      "SELECT category_id FROM system_category_bindings WHERE system_key='expense.transfer_fee'",
    ).single;
    expect(row['category_id'], duplicateId);
  });
}
