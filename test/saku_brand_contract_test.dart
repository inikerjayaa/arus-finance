import 'package:arus_finance/shared/app_theme.dart';
import 'package:arus_finance/shared/brand_icon_catalog.dart';
import 'package:arus_finance/shared/saku_brand.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SAKU canonical palette and identity stay locked', () {
    expect(SakuBrand.appName, 'SAKU');
    expect(SakuBrand.noturno, const Color(0xFF001621));
    expect(SakuBrand.vulcanico, const Color(0xFFFF4103));
    expect(SakuBrand.sand, const Color(0xFFF0EDE4));
    expect(SakuBrand.fontFamily, 'PlusJakartaSans');
  });

  test('default light and dark surfaces use SAKU brand bases', () {
    final light = AppTheme.light();
    final dark = AppTheme.dark();
    expect(light.scaffoldBackgroundColor, SakuBrand.sand);
    expect(dark.scaffoldBackgroundColor, SakuBrand.noturno);
    expect(light.fontFamily, SakuBrand.fontFamily);
    expect(dark.fontFamily, SakuBrand.fontFamily);
  });

  test('brand icon catalog has unique stable ids and required anchors', () {
    final ids = SakuBrandIconCatalog.items.map((item) => item.id).toList();
    expect(ids.toSet().length, ids.length);

    for (final required in <String>[
      'bca',
      'mandiri',
      'bri',
      'bni',
      'dana',
      'ovo',
      'gojek',
      'youtube',
      'chatgpt',
      'gemini',
      'claude',
      'telkomsel',
      'pln',
      'cash',
      'subscription',
    ]) {
      expect(SakuBrandIconCatalog.byId(required), isNotNull,
          reason: 'Missing required SAKU icon catalog id: $required');
    }
  });

  test('brand catalog never requires runtime network assets', () {
    for (final item in SakuBrandIconCatalog.items) {
      final path = item.assetPath;
      if (path == null) continue;
      expect(path.startsWith('http://') || path.startsWith('https://'), isFalse,
          reason: '${item.id} must resolve locally');
    }
  });
}
