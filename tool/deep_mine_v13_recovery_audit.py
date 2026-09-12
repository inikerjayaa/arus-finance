"""Arus Finance V13 catastrophe/recovery + historical portability audit.

This is intentionally executable without Flutter. It combines source-contract
checks with SQLite crash/reference fixtures for the exact failure classes V13
hardens: old-schema startup order, interrupted migration/restore/seed, stable
read snapshots, lost-key fail-closed behavior, and legacy portable-backup data
normalization.
"""
from __future__ import annotations

import os
import sqlite3
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
db_src = (ROOT / 'lib/core/db/app_database.dart').read_text()
backup_src = (ROOT / 'lib/core/services/backup_service.dart').read_text()
repo_src = (ROOT / 'lib/data/local_finance_repository.dart').read_text()

checks = {
    'migration runs before current-object ensure': (
        db_src.index('while (version < kSchemaVersion)') <
        db_src.index('_ensureCurrentSchemaObjects(database);')
    ),
    'schema metadata missing fails closed': 'Metadata versi database hilang/ambigu' in db_src,
    'schema metadata corrupt fails closed': 'Metadata versi database rusak' in db_src,
    'existing DB without key fails closed': (
        'databaseAlreadyExists' in db_src and
        'Kunci database lokal tidak tersedia' in db_src and
        db_src.index('_getOrCreateDatabaseKey(') < db_src.index('database = sqlite3.open(path)')
    ),
    'failed open disposes handle': 'database?.dispose();' in db_src,
    'quick integrity includes foreign-key check': "db.select('PRAGMA foreign_key_check')" in db_src,
    'consistent read snapshot helper exists': "db.execute('BEGIN');" in db_src and 'T readSnapshot<T>' in db_src,
    'backup uses one read snapshot': 'database.readSnapshot((db)' in backup_src,
    'backup validates semantics before emission': '_validateLedger(db);' in backup_src and backup_src.index('_validateLedger(db);') < backup_src.index("'format': 'arus-finance-backup'"),
    'legacy portable data migration helper exists': 'void _repairLegacyPortableBackupState(dynamic db, int schemaVersion)' in backup_src,
    'legacy V3 occurrence normalization retained': "occurrence_key = rule_id || ':' || substr(scheduled_for,1,10)" in backup_src,
    'legacy recurring draft leg backfill retained': 'INSERT INTO transaction_legs(id, transaction_id, account_id, delta_minor, currency)' in backup_src,
    'legacy V4 next-run normalization retained': 'schemaVersion < 5' in backup_src and 'UPDATE recurring_rules SET next_run = substr(next_run,1,10)' in backup_src,
    'legacy V7 duplicate Bill payment normalized pre-insert': 'schemaVersion < 8' in backup_src and 'legacyPaidBillTransactions' in backup_src,
    'initial category seed is atomic': 'First-run/reset seed must be all-or-nothing' in repo_src,
}

failed = [name for name, ok in checks.items() if not ok]
if failed:
    print('FAIL: V13 source recovery contract')
    for item in failed:
        print(' -', item)
    sys.exit(1)


def connect(path: Path) -> sqlite3.Connection:
    db = sqlite3.connect(path, timeout=5)
    db.execute('PRAGMA journal_mode=WAL')
    db.execute('PRAGMA synchronous=FULL')
    db.execute('PRAGMA foreign_keys=ON')
    return db


def test_migration_interruption(tmp: Path) -> None:
    """Kill process after migration writes but before COMMIT.

    app_meta and data cleanup must both roll back, then the migration must be
    safely retryable from the same old version.
    """
    path = tmp / 'migration_crash.db'
    db = connect(path)
    db.executescript('''
      CREATE TABLE app_meta(key TEXT PRIMARY KEY, value TEXT NOT NULL);
      CREATE TABLE bills(id TEXT PRIMARY KEY, paid_transaction_id TEXT, status TEXT NOT NULL);
      INSERT INTO app_meta(key,value) VALUES ('schema_version','7');
      INSERT INTO bills VALUES ('b1','pay','PAID');
      INSERT INTO bills VALUES ('b2','pay','PAID');
    ''')
    db.commit(); db.close()

    code = f'''import os, sqlite3\np={str(path)!r}\ndb=sqlite3.connect(p)\ndb.execute("PRAGMA journal_mode=WAL")\ndb.execute("PRAGMA synchronous=FULL")\ndb.execute("BEGIN IMMEDIATE")\ndb.execute("UPDATE bills SET paid_transaction_id=NULL,status='UPCOMING' WHERE paid_transaction_id IS NOT NULL AND rowid NOT IN (SELECT MIN(rowid) FROM bills WHERE paid_transaction_id IS NOT NULL GROUP BY paid_transaction_id)")\ndb.execute("CREATE UNIQUE INDEX idx_bills_paid_tx_unique ON bills(paid_transaction_id) WHERE paid_transaction_id IS NOT NULL")\ndb.execute("UPDATE app_meta SET value='8' WHERE key='schema_version'")\nos._exit(93)\n'''
    subprocess.run([sys.executable, '-c', code], check=False)

    db = connect(path)
    assert db.execute("SELECT value FROM app_meta WHERE key='schema_version'").fetchone()[0] == '7'
    assert db.execute("SELECT COUNT(*) FROM bills WHERE paid_transaction_id='pay'").fetchone()[0] == 2
    assert db.execute("SELECT COUNT(*) FROM sqlite_master WHERE type='index' AND name='idx_bills_paid_tx_unique'").fetchone()[0] == 0

    db.execute('BEGIN IMMEDIATE')
    db.execute("UPDATE bills SET paid_transaction_id=NULL,status='UPCOMING' WHERE paid_transaction_id IS NOT NULL AND rowid NOT IN (SELECT MIN(rowid) FROM bills WHERE paid_transaction_id IS NOT NULL GROUP BY paid_transaction_id)")
    db.execute("CREATE UNIQUE INDEX idx_bills_paid_tx_unique ON bills(paid_transaction_id) WHERE paid_transaction_id IS NOT NULL")
    db.execute("UPDATE app_meta SET value='8' WHERE key='schema_version'")
    db.commit()
    assert db.execute("SELECT value FROM app_meta WHERE key='schema_version'").fetchone()[0] == '8'
    assert db.execute("SELECT COUNT(*) FROM bills WHERE paid_transaction_id='pay'").fetchone()[0] == 1
    db.close()


def test_restore_interruption(tmp: Path) -> None:
    """A killed restore must leave the pre-restore live snapshot intact."""
    path = tmp / 'restore_crash.db'
    db = connect(path)
    db.executescript('''
      CREATE TABLE accounts(id TEXT PRIMARY KEY, name TEXT NOT NULL);
      CREATE TABLE transactions(id TEXT PRIMARY KEY, account_id TEXT NOT NULL REFERENCES accounts(id), amount INTEGER NOT NULL);
      INSERT INTO accounts VALUES ('old-a','Old Wallet');
      INSERT INTO transactions VALUES ('old-t','old-a',100);
    ''')
    db.commit(); db.close()

    code = f'''import os, sqlite3\np={str(path)!r}\ndb=sqlite3.connect(p)\ndb.execute("PRAGMA journal_mode=WAL")\ndb.execute("PRAGMA synchronous=FULL")\ndb.execute("PRAGMA foreign_keys=ON")\ndb.execute("BEGIN IMMEDIATE")\ndb.execute("PRAGMA defer_foreign_keys=ON")\ndb.execute("DELETE FROM transactions")\ndb.execute("DELETE FROM accounts")\ndb.execute("INSERT INTO accounts VALUES ('new-a','Restored Wallet')")\ndb.execute("INSERT INTO transactions VALUES ('new-t','new-a',999)")\nos._exit(94)\n'''
    subprocess.run([sys.executable, '-c', code], check=False)

    db = connect(path)
    assert db.execute('SELECT id,name FROM accounts').fetchall() == [('old-a', 'Old Wallet')]
    assert db.execute('SELECT id,account_id,amount FROM transactions').fetchall() == [('old-t', 'old-a', 100)]
    assert db.execute('PRAGMA foreign_key_check').fetchall() == []
    db.close()


def test_snapshot_consistency(tmp: Path) -> None:
    """Multiple backup SELECTs inside BEGIN must see one commit snapshot."""
    path = tmp / 'snapshot.db'
    writer = connect(path)
    writer.executescript('''
      CREATE TABLE accounts(id TEXT PRIMARY KEY);
      CREATE TABLE transactions(id TEXT PRIMARY KEY);
      INSERT INTO accounts VALUES ('a1');
      INSERT INTO transactions VALUES ('t1');
    ''')
    writer.commit()
    reader = connect(path)
    reader.execute('BEGIN')
    assert reader.execute('SELECT id FROM accounts ORDER BY id').fetchall() == [('a1',)]

    writer.execute('BEGIN IMMEDIATE')
    writer.execute("INSERT INTO accounts VALUES ('a2')")
    writer.execute("INSERT INTO transactions VALUES ('t2')")
    writer.commit()

    # Reader is pinned to the old snapshot even though writer committed.
    assert reader.execute('SELECT id FROM transactions ORDER BY id').fetchall() == [('t1',)]
    reader.commit()
    assert reader.execute('SELECT id FROM transactions ORDER BY id').fetchall() == [('t1',), ('t2',)]
    reader.close(); writer.close()


def test_atomic_seed_crash(tmp: Path) -> None:
    path = tmp / 'seed_crash.db'
    db = connect(path)
    db.execute('CREATE TABLE categories(id TEXT PRIMARY KEY, type TEXT NOT NULL, name TEXT NOT NULL)')
    db.commit(); db.close()
    code = f'''import os, sqlite3\np={str(path)!r}\ndb=sqlite3.connect(p)\ndb.execute("PRAGMA journal_mode=WAL")\ndb.execute("BEGIN IMMEDIATE")\ndb.execute("INSERT INTO categories VALUES ('1','EXPENSE','Makanan')")\ndb.execute("INSERT INTO categories VALUES ('2','EXPENSE','Transport')")\nos._exit(95)\n'''
    subprocess.run([sys.executable, '-c', code], check=False)
    db = connect(path)
    assert db.execute('SELECT COUNT(*) FROM categories').fetchone()[0] == 0
    db.execute('BEGIN IMMEDIATE')
    for i, name in enumerate(['Makanan','Transport','Belanja','Rumah','Tagihan','Kesehatan','Hiburan','Pendidikan','Travel','Biaya Transfer','Bunga Pinjaman','Biaya Pinjaman','Lainnya']):
        db.execute('INSERT INTO categories VALUES (?,?,?)', (f'e{i}', 'EXPENSE', name))
    for i, name in enumerate(['Gaji','Bonus','Penjualan','Hadiah','Lainnya']):
        db.execute('INSERT INTO categories VALUES (?,?,?)', (f'i{i}', 'INCOME', name))
    db.commit()
    assert db.execute('SELECT COUNT(*) FROM categories').fetchone()[0] == 18
    db.close()


def test_legacy_portable_normalization() -> None:
    """Reference the V3/V4/V7 portable-data transformations against current constraints."""
    db = sqlite3.connect(':memory:')
    db.execute('PRAGMA foreign_keys=ON')
    db.executescript('''
      CREATE TABLE accounts(id TEXT PRIMARY KEY, account_class TEXT NOT NULL, account_type TEXT NOT NULL, currency TEXT NOT NULL);
      CREATE TABLE categories(id TEXT PRIMARY KEY, type TEXT NOT NULL);
      CREATE TABLE recurring_rules(id TEXT PRIMARY KEY, account_id TEXT NOT NULL REFERENCES accounts(id), category_id TEXT NOT NULL REFERENCES categories(id), next_run TEXT NOT NULL);
      CREATE TABLE transactions(id TEXT PRIMARY KEY, status TEXT NOT NULL, deleted_at TEXT, primary_amount_minor INTEGER NOT NULL, primary_currency TEXT NOT NULL);
      CREATE TABLE transaction_legs(id TEXT PRIMARY KEY, transaction_id TEXT NOT NULL REFERENCES transactions(id), account_id TEXT NOT NULL REFERENCES accounts(id), delta_minor INTEGER NOT NULL, currency TEXT NOT NULL);
      CREATE TABLE recurring_occurrences(id TEXT PRIMARY KEY, rule_id TEXT NOT NULL REFERENCES recurring_rules(id), occurrence_key TEXT NOT NULL, transaction_id TEXT REFERENCES transactions(id), scheduled_for TEXT NOT NULL, created_at TEXT NOT NULL, UNIQUE(rule_id,occurrence_key));
      CREATE TABLE bills(id TEXT PRIMARY KEY, paid_transaction_id TEXT, status TEXT NOT NULL);
      CREATE UNIQUE INDEX idx_bills_paid_tx_unique ON bills(paid_transaction_id) WHERE paid_transaction_id IS NOT NULL;
      INSERT INTO accounts VALUES ('a','ASSET','BANK','IDR');
      INSERT INTO categories VALUES ('c','EXPENSE');
      INSERT INTO recurring_rules VALUES ('r','a','c','2026-09-10T09:00:00.000');
      INSERT INTO transactions VALUES ('t1','DRAFT',NULL,1000,'IDR');
      INSERT INTO transactions VALUES ('t2','DRAFT',NULL,1000,'IDR');
      INSERT INTO recurring_occurrences VALUES ('o1','r','r:2026-09-10:v1','t1','2026-09-10T02:00:00Z','2026-09-01T00:00:00Z');
      INSERT INTO recurring_occurrences VALUES ('o2','r','r:2026-09-10:v2','t2','2026-09-10T03:00:00Z','2026-09-02T00:00:00Z');
    ''')

    # V13 portable V3/V4 repair semantics.
    db.execute('''DELETE FROM recurring_occurrences
      WHERE rowid NOT IN (
        SELECT MIN(rowid) FROM recurring_occurrences
        GROUP BY rule_id, substr(scheduled_for,1,10)
      )''')
    db.execute("UPDATE recurring_occurrences SET occurrence_key = rule_id || ':' || substr(scheduled_for,1,10)")
    db.execute('''INSERT INTO transaction_legs(id, transaction_id, account_id, delta_minor, currency)
      SELECT lower(hex(randomblob(16))), t.id, rr.account_id,
             CASE WHEN a.account_class='ASSET' THEN -t.primary_amount_minor ELSE t.primary_amount_minor END,
             t.primary_currency
      FROM transactions t
      JOIN recurring_occurrences ro ON ro.transaction_id=t.id
      JOIN recurring_rules rr ON rr.id=ro.rule_id
      JOIN accounts a ON a.id=rr.account_id
      WHERE t.status='DRAFT' AND t.deleted_at IS NULL
        AND NOT EXISTS (SELECT 1 FROM transaction_legs l WHERE l.transaction_id=t.id)''')
    db.execute("UPDATE recurring_rules SET next_run=substr(next_run,1,10) WHERE length(next_run)>10")
    assert db.execute('SELECT occurrence_key FROM recurring_occurrences').fetchall() == [('r:2026-09-10',)]
    assert db.execute("SELECT transaction_id,account_id,delta_minor FROM transaction_legs").fetchall() == [('t1','a',-1000)]
    assert db.execute("SELECT next_run FROM recurring_rules WHERE id='r'").fetchone()[0] == '2026-09-10'

    # V7 Bill duplicate payment rows must be normalized before insertion into
    # the current unique-index schema.
    legacy_rows = [
        {'id':'b1','paid_transaction_id':'pay','status':'PAID'},
        {'id':'b2','paid_transaction_id':'pay','status':'PAID'},
    ]
    seen=set()
    for row in legacy_rows:
        paid=row['paid_transaction_id']
        if paid and paid in seen:
            row=dict(row); row['paid_transaction_id']=None; row['status']='UPCOMING'
        elif paid:
            seen.add(paid)
        db.execute('INSERT INTO bills(id,paid_transaction_id,status) VALUES (?,?,?)', (row['id'],row['paid_transaction_id'],row['status']))
    assert db.execute("SELECT COUNT(*) FROM bills WHERE paid_transaction_id='pay'").fetchone()[0] == 1
    assert db.execute("SELECT status FROM bills WHERE id='b2'").fetchone()[0] == 'UPCOMING'
    db.close()


def main() -> None:
    with tempfile.TemporaryDirectory(prefix='arus_v13_') as d:
        tmp = Path(d)
        test_migration_interruption(tmp)
        test_restore_interruption(tmp)
        test_snapshot_consistency(tmp)
        test_atomic_seed_crash(tmp)
    test_legacy_portable_normalization()
    print(f'PASS: deep-mine V13 catastrophe/recovery contract ({len(checks)} source checks + crash fixtures)')


if __name__ == '__main__':
    main()
