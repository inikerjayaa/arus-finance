import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'icon_catalog.dart';

class CustomVisualIconData {
  const CustomVisualIconData._();

  static const String prefix = 'custom-data:';
  static const int maxBytes = 512 * 1024;

  static bool isCustom(String? iconKey) =>
      iconKey != null && iconKey.startsWith(prefix);

  static String encode({
    required Uint8List bytes,
    required String mimeType,
  }) {
    if (!_supportedMimeTypes.contains(mimeType)) {
      throw ArgumentError('Format ikon custom belum didukung.');
    }
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw ArgumentError('Ukuran ikon custom maksimal 512 KB.');
    }
    return '$prefix$mimeType;base64,${base64Encode(bytes)}';
  }

  static Uint8List? decode(String? iconKey) {
    if (!isCustom(iconKey)) return null;
    final value = iconKey!;
    final marker = value.indexOf(';base64,', prefix.length);
    if (marker <= prefix.length) return null;
    final mimeType = value.substring(prefix.length, marker);
    if (!_supportedMimeTypes.contains(mimeType)) return null;
    final encoded = value.substring(marker + ';base64,'.length);
    if (encoded.isEmpty) return null;
    try {
      final bytes = base64Decode(encoded);
      if (bytes.isEmpty || bytes.length > maxBytes) return null;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  static bool isValid(String? iconKey) => decode(iconKey) != null;

  static String? mimeTypeForExtension(String? extension) {
    return switch (extension?.trim().toLowerCase()) {
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'webp' => 'image/webp',
      _ => null,
    };
  }

  static const Set<String> _supportedMimeTypes = {
    'image/png',
    'image/jpeg',
    'image/webp',
  };
}

class VisualIcon extends StatelessWidget {
  const VisualIcon({
    super.key,
    required this.iconKey,
    this.size = 24,
    this.color,
    this.customBorderRadius,
  });

  final String iconKey;
  final double size;
  final Color? color;
  final BorderRadius? customBorderRadius;

  @override
  Widget build(BuildContext context) {
    final customBytes = CustomVisualIconData.decode(iconKey);
    if (customBytes != null) {
      final radius = customBorderRadius ?? BorderRadius.circular(size * .28);
      return ClipRRect(
        borderRadius: radius,
        child: Image.memory(
          customBytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => _fallback(),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    final entry = IconCatalog.fallbackFor(iconKey);
    return Icon(entry.fallbackIcon, size: size, color: color);
  }
}
