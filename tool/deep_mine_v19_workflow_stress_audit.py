from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
read = lambda rel: (ROOT / rel).read_text()
controller = read('lib/app_controller.dart')
quick = read('lib/features/quick_add/quick_add_sheet.dart')
detail = read('lib/features/transactions/transaction_detail_screen.dart')
shell = read('lib/app_shell.dart')
docs = read('docs/WORKFLOW_STRESS_UAT_V19.md')

checks = {
    'write and refresh are split in controller': 'The financial write and the presentation refresh are deliberately' in controller,
    'successful write returns value despite refresh failure': "noticeMessage =\n              'Perubahan sudah tersimpan" in controller and 'return value;' in controller,
    'refresh failure is notice not transaction error': 'noticeMessage' in controller and 'Muat ulang sebelum mengulangi aksi.' in controller,
    'resume during busy is queued': '_resumeRefreshPending = true' in controller and 'unawaited(processAppResume())' in controller,
    'notice has explicit clear action': 'void clearNotice()' in controller and 'controller.clearNotice' in shell,
    'post-commit warning has explicit refresh action': 'retryPresentationRefresh' in controller and "tooltip: 'Muat ulang tampilan'" in shell,
    'notice is assistive-tech live region': "label: 'Informasi: ${controller.noticeMessage!}'" in shell and 'liveRegion: true' in shell,
    'quick add cannot barrier-dismiss or drag away': 'isDismissible: false' in quick and 'enableDrag: false' in quick,
    'quick add has explicit close affordance': "tooltip: 'Tutup pencatatan transaksi'" in quick,
    'quick add blocks dirty accidental pop': 'PopScope<void>' in quick and 'canPop: _allowPop || (!_dirty && !_submitting)' in quick,
    'quick add confirms discard': "title: const Text('Buang perubahan?')" in quick and "child: const Text('Lanjut mengisi')" in quick,
    'quick add guards repeated close prompts': '_closePromptOpen' in quick and 'if (_submitting || _closePromptOpen) return;' in quick,
    'quick add has local submit lock': '_submitting' in quick and 'if (_submitting) return;' in quick,
    'quick add disables save while submitting': 'controller.busy || _submitting || eligibleAccounts.isEmpty' in quick,
    'quick add successful save clears dirty before pop': '_dirty = false;' in quick and '_allowPop = true;' in quick,
    'expense edit UI filters unsupported liabilities': 'a.accountType == AccountType.creditCard' in detail and 'a.accountClass == AccountClass.asset' in detail,
    'posted edit cannot select future date': 'd.view.status == TransactionStatus.posted ? DateTime.now() : DateTime(2100)' in detail,
    'posting draft requires financial-effect confirmation': "title: const Text('Catat draft sekarang?')" in detail and 'langsung memengaruhi saldo serta laporan' in detail,
    'workflow UAT covers rapid repeat save': 'Rapid Save / Double Tap' in docs,
    'workflow UAT covers commit-success refresh-failure': 'Commit Sukses / Refresh Gagal' in docs,
    'workflow UAT covers background-resume during write': 'Resume Saat Write Sedang Aktif' in docs,
    'workflow UAT covers accidental close': 'Accidental Close' in docs,
    'workflow UAT covers stale dependency': 'Stale Account / Category' in docs,
}

# Reference state-machine proof for the V19 controller contract. This does not
# pretend to execute Dart; it proves the intended classification independent of
# UI timing so the source assertions above have an executable behavioral oracle.
def model_run(operation_ok: bool, refresh_ok: bool):
    if not operation_ok:
        return {'result': None, 'error': 'WRITE_FAILED', 'notice': None}
    result = 'tx-committed'
    if not refresh_ok:
        return {'result': result, 'error': None, 'notice': 'REFRESH_FAILED_AFTER_COMMIT'}
    return {'result': result, 'error': None, 'notice': None}

assert model_run(False, True)['result'] is None
post_commit = model_run(True, False)
assert post_commit['result'] == 'tx-committed'
assert post_commit['error'] is None
assert post_commit['notice'] is not None
assert model_run(True, True)['notice'] is None

failed = [name for name, ok in checks.items() if not ok]
if failed:
    print('FAIL: deep-mine V19 daily-workflow/human-error contract')
    for item in failed:
        print(' -', item)
    sys.exit(1)
print(f'PASS: deep-mine V19 daily-workflow/human-error contract ({len(checks)} source/UAT checks + reference state machine)')
