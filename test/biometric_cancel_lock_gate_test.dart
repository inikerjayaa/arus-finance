import 'dart:async';

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

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(security.biometricCalls, 1);

      security.pendingBiometric!.complete(false);
      await tester.pump();
      await tester.pump();
      expect(security.biometricCalls, 1);
      expect(find.text('SAKU terkunci'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Gunakan biometrik'), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(security.biometricCalls, 1);

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
