import 'package:arus_finance/shared/saku_brand.dart';
import 'package:arus_finance/shared/saku_splash.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('SAKU splash is brand-only and has no progress spinner', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SakuSplashScreen()),
    );

    expect(find.text('SAKU'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, SakuBrand.noturno);
  });
}
