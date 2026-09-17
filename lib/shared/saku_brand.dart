import 'package:flutter/material.dart';

/// Canonical SAKU identity tokens.
///
/// Product data remains local-first. These tokens are presentation-only and
/// must never introduce a network dependency.
abstract final class SakuBrand {
  static const appName = 'SAKU';

  // Primary brand palette selected for the release direction.
  static const noturno = Color(0xFF001621);
  static const vulcanico = Color(0xFFFF4103);
  static const sand = Color(0xFFF0EDE4);

  static const onNoturno = Color(0xFFFDFCF9);
  static const mutedOnNoturno = Color(0xFFB8C3C8);

  /// Font family name reserved for the bundled Plus Jakarta Sans asset.
  /// Keep the font local to the application; do not runtime-fetch it.
  static const fontFamily = 'PlusJakartaSans';

  static const Radius controlRadius = Radius.circular(16);
  static const Radius cardRadius = Radius.circular(22);
}
