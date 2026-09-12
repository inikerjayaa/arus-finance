from pathlib import Path
import re
import sqlite3
import sys

ROOT = Path(__file__).resolve().parents[1]
repo = (ROOT / 'lib/data/local_finance_repository.dart').read_text()
backup = (ROOT / 'lib/core/services/backup_service.dart').read_text()
categories = (ROOT / 'lib/features/settings/categories_screen.dart').read_text()

source_checks = {
    'group-wide VOID refund guard': (
        'Composite VOID is all-or-nothing' in repo
        and "[row['id']]" in repo
        and "Group transaksi mempunyai refund aktif" in repo
    ),
    'refund destination domain guard': (
        '_requireRefundDestination(destination);' in repo
        and "Refund hanya boleh masuk ke asset atau credit-card liability." in repo
    ),
    'blank budget name blocked': "Nama budget wajib diisi." in repo,
    'blank bill name blocked': "Nama tagihan wajib diisi." in repo,
    'blank recurring name blocked': "Nama recurring wajib diisi." in repo,
    'bill initial status derived': 'final initialStatus = _derivedUnpaidBillStatus(dueDateKey);' in repo,
    'obvious unused oldVersion removed': "final oldVersion = tx['version'] as int;" not in repo,
    'obvious unused dashboard endIso removed': 'final endIso = _localDate(end);' not in repo,
    'obvious unused recurring version removed': "final version = rows.first['version'] as int;" not in repo,
    'unused categories theme removed': 'final theme = Theme.of(context);' not in categories,
    'backup simple shape firewall': 'invalidSimpleShape' in backup,
    'backup simple semantics firewall': 'invalidSimpleSemantics' in backup,
    'backup special transaction firewall': 'invalidSpecialSemantics' in backup,
    'backup group shape firewall': 'invalidGroupShape' in backup,
    'backup unpaid bill active-payment firewall': 'invalidUnpaidBillActivePayment' in backup,
}
failed = [name for name, ok in source_checks.items() if not ok]
if failed:
    print('FAIL: deep-mine V10 source contract')
    for item in failed:
        print(' -', item)
    sys.exit(1)


def extract_sql(var_name: str) -> str:
    pat = rf"final\s+{re.escape(var_name)}\s*=\s*db\.select\(\"\"\"(.*?)\"\"\"\)\.first\['c'\]\s+as\s+int;"
    match = re.search(pat, backup, flags=re.S)
    if not match:
        raise AssertionError(f'Could not extract SQL for {var_name}')
    return match.group(1)

queries = {
    name: extract_sql(name)
    for name in [
        'invalidSimpleShape',
        'invalidSimpleSemantics',
        'invalidNonCategorizedShape',
        'invalidSpecialSemantics',
        'invalidGroupShape',
        'invalidUnpaidBillActivePayment',
    ]
}

conn = sqlite3.connect(':memory:')
conn.row_factory = sqlite3.Row
c = conn.cursor()
c.executescript('''
CREATE TABLE accounts(
  id TEXT PRIMARY KEY,
  account_class TEXT NOT NULL,
  account_type TEXT NOT NULL,
  currency TEXT NOT NULL DEFAULT 'IDR'
);
CREATE TABLE categories(
  id TEXT PRIMARY KEY,
  type TEXT NOT NULL
);
CREATE TABLE transaction_groups(
  id TEXT PRIMARY KEY,
  group_type TEXT NOT NULL
);
CREATE TABLE transactions(
  id TEXT PRIMARY KEY,
  transaction_group_id TEXT,
  group_primary INTEGER NOT NULL DEFAULT 1,
  type TEXT NOT NULL,
  status TEXT NOT NULL,
  primary_amount_minor INTEGER NOT NULL,
  primary_currency TEXT NOT NULL DEFAULT 'IDR',
  original_transaction_id TEXT,
  deleted_at TEXT
);
CREATE TABLE transaction_legs(
  id TEXT PRIMARY KEY,
  transaction_id TEXT NOT NULL,
  account_id TEXT NOT NULL,
  delta_minor INTEGER NOT NULL,
  currency TEXT NOT NULL DEFAULT 'IDR'
);
CREATE TABLE transaction_splits(
  id TEXT PRIMARY KEY,
  transaction_id TEXT NOT NULL,
  category_id TEXT NOT NULL,
  amount_minor INTEGER NOT NULL,
  currency TEXT NOT NULL DEFAULT 'IDR'
);
CREATE TABLE bills(
  id TEXT PRIMARY KEY,
  status TEXT NOT NULL,
  paid_transaction_id TEXT
);
''')

accounts = [
    ('bank', 'ASSET', 'BANK'),
    ('wallet', 'ASSET', 'EWALLET'),
    ('card', 'LIABILITY', 'CREDIT_CARD'),
    ('loan', 'LIABILITY', 'LOAN'),
]
c.executemany('INSERT INTO accounts(id,account_class,account_type) VALUES (?,?,?)', accounts)
c.executemany('INSERT INTO categories(id,type) VALUES (?,?)', [('exp', 'EXPENSE'), ('inc', 'INCOME')])
c.execute("INSERT INTO transaction_groups(id,group_type) VALUES ('gloan','LOAN_PAYMENT')")

# id, group, primary, type, status, amount, original
transactions = [
    ('e1', None, 1, 'EXPENSE', 'POSTED', 100, None),
    ('i1', None, 1, 'INCOME', 'POSTED', 200, None),
    ('r1', None, 1, 'REFUND', 'POSTED', 50, 'e1'),
    ('tr1', None, 1, 'TRANSFER', 'POSTED', 70, None),
    ('cc1', None, 1, 'CREDIT_CARD_PAYMENT', 'POSTED', 80, None),
    ('ld1', None, 1, 'LOAN_DISBURSEMENT', 'POSTED', 300, None),
    ('lp1', 'gloan', 1, 'LOAN_PAYMENT', 'POSTED', 100, None),
    ('ad1', None, 1, 'ADJUSTMENT', 'POSTED', 30, None),
    ('op1', None, 1, 'OPENING_BALANCE', 'POSTED', 500, None),
]
c.executemany('''INSERT INTO transactions(
  id,transaction_group_id,group_primary,type,status,primary_amount_minor,original_transaction_id
) VALUES (?,?,?,?,?,?,?)''', transactions)

legs = [
    ('le1', 'e1', 'bank', -100),
    ('li1', 'i1', 'bank', 200),
    ('lr1', 'r1', 'bank', 50),
    ('ltr1a', 'tr1', 'bank', -70), ('ltr1b', 'tr1', 'wallet', 70),
    ('lcc1a', 'cc1', 'bank', -80), ('lcc1b', 'cc1', 'card', -80),
    ('lld1a', 'ld1', 'bank', 300), ('lld1b', 'ld1', 'loan', 300),
    ('llp1a', 'lp1', 'bank', -100), ('llp1b', 'lp1', 'loan', -100),
    ('lad1', 'ad1', 'bank', -30),
    ('lop1', 'op1', 'bank', 500),
]
c.executemany('INSERT INTO transaction_legs(id,transaction_id,account_id,delta_minor) VALUES (?,?,?,?)', legs)
c.executemany('INSERT INTO transaction_splits(id,transaction_id,category_id,amount_minor) VALUES (?,?,?,?)', [
    ('se1', 'e1', 'exp', 100),
    ('si1', 'i1', 'inc', 200),
    ('sr1', 'r1', 'exp', 50),
])
conn.commit()


def count(name: str) -> int:
    return int(conn.execute(queries[name]).fetchone()['c'])

# Valid canonical fixture must pass every newly added semantic query.
for name in queries:
    assert count(name) == 0, (name, count(name))

# Each firewall must detect a representative corruption.
conn.execute("DELETE FROM transaction_splits WHERE transaction_id='e1'")
assert count('invalidSimpleShape') > 0
conn.execute("INSERT INTO transaction_splits(id,transaction_id,category_id,amount_minor) VALUES ('se1b','e1','exp',100)")

conn.execute("UPDATE transaction_legs SET delta_minor=100 WHERE id='le1'")
assert count('invalidSimpleSemantics') > 0
conn.execute("UPDATE transaction_legs SET delta_minor=-100 WHERE id='le1'")

conn.execute("INSERT INTO transaction_splits(id,transaction_id,category_id,amount_minor) VALUES ('badtrsplit','tr1','exp',70)")
assert count('invalidNonCategorizedShape') > 0
conn.execute("DELETE FROM transaction_splits WHERE id='badtrsplit'")

conn.execute("UPDATE transaction_legs SET delta_minor=-70 WHERE id='ltr1b'")
assert count('invalidSpecialSemantics') > 0
conn.execute("UPDATE transaction_legs SET delta_minor=70 WHERE id='ltr1b'")

conn.execute("UPDATE transaction_groups SET group_type='BOGUS' WHERE id='gloan'")
assert count('invalidGroupShape') > 0
conn.execute("UPDATE transaction_groups SET group_type='LOAN_PAYMENT' WHERE id='gloan'")

# e1 is only partially refunded (50/100); an unpaid bill linked to it is inconsistent.
conn.execute("INSERT INTO bills(id,status,paid_transaction_id) VALUES ('b1','DUE','e1')")
assert count('invalidUnpaidBillActivePayment') > 0
conn.execute("UPDATE bills SET status='PAID' WHERE id='b1'")
assert count('invalidUnpaidBillActivePayment') == 0

print('PASS: deep-mine V10 group-VOID/refund/backup semantic firewall contract')
