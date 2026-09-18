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

  testWidgets(
      'fresh onboarding shows name PIN and confirmation together then recovery code',
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

    expect(find.text('SAKU'), findsOneWidget);
    expect(find.text('Mulai pakai SAKU'), findsOneWidget);
    expect(find.byKey(const Key('onboarding_name_input')), findsOneWidget);
    expect(find.byKey(const Key('onboarding_pin_input')), findsOneWidget);
    expect(
      find.byKey(const Key('onboarding_pin_confirm_input')),
      findsOneWidget,
    );
    expect(find.textContaining('Langkah '), findsNothing);
    expect(find.text('Lanjut'), findsNothing);
    expect(find.text('Kembali'), findsNothing);

    await tester.enterText(
      find.byKey(const Key('onboarding_name_input')),
      '  Ema  ',
    );
    await tester.enterText(
      find.byKey(const Key('onboarding_pin_input')),
      '1234',
    );
    await tester.enterText(
      find.byKey(const Key('onboarding_pin_confirm_input')),
      '1234',
    );
    final saveButton = find.byKey(const Key('onboarding_save_setup'));
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(security.savedPin, '1234');
    expect(security.recoveryCalls, 1);
    expect(find.text('Kode pemulihan PIN'), findsOneWidget);
    expect(find.text('ABCD-EFGH-JKLM-NPQR'), findsOneWidget);
    expect(find.byKey(const Key('onboarding_recovery_saved')), findsNothing);
    expect(done, isFalse);

    final dashboardButton =
        find.byKey(const Key('onboarding_enter_dashboard'));
    await tester.ensureVisible(dashboardButton);
    await tester.tap(dashboardButton);
    await tester.pumpAndSettle();

    expect(done, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboarding_done_v1'), isTrue);
    expect(prefs.getBool('onboarding_security_v2'), isTrue);
    expect(prefs.getString('profile_name_v1'), 'Ema');
  });

  testWidgets('invalid setup does not create PIN or recovery code',
      (tester) async {
    final security = _OnboardingSecurity();

    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingScreen(
          security: security,
          onDone: () {},
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('onboarding_name_input')),
      'Ema',
    );
    await tester.enterText(
      find.byKey(const Key('onboarding_pin_input')),
      '1234',
    );
    await tester.enterText(
      find.byKey(const Key('onboarding_pin_confirm_input')),
      '5678',
    );
    final saveButton = find.byKey(const Key('onboarding_save_setup'));
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pump();

    expect(find.text('Konfirmasi PIN harus sama.'), findsOneWidget);
    expect(security.savedPin, isNull);
    expect(security.recoveryCalls, 0);
    expect(find.text('Kode pemulihan PIN'), findsNothing);
  });
}
