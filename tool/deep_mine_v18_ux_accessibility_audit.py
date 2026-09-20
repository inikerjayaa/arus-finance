"""V18 source contract: production UX, accessibility and daily-use safety."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
read = lambda p: (ROOT / p).read_text()
app = read('lib/app.dart')
splash = read('lib/shared/saku_splash.dart')
shell = read('lib/app_shell.dart')
onboarding = read('lib/features/onboarding_screen.dart')
quick = read('lib/features/quick_add/quick_add_sheet.dart')
accounts = read('lib/features/accounts/accounts_screen.dart')
actions = read('lib/features/accounts/financial_actions_screen.dart')
settings = read('lib/features/settings/settings_screen.dart')
planning = read('lib/features/planning/planning_screen.dart')
detail = read('lib/features/transactions/transaction_detail_screen.dart')
widgets = read('lib/shared/finance_widgets.dart')
theme = read('lib/shared/app_theme.dart')
recovery = read('lib/features/recovery/recovery_screen.dart')
a11y_test = read('test/accessibility_guidelines_test.dart')
transactions = read('lib/features/transactions/transactions_screen.dart')

checks = {
    'startup progress is a labeled live region': (
        'SakuSplashScreen' in app
        and "label: 'SAKU sedang dibuka'" in splash
        and 'liveRegion: true' in splash
    ),
    'global error banner is announced': "label: 'Kesalahan: ${controller.errorMessage!}'" in shell and "tooltip: 'Tutup pesan kesalahan'" in shell,
    'onboarding is large-text scroll safe': 'LayoutBuilder(' in onboarding and 'SingleChildScrollView(' in onboarding and "header: true" in onboarding,
    'onboarding prevents duplicate save': (
        'Future<void> _createSaku() async {' in onboarding
        and 'if (_saving) return;' in onboarding
        and 'onPressed: _saving ? null : _createSaku' in onboarding
        and "await _profile.saveName(cleanName);" in onboarding
        and "await prefs.setBool('onboarding_done_v1', true);" in onboarding
    ),
    'quick add filters income to asset accounts': '_mode == 1' in quick and 'a.accountClass == AccountClass.asset' in quick,
    'quick add allows expense only on asset/card domain': 'a.accountType == AccountType.creditCard' in quick and '_eligibleAccounts' in quick,
    'quick add resets incompatible mode selections': '_accountId = null;' in quick and '_destinationId = null;' in quick,
    'quick add uses inline field errors': all(x in quick for x in ['_amountError', '_accountError', '_categoryError', '_destinationError', '_feeError']),
    'quick add write failures use live region': '_submitError' in quick and 'liveRegion: true' in quick,
    'Accounts pushed route owns a Scaffold/AppBar': "return Scaffold(" in accounts and "appBar: AppBar(" in accounts,
    'Financial Actions pushed route owns a Scaffold/AppBar': "return Scaffold(" in actions and "appBar: AppBar(title: const Text('Aksi finansial'))" in actions,
    'Settings pushed route owns a Scaffold/AppBar': "return Scaffold(" in settings and "appBar: AppBar(title: const Text('Pengaturan'))" in settings,
    'metric values are not scaleDown FittedBox': 'FittedBox(' not in widgets and 'softWrap: true' in widgets,
    'metric cards expose concise semantics': 'Semantics(' in widgets and 'ExcludeSemantics(' in widgets,
    'transaction tiles expose labeled button semantics': 'button: onTap != null' in widgets and "label: '$title, $amount, $subtitle'" in widgets,
    'transaction detail supports retry on load error': "label: const Text('Coba lagi')" in detail,
    'hard delete copy says permanent and backup required': 'Hapus transaksi permanen?' in detail and 'tidak dapat dibatalkan tanpa backup' in detail,
    'VOID reason is required before repository call': 'Alasan VOID wajib diisi.' in detail and 'reason.trim()' in detail,
    'budget archive requires confirmation': 'Arsipkan budget $name?' in planning,
    'bill skip requires confirmation': 'Lewati tagihan $name?' in planning,
    'bill/recurring account choices honor expense account domain': planning.count('AccountType.creditCard') >= 2,
    'full local wipe requires typed HAPUS confirmation': 'Ketik HAPUS' in settings and "value.trim() == 'HAPUS'" in settings,
    'recovery progress/status are live regions': "label: 'Pemulihan sedang berjalan'" in recovery and 'liveRegion: true' in recovery,
    '48dp minimum control theme retained': theme.count('Size(48, 48)') >= 8,
    'empty transaction state has direct add action': 'Catat transaksi pertama' in transactions and 'QuickAddSheet.show' in transactions,
    'Flutter a11y guideline test retained': all(x in a11y_test for x in [
        'androidTapTargetGuideline', 'iOSTapTargetGuideline',
        'labeledTapTargetGuideline', 'textContrastGuideline'
    ]),
    'large-text widget test retained': 'TextScaler.linear(2.0)' in a11y_test and 'find.byType(FittedBox)' in a11y_test,
}

failed = [name for name, ok in checks.items() if not ok]
if failed:
    print('FAIL: V18 production UX/accessibility contract')
    for item in failed:
        print(' -', item)
    raise SystemExit(1)
print(f'PASS: deep-mine V18 production UX/accessibility contract ({len(checks)} source checks)')
