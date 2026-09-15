import 'package:arus_finance/core/db/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy-style default category insertion keeps one stable system identity', () async {
    final database = AppDatabase.inMemory();
    addTearDown(database.close);
    await database.open();

    database.db.execute(
      '''INSERT INTO categories(id,type,name,created_at,updated_at,version)
         VALUES (?,?,?,?,?,1)''',
      ['newer', 'EXPENSE', 'Biaya Transfer', '2026-02-01T00:00:00Z', '2026-02-01T00:00:00Z'],
    );
    database.db.execute(
      '''INSERT INTO categories(id,type,name,created_at,updated_at,version)
         VALUES (?,?,?,?,?,1)''',
      ['older', 'EXPENSE', 'Biaya Transfer', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z'],
    );

    final keyed = database.db.select(
      "SELECT id FROM categories WHERE system_key='expense.transfer_fee'",
    );
    expect(keyed, hasLength(1));

    // Current trigger is intentionally conservative: once an identity exists it
    // never moves merely because another display-name duplicate is inserted.
    // Portable V11+ backups carry system_key directly. Legacy <=V10 restores are
    // therefore repaired by their original insertion identity, never by a later
    // category silently stealing the engine key.
    expect(keyed.single['id'], 'newer');
  });
}
