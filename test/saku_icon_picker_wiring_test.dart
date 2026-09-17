import 'package:arus_finance/shared/saku_icon_registry.dart';
import 'package:arus_finance/shared/saku_visual_icon.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resolver accepts legacy, brand, and strict custom keys', () {
    expect(SakuVisualIconResolver.isKnown('finance.cash'), isTrue);
    expect(SakuVisualIconResolver.isKnown('brand:bca'), isTrue);
    expect(SakuVisualIconResolver.isKnown('brand:dana'), isTrue);
    expect(SakuVisualIconResolver.isKnown('brand:chatgpt'), isTrue);

    final customKey = 'custom:${'a' * 64}.png';
    expect(SakuIconRegistry.isCustomKey(customKey), isTrue);
    expect(SakuVisualIconResolver.isKnown(customKey), isTrue);

    expect(SakuVisualIconResolver.isKnown('brand:not_real'), isFalse);
    expect(SakuVisualIconResolver.isKnown('custom:../../escape.png'), isFalse);
  });

  test('resolver exposes friendly labels and deterministic fallbacks', () {
    expect(SakuVisualIconResolver.labelFor('brand:bca'), 'BCA');
    expect(SakuVisualIconResolver.labelFor('brand:dana'), 'DANA');
    expect(SakuVisualIconResolver.labelFor('brand:chatgpt'), 'ChatGPT');
    expect(SakuVisualIconResolver.labelFor('brand:gemini'), 'Gemini');
    expect(SakuVisualIconResolver.labelFor('brand:claude'), 'Claude');

    final customKey = 'custom:${'b' * 64}.webp';
    expect(SakuVisualIconResolver.labelFor(customKey), 'Ikon custom');
    expect(SakuVisualIconResolver.fallbackFor('brand:bca'), isNotNull);
    expect(SakuVisualIconResolver.fallbackFor(customKey), isNotNull);
  });
}
