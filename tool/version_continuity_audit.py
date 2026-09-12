from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
read = lambda rel: (ROOT / rel).read_text()
repo = read('lib/data/local_finance_repository.dart')
schema = read('lib/core/db/schema.dart')
db = read('lib/core/db/app_database.dart')
backup = read('lib/core/services/backup_service.dart')
notif = read('lib/core/services/local_notification_service.dart')
csv_import = read('lib/core/services/csv_import_service.dart')
blueprint = read('docs/MASTER_BLUEPRINT_FINAL_V2.md')
limits = read('lib/domain/money_limits.dart')
compile_risk = read('tool/compile_risk_audit.py')
money = read('lib/shared/money.dart')
recovery_src = read('lib/features/recovery/recovery_screen.dart')
settings = read('lib/features/settings/settings_screen.dart')
app = read('lib/app.dart')
security = read('lib/core/services/security_service.dart')
lock_gate = read('lib/features/settings/lock_gate.dart')
hardener = read('tool/native_hardening.py')
release_gate = read('tool/native_release_gate.sh')
compile_gate = read('tool/native_compile_gate.sh')
preflight = read('tool/native_toolchain_preflight.sh')
configure_signing = read('tool/configure_android_release_signing.py')
verify_signing = read('tool/verify_android_release_signing.py')
native_setup = read('docs/NATIVE_SETUP.md')
pubspec = read('pubspec.yaml')
evidence_tool = read('tool/capture_native_evidence.py')
ios_modern_verify = read('tool/verify_ios_modern_contract.py')
flutter_pin = read('toolchain/flutter_version.txt').strip()
onboarding = read('lib/features/onboarding_screen.dart')
quick_add = read('lib/features/quick_add/quick_add_sheet.dart')
accounts_screen = read('lib/features/accounts/accounts_screen.dart')
financial_actions = read('lib/features/accounts/financial_actions_screen.dart')
transactions_screen = read('lib/features/transactions/transactions_screen.dart')
transaction_detail = read('lib/features/transactions/transaction_detail_screen.dart')
finance_widgets = read('lib/shared/finance_widgets.dart')
app_theme = read('lib/shared/app_theme.dart')
planning_screen = read('lib/features/planning/planning_screen.dart')
a11y_test = read('test/accessibility_guidelines_test.dart')
app_controller = read('lib/app_controller.dart')
app_shell = read('lib/app_shell.dart')
workflow_uat = read('docs/WORKFLOW_STRESS_UAT_V19.md')
long_session_uat = read('docs/LONG_SESSION_STRESS_UAT_V20.md')
home_screen = read('lib/features/home/home_screen.dart')
rebuild_uat = read('docs/REBUILD_LIFECYCLE_UAT_V21.md')
atomic_filter_uat = read('docs/ATOMIC_FILTER_STATE_UAT_V22.md')
privacy_shield_uat = read('docs/PRIVACY_SHIELD_UAT_V23.md')
pre_native_rc = read('docs/PRE_NATIVE_RELEASE_CANDIDATE_V24.md')
ci_handoff_v25 = read('docs/NATIVE_CI_HANDOFF_V25.md')
ci_workflow_v25 = read('.github/workflows/native-verify.yml')
installer_v25 = read('tool/install_pinned_flutter_ci.py')
dart_pin = read('toolchain/dart_version.txt').strip()
ci_handoff_v26 = read('docs/RELEASE_ORCHESTRATION_V26.md')
ci_lock_bootstrap_v26 = read('.github/workflows/dependency-lock-bootstrap.yml')
action_pins_v26 = read('toolchain/github_actions_pins.json')
git_bootstrap_create_v27 = read('tool/create_git_bootstrap_bundle.sh')
git_bootstrap_verify_v27 = read('tool/verify_git_bootstrap_bundle.sh')
git_handoff_v27 = read('docs/GIT_BOOTSTRAP_HANDOFF_V27.md')
readiness_v26 = read('tool/release_readiness_report.py')
orchestrator_v26 = read('tool/release_orchestrator.sh')

checks = {
    # V1/V2 — product/domain baseline carried by current implementation.
    'V1/V2 master blueprint retained': '# PERSONAL FINANCE APP — MASTER BLUEPRINT FINAL V2' in blueprint,
    'V1/V2 integer ledger transaction engine retained': all(x in repo for x in [
        'createExpense(', 'createIncome(', 'createTransfer(', 'createRefund(',
        'createCreditCardPayment(', 'createLoanDisbursement(', 'createLoanPayment(',
        'reconcileAccount('
    ]),
    'V1/V2 invariant test retained': (ROOT / 'test/finance_invariants_test.dart').exists(),

    # V3 — local-only pivot.
    'V3 local-only normative architecture retained': (ROOT / 'docs/LOCAL_ONLY_ARCHITECTURE_V3.md').exists(),
    'V3 encrypted local DB / no required sync production path': 'sqlite3mc' in read('README.md') and (ROOT / 'future_optional/README.md').exists(),

    # V4 — recurring/data/archive correctness.
    'V4 recurring occurrence normalized migration retained': "occurrence_key = rule_id || ':' || substr(scheduled_for,1,10)" in schema,
    'V4 recurring draft leg backfill retained': 'Legacy recurring drafts did not persist the intended account leg' in schema,
    'V4 active account/category ambiguity guards retained': all(x in repo for x in ['Duplicate active account', 'Duplicate active category']) if 'Duplicate active account' in repo else ('COLLATE NOCASE' in repo),
    'V4 IDR-only core retained': '_requireSupportedCurrency' in repo,

    # V5 — durability/VOID/security.
    'V5 WAL + synchronous FULL retained': 'PRAGMA journal_mode = WAL' in db and 'PRAGMA synchronous = FULL' in db,
    'V5 explicit VOID retained': 'voidTransaction(' in repo,
    'V5 backup quick integrity retained': 'assertQuickIntegrity' in backup,

    # V6 — import/notification/draft recurring.
    'V6 CSV import retained': 'maxRows = 5000' in csv_import and 'importSimpleTransactionsAtomically' in repo,
    'V6 privacy-safe local notifications retained': 'LocalNotificationService' in notif and 'details' in notif,
    'V6 recurring materializes as DRAFT retained': 'Recurring materialization is always a draft' in repo,
    'V6 large-history index retained': 'idx_tx_timeline' in schema,

    # V7 — differential scheduling / FTS / secure delete / future guard.
    'V7 FTS5 retained': 'CREATE VIRTUAL TABLE IF NOT EXISTS transaction_search USING fts5' in schema,
    'V7 secure delete retained': 'PRAGMA secure_delete = ON' in db,
    'V7 future POSTED guard retained': '_requirePostableDate' in repo,
    'V7 bounded import preflight retained': 'chunkSize = 400' in repo and 'sourceChunkSize = 300' in repo,

    # V8 — Bill uniqueness and time-correct reporting guardrails.
    'V8 Bill unique payment index retained': 'idx_bills_paid_tx_unique' in schema,
    'V8 payBill atomic latest-state recheck retained': 'final latestBill = db.select' in repo,
    'V8 refund chronology retained': 'Tanggal refund tidak boleh mendahului transaksi original.' in repo,
    'V8 legacy future POSTED excluded from balance': 't.local_date <= ?' in repo,

    # V9 — local-only lifecycle cleanup/recovery.
    'V9 hard delete retained': "db.execute('DELETE FROM transactions WHERE id=?', [id]);" in repo,
    'V9 Bill/refund reconciliation retained': '_reconcileBillForPayment' in repo,
    'V9 bad-clock recurring healing retained': 'monthsAhead > 2' in repo and 'monthGap > 24' in repo,
    'V9 backup 64 MiB cap retained': '64 * 1024 * 1024' in backup,
    'V9 tombstone cleanup migration retained': "DELETE FROM transactions WHERE deleted_at IS NOT NULL" in schema,

    # V10 — semantic firewall and composite VOID.
    'V10 group-wide VOID refund guard retained': 'Composite VOID is all-or-nothing' in repo,
    'V10 refund destination guard retained': '_requireRefundDestination(destination);' in repo,
    'V10 transaction semantic firewall retained': all(x in backup for x in [
        'invalidSimpleSemantics', 'invalidSpecialSemantics', 'invalidGroupShape'
    ]),

    # V11 — atomic recheck + planning/group firewall.
    'V11 refund atomic recheck retained': 'final latestRefunded = db.select' in repo,
    'V11 loan outstanding atomic recheck retained': 'final latestOutstanding = _accountBalanceInDb(db, loanAccountId);' in repo,
    'V11 recurring domain guard retained': '_requireRecurringExpenseAccount' in repo,
    'V11 planning semantic firewall retained': all(x in backup for x in [
        'invalidBudgetSemantics', 'invalidBillSemantics', 'invalidRecurringSemantics'
    ]),
    'V11 strict group semantics retained': 'invalidGroupSemantics' in backup and 'invalidGroupMembership' in backup,
    'V11 milestone report retained': (ROOT / 'docs/BUG_HUNT_LOCAL_ONLY_V11_REPORT.md').exists(),

    # V12 — restore/compiler/integer boundary hardening.
    'V12 legacy local-only restore repair helper retained': 'void _repairLegacyLocalOnlyState(dynamic db)' in backup,
    'V12 authenticated backup envelope metadata retained': all(x in backup for x in [
        "envelope['kdf'] != 'ARGON2ID'", "envelope['memory_kib'] != 65536",
        "envelope['iterations'] != 3", "envelope['parallelism'] != 2",
        'salt.length != 16', 'nonce.length != 12', 'macBytes.length != 16'
    ]),
    'V12 money safety envelope retained': 'kMaxMoneyMinor = 9_000_000_000_000' in limits and '_requireMoneyMagnitude' in repo,
    'V12 UI/parser money envelope retained': 'parsed > kMaxMoneyMinor' in money,
    'V12 CSV import money envelope retained': 'amount! > kMaxMoneyMinor' in csv_import,
    'V12 backup semantic/date/money firewall retained': all(x in backup for x in [
        'invalidAccountSemantics', 'invalidCategorySemantics', 'invalidImportFingerprint',
        'invalidMoneyRange', 'invalidDateSemantics', 'invalidRefundSemantics',
        'invalidRecurringOccurrenceSemantics'
    ]),
    'V12 compile-risk private helper detector retained': 'unresolved private helper candidate' in compile_risk,
    'V12 deep-mine executable audit retained': (ROOT / 'tool/deep_mine_v12_source_audit.py').exists(),
    'V12 milestone report retained': (ROOT / 'docs/BUG_HUNT_LOCAL_ONLY_V12_REPORT.md').exists(),

    # V13 — catastrophe recovery / true historical portability.
    'V13 real startup migrates before current-object ensure': (
        db.index('while (version < kSchemaVersion)') < db.index('_ensureCurrentSchemaObjects(database);')
    ),
    'V13 missing/corrupt schema metadata fails closed': all(x in db for x in [
        'Metadata versi database hilang/ambigu', 'Metadata versi database rusak'
    ]),
    'V13 existing encrypted DB without key fails closed': all(x in db for x in [
        'databaseAlreadyExists', 'Kunci database lokal tidak tersedia', 'database?.close();'
    ]),
    'V13 quick integrity includes foreign-key check': "PRAGMA foreign_key_check" in db,
    'V13 consistent backup snapshot retained': 'T readSnapshot<T>' in db and 'database.readSnapshot((db)' in backup,
    'V13 backup semantic preflight retained': '_validateLedger(db);' in backup and backup.index('_validateLedger(db);') < backup.index("'format': 'arus-finance-backup'"),
    'V13 historical portable backup migration retained': 'void _repairLegacyPortableBackupState(dynamic db, int schemaVersion)' in backup,
    'V13 V3 recurring duplicate migration safety retained': (
        'DELETE FROM recurring_occurrences' in schema and
        "GROUP BY rule_id, substr(scheduled_for,1,10)" in schema and
        "occurrence_key = rule_id || ':' || substr(scheduled_for,1,10)" in schema
    ),
    'V13 V3 recurring draft leg portability retained': 'Legacy recurring drafts did not persist the intended account leg' in schema and 'schemaVersion < 4' in backup,
    'V13 V4 next-run portability retained': 'schemaVersion < 5' in backup and 'UPDATE recurring_rules SET next_run = substr(next_run,1,10)' in backup,
    'V13 V7 duplicate Bill portability retained': 'schemaVersion < 8' in backup and 'legacyPaidBillTransactions' in backup,
    'V13 atomic initial category seed retained': 'First-run/reset seed must be all-or-nothing' in repo,
    'V13 deep-mine recovery audit retained': (ROOT / 'tool/deep_mine_v13_recovery_audit.py').exists(),
    'V13 milestone report retained': (ROOT / 'docs/BUG_HUNT_LOCAL_ONLY_V13_REPORT.md').exists(),

    # V14 — data survival / self-recovery.
    'V14 fresh recovery marker state machine retained': all(x in db for x in [
        "'state': 'preparing'", "'state': 'quarantined'", "'state': 'replacement_validated'"
    ]),
    'V14 DB/WAL/SHM quarantine family retained': all(x in db for x in [
        "'arus_finance.db-wal'", "'arus_finance.db-shm'", '_moveDatabaseFamilyToQuarantine'
    ]),
    'V14 pre-move crash protection retained': 'session.hadDatabase && !await quarantinedDatabase.exists()' in db,
    'V14 separate local recovery key retained': 'arus_local_recovery_key_v1' in db,
    'V14 AES-GCM local recovery generations retained': "'format': 'arus-finance-local-recovery'" in backup and 'SecretKey(rawKey)' in backup,
    'V14 generation verify-before-prune retained': backup.index('await _decodeLocalRecovery(pending);') < backup.index('generations.skip(keep)'),
    'V14 portable pending/rename durability retained': '.arus_backup_$stamp.pending' in backup and 'pending.rename(file.path)' in backup,
    'V14 portable fresh recovery retained': 'restorePortableBackupAsRecovery' in backup,
    'V14 local generation fresh recovery retained': 'restoreLatestLocalRecoveryAsRecovery' in backup,
    'V14 safe recovery screen retained': 'class RecoveryScreen extends StatefulWidget' in recovery_src,
    'V14 recovery UI protected by lock retained': 'RecoveryScreen(' in app and 'return LockGate(' in app,
    'V14 healthy startup recovery generation retained': 'createLocalRecoveryGeneration()' in app,
    'V14 explicit wipe purges recovery material retained': 'destroyLocalRecoveryMaterial' in settings,
    'V14 executable survival audit retained': (ROOT / 'tool/deep_mine_v14_survival_audit.py').exists(),
    'V14 milestone report retained': (ROOT / 'docs/BUG_HUNT_LOCAL_ONLY_V14_REPORT.md').exists(),

    # V15 — native readiness / device-boundary hardening.
    'V15 secure-storage 11.1 baseline retained': 'flutter_secure_storage: ^11.1.0' in pubspec,
    'V15 secure-storage fail-closed retained': 'AndroidOptions(resetOnError: false)' in db and 'AndroidOptions(resetOnError: false)' in security,
    'V15 enrolled-biometric check retained': 'getAvailableBiometrics()).isNotEmpty' in security,
    'V15 lifecycle anti-race app lock retained': all(x in lock_gate for x in ['_foreground', '_biometricInFlight', '_lifecycleGeneration']),
    'V15 timezone fail-closed reminder retained': 'Zona waktu perangkat tidak dapat dibaca' in notif and 'tz.setLocalLocation(tz.UTC)' not in notif,
    'V15 Android FragmentActivity retained': 'FlutterFragmentActivity' in hardener,
    'V15 Android API24/API36 native floor retained': 'minSdk = 24' in hardener and 'targetSdk = 36' in hardener,
    'V15 Android AppCompat biometric theme retained': 'Theme.AppCompat.DayNight' in hardener and 'androidx.appcompat:appcompat:1.8.0' in hardener,
    'V25-corrected iOS 15/Face ID native floor retained': 'IPHONEOS_DEPLOYMENT_TARGET = 15.0;' in hardener and 'NSFaceIDUsageDescription' in hardener,
    'V15 reproducible native release gate retained': 'flutter pub get --enforce-lockfile' in release_gate and 'flutter build appbundle --release' in release_gate,
    'V15 current store baseline documented': 'Android 16 / API 36+' in native_setup and 'Xcode 26+' in native_setup,
    'V15 executable native-readiness audit retained': (ROOT / 'tool/deep_mine_v15_native_readiness_audit.py').exists(),
    'V15 milestone report retained': (ROOT / 'docs/BUG_HUNT_LOCAL_ONLY_V15_REPORT.md').exists(),

    # V16 — truthful native gate / first-build readiness.
    'V16 staged bootstrap retained': 'mktemp -d' in read('bootstrap.sh') and '$TMP_ROOT/arus_native_shell' in read('bootstrap.sh'),
    'V16 compile-vs-release gate separation retained': 'not a store-signing claim' in compile_gate and 'STORE-RELEASE native gate' in release_gate,
    'V16 all-platform release cannot silently skip iOS': "'all' memerlukan macOS" in release_gate and 'SKIP:' not in release_gate,
    'V16 Android explicit release signing retained': 'verify_android_release_signing.py' in release_gate and 'rootProject.file("key.properties")' in configure_signing,
    'V16 Android debug-signing rejection retained': 'release build masih memakai debug signing' in verify_signing,
    'V16 signed iOS IPA release path retained': 'flutter build ipa --release' in release_gate and 'flutter build ios --release --no-codesign' not in release_gate,
    'V16 JDK17/API36/Xcode26 preflight retained': 'JDK 17' in preflight and 'platforms/android-36' in preflight and 'Xcode 26+' in preflight,
    'V16 lock UI biometric enrollment gate retained': '_biometricAvailable' in lock_gate and 'if (_biometricAvailable)' in lock_gate,
    'V16 Android signing metadata gitignore retained': 'android/key.properties' in read('.gitignore'),
    'V16 device validation matrix retained': (ROOT / 'docs/NATIVE_VALIDATION_MATRIX.md').exists(),
    'V16 executable truthful-native audit retained': (ROOT / 'tool/deep_mine_v16_native_truth_audit.py').exists(),
    'V16 signing fixture retained': (ROOT / 'tool/reference_android_signing_audit.py').exists(),
    'V16 milestone report retained': (ROOT / 'docs/BUG_HUNT_LOCAL_ONLY_V16_REPORT.md').exists(),

    # V17 — reproducible native execution / modern iOS contract.
    'V17 exact Flutter 3.47.2 pin retained': flutter_pin == '3.47.2' and 'Flutter harus tepat $PINNED_FLUTTER' in preflight,
    'V17 pubspec Flutter floor retained': "flutter: '>=3.47.2 <3.48.0'" in pubspec,
    'V17 SwiftPM-first project config retained': 'enable-swift-package-manager: true' in pubspec,
    'V17 conditional CocoaPods fallback retained': 'if [[ -f ios/Podfile ]]' in preflight and 'Swift Package Manager path' in preflight,
    'V17 UIScene post-build verification retained': 'UIApplicationSceneManifest' in ios_modern_verify and 'verify_ios_modern_contract.py' in compile_gate and 'verify_ios_modern_contract.py' in release_gate,
    'V17 native evidence artifact/source hashing retained': 'artifact_hash' in evidence_tool and 'source_manifest_hash' in evidence_tool and 'pubspec_lock_sha256' in evidence_tool,
    'V17 native evidence signing-secret exclusion retained': 'key.properties' in evidence_tool and '.keystore' in evidence_tool,
    'V17 Android keytool private-key proof retained': '-storepass:env' in verify_signing and 'PrivateKeyEntry' in verify_signing,
    'V17 executable native execution fixture retained': (ROOT / 'tool/reference_v17_native_execution_audit.py').exists(),
    'V17 executable source audit retained': (ROOT / 'tool/deep_mine_v17_native_execution_audit.py').exists(),
    'V17 native execution handoff retained': (ROOT / 'docs/NATIVE_EXECUTION_HANDOFF.md').exists(),
    'V17 milestone report retained': (ROOT / 'docs/BUG_HUNT_LOCAL_ONLY_V17_REPORT.md').exists(),

    # V18 — production UX / accessibility / daily-use safety.
    'V18 pushed Accounts route owns navigation Scaffold': 'return Scaffold(' in accounts_screen and 'appBar: AppBar(' in accounts_screen,
    'V18 pushed Settings route owns navigation Scaffold': "appBar: AppBar(title: const Text('Pengaturan'))" in settings,
    'V18 pushed Financial Actions route owns navigation Scaffold': "appBar: AppBar(title: const Text('Aksi finansial'))" in financial_actions,
    'V18 onboarding large-text scroll safety retained': 'LayoutBuilder(' in onboarding and 'SingleChildScrollView(' in onboarding,
    'V18 quick-add domain-safe account filtering retained': '_eligibleAccounts' in quick_add and 'AccountType.creditCard' in quick_add,
    'V18 quick-add inline/live validation retained': '_amountError' in quick_add and '_submitError' in quick_add and 'liveRegion: true' in quick_add,
    'V18 financial metric no scale-down regression': 'FittedBox(' not in finance_widgets and 'softWrap: true' in finance_widgets,
    'V18 destructive hard-delete truth retained': 'Hapus transaksi permanen?' in transaction_detail and 'tidak dapat dibatalkan tanpa backup' in transaction_detail,
    'V18 VOID reason UI guard retained': 'Alasan VOID wajib diisi.' in transaction_detail,
    'V18 planning destructive confirmations retained': 'Arsipkan budget $name?' in planning_screen and 'Lewati tagihan $name?' in planning_screen,
    'V18 typed local wipe confirmation retained': 'Ketik HAPUS' in settings and "value.trim() == 'HAPUS'" in settings,
    'V18 direct empty-state quick add retained': 'Catat transaksi pertama' in transactions_screen and 'QuickAddSheet.show' in transactions_screen,
    'V18 48dp target theme retained': app_theme.count('Size(48, 48)') >= 8,
    'V18 Flutter accessibility guideline test retained': all(x in a11y_test for x in ['androidTapTargetGuideline','iOSTapTargetGuideline','labeledTapTargetGuideline','textContrastGuideline']),
    'V18 UX UAT matrix retained': (ROOT / 'docs/UX_ACCESSIBILITY_UAT_V18.md').exists(),
    'V18 executable source audit retained': (ROOT / 'tool/deep_mine_v18_ux_accessibility_audit.py').exists(),
    'V18 milestone report retained': (ROOT / 'docs/BUG_HUNT_LOCAL_ONLY_V18_REPORT.md').exists(),

    # V19 — daily workflow stress / human-error hardening.
    'V19 post-commit refresh failure cannot masquerade as write failure': 'The financial write and the presentation refresh are deliberately' in app_controller and 'Muat ulang sebelum mengulangi aksi.' in app_controller,
    'V19 successful-write refresh warning is separate notice channel': 'String? noticeMessage;' in app_controller and 'controller.noticeMessage' in app_shell and 'controller.clearNotice' in app_shell,
    'V19 post-commit warning offers explicit presentation refresh': 'retryPresentationRefresh' in app_controller and "tooltip: 'Muat ulang tampilan'" in app_shell,
    'V19 resume during active write is queued': '_resumeRefreshPending = true' in app_controller and 'unawaited(processAppResume())' in app_controller,
    'V19 quick-add local submit guard retained': '_submitting' in quick_add and 'if (_submitting) return;' in quick_add,
    'V19 quick-add accidental close guard retained': 'PopScope<void>' in quick_add and "title: const Text('Buang perubahan?')" in quick_add and '_closePromptOpen' in quick_add,
    'V19 quick-add explicit non-dismissible sheet retained': 'isDismissible: false' in quick_add and 'enableDrag: false' in quick_add and "tooltip: 'Tutup pencatatan transaksi'" in quick_add,
    'V19 expense edit domain-safe account filtering retained': 'a.accountType == AccountType.creditCard' in transaction_detail and 'a.accountClass == AccountClass.asset' in transaction_detail,
    'V19 posted edit future-date guard retained': 'd.view.status == TransactionStatus.posted ? DateTime.now() : DateTime(2100)' in transaction_detail,
    'V19 draft posting confirmation retained': "title: const Text('Catat draft sekarang?')" in transaction_detail and 'langsung memengaruhi saldo serta laporan' in transaction_detail,
    'V19 workflow stress UAT retained': 'Rapid Save / Double Tap' in workflow_uat and 'Commit Sukses / Refresh Gagal' in workflow_uat and 'Resume Saat Write Sedang Aktif' in workflow_uat,
    'V19 executable source/reference audit retained': (ROOT / 'tool/deep_mine_v19_workflow_stress_audit.py').exists(),
    'V19 milestone report retained': (ROOT / 'docs/BUG_HUNT_LOCAL_ONLY_V19_REPORT.md').exists(),

    # V20 — long-session/state-consistency/performance hardening.
    'V20 timeline generation guard retained': '_transactionRequestGeneration' in app_controller and 'generation != _transactionRequestGeneration' in app_controller,
    'V20 full-refresh generation guard retained': '_refreshRequestGeneration' in app_controller and 'refreshGeneration != _refreshRequestGeneration' in app_controller,
    'V20 single in-flight pagination retained': '_loadingMoreTransactions' in app_controller and '|| _loadingMoreTransactions' in app_controller,
    'V20 stable pagination offset retained': 'final requestOffset = _loadedTransactionCount;' in app_controller and 'offset: transactions.length' not in app_controller,
    'V20 duplicate append guard retained': 'existingIds.add(tx.id)' in app_controller and 'uniqueNext' in app_controller,
    'V20 dashboard recent state isolated from timeline filters': 'List<TransactionView> recentTransactions' in app_controller and 'repository.listTransactions(limit: 5)' in app_controller and 'controller.recentTransactions' in home_screen,
    'V20 pagination progress UI retained': 'controller.loadingMoreTransactions' in transactions_screen and "'Memuat…'" in transactions_screen,
    'V20 long-session UAT retained': 'Rapid Search / Filter Race' in long_session_uat and 'Repeated Pagination' in long_session_uat and '100.000' in long_session_uat,
    'V20 executable source/race audit retained': (ROOT / 'tool/deep_mine_v20_long_session_audit.py').exists(),
    'V20 milestone report retained': (ROOT / 'docs/BUG_HUNT_LOCAL_ONLY_V20_REPORT.md').exists(),
    'V20 continuity doc retained': (ROOT / 'docs/VERSION_CONTINUITY_V1_V20.md').exists(),

    # V21 — root rebuild/lifecycle isolation.
    'V21 selective root controller listener retained': 'widget.controller.addListener(_controllerChanged)' in app and 'widget.controller.addListener(_refresh)' not in app,
    'V21 root only tracks initializing/fatal-recovery modes': '_lastInitializing' in app and '_lastFatalRecovery' in app and 'dashboardData == null' in app,
    'V21 shell controller AnimatedBuilder retained': 'AnimatedBuilder(' in app_shell and 'animation: controller' in app_shell,
    'V21 shell busy/error/notice/navigation reactivity retained': 'if (controller.busy)' in app_shell and 'controller.errorMessage != null' in app_shell and 'controller.noticeMessage != null' in app_shell and 'selectedIndex: controller.navigationIndex' in app_shell,
    'V21 controller listener replacement/dispose retained': 'didUpdateWidget' in app and 'oldWidget.controller.removeListener(_controllerChanged)' in app and 'widget.controller.removeListener(_controllerChanged)' in app,
    'V21 rebuild lifecycle UAT retained': 'Search / Pagination Rebuild Boundary' in rebuild_uat and 'Fatal Recovery Transition' in rebuild_uat,
    'V21 executable rebuild audit retained': (ROOT / 'tool/deep_mine_v21_rebuild_isolation_audit.py').exists(),
    'V21 milestone report retained': (ROOT / 'docs/BUG_HUNT_LOCAL_ONLY_V21_REPORT.md').exists(),
    'V21 continuity doc retained': (ROOT / 'docs/VERSION_CONTINUITY_V1_V21.md').exists(),

    # V22 — atomic timeline presentation state.
    'V22 requested query/filter stay local until success': 'final requestQuery = query?.trim() ?? transactionQuery;' in app_controller and 'final requestFilter = filter ?? transactionFilter;' in app_controller,
    'V22 query/filter commit after stale-generation guard': 'transactionQuery = requestQuery;' in app_controller and 'transactionFilter = requestFilter;' in app_controller,
    'V22 no eager timeline filter mutation retained': 'if (query != null) transactionQuery' not in app_controller and 'if (filter != null) transactionFilter' not in app_controller,
    'V22 reset is request-based retained': "query: ''," in app_controller and 'filter: const TransactionFilter()' in app_controller,
    'V22 search input committed-state resync retained': 'if (_search.text != controller.transactionQuery)' in transactions_screen,
    'V22 atomic filter UAT retained': 'Failed Search / Filter Request' in atomic_filter_uat and 'Failed Clear / Reset' in atomic_filter_uat,
    'V22 executable atomic filter audit retained': (ROOT / 'tool/deep_mine_v22_atomic_filter_state_audit.py').exists(),
    'V22 milestone report retained': (ROOT / 'docs/BUG_HUNT_LOCAL_ONLY_V22_REPORT.md').exists(),
    'V22 continuity doc retained': (ROOT / 'docs/VERSION_CONTINUITY_V1_V22.md').exists(),

    # V23 — sensitive UI privacy shield.
    'V23 Flutter lifecycle privacy shield retained': '_privacyShielded' in app and 'AppLifecycleState.inactive' in app and 'AppLifecycleState.hidden' in app and '_buildPrivacyProtectedHome()' in app,
    'V23 privacy shield clears on resume retained': 'setState(() => _privacyShielded = false)' in app,
    'V23 Android FLAG_SECURE hardening retained': 'WindowManager.LayoutParams.FLAG_SECURE' in hardener and 'android.view.WindowManager' in hardener,
    'V23 privacy shield UAT retained': 'App Switcher Snapshot' in privacy_shield_uat and 'Android Screenshot / Screen Share' in privacy_shield_uat,
    'V23 executable privacy audit retained': (ROOT / 'tool/deep_mine_v23_privacy_shield_audit.py').exists(),
    'V23 milestone report retained': (ROOT / 'docs/BUG_HUNT_LOCAL_ONLY_V23_REPORT.md').exists(),
    'V23 continuity doc retained': (ROOT / 'docs/VERSION_CONTINUITY_V1_V23.md').exists(),

    # V24 — pre-native RC freeze / handoff truthfulness.
    'V24 freeze evidence retained after milestone advance': (ROOT / 'docs/PRE_NATIVE_RELEASE_CANDIDATE_V24.md').exists() and 'SOURCE / NON-NATIVE RC: READY' in pre_native_rc,
    'V24 test matrix carries V20-V23 gates': '79. Out-of-order timeline requests' in read('docs/TEST_MATRIX.md') and '86. Inactive/hidden/paused' in read('docs/TEST_MATRIX.md'),
    'V24 RC keeps SOURCE separate from native proof': 'SOURCE / NON-NATIVE RC: READY' in pre_native_rc and 'Android COMPILE/DEVICE/STORE PASS' in pre_native_rc,
    'V24 native handoff requires pubspec lock/audits/device validation': 'pubspec.lock' in pre_native_rc and 'tool/run_all_audits.sh' in pre_native_rc and 'device validation matrix' in pre_native_rc,
    'V24 executable RC audit retained': (ROOT / 'tool/pre_native_rc_v24_audit.py').exists(),
    'V24 continuity doc retained': (ROOT / 'docs/VERSION_CONTINUITY_V1_V24.md').exists(),

    # V25 — pinned official SDK provenance + reproducible cross-platform CI handoff.
    'V25 milestone retained after V26 advancement': (ROOT / 'docs/NATIVE_CI_HANDOFF_V25.md').exists() and (ROOT / 'docs/BUG_HUNT_LOCAL_ONLY_V25_REPORT.md').exists(),
    'V25 exact Flutter/Dart pins retained': flutter_pin == '3.47.2' and dart_pin == '3.13.2',
    'V25 official release hash/checksum pin retained': 'd3b14c876900e553bc736ca19295fc09e3853e8e' in read('toolchain/flutter_release_pin.json') and '447878859d01ca9bfdb99a85f245af07ed8a15fedcd9d189c4749e8e92d1f185' in read('toolchain/flutter_release_pin.json'),
    'V25 installer fail-closed provenance retained': 'release git hash differs from Arus pin' in installer_v25 and 'Flutter SDK SHA-256 mismatch' in installer_v25,
    'V25 active iOS15 floor retained': 'IPHONEOS_DEPLOYMENT_TARGET = 15.0;' in hardener and 'iOS 15.0+' in native_setup,
    'V25 shared dependency-lock principle retained under V26 committed-lock flow': 'arus-pubspec-lock-v26' in ci_workflow_v25 and 'flutter pub get --enforce-lockfile' in ci_workflow_v25,
    'V25 unprivileged compile CI retained': 'pull_request:' in ci_workflow_v25 and 'pull_request_target' not in ci_workflow_v25 and '${{ secrets.' not in ci_workflow_v25,
    'V25 Android API36 compile job retained': 'ensure_android_sdk_36_ci.sh' in ci_workflow_v25 and 'native_compile_gate.sh android' in ci_workflow_v25,
    'V25 macOS26 iOS compile job retained': 'runs-on: macos-26' in ci_workflow_v25 and 'native_compile_gate.sh ios' in ci_workflow_v25,
    'V25 cross-platform canonical evidence retained': 'canonical_source_manifest' in evidence_tool and 'verify_ci_native_evidence.py' in ci_workflow_v25,
    'V25 CI handoff doc retained': (ROOT / 'docs/NATIVE_CI_HANDOFF_V25.md').exists() and 'REPRODUCIBLE CI HANDOFF' in ci_handoff_v25,
    'V25 executable CI audits retained': (ROOT / 'tool/deep_mine_v25_ci_handoff_audit.py').exists() and (ROOT / 'tool/reference_v25_ci_handoff_audit.py').exists(),
    'V25 milestone report retained': (ROOT / 'docs/BUG_HUNT_LOCAL_ONLY_V25_REPORT.md').exists(),
    'V25 continuity doc retained': (ROOT / 'docs/VERSION_CONTINUITY_V1_V25.md').exists(),

    # V26 — immutable CI supply chain + committed lock + release orchestration.
    'V26 milestone/status section retained': '## V26 release orchestration / immutable CI' in read('docs/IMPLEMENTATION_STATUS_LOCAL_ONLY.md'),
    'V26 immutable GitHub Action pin manifest retained': all(x in action_pins_v26 for x in ['3d3c42e5aac5ba805825da76410c181273ba90b1','043fb46d1a93c77aae656e7c1c64a875d1fc6a0a','3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c','de7274f081f381c8f8158605e0321c36c376e2e6']),
    'V26 executable immutable-action verifier retained': (ROOT / 'tool/verify_ci_action_pins.py').exists(),
    'V26 native verify requires committed lock': 'test -f pubspec.lock' in ci_workflow_v25 and 'flutter pub get --enforce-lockfile' in ci_workflow_v25,
    'V26 manual review-only lock bootstrap retained': 'workflow_dispatch:' in ci_lock_bootstrap_v26 and 'NOT compile/release proof' in ci_lock_bootstrap_v26 and 'pull_request:' not in ci_lock_bootstrap_v26,
    'V26 Android/iOS exact lock comparison retained': ci_workflow_v25.count('cmp --silent pubspec.lock .ci/lock/pubspec.lock') == 2,
    'V26 release readiness truth states retained': all(x in readiness_v26 for x in ['SOURCE_NON_NATIVE','DEPENDENCY_LOCK','ANDROID_COMPILE','IOS_COMPILE','DEVICE_VALIDATION','STORE_ARTIFACTS']),
    'V26 stale source/lock evidence rejection retained': 'different canonical source' in readiness_v26 and 'does not match current committed lock' in readiness_v26,
    'V26 source/status/compile/store orchestrator retained': all(x in orchestrator_v26 for x in ['source)','status)','compile)','store)']),
    'V26 Dependabot action maintenance retained': 'package-ecosystem: github-actions' in read('.github/dependabot.yml'),
    'V26 executable orchestration audits retained': (ROOT / 'tool/deep_mine_v26_release_orchestration_audit.py').exists() and (ROOT / 'tool/reference_v26_release_orchestration_audit.py').exists(),
    'V26 milestone report retained': (ROOT / 'docs/BUG_HUNT_LOCAL_ONLY_V26_REPORT.md').exists(),
    'V26 continuity doc retained': (ROOT / 'docs/VERSION_CONTINUITY_V1_V26.md').exists(),

    # V27 — deterministic Git repository bootstrap transport.
    'V27 canonical status synchronized': 'Canonical persisted milestone: **V27' in read('docs/IMPLEMENTATION_STATUS_LOCAL_ONLY.md'),
    'V27 LF-normalizing gitattributes retained': '* text=auto eol=lf' in read('.gitattributes'),
    'V27 deterministic Git metadata retained': all(x in git_bootstrap_create_v27 for x in ['Arus Finance Canonical Builder','2026-09-12T00:00:00Z','Arus Finance V27 canonical Git bootstrap']),
    'V27 secret/build residue rejection retained': all(x in git_bootstrap_create_v27 for x in ["'*.jks'","'*.keystore'","-name '__pycache__'","-name 'build'"]),
    'V27 Git fsck/bundle verify retained': 'git fsck --full --no-dangling' in git_bootstrap_create_v27 and 'git bundle verify' in git_bootstrap_create_v27,
    'V27 fresh-clone verification retained': 'git clone -q -b main "$bundle"' in git_bootstrap_verify_v27 and 'sha256sum -c "$files_manifest"' in git_bootstrap_verify_v27,
    'V27 Git evidence does not claim native PASS': 'does **not** claim Flutter analyze/test' in git_handoff_v27,
    'V27 executable Git audits retained': (ROOT / 'tool/deep_mine_v27_git_bootstrap_audit.py').exists() and (ROOT / 'tool/reference_v27_git_bootstrap_audit.py').exists(),
    'V27 milestone report retained': (ROOT / 'docs/BUG_HUNT_LOCAL_ONLY_V27_REPORT.md').exists(),
    'V27 continuity doc retained': (ROOT / 'docs/VERSION_CONTINUITY_V1_V27.md').exists(),

}

failed = [name for name, ok in checks.items() if not ok]
if failed:
    print('FAIL: V1→V27 continuity contract')
    for item in failed:
        print(' -', item)
    sys.exit(1)
print(f'PASS: V1→V27 continuity contract ({len(checks)} carry-forward checks)')
