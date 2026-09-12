from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
security = (ROOT / 'lib/core/services/security_service.dart').read_text()
gate = (ROOT / 'lib/features/settings/lock_gate.dart').read_text()
test = (ROOT / 'test/biometric_cancel_lock_gate_test.dart').read_text()

checks = {
    'local_auth does not sticky-retry after backgrounding': 'persistAcrossBackgrounding: false' in security,
    'resume does not overlap an in-flight biometric request': 'if (_biometricInFlight) return;' in gate,
    'cancel suppresses automatic retry for current activation': '_biometricAutoSuppressed = true;' in gate,
    'manual biometric retry remains available': '_tryBiometric(manual: true)' in gate,
    'real background may reset one-shot auto attempt': 'state == AppLifecycleState.paused' in gate and '_biometricAutoSuppressed = false;' in gate,
    'widget regression reproduces inactive-resumed cancel': 'handleAppLifecycleStateChanged(AppLifecycleState.inactive)' in test and "complete(false)" in test,
}
failed = [name for name, ok in checks.items() if not ok]
for name, ok in checks.items():
    print(('PASS' if ok else 'FAIL') + ': ' + name)
if failed:
    raise SystemExit(f'FAIL: biometric cancel audit {len(checks)-len(failed)}/{len(checks)}')
print(f'PASS: biometric cancel audit {len(checks)}/{len(checks)}')
