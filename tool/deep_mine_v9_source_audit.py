from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[1]
repo=(ROOT/'lib/data/local_finance_repository.dart').read_text()
backup=(ROOT/'lib/core/services/backup_service.dart').read_text()
schema=(ROOT/'lib/core/db/schema.dart').read_text()
checks={
 'hard delete transaction': "db.execute('DELETE FROM transactions WHERE id=?', [id]);" in repo,
 'detach recurring occurrence on hard delete': "UPDATE recurring_occurrences SET transaction_id=NULL" in repo,
 'bill refund reconciliation helper': '_reconcileBillForPayment' in repo,
 'refund invokes bill reconcile': '_reconcileBillForPayment(db, originalTransactionId, now: occurredAt);' in repo,
 'void refund invokes bill reconcile': "if (originalId != null) _reconcileBillForPayment(db, originalId);" in repo,
 'bill permits fully-refunded previous payment replacement': "previousPaymentId != null && !_paymentFullyRefunded" in repo,
 'recurring backward-clock healing': 'monthsAhead > 2' in repo and 'bad device clock' in repo,
 'backup max 64 MiB': '64 * 1024 * 1024' in backup,
 'backup over-refund validation': 'overRefund' in backup,
 'backup invalid-paid-bill validation': 'invalidPaidBill' in backup,
 'backup orphan-refund validation': 'orphanPostedRefund' in backup,
 'schema v9 local-only tombstone purge': 'const int kSchemaVersion = 9;' in schema and "DELETE FROM transactions WHERE deleted_at IS NOT NULL" in schema,
 'restore legacy tombstone repair': '_repairLegacyLocalOnlyState' in backup,
}
failed=[k for k,v in checks.items() if not v]
if failed:
    print('FAIL: deep-mine V9 source contract')
    for x in failed: print(' -',x)
    sys.exit(1)
print('PASS: deep-mine V9 hard-delete/refund/bill/clock/backup contract')
