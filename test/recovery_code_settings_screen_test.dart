import 'package:arus_finance/core/services/security_service.dart';
import 'package:arus_finance/features/settings/recovery_code_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _SettingsSecurity extends SecurityService {
  _SettingsSecurity({this.recoveryExists = false});

  bool recoveryExists;
  int generateCalls = 0;

  @override
  Future<bool> hasRecoveryCode() async => recoveryExists;

  @override
  Future<bool> verifyPin(String pin) async => pin == '1234';

  @override
  Future<DateTime?> pinLockedUntil() async => null;

  @override
  Future<String> createRecoveryCode() async {
    generateCalls++;
    recoveryExists = true;
    return 'ABCD-EFGH-JKLM-NPQR';
  }
}

void main() {
  testWidgets(
    'legacy user can create recovery code only after current PIN confirmation',
    (tester) async {
      final security = _SettingsSecurity();

      await tester.pumpWidget(
        MaterialApp(
          home: RecoveryCodeSettingsScreen(security: security),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Siapkan kode pemulihan'), findsOneWidget);
      await tester.tap(find.byKey(const Key('recovery_settings_generate')));
      await tester.pumpAndSettle();

      expect(find.text('Konfirmasi PIN'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('recovery_settings_pin')),
        '1234',
      );
      await tester.tap(find.text('Lanjut'));
      await tester.pumpAndSettle();

      expect(security.generateCalls, 1);
      expect(find.text('ABCD-EFGH-JKLM-NPQR'), findsOneWidget);

      final finishBeforeSave = tester.widget<FilledButton>(
        find.byKey(const Key('recovery_settings_finish')),
      );
      expect(finishBeforeSave.onPressed, isNull);

      await tester.tap(find.byKey(const Key('recovery_settings_saved')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('recovery_settings_finish')));
      await tester.pumpAndSettle();

      expect(find.text('Kode pemulihan sudah aktif'), findsOneWidget);
    },
  );

  testWidgets('wrong current PIN cannot rotate recovery code', (tester) async {
    final security = _SettingsSecurity(recoveryExists: true);

    await tester.pumpWidget(
      MaterialApp(
        home: RecoveryCodeSettingsScreen(security: security),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('recovery_settings_generate')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('recovery_settings_pin')),
      '9999',
    );
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();

    expect(security.generateCalls, 0);
    expect(find.text('PIN tidak cocok.'), findsOneWidget);
  });
}
