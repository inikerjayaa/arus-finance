import 'package:flutter/material.dart';

import '../core/services/theme_preferences_service.dart';
import 'saku_brand.dart';

class AppTheme {
  static ThemeData light([ArusThemeId themeId = ArusThemeId.original]) =>
      _withLightMinimumTargets(_build(themeId, Brightness.light));

  static ThemeData dark([ArusThemeId themeId = ArusThemeId.original]) =>
      _withDarkMinimumTargets(_build(themeId, Brightness.dark));

  static ThemeData _build(ArusThemeId themeId, Brightness brightness) {
    final seed = _seed(themeId, brightness);
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      contrastLevel: themeId == ArusThemeId.highContrast ? 1 : 0,
    );
    final isDark = brightness == Brightness.dark;
    final background = _background(themeId, brightness);

    return ThemeData(
      useMaterial3: true,
      fontFamily: SakuBrand.fontFamily,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? scheme.surfaceContainerHighest.withValues(alpha: .34)
            : scheme.surface,
        border: OutlineInputBorder(
          borderRadius: const BorderRadius.all(SakuBrand.controlRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(SakuBrand.controlRadius),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(SakuBrand.controlRadius),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: themeId == ArusThemeId.midnight && isDark
            ? const Color(0xFF121820)
            : null,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(SakuBrand.cardRadius),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: isDark ? .45 : .55),
          ),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(height: 72),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: .7),
      ),
    );
  }

  // Keep the 48dp accessibility contract explicit in both brightness modes.
  // This duplication is intentional: light and dark remain independently
  // auditable even as their visual tokens evolve.
  static ThemeData _withLightMinimumTargets(ThemeData base) => base.copyWith(
        iconButtonTheme: const IconButtonThemeData(
          style: ButtonStyle(
            minimumSize: WidgetStatePropertyAll(Size(48, 48)),
          ),
        ),
        filledButtonTheme: const FilledButtonThemeData(
          style: ButtonStyle(
            minimumSize: WidgetStatePropertyAll(Size(48, 48)),
          ),
        ),
        outlinedButtonTheme: const OutlinedButtonThemeData(
          style: ButtonStyle(
            minimumSize: WidgetStatePropertyAll(Size(48, 48)),
          ),
        ),
        textButtonTheme: const TextButtonThemeData(
          style: ButtonStyle(
            minimumSize: WidgetStatePropertyAll(Size(48, 48)),
          ),
        ),
      );

  static ThemeData _withDarkMinimumTargets(ThemeData base) => base.copyWith(
        iconButtonTheme: const IconButtonThemeData(
          style: ButtonStyle(
            minimumSize: WidgetStatePropertyAll(Size(48, 48)),
          ),
        ),
        filledButtonTheme: const FilledButtonThemeData(
          style: ButtonStyle(
            minimumSize: WidgetStatePropertyAll(Size(48, 48)),
          ),
        ),
        outlinedButtonTheme: const OutlinedButtonThemeData(
          style: ButtonStyle(
            minimumSize: WidgetStatePropertyAll(Size(48, 48)),
          ),
        ),
        textButtonTheme: const TextButtonThemeData(
          style: ButtonStyle(
            minimumSize: WidgetStatePropertyAll(Size(48, 48)),
          ),
        ),
      );

  static Color _seed(ArusThemeId themeId, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return switch (themeId) {
      ArusThemeId.original => SakuBrand.vulcanico,
      ArusThemeId.ocean => dark ? const Color(0xFF69B8CF) : const Color(0xFF246B82),
      ArusThemeId.forest => dark ? const Color(0xFF78B88A) : const Color(0xFF315E3D),
      ArusThemeId.graphite => dark ? const Color(0xFF9DA8B2) : const Color(0xFF4D5963),
      ArusThemeId.midnight => dark ? const Color(0xFF7CA7D9) : const Color(0xFF35577E),
      ArusThemeId.sand => dark ? const Color(0xFFD0AD7A) : const Color(0xFF8A6846),
      ArusThemeId.highContrast => dark ? Colors.white : Colors.black,
    };
  }

  static Color _background(ArusThemeId themeId, Brightness brightness) {
    if (brightness == Brightness.dark) {
      return switch (themeId) {
        ArusThemeId.original => SakuBrand.noturno,
        ArusThemeId.midnight => const Color(0xFF080B10),
        ArusThemeId.sand => const Color(0xFF17130F),
        ArusThemeId.highContrast => Colors.black,
        _ => const Color(0xFF101114),
      };
    }
    return switch (themeId) {
      ArusThemeId.original => SakuBrand.sand,
      ArusThemeId.ocean => const Color(0xFFF4F8FA),
      ArusThemeId.forest => const Color(0xFFF5F8F4),
      ArusThemeId.graphite => const Color(0xFFF5F6F7),
      ArusThemeId.midnight => const Color(0xFFF3F6FA),
      ArusThemeId.sand => const Color(0xFFFAF6EF),
      ArusThemeId.highContrast => Colors.white,
    };
  }
}
