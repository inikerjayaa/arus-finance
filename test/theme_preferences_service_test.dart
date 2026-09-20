import 'package:arus_finance/core/services/theme_preferences_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final service = ThemePreferencesService.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await service.load();
  });

  test('theme preferences default to SAKU Original and system mode', () {
    expect(service.themeId, ArusThemeId.original);
    expect(service.themeMode, ThemeMode.system);
  });

  test('theme and mode persist locally', () async {
    await service.setThemeId(ArusThemeId.ocean);
    await service.setThemeMode(ThemeMode.dark);

    expect(service.themeId, ArusThemeId.ocean);
    expect(service.themeMode, ThemeMode.dark);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('appearance_theme_id_v1'), 'ocean');
    expect(prefs.getString('appearance_theme_mode_v1'), 'dark');
  });

  test('unknown persisted values fail safe to defaults', () async {
    SharedPreferences.setMockInitialValues({
      'appearance_theme_id_v1': 'future-theme',
      'appearance_theme_mode_v1': 'future-mode',
    });
    await service.load();

    expect(service.themeId, ArusThemeId.original);
    expect(service.themeMode, ThemeMode.system);
  });

  test('theme catalog exposes the planned selectable presets', () {
    expect(
      ArusThemeId.values.map((theme) => theme.label),
      containsAll(<String>[
        'SAKU Original',
        'Ocean',
        'Forest',
        'Graphite',
        'Midnight',
        'Sand',
        'High Contrast',
      ]),
    );
  });
}
