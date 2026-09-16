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
    'leaving foreground locks above an already-open root navigator dialog',
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

      expect(find.text('Arus terkunci'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '1234');
      await tester.tap(find.text('Buka'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open dialog'));
      await tester.pumpAndSettle();
      expect(find.text('Sensitive dialog'), findsOneWidget);

      // Flutter/Android leaves the foreground through `inactive` before the
      // later hidden/paused states. Arus must fail closed at this earliest
      // transition, not wait for the app to become fully paused.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(find.text('Arus terkunci'), findsOneWidget);
      expect(find.text('Sensitive dialog'), findsOneWidget);

      await tester.tap(
        find.text('Commit sensitive action'),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(committed, 0);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();
      await tester.enterText(find.byType(TextField), '1234');
      await tester.tap(find.text('Buka'));
      await tester.pumpAndSettle();

      expect(find.text('Sensitive dialog'), findsOneWidget);
      await tester.tap(find.text('Commit sensitive action'));
      await tester.pumpAndSettle();
      expect(committed, 1);
    },
  );
}
