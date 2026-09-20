import 'dart:async';

import 'package:arus_finance/core/services/security_service.dart';
import 'package:arus_finance/features/settings/lock_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _BiometricSecurity extends SecurityService {
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
    'successful biometric completed while inactive unlocks only after immediate resume',
    (tester) async {
      final security = _BiometricSecurity();

      await tester.pumpWidget(
        MaterialApp(
          home: LockGate(
            security: security,
            child: const Text('Sensitive finance data'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(security.biometricCalls, 1);
      expect(find.text('SAKU terkunci'), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();

      // Vivo/OEM-style ordering: BiometricPrompt can finish successfully while
      // Flutter still reports inactive, just before the resumed callback.
      security.pendingBiometric!.complete(true);
      await tester.pump();
      await tester.pump();

      // Never expose finance data while the app is still inactive.
      expect(find.text('SAKU terkunci'), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();

      expect(security.biometricCalls, 1);
      expect(find.text('SAKU terkunci'), findsNothing);
      expect(find.text('Sensitive finance data'), findsOneWidget);
    },
  );

  testWidgets(
    'successful biometric is not carried across a real paused background transition',
    (tester) async {
      final security = _BiometricSecurity();

      await tester.pumpWidget(
        MaterialApp(
          home: LockGate(
            security: security,
            child: const Text('Sensitive finance data'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      security.pendingBiometric!.complete(true);
      await tester.pump();
      await tester.pump();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();

      expect(find.text('SAKU terkunci'), findsOneWidget);
      expect(security.biometricCalls, greaterThanOrEqualTo(1));
    },
  );
}
