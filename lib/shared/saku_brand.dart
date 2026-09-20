import 'package:flutter/material.dart';

/// Canonical SAKU identity tokens.
///
/// Product data remains local-first. These tokens are presentation-only and
/// must never introduce a network dependency.
abstract final class SakuBrand {
  static const appName = 'SAKU';

  // Locked release palette.
  static const cyprus = Color(0xFF004741);
  static const noturno = Color(0xFF001621);
  static const vulcanico = Color(0xFFFF4103);
  static const sand = Color(0xFFF0EDE4);

  static const onNoturno = Color(0xFFFDFCF9);
  static const mutedOnNoturno = Color(0xFFB8C3C8);

  /// Font family name reserved for the bundled Plus Jakarta Sans asset.
  /// Keep the font local to the application; do not runtime-fetch it.
  static const fontFamily = 'PlusJakartaSans';

  // A compact, consistent geometry vocabulary for the final cosmetic pass.
  static const double pageInset = 20;
  static const double sectionGap = 24;
  static const double itemGap = 12;
  static const double compactGap = 8;
  static const Radius controlRadius = Radius.circular(14);
  static const Radius cardRadius = Radius.circular(20);
}
