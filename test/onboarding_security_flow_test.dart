import 'package:arus_finance/features/onboarding_screen.dart';
import 'package:arus_finance/shared/saku_splash.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('fresh install asks only for name before entering SAKU',
      (tester) async {
    var done = false;

    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingScreen(onDone: () => done = true),
      ),
    );

    expect(find.byType(SakuBrandLockup), findsOneWidget);
    expect(find.text('SAKU'), findsOneWidget);
    expect(find.byKey(const Key('onboarding_name_input')), findsOneWidget);
    expect(find.byKey(const Key('onboarding_create_button')), findsOneWidget);
    expect(find.byKey(const Key('onboarding_pin_input')), findsNothing);
    expect(find.byKey(const Key('onboarding_pin_confirm_input')), findsNothing);
    expect(find.text('Mulai dengan SAKU'), findsNothing);
    expect(find.textContaining('Siapkan sekali'), findsNothing);
    expect(find.textContaining('Isi nama dan PIN'), findsNothing);
    expect(find.textContaining('Contoh: Ema'), findsNothing);
    expect(find.textContaining('Tidak perlu login'), findsNothing);

    await tester.enterText(
      find.byKey(const Key('onboarding_name_input')),
      '  Ema  ',
    );
    await tester.tap(find.byKey(const Key('onboarding_create_button')));
    await tester.pumpAndSettle();

    expect(done, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboarding_done_v1'), isTrue);
    expect(prefs.getString('profile_name_v1'), 'Ema');
  });

  testWidgets('blank name stays on onboarding with a clear error', (tester) async {
    var done = false;

    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingScreen(onDone: () => done = true),
      ),
    );

    await tester.tap(find.byKey(const Key('onboarding_create_button')));
    await tester.pump();

    expect(find.text('Nama tidak boleh kosong.'), findsOneWidget);
    expect(done, isFalse);
  });
}
