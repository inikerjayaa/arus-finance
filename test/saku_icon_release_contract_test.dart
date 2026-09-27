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
      ]) {
        expect(
          SakuIconRegistry.sourceFor(key),
          SakuResolvedIconSource.genericFallback,
        );
      }
    });

    test('release readiness only counts real named brands', () {
      final missing = SakuIconRegistry.missingOfficialBrandAssets;
      expect(missing.every((choice) => choice.requiresOfficialAsset), isTrue);
      expect(missing.every((choice) => !choice.isGeneric), isTrue);
    });
  });
}
