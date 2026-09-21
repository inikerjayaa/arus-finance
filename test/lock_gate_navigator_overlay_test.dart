import 'package:arus_finance/core/services/security_service.dart';
import 'package:arus_finance/features/settings/lock_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _PinSecurity extends SecurityService {
  @override
  Future<bool> hasPin() async => true;

  @override
  Future<bool> canUseBiometrics() async => false;

  @override
  Future<bool> biometricEnabled() async => false;

  @override
  Future<bool> verifyPin(String pin) async => pin == '1234';

  @override
  Future<DateTime?> pinLockedUntil() async => null;
}

void main() {
  testWidgets(
    'security surface replaces an already-open root navigator dialog when locked',
    (tester) async {
      final security = _PinSecurity();
      var committed = 0;

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => LockGate(
            security: security,
            child: child ?? const SizedBox.shrink(),
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('Sensitive dialog'),
                      actions: [
                        FilledButton(
                          onPressed: () {
                            committed++;
                            Navigator.pop(dialogContext);
                          },
                          child: const Text('Commit sensitive action'),
                        ),
                      ],
                    ),
                  ),
                  child: const Text('Open dialog'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('SAKU terkunci'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '1234');
      await tester.tap(find.text('Buka'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open dialog'));
      await tester.pumpAndSettle();
      expect(find.text('Sensitive dialog'), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(find.text('SAKU terkunci'), findsOneWidget);
      // Sensitive routes are deliberately unmounted, not left composited under
      // the lock surface where a stale frame could expose financial data.
      expect(find.text('Sensitive dialog'), findsNothing);
      expect(committed, 0);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();
      await tester.enterText(find.byType(TextField), '1234');
      await tester.tap(find.text('Buka'));
      await tester.pumpAndSettle();

      // The sensitive route was discarded by fail-closed locking and must not
      // silently reappear or commit after authentication.
      expect(find.text('Sensitive dialog'), findsNothing);
      expect(committed, 0);
    },
  );
}
