import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:arus_finance/core/services/custom_icon_repository.dart';
import 'package:arus_finance/shared/brand_icon_catalog.dart';
import 'package:arus_finance/shared/saku_icon_registry.dart';

void main() {
  test('SAKU A-I catalog resolves required anchors', () {
    for (final id in [
      'bca',
      'mandiri',
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
    ]) {
      expect(SakuIconRegistry.byKey('brand:$id'), isNotNull, reason: id);
    }
    expect(
      SakuIconRegistry.choices.length,
      SakuBrandIconCatalog.items.length,
    );
  });

  test('brand search is local and deterministic', () {
    expect(SakuIconRegistry.search('BCA').first.key, 'brand:bca');
    expect(SakuIconRegistry.search('ChatGPT').first.key, 'brand:chatgpt');
    expect(SakuIconRegistry.search('Gemini').first.key, 'brand:gemini');
    expect(SakuIconRegistry.search('Claude').first.key, 'brand:claude');
    expect(SakuIconRegistry.search('DANA').first.key, 'brand:dana');
  });

  test('custom key contract is strict', () {
    final valid = 'custom:${'a' * 64}.png';
    expect(SakuIconRegistry.isCustomKey(valid), isTrue);
    expect(SakuIconRegistry.sourceFor(valid), SakuResolvedIconSource.userCustom);
    expect(SakuIconRegistry.isCustomKey('brand:bca'), isFalse);
    expect(SakuIconRegistry.isCustomKey('custom:../../secret.png'), isFalse);
    expect(SakuIconRegistry.isCustomKey('custom:not-a-hash.png'), isFalse);
    expect(SakuIconRegistry.isCustomKey('custom:${'a' * 64}.svg'), isFalse);
  });

  test('custom image signatures accept supported formats only', () {
    expect(
      CustomIconRepository.detectExtension(
        Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
      ),
      'png',
    );
    expect(
      CustomIconRepository.detectExtension(
        Uint8List.fromList([0xFF, 0xD8, 0xFF, 0x00]),
      ),
      'jpg',
    );
    expect(
      CustomIconRepository.detectExtension(
        Uint8List.fromList([
          0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0,
          0x57, 0x45, 0x42, 0x50,
        ]),
      ),
      'webp',
    );
    expect(
      CustomIconRepository.detectExtension(Uint8List.fromList([1, 2, 3, 4])),
      isNull,
    );
  });
}
