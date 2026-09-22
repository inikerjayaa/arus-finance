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
    'transient inactive keeps session while real background replaces sensitive routes',
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

      // Screenshot/system UI/image-picker style transient interruption must not
      // create a new authentication boundary or discard in-progress UI.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(find.text('SAKU terkunci'), findsNothing);
      expect(find.text('Sensitive dialog'), findsOneWidget);
      expect(committed, 0);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.text('SAKU terkunci'), findsNothing);
      expect(find.text('Sensitive dialog'), findsOneWidget);

      // A genuine background boundary arms fail-closed authentication. Flutter
      // deliberately does not render application frames while paused, so the
      // security surface is asserted on the first resumed frame. The app-level
      // privacy shield independently owns the background/Recent Apps cover.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      expect(committed, 0);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.text('SAKU terkunci'), findsOneWidget);
      expect(find.text('Sensitive dialog'), findsNothing);
      expect(committed, 0);

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
