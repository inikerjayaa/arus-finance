"""Executable SQLite schema/migration audit derived from the Dart schema source."""
from pathlib import Path
import re
import sqlite3

ROOT = Path(__file__).resolve().parents[1]
TEXT = (ROOT / 'lib/core/db/schema.dart').read_text()
VERSION = int(re.search(r'kSchemaVersion\s*=\s*(\d+)', TEXT).group(1))

SQL_PATTERN = re.compile(
    r"'''(.*?)'''|\"\"\"(.*?)\"\"\"|^\s*'([^']*)',|^\s*\"([^\"]*)\",",
    re.S | re.M,
)


def extract(body):
    out = []
    for match in SQL_PATTERN.finditer(body):
        out.append(next(group for group in match.groups() if group is not None))
    return out


STATEMENT_BODY = re.search(
    r'const List<String> kSchemaStatements = \[(.*?)\n\];', TEXT, re.S
).group(1)
STATEMENTS = extract(STATEMENT_BODY)
MIGRATION_BODY = re.search(
    r'const Map<int, List<String>> kSchemaMigrations = \{(.*?)\n\};', TEXT, re.S
).group(1)


def migration_statements(target):
    match = re.search(
        rf'\n\s*{target}:\s*\[(.*?)(?=\n\s*\],)',
        MIGRATION_BODY,
        re.S,
    )
    if not match:
        raise AssertionError(f'missing migration {target}')
    return extract(match.group(1))


def open_db():
    db = sqlite3.connect(':memory:')
    db.execute('PRAGMA foreign_keys=ON')
    return db


def apply(statements, db):
    for sql in statements:
        db.execute(sql)


def current_objects(db):
    apply(STATEMENTS, db)


def legacy_v1_statement(sql):
    """Strip columns/objects introduced after schema v1."""
    if 'CREATE TABLE IF NOT EXISTS bills' in sql:
        sql = sql.replace(
            '    paid_transaction_id TEXT REFERENCES transactions(id),\n',
            '',
        )
    if 'CREATE TABLE IF NOT EXISTS accounts' in sql:
        sql = sql.replace('    visual_icon_key TEXT,\n', '')
        sql = sql.replace('    visual_color_key TEXT,\n', '')
    if 'CREATE TABLE IF NOT EXISTS categories' in sql:
        sql = sql.replace('    system_key TEXT,\n', '')
        sql = sql.replace('    visual_icon_key TEXT,\n', '')
        sql = sql.replace('    visual_color_key TEXT,\n', '')

    post_v1_markers = (
        'import_fingerprints',
        'transaction_search',
        'trg_',
        'idx_bills_paid_tx_unique',
        'idx_categories_system_key_unique',
    )
    if any(marker in sql for marker in post_v1_markers):
        return None
    return sql


def fresh_schema():
    db = open_db()
    current_objects(db)
    db.execute(
        "INSERT OR REPLACE INTO app_meta(key,value) VALUES ('schema_version',?)",
        (str(VERSION),),
    )

    account_cols = {r[1] for r in db.execute('PRAGMA table_info(accounts)')}
    category_cols = {r[1] for r in db.execute('PRAGMA table_info(categories)')}
    assert {'visual_icon_key', 'visual_color_key'} <= account_cols
    assert {'visual_icon_key', 'visual_color_key', 'system_key'} <= category_cols
    assert db.execute(
        "SELECT COUNT(*) FROM sqlite_master WHERE type='index' "
        "AND name='idx_categories_system_key_unique'"
    ).fetchone()[0] == 1
    assert db.execute(
        "SELECT COUNT(*) FROM sqlite_master WHERE type='trigger' "
        "AND name='trg_category_system_key_seed'"
    ).fetchone()[0] == 1

    db.execute(
        "INSERT INTO categories(id,type,name,created_at,updated_at,version) "
        "VALUES ('food','EXPENSE','Makanan','x','x',1)"
    )
    assert db.execute(
        "SELECT system_key FROM categories WHERE id='food'"
    ).fetchone()[0] == 'expense.food'

    db.execute(
        "INSERT INTO accounts(id,name,account_class,account_type,currency,"
        "include_available,include_net_worth,created_at,updated_at,version) "
        "VALUES ('a','BCA Utama','ASSET','BANK','IDR',1,1,'x','x',1)"
    )
    db.execute(
        "INSERT INTO transactions(id,group_primary,type,status,primary_amount_minor,"
        "primary_currency,occurred_at_utc,local_date,note,created_at,updated_at,version) "
        "VALUES ('t',1,'EXPENSE','POSTED',25000,'IDR','2026-09-09T02:00:00Z',"
        "'2026-09-09','makan siang','x','x',1)"
    )
    db.execute(
        "INSERT INTO transaction_legs(id,transaction_id,account_id,delta_minor,currency) "
        "VALUES ('l','t','a',-25000,'IDR')"
    )
    db.execute(
        "INSERT INTO transaction_splits(id,transaction_id,category_id,amount_minor,currency) "
        "VALUES ('s','t','food',25000,'IDR')"
    )
    assert db.execute(
        "SELECT transaction_id FROM transaction_search WHERE transaction_search MATCH ?",
        ('\"makan\"*',),
    ).fetchone()[0] == 't'
    assert db.execute('PRAGMA foreign_key_check').fetchall() == []
    db.close()


def legacy_v1_to_current():
    db = open_db()
    for raw in STATEMENTS:
        sql = legacy_v1_statement(raw)
        if sql is not None:
            db.execute(sql)
    db.execute(
        "INSERT OR REPLACE INTO app_meta(key,value) VALUES ('schema_version','1')"
    )
    db.execute(
        "INSERT INTO categories(id,type,name,created_at,updated_at,version) "
        "VALUES ('legacy-fee','EXPENSE','Biaya Transfer','2025-01-01','2025-01-01',1)"
    )
    db.execute(
        "INSERT INTO bills(id,name,expected_amount_minor,currency,due_date,status,created_at,updated_at) "
        "VALUES ('b1','Legacy Bill',1000,'IDR','2026-09-01','UPCOMING','x','x')"
    )
    db.commit()

    current = 1
    while current < VERSION:
        target = current + 1
        db.execute('BEGIN IMMEDIATE')
        try:
            apply(migration_statements(target), db)
            db.execute(
                "INSERT OR REPLACE INTO app_meta(key,value) VALUES ('schema_version',?)",
                (str(target),),
            )
            db.commit()
        except Exception:
            db.rollback()
            raise
        current = target

    current_objects(db)
    category_cols = {r[1] for r in db.execute('PRAGMA table_info(categories)')}
    account_cols = {r[1] for r in db.execute('PRAGMA table_info(accounts)')}
    bill_cols = {r[1] for r in db.execute('PRAGMA table_info(bills)')}
    assert 'paid_transaction_id' in bill_cols
    assert {'visual_icon_key', 'visual_color_key'} <= account_cols
    assert {'visual_icon_key', 'visual_color_key', 'system_key'} <= category_cols
    assert db.execute(
        "SELECT system_key FROM categories WHERE id='legacy-fee'"
    ).fetchone()[0] == 'expense.transfer_fee'
    assert db.execute(
        "SELECT value FROM app_meta WHERE key='schema_version'"
    ).fetchone()[0] == str(VERSION)
    assert db.execute("SELECT COUNT(*) FROM bills WHERE id='b1'").fetchone()[0] == 1
    assert db.execute('PRAGMA foreign_key_check').fetchall() == []
    db.close()


def legacy_v3_recurring_normalization():
    db = open_db()
    current_objects(db)
    db.execute(
        "INSERT INTO accounts(id,name,account_class,account_type,currency,include_available,"
        "include_net_worth,created_at,updated_at,version) "
        "VALUES ('a3','Bank','ASSET','BANK','IDR',1,1,'x','x',1)"
    )
    db.execute(
        "INSERT INTO categories(id,type,name,created_at,updated_at,version) "
        "VALUES ('c3','EXPENSE','Tagihan Lama','x','x',1)"
    )
    db.execute(
        "INSERT INTO recurring_rules(id,name,mode,amount_minor,currency,account_id,category_id,"
        "day_of_month,next_run,active,version,created_at,updated_at) "
        "VALUES ('r3','Internet','AUTO_CREATE_DRAFT',1000,'IDR','a3','c3',8,"
        "'2026-09-08T09:00:00.000',1,2,'x','x')"
    )
    for txid, hour in [('t3','02'), ('t3dup','03')]:
        db.execute(
            "INSERT INTO transactions(id,group_primary,type,status,primary_amount_minor,"
            "primary_currency,occurred_at_utc,local_date,note,created_at,updated_at,version) "
            f"VALUES ('{txid}',1,'EXPENSE','DRAFT',1000,'IDR','2026-09-08T{hour}:00:00Z',"
            "'2026-09-08','Recurring','x','x',1)"
        )
        db.execute(
            "INSERT INTO transaction_splits(id,transaction_id,category_id,amount_minor,currency) "
            "VALUES (?,?,?,?,?)",
            (f's-{txid}', txid, 'c3', 1000, 'IDR'),
        )
    db.execute(
        "INSERT INTO recurring_occurrences(id,rule_id,occurrence_key,transaction_id,scheduled_for,created_at) "
        "VALUES ('o3','r3','r3:2026-09-08:v1','t3','2026-09-08T02:00:00Z','x')"
    )
    db.execute(
        "INSERT INTO recurring_occurrences(id,rule_id,occurrence_key,transaction_id,scheduled_for,created_at) "
        "VALUES ('o3dup','r3','r3:2026-09-08:v2','t3dup','2026-09-08T03:00:00Z','x')"
    )
    apply(migration_statements(4), db)
    assert db.execute(
        "SELECT COUNT(*) FROM recurring_occurrences WHERE rule_id='r3'"
    ).fetchone()[0] == 1
    assert db.execute(
        "SELECT occurrence_key FROM recurring_occurrences WHERE rule_id='r3'"
    ).fetchone()[0] == 'r3:2026-09-08'
    assert db.execute(
        "SELECT account_id,delta_minor FROM transaction_legs WHERE transaction_id='t3'"
    ).fetchone() == ('a3', -1000)
    db.close()


def legacy_v6_to_v7_fts():
    db = open_db()
    current_objects(db)
    for name, kind in db.execute(
        "SELECT name,type FROM sqlite_master WHERE name LIKE 'trg_%_search_%'"
    ).fetchall():
        if kind == 'trigger':
            db.execute(f'DROP TRIGGER IF EXISTS {name}')
    db.execute('DROP TABLE IF EXISTS transaction_search')
    db.execute(
        "INSERT INTO accounts(id,name,account_class,account_type,currency,include_available,"
        "include_net_worth,created_at,updated_at,version) "
        "VALUES ('a7','Bank Lama','ASSET','BANK','IDR',1,1,'x','x',1)"
    )
    db.execute(
        "INSERT INTO categories(id,type,name,created_at,updated_at,version) "
        "VALUES ('c7','EXPENSE','Makanan Lama','x','x',1)"
    )
    db.execute(
        "INSERT INTO transactions(id,group_primary,type,status,primary_amount_minor,primary_currency,"
        "occurred_at_utc,local_date,note,created_at,updated_at,version) "
        "VALUES ('t7',1,'EXPENSE','POSTED',1000,'IDR','2026-09-09T02:00:00Z',"
        "'2026-09-09','kopi lama','x','x',1)"
    )
    db.execute(
        "INSERT INTO transaction_legs(id,transaction_id,account_id,delta_minor,currency) "
        "VALUES ('l7','t7','a7',-1000,'IDR')"
    )
    db.execute(
        "INSERT INTO transaction_splits(id,transaction_id,category_id,amount_minor,currency) "
        "VALUES ('s7','t7','c7',1000,'IDR')"
    )
    apply(migration_statements(7), db)
    assert db.execute(
        "SELECT transaction_id FROM transaction_search WHERE transaction_search MATCH ?",
        ('\"kopi\"*',),
    ).fetchone()[0] == 't7'
    db.close()


def legacy_v7_to_v8_bill_uniqueness():
    db = open_db()
    current_objects(db)
    db.execute('DROP INDEX IF EXISTS idx_bills_paid_tx_unique')
    db.execute(
        "INSERT INTO accounts(id,name,account_class,account_type,currency,include_available,"
        "include_net_worth,created_at,updated_at,version) "
        "VALUES ('a8','Bank','ASSET','BANK','IDR',1,1,'x','x',1)"
    )
    db.execute(
        "INSERT INTO categories(id,type,name,created_at,updated_at,version) "
        "VALUES ('c8','EXPENSE','Tagihan Khusus','x','x',1)"
    )
    db.execute(
        "INSERT INTO transactions(id,group_primary,type,status,primary_amount_minor,primary_currency,"
        "occurred_at_utc,local_date,note,created_at,updated_at,version) "
        "VALUES ('pay8',1,'EXPENSE','POSTED',1000,'IDR','2026-09-09T02:00:00Z',"
        "'2026-09-09','bill','x','x',1)"
    )
    db.execute(
        "INSERT INTO transaction_legs(id,transaction_id,account_id,delta_minor,currency) "
        "VALUES ('l8','pay8','a8',-1000,'IDR')"
    )
    db.execute(
        "INSERT INTO transaction_splits(id,transaction_id,category_id,amount_minor,currency) "
        "VALUES ('s8','pay8','c8',1000,'IDR')"
    )
    for bill in ('b81', 'b82'):
        db.execute(
            "INSERT INTO bills(id,name,expected_amount_minor,currency,due_date,status,"
            "paid_transaction_id,created_at,updated_at) VALUES (?,?,?,?,?,?,?,?,?)",
            (bill, bill, 1000, 'IDR', '2026-09-09', 'PAID', 'pay8', 'x', 'x'),
        )
    apply(migration_statements(8), db)
    assert db.execute(
        "SELECT COUNT(*) FROM bills WHERE paid_transaction_id='pay8'"
    ).fetchone()[0] == 1
    db.close()


def legacy_v8_to_v9_tombstone_cleanup():
    db = open_db()
    current_objects(db)
    db.execute(
        "INSERT INTO transactions(id,group_primary,type,status,primary_amount_minor,primary_currency,"
        "occurred_at_utc,local_date,note,created_at,updated_at,deleted_at,version) "
        "VALUES ('dead9',1,'ADJUSTMENT','POSTED',1,'IDR','2026-09-09T02:00:00Z',"
        "'2026-09-09','dead','x','x','2026-09-10T00:00:00Z',1)"
    )
    apply(migration_statements(9), db)
    assert db.execute("SELECT COUNT(*) FROM transactions WHERE id='dead9'").fetchone()[0] == 0
    db.close()


def legacy_v9_to_v10_visual_identity():
    db = open_db()
    for raw in STATEMENTS:
        sql = raw
        if 'CREATE TABLE IF NOT EXISTS accounts' in sql or 'CREATE TABLE IF NOT EXISTS categories' in sql:
            sql = sql.replace('    visual_icon_key TEXT,\n', '')
            sql = sql.replace('    visual_color_key TEXT,\n', '')
        if 'CREATE TABLE IF NOT EXISTS categories' in sql:
            sql = sql.replace('    system_key TEXT,\n', '')
        if 'trg_category_system_key_seed' in sql or 'idx_categories_system_key_unique' in sql:
            continue
        db.execute(sql)
    apply(migration_statements(10), db)
    account_cols = {r[1] for r in db.execute('PRAGMA table_info(accounts)')}
    category_cols = {r[1] for r in db.execute('PRAGMA table_info(categories)')}
    assert {'visual_icon_key', 'visual_color_key'} <= account_cols
    assert {'visual_icon_key', 'visual_color_key'} <= category_cols
    assert 'system_key' not in category_cols
    db.close()


def legacy_v10_to_v11_system_identity():
    db = open_db()
    for raw in STATEMENTS:
        sql = raw
        if 'CREATE TABLE IF NOT EXISTS categories' in sql:
            sql = sql.replace('    system_key TEXT,\n', '')
        if 'trg_category_system_key_seed' in sql or 'idx_categories_system_key_unique' in sql:
            continue
        db.execute(sql)

    db.execute(
        "INSERT INTO categories(id,type,name,created_at,updated_at,version) "
        "VALUES ('fee-old','EXPENSE','Biaya Transfer','2025-01-01','2025-01-01',1)"
    )
    db.execute(
        "INSERT INTO categories(id,type,name,created_at,updated_at,version) "
        "VALUES ('fee-new','EXPENSE','Biaya Transfer','2026-01-01','2026-01-01',1)"
    )
    apply(migration_statements(11), db)

    cols = {r[1] for r in db.execute('PRAGMA table_info(categories)')}
    assert 'system_key' in cols
    assert db.execute(
        "SELECT system_key FROM categories WHERE id='fee-old'"
    ).fetchone()[0] == 'expense.transfer_fee'
    assert db.execute(
        "SELECT system_key FROM categories WHERE id='fee-new'"
    ).fetchone()[0] is None

    db.execute("UPDATE categories SET name='Admin Transfer' WHERE id='fee-old'")
    assert db.execute(
        "SELECT system_key FROM categories WHERE id='fee-old'"
    ).fetchone()[0] == 'expense.transfer_fee'

    try:
        db.execute(
            "UPDATE categories SET system_key='expense.transfer_fee' WHERE id='fee-new'"
        )
        raise AssertionError('system_key uniqueness did not reject duplicate')
    except sqlite3.IntegrityError:
        pass

    db.execute(
        "INSERT INTO categories(id,type,name,created_at,updated_at,version) "
        "VALUES ('salary','INCOME','Gaji','2026-01-01','2026-01-01',1)"
    )
    assert db.execute(
        "SELECT system_key FROM categories WHERE id='salary'"
    ).fetchone()[0] == 'income.salary'
    db.close()


fresh_schema()
legacy_v1_to_current()
legacy_v3_recurring_normalization()
legacy_v6_to_v7_fts()
legacy_v7_to_v8_bill_uniqueness()
legacy_v8_to_v9_tombstone_cleanup()
legacy_v9_to_v10_visual_identity()
legacy_v10_to_v11_system_identity()
print(
    f'PASS: fresh schema v{VERSION} + real-order legacy v1→current + legacy v3 + '
    'v6→v7 FTS + v7→v8 Bill uniqueness + v8→v9 tombstone cleanup + '
    'v9→v10 visual identity + v10→v11 stable category identity'
)
