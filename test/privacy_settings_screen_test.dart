import 'package:arus_finance/core/services/screen_protection_service.dart';
import 'package:arus_finance/features/settings/privacy_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('arus.finance/screen_protection.widget_test');

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('disabling screenshot protection requires explicit warning confirmation', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final applied = <bool>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'isSupported') return true;
      if (call.method == 'setEnabled') {
        applied.add((call.arguments as Map)['enabled'] as bool);
        return true;
      }
      return null;
    });

    final service = ScreenProtectionService(channel: channel);
    await service.loadAndApply();

    await tester.pumpWidget(
      MaterialApp(home: PrivacySettingsScreen(service: service)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lindungi screenshot & rekaman layar'), findsOneWidget);
    expect(service.enabled, isTrue);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('Izinkan screenshot?'), findsOneWidget);
    expect(service.enabled, isTrue);

    await tester.tap(find.text('Matikan perlindungan'));
    await tester.pumpAndSettle();

    expect(service.enabled, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('screen_protection_enabled_v1'), isFalse);
    expect(applied, [true, false]);
    expect(
      find.textContaining('app switcher', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('unsupported platform keeps toggle disabled and states limitation', (tester) async {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'isSupported') return false;
      return null;
    });

    final service = ScreenProtectionService(channel: channel);
    await service.loadAndApply();

    await tester.pumpWidget(
      MaterialApp(home: PrivacySettingsScreen(service: service)),
    );
    await tester.pumpAndSettle();

    expect(service.supported, isFalse);
    expect(
      find.textContaining('belum tersedia di platform/perangkat ini'),
      findsOneWidget,
    );
    final tile = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(tile.onChanged, isNull);
  });
}
