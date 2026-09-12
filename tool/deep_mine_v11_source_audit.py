from pathlib import Path
import re
import sqlite3
import sys

ROOT = Path(__file__).resolve().parents[1]
repo = (ROOT / 'lib/data/local_finance_repository.dart').read_text()
backup = (ROOT / 'lib/core/services/backup_service.dart').read_text()

source_checks = {
    'recurring account domain guard': (
        '_requireRecurringExpenseAccount(account);' in repo
        and 'Recurring expense hanya boleh memakai asset atau credit-card liability.' in repo
    ),
    'recurring generation revalidates account/category': (
        'final recurringAccount = _accountRow' in repo
        and '_requireRecurringExpenseAccount(recurringAccount);' in repo
        and '_requireCategoryType(recurringCategory, CategoryType.expense);' in repo
    ),
    'refund atomic recheck': (
        'final latestOriginalRows = db.select' in repo
        and 'final latestRefunded = db.select' in repo
        and 'Transaksi original tidak lagi valid untuk refund.' in repo
    ),
    'simple edit atomic refund recheck': (
        'final latestRefundTotal = db.select' in repo
        and 'Transaksi tidak lagi valid untuk diedit sebagai simple transaction.' in repo
    ),
    'loan outstanding rechecked inside transaction': (
        'final latestOutstanding = _accountBalanceInDb(db, loanAccountId);' in repo
        and 'Pokok pembayaran melebihi outstanding pinjaman.' in repo
    ),
    'bill manual state restricted': (
        'status != BillStatus.skipped' in repo
        and 'Tagihan dengan pembayaran aktif tidak boleh dilewati.' in repo
    ),
    'planning restore semantics': all(x in backup for x in [
        'invalidBudgetSemantics', 'invalidBillSemantics', 'invalidRecurringSemantics'
    ]),
    'group restore semantics': all(x in backup for x in [
        'invalidGroupSemantics', 'invalidGroupMembership'
    ]),
}
failed = [name for name, ok in source_checks.items() if not ok]
if failed:
    print('FAIL: deep-mine V11 source contract')
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
        'invalidBudgetSemantics',
        'invalidBillSemantics',
        'invalidRecurringSemantics',
        'invalidGroupSemantics',
        'invalidGroupMembership',
    ]
}

conn = sqlite3.connect(':memory:')
conn.row_factory = sqlite3.Row
c = conn.cursor()
c.executescript('''
CREATE TABLE accounts(
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  account_class TEXT NOT NULL,
  account_type TEXT NOT NULL,
  currency TEXT NOT NULL DEFAULT 'IDR',
  archived_at TEXT
);
CREATE TABLE categories(
  id TEXT PRIMARY KEY,
  type TEXT NOT NULL,
  name TEXT NOT NULL,
  archived_at TEXT
);
CREATE TABLE budgets(
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  limit_minor INTEGER NOT NULL,
  currency TEXT NOT NULL,
  category_id TEXT,
  period_start TEXT NOT NULL,
  period_end TEXT NOT NULL,
  archived_at TEXT
);
CREATE TABLE bills(
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  expected_amount_minor INTEGER NOT NULL,
  currency TEXT NOT NULL,
  due_date TEXT NOT NULL,
  status TEXT NOT NULL,
  paid_transaction_id TEXT
);
CREATE TABLE recurring_rules(
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  mode TEXT NOT NULL,
  amount_minor INTEGER NOT NULL,
  currency TEXT NOT NULL,
  account_id TEXT NOT NULL,
  category_id TEXT NOT NULL,
  day_of_month INTEGER NOT NULL,
  next_run TEXT NOT NULL,
  active INTEGER NOT NULL
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
''')

c.executemany('INSERT INTO accounts(id,name,account_class,account_type,currency,archived_at) VALUES (?,?,?,?,?,?)', [
    ('bank','Bank','ASSET','BANK','IDR',None),
    ('wallet','Wallet','ASSET','EWALLET','IDR',None),
    ('card','Card','LIABILITY','CREDIT_CARD','IDR',None),
    ('loan','Loan','LIABILITY','LOAN','IDR',None),
])
c.executemany('INSERT INTO categories(id,type,name,archived_at) VALUES (?,?,?,?)', [
    ('exp','EXPENSE','Expense',None),
    ('inc','INCOME','Income',None),
])
c.execute("INSERT INTO budgets VALUES ('bud','Monthly',1000,'IDR','exp','2026-09-01','2026-09-30',NULL)")
c.execute("INSERT INTO bills VALUES ('bill','Internet',500,'IDR','2026-09-20','UPCOMING',NULL)")
c.execute("INSERT INTO recurring_rules VALUES ('rr','Rent','AUTO_CREATE_DRAFT',700,'IDR','bank','exp',5,'2026-10-05',1)")
c.executemany('INSERT INTO transaction_groups(id,group_type) VALUES (?,?)', [
    ('gtr','TRANSFER_WITH_FEE'),
    ('gloan','LOAN_PAYMENT'),
])

transactions = [
    ('trp','gtr',1,'TRANSFER','POSTED',100,None,None),
    ('trfee','gtr',0,'EXPENSE','POSTED',5,None,None),
    ('lp','gloan',1,'LOAN_PAYMENT','POSTED',100,None,None),
    ('lpint','gloan',0,'EXPENSE','POSTED',10,None,None),
    ('standalone','',1,'EXPENSE','POSTED',50,None,None),
]
for tid,gid,primary,typ,status,amount,orig,deleted in transactions:
    c.execute('INSERT INTO transactions(id,transaction_group_id,group_primary,type,status,primary_amount_minor,original_transaction_id,deleted_at) VALUES (?,?,?,?,?,?,?,?)',
              (tid, gid or None, primary, typ, status, amount, orig, deleted))
conn.commit()


def count(name: str) -> int:
    return int(conn.execute(queries[name]).fetchone()['c'])

for name in queries:
    assert count(name) == 0, (name, count(name))

# Planning firewall: category-budget semantics.
conn.execute("UPDATE budgets SET category_id='inc' WHERE id='bud'")
assert count('invalidBudgetSemantics') > 0
conn.execute("UPDATE budgets SET category_id='exp' WHERE id='bud'")

# Bill firewall: blank/zero/invalid basic state.
conn.execute("UPDATE bills SET name='   ' WHERE id='bill'")
assert count('invalidBillSemantics') > 0
conn.execute("UPDATE bills SET name='Internet' WHERE id='bill'")

# Recurring firewall: a recurring expense must never target a loan liability.
conn.execute("UPDATE recurring_rules SET account_id='loan' WHERE id='rr'")
assert count('invalidRecurringSemantics') > 0
conn.execute("UPDATE recurring_rules SET account_id='bank' WHERE id='rr'")

# Active recurring cannot point to archived dependencies.
conn.execute("UPDATE accounts SET archived_at='2026-09-11T00:00:00Z' WHERE id='bank'")
assert count('invalidRecurringSemantics') > 0
conn.execute("UPDATE accounts SET archived_at=NULL WHERE id='bank'")

# Group firewall: child type/status must remain canonical.
conn.execute("UPDATE transactions SET type='INCOME' WHERE id='trfee'")
assert count('invalidGroupSemantics') > 0
conn.execute("UPDATE transactions SET type='EXPENSE' WHERE id='trfee'")
conn.execute("UPDATE transactions SET status='VOIDED' WHERE id='trfee'")
assert count('invalidGroupSemantics') > 0
conn.execute("UPDATE transactions SET status='POSTED' WHERE id='trfee'")

# Group membership firewall: loan payment cannot be standalone.
conn.execute("UPDATE transactions SET transaction_group_id=NULL WHERE id='lp'")
assert count('invalidGroupMembership') > 0
conn.execute("UPDATE transactions SET transaction_group_id='gloan' WHERE id='lp'")

print('PASS: deep-mine V11 atomic/planning/group semantic contract')
