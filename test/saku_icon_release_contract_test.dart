import 'package:flutter_test/flutter_test.dart';
import 'package:arus_finance/shared/saku_icon_registry.dart';

void main() {
  group('SAKU icon release contract', () {
    test('known real brands never resolve as generic SAKU fallback', () {
      for (final key in const [
        'brand:bca',
        'brand:gopay',
        'brand:grab',
        'brand:shopee',
        'brand:netflix',
        'brand:chatgpt',
        'brand:telkomsel',
        'brand:pln',
      ]) {
        expect(
          SakuIconRegistry.sourceFor(key),
          isNot(SakuResolvedIconSource.genericFallback),
          reason: '$key must use authentic bundled artwork or stay explicitly '
              'blocked as a missing brand asset.',
        );
      }
    });

    test('generic concepts intentionally resolve to SAKU fallback', () {
      for (final key in const [
        'brand:cash',
        'brand:food',
        'brand:health',
        'brand:education',
        'brand:other',
        'brand:pbb',
        'brand:vehicle_tax',
        'brand:home_internet',
        'brand:electricity',
        'brand:water',
        'brand:gas',
        'brand:installment',
      ]) {
        expect(
          SakuIconRegistry.sourceFor(key),
          SakuResolvedIconSource.genericFallback,
          reason: '$key is a concept/category and must use canonical SAKU '
              'artwork rather than pretending to have a company logo.',
        );
      }
    });

    test('all supported named brands have vetted bundled artwork before release', () {
      final missing = SakuIconRegistry.missingOfficialBrandAssets;
      expect(
        missing,
        isEmpty,
        reason: 'V50 release is blocked while any supported real brand lacks '
            'its vetted bundled asset. Missing: '
            '${missing.map((choice) => choice.key).join(', ')}',
      );
    });

    test('release readiness only counts real named brands', () {
      final missing = SakuIconRegistry.missingOfficialBrandAssets;
      expect(missing.every((choice) => choice.requiresOfficialAsset), isTrue);
      expect(missing.every((choice) => !choice.isGeneric), isTrue);
    });
  });
}
