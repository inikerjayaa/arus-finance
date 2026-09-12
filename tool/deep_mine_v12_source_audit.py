from pathlib import Path
import re
import sqlite3
import sys

ROOT = Path(__file__).resolve().parents[1]
repo = (ROOT / 'lib/data/local_finance_repository.dart').read_text()
backup = (ROOT / 'lib/core/services/backup_service.dart').read_text()
limits = (ROOT / 'lib/domain/money_limits.dart').read_text()
compile_audit = (ROOT / 'tool/compile_risk_audit.py').read_text()
money_parser = (ROOT / 'lib/shared/money.dart').read_text()
csv_import = (ROOT / 'lib/core/services/csv_import_service.dart').read_text()
native_tests = (ROOT / 'test/finance_invariants_test.dart').read_text()

source_checks = {
    'V9 legacy restore helper exists': 'void _repairLegacyLocalOnlyState(dynamic db)' in backup,
    'legacy restore helper detaches bills': "UPDATE bills SET paid_transaction_id=NULL,status='UPCOMING'" in backup,
    'legacy restore helper detaches recurring': 'UPDATE recurring_occurrences SET transaction_id=NULL' in backup,
    'legacy restore helper neutralizes orphan refunds': "UPDATE transactions SET status='VOIDED',original_transaction_id=NULL" in backup,
    'legacy restore helper hard-deletes tombstones': "DELETE FROM transactions WHERE deleted_at IS NOT NULL" in backup,
    'legacy restore helper prunes empty groups': 'DELETE FROM transaction_groups WHERE NOT EXISTS' in backup,
    'backup envelope parameters are authenticated-format gated': all(x in backup for x in [
        "envelope['kdf'] != 'ARGON2ID'", "envelope['memory_kib'] != 65536",
        "envelope['iterations'] != 3", "envelope['parallelism'] != 2",
        'salt.length != 16', 'nonce.length != 12', 'macBytes.length != 16'
    ]),
    'payload format version validated': "['format_version'] != 1" in backup,
    'money safety envelope exists': 'kMaxMoneyMinor = 9_000_000_000_000' in limits,
    'repository positive money guard uses envelope': '_requireMoneyMagnitude(amountMinor, label);' in repo,
    'repository observed balance uses envelope': "_requireMoneyMagnitude(observedBalanceMinor, 'Saldo observasi');" in repo,
    'backup money range firewall': 'invalidMoneyRange' in backup and 'kMaxMoneyMinor' in backup,
    'backup account semantic firewall': 'invalidAccountSemantics' in backup,
    'backup category semantic firewall': 'invalidCategorySemantics' in backup,
    'backup import fingerprint firewall': 'invalidImportFingerprint' in backup,
    'backup date semantic firewall': 'invalidDateSemantics' in backup,
    'backup refund semantic firewall': 'invalidRefundSemantics' in backup,
    'backup recurring occurrence firewall': 'invalidRecurringOccurrenceSemantics' in backup,
    'compile risk checks private helpers': 'unresolved private helper candidate' in compile_audit,
    'IDR parser enforces money envelope': 'parsed > kMaxMoneyMinor' in money_parser,
    'CSV preview enforces money envelope': 'amount! > kMaxMoneyMinor' in csv_import and 'batas keamanan nominal aplikasi' in csv_import,
    'native regression test prepared for money envelope': "test('money safety envelope rejects oversized values before SQLite write'" in native_tests,
}
failed = [name for name, ok in source_checks.items() if not ok]
if failed:
    print('FAIL: deep-mine V12 source contract')
    for item in failed:
        print(' -', item)
    sys.exit(1)

m = re.search(r'kMaxMoneyMinor\s*=\s*([0-9_]+)', limits)
assert m
MAX_MONEY = int(m.group(1).replace('_', ''))


def extract_sql(var_name: str) -> str:
    pat = rf"final\s+{re.escape(var_name)}\s*=\s*db\.select\(\"\"\"(.*?)\"\"\"\)\.first\['c'\]\s+as\s+int;"
    match = re.search(pat, backup, flags=re.S)
    if not match:
        raise AssertionError(f'Could not extract SQL for {var_name}')
    sql = match.group(1)
    sql = sql.replace('${kMaxMoneyMinor}', str(MAX_MONEY)).replace('$kMaxMoneyMinor', str(MAX_MONEY))
    return sql

queries = {name: extract_sql(name) for name in [
    'invalidAccountSemantics',
    'invalidCategorySemantics',
    'invalidImportFingerprint',
    'invalidMoneyRange',
    'invalidDateSemantics',
    'invalidRefundSemantics',
    'invalidRecurringOccurrenceSemantics',
]}

conn = sqlite3.connect(':memory:')
conn.row_factory = sqlite3.Row
c = conn.cursor()
c.executescript('''
PRAGMA foreign_keys=ON;
CREATE TABLE accounts(
  id TEXT PRIMARY KEY, name TEXT NOT NULL, account_class TEXT NOT NULL,
  account_type TEXT NOT NULL, currency TEXT NOT NULL,
  include_available INTEGER NOT NULL DEFAULT 1, include_net_worth INTEGER NOT NULL DEFAULT 1,
  archived_at TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL, version INTEGER NOT NULL DEFAULT 1
);
CREATE TABLE categories(
  id TEXT PRIMARY KEY, parent_id TEXT, type TEXT NOT NULL, name TEXT NOT NULL,
  archived_at TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL, version INTEGER NOT NULL DEFAULT 1
);
CREATE TABLE transaction_groups(
  id TEXT PRIMARY KEY, group_type TEXT NOT NULL, created_at TEXT NOT NULL, updated_at TEXT NOT NULL, version INTEGER NOT NULL DEFAULT 1
);
CREATE TABLE transactions(
  id TEXT PRIMARY KEY, transaction_group_id TEXT, group_primary INTEGER NOT NULL DEFAULT 1,
  type TEXT NOT NULL, status TEXT NOT NULL, primary_amount_minor INTEGER NOT NULL,
  primary_currency TEXT NOT NULL, occurred_at_utc TEXT NOT NULL, local_date TEXT NOT NULL,
  note TEXT, original_transaction_id TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
  deleted_at TEXT, version INTEGER NOT NULL DEFAULT 1
);
CREATE TABLE transaction_legs(
  id TEXT PRIMARY KEY, transaction_id TEXT NOT NULL, account_id TEXT NOT NULL,
  delta_minor INTEGER NOT NULL, currency TEXT NOT NULL
);
CREATE TABLE transaction_splits(
  id TEXT PRIMARY KEY, transaction_id TEXT NOT NULL, category_id TEXT NOT NULL,
  amount_minor INTEGER NOT NULL, currency TEXT NOT NULL
);
CREATE TABLE budgets(
  id TEXT PRIMARY KEY, name TEXT NOT NULL, limit_minor INTEGER NOT NULL, currency TEXT NOT NULL,
  category_id TEXT, period_start TEXT NOT NULL, period_end TEXT NOT NULL, archived_at TEXT,
  created_at TEXT NOT NULL, updated_at TEXT NOT NULL
);
CREATE TABLE bills(
  id TEXT PRIMARY KEY, name TEXT NOT NULL, expected_amount_minor INTEGER NOT NULL, currency TEXT NOT NULL,
  due_date TEXT NOT NULL, status TEXT NOT NULL, paid_transaction_id TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL
);
CREATE TABLE recurring_rules(
  id TEXT PRIMARY KEY, name TEXT NOT NULL, mode TEXT NOT NULL, amount_minor INTEGER NOT NULL,
  currency TEXT NOT NULL, account_id TEXT NOT NULL, category_id TEXT NOT NULL,
  day_of_month INTEGER NOT NULL, next_run TEXT NOT NULL, active INTEGER NOT NULL,
  version INTEGER NOT NULL DEFAULT 1, created_at TEXT NOT NULL, updated_at TEXT NOT NULL
);
CREATE TABLE recurring_occurrences(
  id TEXT PRIMARY KEY, rule_id TEXT NOT NULL, occurrence_key TEXT NOT NULL,
  transaction_id TEXT, scheduled_for TEXT NOT NULL, created_at TEXT NOT NULL
);
CREATE TABLE import_fingerprints(
  fingerprint TEXT PRIMARY KEY, transaction_id TEXT NOT NULL, created_at TEXT NOT NULL
);
''')

STAMP = '2026-09-11T06:00:00.000Z'
c.executemany('INSERT INTO accounts VALUES (?,?,?,?,?,?,?,?,?,?,?)', [
    ('bank','Bank','ASSET','BANK','IDR',1,1,None,STAMP,STAMP,1),
    ('card','Card','LIABILITY','CREDIT_CARD','IDR',1,1,None,STAMP,STAMP,1),
])
c.execute('INSERT INTO categories VALUES (?,?,?,?,?,?,?,?)', ('exp',None,'EXPENSE','Expense',None,STAMP,STAMP,1))
c.execute('INSERT INTO budgets VALUES (?,?,?,?,?,?,?,?,?,?)', ('bud','Monthly',100000,'IDR','exp','2026-09-01','2026-09-30',None,STAMP,STAMP))
c.execute('INSERT INTO bills VALUES (?,?,?,?,?,?,?,?,?)', ('bill','Internet',50000,'IDR','2026-09-20','UPCOMING',None,STAMP,STAMP))
c.execute('INSERT INTO recurring_rules VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)', ('rr','Rent','AUTO_CREATE_DRAFT',70000,'IDR','bank','exp',5,'2026-10-05',1,1,STAMP,STAMP))

# Canonical original expense + refund.
txs = [
    ('orig',None,1,'EXPENSE','POSTED',100000,'IDR','2026-09-05T03:00:00.000Z','2026-09-05',None,None,STAMP,STAMP,None,1),
    ('refund',None,1,'REFUND','POSTED',20000,'IDR','2026-09-06T03:00:00.000Z','2026-09-06',None,'orig',STAMP,STAMP,None,1),
    ('rtd',None,1,'EXPENSE','DRAFT',70000,'IDR','2026-09-05T02:00:00.000Z','2026-09-05','Recurring: Rent',None,STAMP,STAMP,None,1),
]
c.executemany('INSERT INTO transactions VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)', txs)
c.executemany('INSERT INTO transaction_legs VALUES (?,?,?,?,?)', [
    ('lorig','orig','bank',-100000,'IDR'),
    ('lrefund','refund','bank',20000,'IDR'),
    ('lrtd','rtd','bank',-70000,'IDR'),
])
c.executemany('INSERT INTO transaction_splits VALUES (?,?,?,?,?)', [
    ('sorig','orig','exp',100000,'IDR'),
    ('srefund','refund','exp',20000,'IDR'),
    ('srtd','rtd','exp',70000,'IDR'),
])
c.execute('INSERT INTO recurring_occurrences VALUES (?,?,?,?,?,?)', ('occ','rr','rr:2026-09-05','rtd','2026-09-05T09:00:00.000Z',STAMP))
c.execute('INSERT INTO import_fingerprints VALUES (?,?,?)', ('a'*64,'orig',STAMP))
conn.commit()


def count(name: str) -> int:
    return int(conn.execute(queries[name]).fetchone()['c'])

for name in queries:
    assert count(name) == 0, (name, count(name))

# Account semantic corruption must be rejected even if unused by transactions.
conn.execute("UPDATE accounts SET account_type='LOAN' WHERE id='bank'")
assert count('invalidAccountSemantics') > 0
conn.execute("UPDATE accounts SET account_type='BANK' WHERE id='bank'")
conn.execute("UPDATE categories SET name='   ' WHERE id='exp'")
assert count('invalidCategorySemantics') > 0
conn.execute("UPDATE categories SET name='Expense' WHERE id='exp'")
conn.execute("UPDATE import_fingerprints SET fingerprint='NOT-A-HASH'")
assert count('invalidImportFingerprint') > 0
conn.execute("UPDATE import_fingerprints SET fingerprint=?", ('a'*64,))

# Money values beyond the safety envelope must be rejected before aggregate risk.
conn.execute('UPDATE transactions SET primary_amount_minor=? WHERE id=?', (MAX_MONEY + 1, 'orig'))
assert count('invalidMoneyRange') > 0
conn.execute('UPDATE transactions SET primary_amount_minor=100000 WHERE id=?', ('orig',))

# Calendar-invalid-but-length-correct dates must fail.
conn.execute("UPDATE bills SET due_date='2026-02-31' WHERE id='bill'")
assert count('invalidDateSemantics') > 0
conn.execute("UPDATE bills SET due_date='2026-09-20' WHERE id='bill'")

# Refund chronology and category linkage are canonical invariants.
conn.execute("UPDATE transactions SET local_date='2026-09-04' WHERE id='refund'")
assert count('invalidRefundSemantics') > 0
conn.execute("UPDATE transactions SET local_date='2026-09-06' WHERE id='refund'")
c.execute('INSERT INTO categories VALUES (?,?,?,?,?,?,?,?)', ('exp2',None,'EXPENSE','Other',None,STAMP,STAMP,1))
conn.execute("UPDATE transaction_splits SET category_id='exp2' WHERE transaction_id='refund'")
assert count('invalidRefundSemantics') > 0
conn.execute("UPDATE transaction_splits SET category_id='exp' WHERE transaction_id='refund'")

# Recurring occurrence may only point to the exact draft materialized from its rule.
conn.execute("UPDATE transactions SET primary_amount_minor=70001 WHERE id='rtd'")
assert count('invalidRecurringOccurrenceSemantics') > 0
conn.execute("UPDATE transactions SET primary_amount_minor=70000 WHERE id='rtd'")
conn.execute("UPDATE recurring_occurrences SET occurrence_key='rr:2026-09-06' WHERE id='occ'")
assert count('invalidRecurringOccurrenceSemantics') > 0
conn.execute("UPDATE recurring_occurrences SET occurrence_key='rr:2026-09-05' WHERE id='occ'")
# Detached AUTO_CREATE_DRAFT occurrence is valid dedupe history after user deletes its draft.
conn.execute("UPDATE recurring_occurrences SET transaction_id=NULL WHERE id='occ'")
assert count('invalidRecurringOccurrenceSemantics') == 0
conn.execute("UPDATE recurring_occurrences SET transaction_id='rtd' WHERE id='occ'")

# V9 legacy repair reference: tombstoned payment/original links are normalized.
c.execute("INSERT INTO transaction_groups VALUES ('gold','TRANSFER_WITH_FEE',?,?,1)", (STAMP,STAMP))
c.execute('INSERT INTO transactions VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
          ('old-del','gold',1,'EXPENSE','VOIDED',100,'IDR','2026-01-01T00:00:00.000Z','2026-01-01',None,None,STAMP,STAMP,STAMP,1))
c.execute('INSERT INTO transactions VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
          ('old-ref',None,1,'REFUND','POSTED',50,'IDR','2026-01-02T00:00:00.000Z','2026-01-02',None,'old-del',STAMP,STAMP,None,1))
c.execute("UPDATE bills SET paid_transaction_id='old-del',status='PAID' WHERE id='bill'")
c.execute("UPDATE recurring_occurrences SET transaction_id='old-del' WHERE id='occ'")
conn.commit()

repair_sql = [
    "UPDATE bills SET paid_transaction_id=NULL,status='UPCOMING' WHERE paid_transaction_id IN (SELECT id FROM transactions WHERE deleted_at IS NOT NULL)",
    "UPDATE recurring_occurrences SET transaction_id=NULL WHERE transaction_id IN (SELECT id FROM transactions WHERE deleted_at IS NOT NULL)",
    "UPDATE transactions SET status='VOIDED',original_transaction_id=NULL WHERE type='REFUND' AND original_transaction_id IN (SELECT id FROM transactions WHERE deleted_at IS NOT NULL)",
    "DELETE FROM transactions WHERE deleted_at IS NOT NULL",
    "DELETE FROM transaction_groups WHERE NOT EXISTS (SELECT 1 FROM transactions WHERE transaction_group_id=transaction_groups.id)",
]
for sql in repair_sql:
    conn.execute(sql)
assert conn.execute("SELECT COUNT(*) FROM transactions WHERE id='old-del'").fetchone()[0] == 0
row = conn.execute("SELECT status,original_transaction_id FROM transactions WHERE id='old-ref'").fetchone()
assert tuple(row) == ('VOIDED', None)
assert conn.execute("SELECT paid_transaction_id FROM bills WHERE id='bill'").fetchone()[0] is None
assert conn.execute("SELECT transaction_id FROM recurring_occurrences WHERE id='occ'").fetchone()[0] is None
assert conn.execute("SELECT COUNT(*) FROM transaction_groups WHERE id='gold'").fetchone()[0] == 0
conn.rollback()

# Atomic restore reference: failed semantic validation must leave live data untouched.
atomic = sqlite3.connect(':memory:')
atomic.row_factory = sqlite3.Row
atomic.execute('CREATE TABLE accounts(id TEXT PRIMARY KEY,name TEXT,account_class TEXT,account_type TEXT,currency TEXT,include_available INTEGER,include_net_worth INTEGER)')
atomic.execute("INSERT INTO accounts VALUES ('live','Live','ASSET','BANK','IDR',1,1)")
atomic.commit()
try:
    atomic.execute('BEGIN IMMEDIATE')
    atomic.execute('DELETE FROM accounts')
    atomic.execute("INSERT INTO accounts VALUES ('bad','Bad','ASSET','LOAN','IDR',1,1)")
    bad = atomic.execute("SELECT COUNT(*) FROM accounts WHERE NOT ((account_class='ASSET' AND account_type IN ('CASH','BANK','EWALLET','INVESTMENT','OTHER_ASSET')) OR (account_class='LIABILITY' AND account_type IN ('CREDIT_CARD','LOAN','OTHER_LIABILITY')))").fetchone()[0]
    if bad:
        raise ValueError('semantic failure')
    atomic.commit()
except ValueError:
    atomic.rollback()
assert atomic.execute("SELECT COUNT(*) FROM accounts WHERE id='live'").fetchone()[0] == 1
assert atomic.execute("SELECT COUNT(*) FROM accounts WHERE id='bad'").fetchone()[0] == 0

print('PASS: deep-mine V12 restore/money/date/helper/atomic contract')
