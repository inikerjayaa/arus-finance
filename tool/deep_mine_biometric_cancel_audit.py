from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
security = (ROOT / 'lib/core/services/security_service.dart').read_text()
gate = (ROOT / 'lib/features/settings/lock_gate.dart').read_text()
cancel_test = (ROOT / 'test/biometric_cancel_lock_gate_test.dart').read_text()
success_test = (ROOT / 'test/biometric_inactive_success_lock_gate_test.dart').read_text()

checks = {
    'local_auth does not sticky-retry after backgrounding': 'persistAcrossBackgrounding: false' in security,
    'resume does not overlap an in-flight biometric request': 'if (_biometricInFlight) return;' in gate,
    'cancel suppresses automatic retry for current activation': '_biometricAutoSuppressed = true;' in gate,
    'manual biometric retry remains available': '_tryBiometric(manual: true)' in gate,
    'real background may reset one-shot auto attempt': 'state == AppLifecycleState.paused' in gate and '_biometricAutoSuppressed = false;' in gate,
    'widget regression reproduces inactive-resumed cancel': 'handleAppLifecycleStateChanged(AppLifecycleState.inactive)' in cancel_test and 'complete(false)' in cancel_test,
    'transient inactive biometric success waits for resume': '_biometricSuccessPendingResume = true;' in gate and '_biometricSuccessPendingResume && _hasPin' in gate,
    'real background invalidates pending biometric success': '_biometricSuccessPendingResume = false;' in gate and all(state in gate for state in ['AppLifecycleState.paused', 'AppLifecycleState.hidden', 'AppLifecycleState.detached']),
    'widget regression covers OEM success-before-resume ordering': 'complete(true)' in success_test and 'AppLifecycleState.inactive' in success_test and 'AppLifecycleState.resumed' in success_test,
    'widget regression covers stale-success rejection after pause': 'AppLifecycleState.paused' in success_test and 'not carried across a real paused background transition' in success_test,
}
failed = [name for name, ok in checks.items() if not ok]
for name, ok in checks.items():
    print(('PASS' if ok else 'FAIL') + ': ' + name)
if failed:
    raise SystemExit(f'FAIL: biometric lifecycle audit {len(checks)-len(failed)}/{len(checks)}')
print(f'PASS: biometric lifecycle audit {len(checks)}/{len(checks)}')
