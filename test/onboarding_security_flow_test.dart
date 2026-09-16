import 'package:arus_finance/core/services/security_service.dart';
import 'package:arus_finance/features/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _OnboardingSecurity extends SecurityService {
  String? savedPin;
  int recoveryCalls = 0;

  @override
  Future<void> setPin(String pin) async {
    savedPin = pin;
  }

  @override
  Future<String> createRecoveryCode() async {
    recoveryCalls++;
    return 'ABCD-EFGH-JKLM-NPQR';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('fresh onboarding requires name PIN and recovery-code acknowledgement',
      (tester) async {
    final security = _OnboardingSecurity();
    var done = false;

    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingScreen(
          security: security,
          onDone: () => done = true,
        ),
      ),
    );

    expect(find.text('Siapa nama kamu?'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('onboarding_name_input')),
      '  Ema  ',
    );
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();

    expect(find.text('Buat PIN Arus'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('onboarding_pin_input')),
      '1234',
    );
    await tester.enterText(
      find.byKey(const Key('onboarding_pin_confirm_input')),
      '1234',
    );
    await tester.tap(find.text('Buat PIN'));
    await tester.pumpAndSettle();

    expect(security.savedPin, '1234');
    expect(security.recoveryCalls, 1);
    expect(find.text('Simpan kode pemulihan'), findsOneWidget);
    expect(find.text('ABCD-EFGH-JKLM-NPQR'), findsOneWidget);
    expect(done, isFalse);

    final finishButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Masuk ke Arus'),
    );
    expect(finishButton.onPressed, isNull);

    await tester.tap(find.byKey(const Key('onboarding_recovery_saved')));
    await tester.pump();
    await tester.tap(find.text('Masuk ke Arus'));
    await tester.pumpAndSettle();

    expect(done, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboarding_done_v1'), isTrue);
    expect(prefs.getBool('onboarding_security_v2'), isTrue);
    expect(prefs.getString('profile_name_v1'), 'Ema');
  });
}
