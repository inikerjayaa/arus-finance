import 'package:arus_finance/core/services/security_service.dart';
import 'package:arus_finance/features/onboarding_screen.dart';
import 'package:arus_finance/shared/app_theme.dart';
import 'package:arus_finance/shared/finance_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('onboarding follows core accessibility guidelines', (tester) async {
    final handle = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: OnboardingScreen(
            security: SecurityService(),
            onDone: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    } finally {
      handle.dispose();
    }
  });

  testWidgets('onboarding remains usable with large text on a small phone', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            textScaler: TextScaler.linear(2.0),
          ),
          child: OnboardingScreen(
            security: SecurityService(),
            onDone: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('onboarding_name_input')), findsOneWidget);
    expect(find.byKey(const Key('onboarding_pin_input')), findsOneWidget);
    expect(find.byKey(const Key('onboarding_pin_confirm_input')), findsOneWidget);
    expect(find.text('Buat SAKU'), findsOneWidget);
    await tester.ensureVisible(find.text('Buat SAKU'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('metric card preserves scaled text instead of shrinking it', (tester) async {
    tester.view.physicalSize = const Size(320, 320);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: SingleChildScrollView(
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 260,
                child: MediaQuery(
                  data: MediaQueryData(
                    size: Size(320, 320),
                    textScaler: TextScaler.linear(2.0),
                  ),
                  child: MetricCard(
                    label: 'Saldo tersedia',
                    value: 'Rp 9.000.000.000.000',
                    caption: 'Contoh nominal besar',
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(FittedBox), findsNothing);
  });
}
