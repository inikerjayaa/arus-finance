import 'dart:io';

import 'package:flutter/material.dart';

import '../core/services/custom_icon_repository.dart';
import 'icon_catalog.dart';
import 'saku_icon_registry.dart';

abstract final class SakuVisualIconResolver {
  static bool isKnown(String? key) {
    if (key == null || key.isEmpty) return false;
    return IconCatalog.byKey(key) != null ||
        SakuIconRegistry.isBrandKey(key) ||
        SakuIconRegistry.isCustomKey(key);
  }

  static String labelFor(String? key) {
    final legacy = IconCatalog.byKey(key);
    if (legacy != null) return legacy.label;
    final brand = SakuIconRegistry.byKey(key);
    if (brand != null) return brand.label;
    if (SakuIconRegistry.isCustomKey(key)) return 'Ikon custom';
    return IconCatalog.fallbackFor(null).label;
  }

  static IconData fallbackFor(String? key) {
    final legacy = IconCatalog.byKey(key);
    if (legacy != null) return legacy.fallbackIcon;
    final brand = SakuIconRegistry.byKey(key);
    if (brand != null) return brand.fallbackIcon;
    return IconCatalog.fallbackFor(null).fallbackIcon;
  }
}

class SakuVisualIcon extends StatelessWidget {
  const SakuVisualIcon({
    super.key,
    required this.iconKey,
    this.size = 24,
    this.color,
    this.fit = BoxFit.contain,
  });

  final String? iconKey;
  final double size;
  final Color? color;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final key = iconKey;
    final brand = SakuIconRegistry.byKey(key);
    if (brand != null && brand.hasBundledAsset) {
      return Image.asset(
        brand.assetPath!,
        width: size,
        height: size,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _fallback(),
      );
    }
    if (SakuIconRegistry.isCustomKey(key)) {
      return FutureBuilder<File?>(
        future: CustomIconRepository().resolve(key),
        builder: (context, snapshot) {
          final file = snapshot.data;
          if (file == null) return _fallback();
          return ClipRRect(
            borderRadius: BorderRadius.circular(size * .22),
            child: Image.file(
              file,
              width: size,
              height: size,
              fit: fit,
              errorBuilder: (context, error, stackTrace) => _fallback(),
            ),
          );
        },
      );
    }
    return _fallback();
  }

  Widget _fallback() => Icon(
        SakuVisualIconResolver.fallbackFor(iconKey),
        size: size,
        color: color,
      );
}
