"""Executable SQLite schema/migration sanity audit from the Dart schema source."""
from pathlib import Path
import re, sqlite3

ROOT = Path(__file__).resolve().parents[1]
text = (ROOT / 'lib/core/db/schema.dart').read_text()
version = int(re.search(r'kSchemaVersion\s*=\s*(\d+)', text).group(1))

pat = re.compile(
    r"'''(.*?)'''|\"\"\"(.*?)\"\"\"|^\s*'([^']*)',|^\s*\"([^\"]*)\",",
    re.S | re.M,
)

def extract(body):
    out = []
    for match in pat.finditer(body):
        out.append(next(group for group in match.groups() if group is not None))
    return out

list_body = re.search(
    r'const List<String> kSchemaStatements = \[(.*?)\n\];', text, re.S
).group(1)
statements = extract(list_body)
map_body = re.search(
    r'const Map<int, List<String>> kSchemaMigrations = \{(.*?)\n\};', text, re.S
).group(1)

def migration_statements(target):
    match = re.search(rf'\n\s*{target}:\s*\[(.*?)(?=\n\s*\],)', map_body, re.S)
    if not match:
        raise AssertionError(f'missing migration {target}')
    return extract(match.group(1))

def pre_v10_schema(sql):
    """Remove V10 visual columns when emulating a database created before V10."""
    if 'CREATE TABLE IF NOT EXISTS accounts' in sql or 'CREATE TABLE IF NOT EXISTS categories' in sql:
        sql = sql.replace('    visual_icon_key TEXT,\n', '')
        sql = sql.replace('    visual_color_key TEXT,\n', '')
    return sql

def fresh_schema():
    db = sqlite3.connect(':memory:')
    db.execute('PRAGMA foreign_keys=ON')
    for sql in statements:
        db.execute(sql)
    db.execute(
        "INSERT OR REPLACE INTO app_meta(key,value) VALUES ('schema_version',?)",
        (str(version),),
    )
    assert db.execute('PRAGMA foreign_key_check').fetchall() == []
    expected = {
        'accounts', 'categories', 'transactions', 'transaction_legs',
        'transaction_splits', 'budgets', 'bills', 'recurring_rules',
        'recurring_occurrences', 'import_fingerprints', 'transaction_search',
    }
    existing = {
        row[0] for row in db.execute(
            "SELECT name FROM sqlite_master WHERE type='table'"
        )
    }
    assert expected <= existing, expected - existing
    account_cols = {row[1] for row in db.execute('PRAGMA table_info(accounts)')}
    category_cols = {row[1] for row in db.execute('PRAGMA table_info(categories)')}
    assert {'visual_icon_key', 'visual_color_key'} <= account_cols
    assert {'visual_icon_key', 'visual_color_key'} <= category_cols

    db.execute("INSERT INTO accounts(id,name,account_class,account_type,currency,include_available,include_net_worth,created_at,updated_at,version) VALUES ('a','BCA Utama','ASSET','BANK','IDR',1,1,'x','x',1)")
    db.execute("INSERT INTO categories(id,type,name,created_at,updated_at,version) VALUES ('c','EXPENSE','Makanan','x','x',1)")
    db.execute("INSERT INTO transactions(id,group_primary,type,status,primary_amount_minor,primary_currency,occurred_at_utc,local_date,note,created_at,updated_at,version) VALUES ('t',1,'EXPENSE','POSTED',25000,'IDR','2026-09-09T02:00:00Z','2026-09-09','makan siang','x','x',1)")
    db.execute("INSERT INTO transaction_legs(id,transaction_id,account_id,delta_minor,currency) VALUES ('l','t','a',-25000,'IDR')")
    db.execute("INSERT INTO transaction_splits(id,transaction_id,category_id,amount_minor,currency) VALUES ('s','t','c',25000,'IDR')")
    assert db.execute(
        "SELECT transaction_id FROM transaction_search WHERE transaction_search MATCH ?",
        ('\"makan\"*',),
    ).fetchone()[0] == 't'
    assert db.execute(
        "SELECT transaction_id FROM transaction_search WHERE transaction_search MATCH ?",
        ('\"BCA\"*',),
    ).fetchone()[0] == 't'
    assert db.execute(
        "SELECT transaction_id FROM transaction_search WHERE transaction_search MATCH ?",
        ('\"Makanan\"*',),
    ).fetchone()[0] == 't'
    db.close()

def legacy_v1_real_startup_order():
    """Reproduce startup from a true pre-v2/pre-v10 database."""
    db = sqlite3.connect(':memory:')
    db.execute('PRAGMA foreign_keys=ON')
    for raw_sql in statements:
        sql = pre_v10_schema(raw_sql)
        if 'CREATE TABLE IF NOT EXISTS bills' in sql:
            sql = sql.replace(
                '    paid_transaction_id TEXT REFERENCES transactions(id),\n', ''
            )
        if (
            'import_fingerprints' in sql
            or 'transaction_search' in sql
            or 'trg_' in sql
            or 'idx_bills_paid_tx_unique' in sql
        ):
            continue
        db.execute(sql)
    db.execute(
        "INSERT OR REPLACE INTO app_meta(key,value) VALUES ('schema_version','1')"
    )
    db.execute("INSERT INTO bills(id,name,expected_amount_minor,currency,due_date,status,created_at,updated_at) VALUES ('b1','Legacy Bill',1000,'IDR','2026-09-01','UPCOMING','x','x')")
    db.commit()

    current = 1
    while current < version:
        target = current + 1
        db.execute('BEGIN IMMEDIATE')
        try:
            for sql in migration_statements(target):
                db.execute(sql)
            db.execute(
                "INSERT OR REPLACE INTO app_meta(key,value) VALUES ('schema_version',?)",
                (str(target),),
            )
            db.commit()
            current = target
        except Exception:
            db.rollback()
            raise

    db.execute('BEGIN IMMEDIATE')
    try:
        for sql in statements:
            db.execute(sql)
        db.commit()
    except Exception:
        db.rollback()
        raise

    bill_cols = {row[1] for row in db.execute('PRAGMA table_info(bills)')}
    account_cols = {row[1] for row in db.execute('PRAGMA table_info(accounts)')}
    category_cols = {row[1] for row in db.execute('PRAGMA table_info(categories)')}
    assert 'paid_transaction_id' in bill_cols
    assert {'visual_icon_key', 'visual_color_key'} <= account_cols
    assert {'visual_icon_key', 'visual_color_key'} <= category_cols
    assert db.execute(
        "SELECT value FROM app_meta WHERE key='schema_version'"
    ).fetchone()[0] == str(version)
    assert db.execute("SELECT COUNT(*) FROM bills WHERE id='b1'").fetchone()[0] == 1
    assert db.execute(
        "SELECT COUNT(*) FROM sqlite_master WHERE type='index' AND name='idx_bills_paid_tx_unique'"
    ).fetchone()[0] == 1
    assert db.execute('PRAGMA foreign_key_check').fetchall() == []
    db.close()

def legacy_v3_to_current():
    db = sqlite3.connect(':memory:')
    db.execute('PRAGMA foreign_keys=ON')
    for sql in statements:
        db.execute(sql)
    db.execute("INSERT INTO accounts(id,name,account_class,account_type,currency,include_available,include_net_worth,created_at,updated_at,version) VALUES ('a','Bank','ASSET','BANK','IDR',1,1,'x','x',1)")
    db.execute("INSERT INTO categories(id,type,name,created_at,updated_at,version) VALUES ('c','EXPENSE','Tagihan','x','x',1)")
    db.execute("INSERT INTO recurring_rules(id,name,mode,amount_minor,currency,account_id,category_id,day_of_month,next_run,active,version,created_at,updated_at) VALUES ('r','Internet','AUTO_CREATE_DRAFT',1000,'IDR','a','c',8,'2026-09-08T09:00:00.000','1',2,'x','x')")
    db.execute("INSERT INTO transactions(id,group_primary,type,status,primary_amount_minor,primary_currency,occurred_at_utc,local_date,note,created_at,updated_at,version) VALUES ('t',1,'EXPENSE','DRAFT',1000,'IDR','2026-09-08T02:00:00Z','2026-09-08','Recurring: Internet','x','x',1)")
    db.execute("INSERT INTO transaction_splits(id,transaction_id,category_id,amount_minor,currency) VALUES ('s','t','c',1000,'IDR')")
    db.execute("INSERT INTO transactions(id,group_primary,type,status,primary_amount_minor,primary_currency,occurred_at_utc,local_date,note,created_at,updated_at,version) VALUES ('tdup',1,'EXPENSE','DRAFT',1000,'IDR','2026-09-08T03:00:00Z','2026-09-08','Recurring duplicate after rule edit','x','x',1)")
    db.execute("INSERT INTO transaction_splits(id,transaction_id,category_id,amount_minor,currency) VALUES ('sdup','tdup','c',1000,'IDR')")
    db.execute("INSERT INTO recurring_occurrences(id,rule_id,occurrence_key,transaction_id,scheduled_for,created_at) VALUES ('o','r','r:2026-09-08:v1','t','2026-09-08T02:00:00Z','x')")
    db.execute("INSERT INTO recurring_occurrences(id,rule_id,occurrence_key,transaction_id,scheduled_for,created_at) VALUES ('odup','r','r:2026-09-08:v2','tdup','2026-09-08T03:00:00Z','x')")
    for sql in migration_statements(4):
        db.execute(sql)
    db.execute(
        "UPDATE recurring_rules SET next_run = substr(next_run,1,10) WHERE length(next_run) > 10"
    )
    db.commit()
    assert db.execute(
        "SELECT occurrence_key FROM recurring_occurrences WHERE id='o'"
    ).fetchone()[0] == 'r:2026-09-08'
    assert db.execute(
        "SELECT COUNT(*) FROM recurring_occurrences WHERE rule_id='r'"
    ).fetchone()[0] == 1
    assert db.execute(
        "SELECT account_id,delta_minor FROM transaction_legs WHERE transaction_id='t'"
    ).fetchone() == ('a', -1000)
    assert db.execute("SELECT COUNT(*) FROM transactions WHERE id='tdup'").fetchone()[0] == 1
    assert db.execute("SELECT next_run FROM recurring_rules WHERE id='r'").fetchone()[0] == '2026-09-08'
    assert db.execute('PRAGMA foreign_key_check').fetchall() == []
    db.close()

def legacy_v6_to_v7():
    db = sqlite3.connect(':memory:')
    db.execute('PRAGMA foreign_keys=ON')
    for sql in statements:
        db.execute(sql)
    for name, kind in db.execute(
        "SELECT name,type FROM sqlite_master WHERE name LIKE 'trg_%_search_%'"
    ).fetchall():
        if kind == 'trigger':
            db.execute(f'DROP TRIGGER IF EXISTS {name}')
    db.execute('DROP TABLE IF EXISTS transaction_search')
    db.execute("INSERT INTO accounts(id,name,account_class,account_type,currency,include_available,include_net_worth,created_at,updated_at,version) VALUES ('a','Bank Lama','ASSET','BANK','IDR',1,1,'x','x',1)")
    db.execute("INSERT INTO categories(id,type,name,created_at,updated_at,version) VALUES ('c','EXPENSE','Makanan Lama','x','x',1)")
    db.execute("INSERT INTO transactions(id,group_primary,type,status,primary_amount_minor,primary_currency,occurred_at_utc,local_date,note,created_at,updated_at,version) VALUES ('t',1,'EXPENSE','POSTED',1000,'IDR','2026-09-09T02:00:00Z','2026-09-09','kopi lama','x','x',1)")
    db.execute("INSERT INTO transaction_legs(id,transaction_id,account_id,delta_minor,currency) VALUES ('l','t','a',-1000,'IDR')")
    db.execute("INSERT INTO transaction_splits(id,transaction_id,category_id,amount_minor,currency) VALUES ('s','t','c',1000,'IDR')")
    for sql in migration_statements(7):
        db.execute(sql)
    assert db.execute(
        "SELECT transaction_id FROM transaction_search WHERE transaction_search MATCH ?",
        ('\"kopi\"*',),
    ).fetchone()[0] == 't'
    assert db.execute(
        "SELECT transaction_id FROM transaction_search WHERE transaction_search MATCH ?",
        ('\"Bank\"*',),
    ).fetchone()[0] == 't'
    assert db.execute('PRAGMA foreign_key_check').fetchall() == []
    db.close()

def legacy_v7_to_v8_bill_payment_uniqueness():
    db = sqlite3.connect(':memory:')
    db.execute('PRAGMA foreign_keys=ON')
    for sql in statements:
        db.execute(sql)
    db.execute('DROP INDEX IF EXISTS idx_bills_paid_tx_unique')
    db.execute("INSERT INTO accounts(id,name,account_class,account_type,currency,include_available,include_net_worth,created_at,updated_at,version) VALUES ('a8','Bank','ASSET','BANK','IDR',1,1,'x','x',1)")
    db.execute("INSERT INTO categories(id,type,name,created_at,updated_at,version) VALUES ('c8','EXPENSE','Tagihan','x','x',1)")
    db.execute("INSERT INTO transactions(id,group_primary,type,status,primary_amount_minor,primary_currency,occurred_at_utc,local_date,note,created_at,updated_at,version) VALUES ('pay8',1,'EXPENSE','POSTED',1000,'IDR','2026-09-09T02:00:00Z','2026-09-09','bill','x','x',1)")
    db.execute("INSERT INTO transaction_legs(id,transaction_id,account_id,delta_minor,currency) VALUES ('l8','pay8','a8',-1000,'IDR')")
    db.execute("INSERT INTO transaction_splits(id,transaction_id,category_id,amount_minor,currency) VALUES ('s8','pay8','c8',1000,'IDR')")
    db.execute("INSERT INTO bills(id,name,expected_amount_minor,currency,due_date,status,paid_transaction_id,created_at,updated_at) VALUES ('b81','A',1000,'IDR','2026-09-09','PAID','pay8','x','x')")
    db.execute("INSERT INTO bills(id,name,expected_amount_minor,currency,due_date,status,paid_transaction_id,created_at,updated_at) VALUES ('b82','B',1000,'IDR','2026-09-09','PAID','pay8','x','x')")
    for sql in migration_statements(8):
        db.execute(sql)
    assert db.execute(
        "SELECT COUNT(*) FROM bills WHERE paid_transaction_id='pay8'"
    ).fetchone()[0] == 1
    try:
        db.execute("UPDATE bills SET paid_transaction_id='pay8',status='PAID' WHERE id='b82'")
        raise AssertionError('unique bill payment index did not reject duplicate')
    except sqlite3.IntegrityError:
        pass
    db.close()

def legacy_v8_to_v9_tombstone_cleanup():
    db = sqlite3.connect(':memory:')
    db.execute('PRAGMA foreign_keys=ON')
    for sql in statements:
        db.execute(sql)
    db.execute("INSERT INTO accounts(id,name,account_class,account_type,currency,include_available,include_net_worth,created_at,updated_at,version) VALUES ('a9','Bank','ASSET','BANK','IDR',1,1,'x','x',1)")
    db.execute("INSERT INTO categories(id,type,name,created_at,updated_at,version) VALUES ('c9','EXPENSE','Tagihan','x','x',1)")
    db.execute("INSERT INTO recurring_rules(id,name,mode,amount_minor,currency,account_id,category_id,day_of_month,next_run,active,version,created_at,updated_at) VALUES ('r9','Internet','AUTO_CREATE_DRAFT',1000,'IDR','a9','c9',10,'2026-09-10',1,1,'x','x')")
    db.execute("INSERT INTO transactions(id,group_primary,type,status,primary_amount_minor,primary_currency,occurred_at_utc,local_date,note,created_at,updated_at,deleted_at,version) VALUES ('dead9',1,'EXPENSE','POSTED',1000,'IDR','2026-09-10T02:00:00Z','2026-09-10','old deleted','x','x','2026-09-10T03:00:00Z',1)")
    db.execute("INSERT INTO transaction_legs(id,transaction_id,account_id,delta_minor,currency) VALUES ('ld9','dead9','a9',-1000,'IDR')")
    db.execute("INSERT INTO transaction_splits(id,transaction_id,category_id,amount_minor,currency) VALUES ('sd9','dead9','c9',1000,'IDR')")
    db.execute("INSERT INTO recurring_occurrences(id,rule_id,occurrence_key,transaction_id,scheduled_for,created_at) VALUES ('o9','r9','r9:2026-09-10','dead9','2026-09-10','x')")
    db.execute("INSERT INTO bills(id,name,expected_amount_minor,currency,due_date,status,paid_transaction_id,created_at,updated_at) VALUES ('b9','Internet',1000,'IDR','2026-09-10','PAID','dead9','x','x')")
    db.execute("INSERT INTO transactions(id,group_primary,type,status,primary_amount_minor,primary_currency,occurred_at_utc,local_date,note,original_transaction_id,created_at,updated_at,version) VALUES ('refund9',1,'REFUND','VOIDED',1000,'IDR','2026-09-10T04:00:00Z','2026-09-10','legacy refund','dead9','x','x',1)")
    db.execute("INSERT INTO transactions(id,group_primary,type,status,primary_amount_minor,primary_currency,occurred_at_utc,local_date,note,created_at,updated_at,version) VALUES ('live9',1,'EXPENSE','POSTED',2000,'IDR','2026-09-10T05:00:00Z','2026-09-10','keep me','x','x',1)")
    db.execute("INSERT INTO transaction_legs(id,transaction_id,account_id,delta_minor,currency) VALUES ('ll9','live9','a9',-2000,'IDR')")
    db.execute("INSERT INTO transaction_splits(id,transaction_id,category_id,amount_minor,currency) VALUES ('sl9','live9','c9',2000,'IDR')")
    for sql in migration_statements(9):
        db.execute(sql)
    assert db.execute("SELECT COUNT(*) FROM transactions WHERE id='dead9'").fetchone()[0] == 0
    assert db.execute("SELECT COUNT(*) FROM transactions WHERE id='live9'").fetchone()[0] == 1
    assert db.execute(
        "SELECT transaction_id FROM recurring_occurrences WHERE id='o9'"
    ).fetchone()[0] is None
    assert db.execute(
        "SELECT paid_transaction_id,status FROM bills WHERE id='b9'"
    ).fetchone() == (None, 'UPCOMING')
    assert db.execute(
        "SELECT status,original_transaction_id FROM transactions WHERE id='refund9'"
    ).fetchone() == ('VOIDED', None)
    assert db.execute('PRAGMA foreign_key_check').fetchall() == []
    db.close()

def legacy_v9_to_v10_visual_identity():
    db = sqlite3.connect(':memory:')
    db.execute('PRAGMA foreign_keys=ON')
    for raw_sql in statements:
        db.execute(pre_v10_schema(raw_sql))
    db.execute("INSERT INTO accounts(id,name,account_class,account_type,currency,include_available,include_net_worth,created_at,updated_at,version) VALUES ('a10','BCA','ASSET','BANK','IDR',1,1,'x','x',1)")
    db.execute("INSERT INTO categories(id,type,name,created_at,updated_at,version) VALUES ('c10','EXPENSE','Makanan','x','x',1)")
    for sql in migration_statements(10):
        db.execute(sql)
    account_cols = {row[1] for row in db.execute('PRAGMA table_info(accounts)')}
    category_cols = {row[1] for row in db.execute('PRAGMA table_info(categories)')}
    assert {'visual_icon_key', 'visual_color_key'} <= account_cols
    assert {'visual_icon_key', 'visual_color_key'} <= category_cols
    assert db.execute("SELECT name FROM accounts WHERE id='a10'").fetchone()[0] == 'BCA'
    assert db.execute("SELECT name FROM categories WHERE id='c10'").fetchone()[0] == 'Makanan'
    db.execute("UPDATE accounts SET visual_icon_key='bank.bca',visual_color_key='blue' WHERE id='a10'")
    db.execute("UPDATE categories SET visual_icon_key='food.meal',visual_color_key='orange' WHERE id='c10'")
    assert db.execute(
        "SELECT visual_icon_key,visual_color_key FROM accounts WHERE id='a10'"
    ).fetchone() == ('bank.bca', 'blue')
    assert db.execute(
        "SELECT visual_icon_key,visual_color_key FROM categories WHERE id='c10'"
    ).fetchone() == ('food.meal', 'orange')
    assert db.execute('PRAGMA foreign_key_check').fetchall() == []
    db.close()

fresh_schema()
legacy_v1_real_startup_order()
legacy_v3_to_current()
legacy_v6_to_v7()
legacy_v7_to_v8_bill_payment_uniqueness()
legacy_v8_to_v9_tombstone_cleanup()
legacy_v9_to_v10_visual_identity()
print(
    f'PASS: fresh schema v{version} + real-order legacy v1→current + legacy v3 + '
    'v6→v7 FTS + v7→v8 Bill uniqueness + v8→v9 tombstone cleanup + '
    'v9→v10 visual identity migration'
)
