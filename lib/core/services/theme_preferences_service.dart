import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ArusThemeId {
  original,
  ocean,
  forest,
  graphite,
  midnight,
  sand,
  highContrast,
}

extension ArusThemeIdLabel on ArusThemeId {
  String get label => switch (this) {
        ArusThemeId.original => 'Arus Original',
        ArusThemeId.ocean => 'Ocean',
        ArusThemeId.forest => 'Forest',
        ArusThemeId.graphite => 'Graphite',
        ArusThemeId.midnight => 'Midnight',
        ArusThemeId.sand => 'Sand',
        ArusThemeId.highContrast => 'High Contrast',
      };
}

class ThemePreferencesService extends ChangeNotifier {
  ThemePreferencesService._();

  static final ThemePreferencesService instance = ThemePreferencesService._();

  static const _themeIdKey = 'appearance_theme_id_v1';
  static const _themeModeKey = 'appearance_theme_mode_v1';

  ArusThemeId _themeId = ArusThemeId.original;
  ThemeMode _themeMode = ThemeMode.system;
  bool _loaded = false;

  ArusThemeId get themeId => _themeId;
  ThemeMode get themeMode => _themeMode;
  bool get loaded => _loaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _themeId = _parseThemeId(prefs.getString(_themeIdKey));
    _themeMode = _parseThemeMode(prefs.getString(_themeModeKey));
    _loaded = true;
    notifyListeners();
  }

  Future<void> setThemeId(ArusThemeId value) async {
    if (_themeId == value && _loaded) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeIdKey, value.name);
    _themeId = value;
    _loaded = true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode value) async {
    if (_themeMode == value && _loaded) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, value.name);
    _themeMode = value;
    _loaded = true;
    notifyListeners();
  }

  static ArusThemeId _parseThemeId(String? value) {
    for (final item in ArusThemeId.values) {
      if (item.name == value) return item;
    }
    return ArusThemeId.original;
  }

  static ThemeMode _parseThemeMode(String? value) {
    for (final item in ThemeMode.values) {
      if (item.name == value) return item;
    }
    return ThemeMode.system;
  }
}
