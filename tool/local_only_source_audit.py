from pathlib import Path
import re, sys
root=Path(__file__).resolve().parents[1]
errors=[]
pub=(root/'pubspec.yaml').read_text().lower()
if 'supabase' in pub: errors.append('Supabase remains in production pubspec')
lib='\n'.join(p.read_text(errors='ignore') for p in (root/'lib').rglob('*.dart'))
if 'package:supabase' in lib.lower(): errors.append('Supabase import remains in lib/')
schema=(root/'lib/core/db/schema.dart').read_text()
if 'CREATE TABLE IF NOT EXISTS sync_operations' in schema or 'CREATE TABLE IF NOT EXISTS sync_conflicts' in schema:
    errors.append('Sync tables still created by current schema')
backup=(root/'lib/core/services/backup_service.dart').read_text()
if "'sync_operations'" in backup or "'sync_conflicts'" in backup:
    errors.append('Portable backup still contains sync state')
security=(root/'lib/core/services/security_service.dart').read_text()
for token in ['_failedAttemptsKey','_lockUntilKey','pinLockedUntil']:
    if token not in security: errors.append(f'Missing PIN throttling token: {token}')
repo=(root/'lib/data/local_finance_repository.dart').read_text()
if 'Account masih memiliki saldo' not in repo: errors.append('Archive non-zero-balance guard missing')

for token,label in [
    ("latestBill = db.select('SELECT status,paid_transaction_id FROM bills WHERE id=?'", 'Atomic payBill re-check missing'),
    ("t.local_date<=? AND t.type='INCOME'", 'Dashboard income today-inclusive guard missing'),
    ("future_posted_count", 'Archive future-POSTED dependency guard missing'),
    ("status IN ('DUE','OVERDUE') AND due_date > ?", 'Bill backward-clock healing missing'),
    ("Tanggal refund tidak boleh mendahului transaksi original", 'Refund chronology guard missing'),
]:
    if token not in repo: errors.append(label)

if '_requirePostableDate' not in repo: errors.append('Future POSTED transaction guard missing')
if 'transaction_search MATCH ?' not in repo: errors.append('FTS5 transaction search is not wired into repository')
appdb=(root/'lib/core/db/app_database.dart').read_text()
for token in ['PRAGMA secure_delete = ON','secureMaintenanceAfterWipe','transaction_search(transaction_search) VALUES(\'integrity-check\')']:
    if token not in appdb: errors.append(f'Missing local data hardening token: {token}')
if "VALUES('secure-delete', 1)" not in schema: errors.append('FTS5 secure-delete is not enabled')

money=(root/'lib/shared/money.dart').read_text()
if 'final negative = value.startsWith' not in money: errors.append('Signed-money parser hardening missing')
if errors:
    print('FAIL')
    for e in errors: print('-',e)
    sys.exit(1)
print('PASS: local-only source contract')
