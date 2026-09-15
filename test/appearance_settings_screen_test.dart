import 'package:arus_finance/core/services/theme_preferences_service.dart';
import 'package:arus_finance/features/settings/appearance_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('appearance screen changes theme preset and brightness mode locally', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final service = ThemePreferencesService.instance;
    await service.load();

    await tester.pumpWidget(
      const MaterialApp(home: AppearanceSettingsScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Arus Original'), findsOneWidget);
    expect(find.text('Ocean'), findsOneWidget);
    expect(service.themeId, ArusThemeId.original);
    expect(service.themeMode, ThemeMode.system);

    await tester.tap(find.text('Ocean'));
    await tester.pumpAndSettle();
    expect(service.themeId, ArusThemeId.ocean);

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(service.themeMode, ThemeMode.dark);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('appearance_theme_id_v1'), 'ocean');
    expect(prefs.getString('appearance_theme_mode_v1'), 'dark');
  });

  testWidgets('appearance controls retain accessible tap targets', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await ThemePreferencesService.instance.load();

    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(home: AppearanceSettingsScreen()),
    );
    await tester.pumpAndSettle();

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });
}
