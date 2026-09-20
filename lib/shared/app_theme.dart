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
    final generated = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      contrastLevel: themeId == ArusThemeId.highContrast ? 1 : 0,
    );
    final isDark = brightness == Brightness.dark;
    final isOriginal = themeId == ArusThemeId.original;
    final background = _background(themeId, brightness);
    final scheme = isOriginal
        ? generated.copyWith(
            primary: isDark ? SakuBrand.vulcanico : SakuBrand.cyprus,
            onPrimary: Colors.white,
            secondary: isDark ? SakuBrand.cyprus : SakuBrand.vulcanico,
            surface: isDark ? SakuBrand.noturno : SakuBrand.sand,
          )
        : generated;

    return ThemeData(
      useMaterial3: true,
      fontFamily: SakuBrand.fontFamily,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        titleTextStyle: TextStyle(
          fontFamily: SakuBrand.fontFamily,
          color: scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -.3,
        ),
      ),
      textTheme: ThemeData(brightness: brightness).textTheme.apply(
            fontFamily: SakuBrand.fontFamily,
            bodyColor: scheme.onSurface,
            displayColor: scheme.onSurface,
          ).copyWith(
            headlineSmall: TextStyle(
              fontFamily: SakuBrand.fontFamily,
              color: scheme.onSurface,
              fontSize: 22,
              height: 1.2,
              fontWeight: FontWeight.w700,
              letterSpacing: -.35,
            ),
            titleLarge: TextStyle(
              fontFamily: SakuBrand.fontFamily,
              color: scheme.onSurface,
              fontSize: 18,
              height: 1.25,
              fontWeight: FontWeight.w700,
              letterSpacing: -.2,
            ),
            titleMedium: TextStyle(
              fontFamily: SakuBrand.fontFamily,
              color: scheme.onSurface,
              fontSize: 15,
              height: 1.3,
              fontWeight: FontWeight.w600,
            ),
            bodyLarge: TextStyle(
              fontFamily: SakuBrand.fontFamily,
              color: scheme.onSurface,
              fontSize: 15,
              height: 1.45,
            ),
            bodyMedium: TextStyle(
              fontFamily: SakuBrand.fontFamily,
              color: scheme.onSurface,
              fontSize: 14,
              height: 1.45,
            ),
            labelLarge: TextStyle(
              fontFamily: SakuBrand.fontFamily,
              color: scheme.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        fillColor: isDark
            ? scheme.surfaceContainerHighest.withValues(alpha: .30)
            : scheme.surface,
        border: OutlineInputBorder(
          borderRadius: const BorderRadius.all(SakuBrand.controlRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(SakuBrand.controlRadius),
          borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: .8)),
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
            : scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(SakuBrand.cardRadius),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: isDark ? .36 : .52),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        elevation: 0,
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primary.withValues(alpha: isDark ? .22 : .12),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontFamily: SakuBrand.fontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: .58),
        space: 1,
      ),
    );
  }

  // Keep the 48dp accessibility contract explicit in both brightness modes.
  static ThemeData _withLightMinimumTargets(ThemeData base) => base.copyWith(
        iconButtonTheme: const IconButtonThemeData(
          style: ButtonStyle(minimumSize: WidgetStatePropertyAll(Size(48, 48))),
        ),
        filledButtonTheme: const FilledButtonThemeData(
          style: ButtonStyle(minimumSize: WidgetStatePropertyAll(Size(48, 48))),
        ),
        outlinedButtonTheme: const OutlinedButtonThemeData(
          style: ButtonStyle(minimumSize: WidgetStatePropertyAll(Size(48, 48))),
        ),
        textButtonTheme: const TextButtonThemeData(
          style: ButtonStyle(minimumSize: WidgetStatePropertyAll(Size(48, 48))),
        ),
      );

  static ThemeData _withDarkMinimumTargets(ThemeData base) => base.copyWith(
        iconButtonTheme: const IconButtonThemeData(
          style: ButtonStyle(minimumSize: WidgetStatePropertyAll(Size(48, 48))),
        ),
        filledButtonTheme: const FilledButtonThemeData(
          style: ButtonStyle(minimumSize: WidgetStatePropertyAll(Size(48, 48))),
        ),
        outlinedButtonTheme: const OutlinedButtonThemeData(
          style: ButtonStyle(minimumSize: WidgetStatePropertyAll(Size(48, 48))),
        ),
        textButtonTheme: const TextButtonThemeData(
          style: ButtonStyle(minimumSize: WidgetStatePropertyAll(Size(48, 48))),
        ),
      );

  static Color _seed(ArusThemeId themeId, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return switch (themeId) {
      ArusThemeId.original => SakuBrand.cyprus,
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
