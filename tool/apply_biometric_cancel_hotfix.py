from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace_once(path: str, old: str, new: str) -> None:
    p = ROOT / path
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'FAIL: {path}: expected one match, found {count}: {old[:100]!r}')
    p.write_text(text.replace(old, new, 1))


replace_once(
    'lib/core/services/security_service.dart',
    "        persistAcrossBackgrounding: true,\n",
    "        // Do not let the plugin re-open the biometric prompt after an OS\n"
    "        // lifecycle transition. Cancel must return control to Arus so the\n"
    "        // user can fall back to the app PIN. LockGate owns any later retry.\n"
    "        persistAcrossBackgrounding: false,\n",
)

replace_once(
    'lib/features/settings/lock_gate.dart',
    "  bool _biometricInFlight = false;\n  bool _biometricAvailable = false;\n",
    "  bool _biometricInFlight = false;\n"
    "  bool _biometricAutoSuppressed = false;\n"
    "  bool _biometricAvailable = false;\n",
)

replace_once(
    'lib/features/settings/lock_gate.dart',
    "    if (state == AppLifecycleState.resumed) {\n"
    "      _foreground = true;\n"
    "      unawaited(_refreshPinStateOnResume(_lifecycleGeneration));\n"
    "      return;\n"
    "    }\n",
    "    if (state == AppLifecycleState.resumed) {\n"
    "      _foreground = true;\n"
    "      // Android's biometric prompt can emit inactive/resumed while the\n"
    "      // authenticate Future is still in flight. Never start a second\n"
    "      // biometric request from that synthetic resume.\n"
    "      if (_biometricInFlight) return;\n"
    "      unawaited(_refreshPinStateOnResume(_lifecycleGeneration));\n"
    "      return;\n"
    "    }\n",
)

replace_once(
    'lib/features/settings/lock_gate.dart',
    "      _foreground = false;\n"
    "      // Hide finance data immediately. Do not wait for secure-storage I/O;\n",
    "      _foreground = false;\n"
    "      // A real background transition starts a new activation, so one\n"
    "      // automatic biometric attempt is allowed again next time. Merely\n"
    "      // becoming inactive for the biometric system dialog does not reset\n"
    "      // cancellation suppression.\n"
    "      if (!_biometricInFlight &&\n"
    "          (state == AppLifecycleState.paused ||\n"
    "              state == AppLifecycleState.hidden ||\n"
    "              state == AppLifecycleState.detached)) {\n"
    "        _biometricAutoSuppressed = false;\n"
    "      }\n"
    "      // Hide finance data immediately. Do not wait for secure-storage I/O;\n",
)

replace_once(
    'lib/features/settings/lock_gate.dart',
    "    if (biometricEnabled) {\n"
    "      if (!mounted || !_foreground || generation != _lifecycleGeneration) return;\n"
    "      await _tryBiometric();\n"
    "    }\n",
    "    if (biometricEnabled && !_biometricAutoSuppressed) {\n"
    "      if (!mounted || !_foreground || generation != _lifecycleGeneration) return;\n"
    "      await _tryBiometric();\n"
    "    }\n",
)

old_try = """  Future<void> _tryBiometric() async {
    if (_biometricInFlight || !_foreground || !_hasPin) return;
    _biometricInFlight = true;
    try {
      final ok = await widget.security.authenticateBiometric();
      if (!mounted || !_foreground || !_hasPin) return;
      if (ok) {
        setState(() {
          _locked = false;
          _error = null;
          _pin.clear();
        });
      }
    } finally {
      _biometricInFlight = false;
    }
  }
"""
new_try = """  Future<void> _tryBiometric({bool manual = false}) async {
    if (_biometricInFlight || !_foreground || !_hasPin) return;
    if (manual) _biometricAutoSuppressed = false;
    _biometricInFlight = true;
    try {
      final ok = await widget.security.authenticateBiometric();
      if (!mounted || !_hasPin) return;
      if (!ok) {
        // false includes a normal user Cancel. Keep the gate locked and stop
        // automatic biometric retries for this activation. PIN remains usable;
        // the explicit biometric button is the only retry path until a genuine
        // background/foreground cycle occurs.
        _biometricAutoSuppressed = true;
        if (_foreground) {
          setState(() {
            _locked = true;
            _error = null;
          });
        }
        return;
      }
      if (!_foreground) {
        // Never expose finance data because auth completed while Arus was not
        // visibly foregrounded. Require PIN/manual biometric after resume.
        _biometricAutoSuppressed = true;
        return;
      }
      setState(() {
        _locked = false;
        _error = null;
        _pin.clear();
      });
    } finally {
      _biometricInFlight = false;
    }
  }
"""
replace_once('lib/features/settings/lock_gate.dart', old_try, new_try)

replace_once(
    'lib/features/settings/lock_gate.dart',
    "                    onPressed: _tryBiometric,\n",
    "                    onPressed: () => _tryBiometric(manual: true),\n",
)

(ROOT / 'test/biometric_cancel_lock_gate_test.dart').write_text(r'''import 'dart:async';

import 'package:arus_finance/core/services/security_service.dart';
import 'package:arus_finance/features/settings/lock_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSecurityService extends SecurityService {
  int biometricCalls = 0;
  Completer<bool>? pendingBiometric;

  @override
  Future<bool> hasPin() async => true;

  @override
  Future<bool> canUseBiometrics() async => true;

  @override
  Future<bool> biometricEnabled() async => true;

  @override
  Future<bool> authenticateBiometric() {
    biometricCalls++;
    pendingBiometric = Completer<bool>();
    return pendingBiometric!.future;
  }

  @override
  Future<bool> verifyPin(String pin) async => pin == '1234';

  @override
  Future<DateTime?> pinLockedUntil() async => null;
}

void main() {
  testWidgets(
    'cancelled biometric does not auto-loop and explicit retry still works',
    (tester) async {
      final security = _FakeSecurityService();
      await tester.pumpWidget(
        MaterialApp(
          home: LockGate(
            security: security,
            child: const Text('Unlocked finance'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(security.biometricCalls, 1);

      // Reproduce Android biometric dialog lifecycle: system prompt can make
      // Flutter inactive then resumed before authenticate() completes.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(security.biometricCalls, 1);

      // User presses Cancel in the system biometric prompt.
      security.pendingBiometric!.complete(false);
      await tester.pump();
      await tester.pump();
      expect(security.biometricCalls, 1);
      expect(find.text('Arus terkunci'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Gunakan biometrik'), findsOneWidget);

      // Another synthetic resume must not reopen biometric automatically.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(security.biometricCalls, 1);

      // User can explicitly try biometric again; success unlocks the app.
      await tester.tap(find.text('Gunakan biometrik'));
      await tester.pump();
      expect(security.biometricCalls, 2);
      security.pendingBiometric!.complete(true);
      await tester.pump();
      await tester.pump();
      expect(find.text('Unlocked finance'), findsOneWidget);
    },
  );
}
''')

(ROOT / 'tool/deep_mine_biometric_cancel_audit.py').write_text(r'''from pathlib import Path

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
''')

run_all = ROOT / 'tool/run_all_audits.sh'
text = run_all.read_text()
needle = 'python3 tool/deep_mine_v27_git_bootstrap_audit.py\n'
if needle not in text:
    raise SystemExit('FAIL: run_all insertion point missing')
if 'deep_mine_biometric_cancel_audit.py' not in text:
    run_all.write_text(text.replace(needle, needle + 'python3 tool/deep_mine_biometric_cancel_audit.py\n', 1))

print('PASS: biometric cancel hotfix applied')
