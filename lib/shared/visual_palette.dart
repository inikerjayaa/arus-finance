import 'package:flutter/material.dart';

class VisualColorPreset {
  const VisualColorPreset({
    required this.key,
    required this.label,
    required this.light,
    required this.dark,
  });

  final String key;
  final String label;
  final Color light;
  final Color dark;

  Color resolve(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
}

class VisualPalette {
  const VisualPalette._();

  static const presets = <VisualColorPreset>[
    VisualColorPreset(key: 'slate', label: 'Slate', light: Color(0xFF60707D), dark: Color(0xFF9FB0BC)),
    VisualColorPreset(key: 'red', label: 'Merah', light: Color(0xFFC94B4B), dark: Color(0xFFFF8A80)),
    VisualColorPreset(key: 'orange', label: 'Oranye', light: Color(0xFFD97724), dark: Color(0xFFFFB36B)),
    VisualColorPreset(key: 'amber', label: 'Amber', light: Color(0xFFB98516), dark: Color(0xFFFFCB6B)),
    VisualColorPreset(key: 'lime', label: 'Lime', light: Color(0xFF6F8F22), dark: Color(0xFFB9D86A)),
    VisualColorPreset(key: 'green', label: 'Hijau', light: Color(0xFF3C7A57), dark: Color(0xFF7FC8A0)),
    VisualColorPreset(key: 'teal', label: 'Teal', light: Color(0xFF347B76), dark: Color(0xFF75C9C0)),
    VisualColorPreset(key: 'cyan', label: 'Cyan', light: Color(0xFF317A93), dark: Color(0xFF7CC9E3)),
    VisualColorPreset(key: 'blue', label: 'Biru', light: Color(0xFF3E6FA8), dark: Color(0xFF86B6ED)),
    VisualColorPreset(key: 'indigo', label: 'Indigo', light: Color(0xFF5365A5), dark: Color(0xFF9EADF0)),
    VisualColorPreset(key: 'purple', label: 'Ungu', light: Color(0xFF7754A5), dark: Color(0xFFC2A0ED)),
    VisualColorPreset(key: 'pink', label: 'Pink', light: Color(0xFFA9507D), dark: Color(0xFFE69AC0)),
    VisualColorPreset(key: 'brown', label: 'Cokelat', light: Color(0xFF82614F), dark: Color(0xFFC7A390)),
  ];

  static final Map<String, VisualColorPreset> _byKey = {
    for (final preset in presets) preset.key: preset,
  };

  static VisualColorPreset? byKey(String? key) => key == null ? null : _byKey[key];

  static VisualColorPreset fallbackFor(String? key) =>
      byKey(key) ?? byKey('slate')!;
}
