import 'package:arus_finance/features/saku_splash_screen.dart';
import 'package:arus_finance/shared/app_theme.dart';
import 'package:arus_finance/shared/saku_brand.dart';
import 'package:arus_finance/shared/saku_icon_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SAKU brand tokens stay locked to approved palette', () {
    expect(SakuBrand.appName, 'SAKU');
    expect(SakuBrand.noturno, const Color(0xFF001621));
    expect(SakuBrand.vulcanico, const Color(0xFFFF4103));
    expect(SakuBrand.sand, const Color(0xFFF0EDE4));
    expect(SakuBrand.fontFamily, 'Plus Jakarta Sans');
  });

  test('master icon catalog contains all required representative groups', () {
    expect(SakuIconCatalog.byId('bca')?.group, SakuIconGroup.bank);
    expect(SakuIconCatalog.byId('dana')?.group, SakuIconGroup.eWallet);
    expect(SakuIconCatalog.byId('gojek')?.group, SakuIconGroup.transport);
    expect(SakuIconCatalog.byId('tokopedia')?.group, SakuIconGroup.marketplace);
    expect(SakuIconCatalog.byId('youtube_premium')?.group, SakuIconGroup.subscription);
    expect(SakuIconCatalog.byId('chatgpt')?.group, SakuIconGroup.ai);
    expect(SakuIconCatalog.byId('telkomsel')?.group, SakuIconGroup.telco);
    expect(SakuIconCatalog.byId('pln')?.group, SakuIconGroup.utility);
    expect(SakuIconCatalog.byId('cash')?.group, SakuIconGroup.generic);
    expect(SakuIconCatalog.byId('claude')?.brandSlug, 'claude');
  });

  test('custom icon selection stays local-path based', () {
    const selection = SakuIconSelection.custom('/local/icons/my-wallet.png');
    expect(selection.source, SakuIconSource.custom);
    expect(selection.customLocalPath, '/local/icons/my-wallet.png');
    expect(selection.catalogId, isNull);
  });

  test('default SAKU theme uses approved surfaces and font family', () {
    final light = AppTheme.light();
    final dark = AppTheme.dark();
    expect(light.scaffoldBackgroundColor, SakuBrand.sand);
    expect(dark.scaffoldBackgroundColor, SakuBrand.noturno);
    expect(light.textTheme.bodyMedium?.fontFamily, SakuBrand.fontFamily);
    expect(dark.textTheme.bodyMedium?.fontFamily, SakuBrand.fontFamily);
  });

  testWidgets('splash contains only the approved SAKU wordmark copy', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SakuSplashScreen()),
    );

    expect(find.text('SAKU'), findsOneWidget);
    expect(find.textContaining('SIMPLE'), findsNothing);
    expect(find.textContaining('Arus'), findsNothing);
  });
}
