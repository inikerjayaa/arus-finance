import 'package:flutter/material.dart';

import '../../core/services/theme_preferences_service.dart';

class AppearanceSettingsScreen extends StatelessWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = ThemePreferencesService.instance;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Tampilan')),
      body: AnimatedBuilder(
        animation: service,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 120),
            children: [
              Semantics(
                header: true,
                child: Text('Tampilan SAKU', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 6),
              Text(
                'Tema hanya mengubah tampilan di perangkat ini. Data dan perhitungan keuangan tidak berubah.',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              Text('Mode', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_rounded), label: Text('System')),
                  ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_rounded), label: Text('Light')),
                  ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_rounded), label: Text('Dark')),
                ],
                selected: {service.themeMode},
                onSelectionChanged: (value) {
                  if (value.isNotEmpty) service.setThemeMode(value.first);
                },
              ),
              const SizedBox(height: 24),
              Text('Tema warna', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    for (var i = 0; i < ArusThemeId.values.length; i++) ...[
                      _ThemePresetTile(
                        themeId: ArusThemeId.values[i],
                        selected: service.themeId == ArusThemeId.values[i],
                        onTap: () => service.setThemeId(ArusThemeId.values[i]),
                      ),
                      if (i != ArusThemeId.values.length - 1) const Divider(height: 1),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'SAKU Original tetap menjadi default. High Contrast disediakan untuk kebutuhan keterbacaan yang lebih kuat.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ThemePresetTile extends StatelessWidget {
  const _ThemePresetTile({required this.themeId, required this.selected, required this.onTap});
  final ArusThemeId themeId;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _previewColors(themeId);
    return ListTile(
      onTap: onTap,
      minVerticalPadding: 12,
      leading: SizedBox(
        width: 48,
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(shape: BoxShape.circle, color: colors.$1, border: Border.all(color: theme.colorScheme.outlineVariant)),
              child: const SizedBox.expand(),
            ),
            Align(
              alignment: const Alignment(0.48, 0.48),
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(shape: BoxShape.circle, color: colors.$2, border: Border.all(color: theme.colorScheme.surface, width: 2)),
              ),
            ),
          ],
        ),
      ),
      title: Text(themeId.label),
      subtitle: Text(_description(themeId)),
      trailing: selected ? Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary) : const Icon(Icons.chevron_right),
    );
  }

  static (Color, Color) _previewColors(ArusThemeId themeId) {
    return switch (themeId) {
      ArusThemeId.original => (const Color(0xFF375B53), const Color(0xFF7BA89C)),
      ArusThemeId.ocean => (const Color(0xFF246B82), const Color(0xFF69B8CF)),
      ArusThemeId.forest => (const Color(0xFF315E3D), const Color(0xFF78B88A)),
      ArusThemeId.graphite => (const Color(0xFF4D5963), const Color(0xFF9DA8B2)),
      ArusThemeId.midnight => (const Color(0xFF172337), const Color(0xFF7CA7D9)),
      ArusThemeId.sand => (const Color(0xFF8A6846), const Color(0xFFD0AD7A)),
      ArusThemeId.highContrast => (Colors.black, Colors.white),
    };
  }

  static String _description(ArusThemeId themeId) {
    return switch (themeId) {
      ArusThemeId.original => 'Hijau Cyprus khas SAKU',
      ArusThemeId.ocean => 'Biru-teal bersih dan modern',
      ArusThemeId.forest => 'Hijau natural dengan rasa premium',
      ArusThemeId.graphite => 'Netral, profesional, minim distraksi',
      ArusThemeId.midnight => 'Gelap pekat untuk suasana malam',
      ArusThemeId.sand => 'Cream hangat dan elegan',
      ArusThemeId.highContrast => 'Kontras maksimum untuk keterbacaan',
    };
  }
}
