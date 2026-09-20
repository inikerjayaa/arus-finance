import 'package:arus_finance/core/services/security_service.dart';
import 'package:arus_finance/features/settings/lock_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecoverySecurity extends SecurityService {
  int recoveryCalls = 0;

  @override
  Future<bool> hasPin() async => true;

  @override
  Future<bool> canUseBiometrics() async => false;

  @override
  Future<bool> biometricEnabled() async => false;

  @override
  Future<bool> hasRecoveryCode() async => true;

  @override
  Future<DateTime?> pinLockedUntil() async => null;

  @override
  Future<bool> verifyPin(String pin) async => false;

  @override
  Future<String?> resetPinWithRecoveryCode({
    required String recoveryCode,
    required String newPin,
  }) async {
    recoveryCalls++;
    if (recoveryCode == 'ABCD-EFGH-JKLM-NPQR' && newPin == '5678') {
      return 'RSTU-VWXY-2345-6789';
    }
    return null;
  }

  @override
  Future<DateTime?> recoveryLockedUntil() async => null;
}

void main() {
  testWidgets('forgot PIN recovery stays inside LockGate and unlocks after new code is saved',
      (tester) async {
    final security = _RecoverySecurity();

    await tester.pumpWidget(
      MaterialApp(
        home: LockGate(
          security: security,
          child: const Text('Sensitive home'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('SAKU terkunci'), findsOneWidget);
    expect(find.text('Sensitive home'), findsOneWidget);

    await tester.tap(find.text('Lupa PIN?'));
    await tester.pumpAndSettle();

    expect(find.text('Pulihkan PIN'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('recovery_new_pin_input')),
      '5678',
    );
    await tester.enterText(
      find.byKey(const Key('recovery_confirm_pin_input')),
      '5678',
    );
    await tester.enterText(
      find.byKey(const Key('recovery_code_input')),
      'ABCD-EFGH-JKLM-NPQR',
    );
    await tester.tap(find.text('Reset dengan kode'));
    await tester.pumpAndSettle();

    expect(security.recoveryCalls, 1);
    expect(find.text('PIN berhasil diganti'), findsOneWidget);
    expect(find.text('RSTU-VWXY-2345-6789'), findsOneWidget);

    final openButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Buka SAKU'),
    );
    expect(openButton.onPressed, isNull);

    await tester.tap(find.byKey(const Key('replacement_recovery_saved')));
    await tester.pump();
    await tester.tap(find.text('Buka SAKU'));
    await tester.pumpAndSettle();

    expect(find.text('SAKU terkunci'), findsNothing);
    expect(find.text('Sensitive home'), findsOneWidget);
  });
}
