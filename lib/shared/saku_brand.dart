import 'package:flutter/material.dart';

/// Locked public-facing visual identity for SAKU.
///
/// Financial storage and architecture remain local-first/device-owned. These
/// tokens are presentation-only and must never become a network dependency.
abstract final class SakuBrand {
  static const appName = 'SAKU';
  static const fontFamily = 'Plus Jakarta Sans';

  /// Primary dark brand surface (NOTURNO).
  static const noturno = Color(0xFF001621);

  /// Primary energetic brand accent (VULCANICO).
  static const vulcanico = Color(0xFFFF4103);

  /// Warm neutral retained as a supporting light surface (SAND).
  static const sand = Color(0xFFF0EDE4);

  static const white = Color(0xFFFFFFFF);
  static const ink = Color(0xFF0A2029);
  static const mutedOnDark = Color(0xFFB9C5C9);

  static const radiusSmall = 12.0;
  static const radiusMedium = 16.0;
  static const radiusLarge = 22.0;

  /// Minimum interactive target retained from the existing accessibility
  /// contract.
  static const minTouchTarget = 48.0;
}
