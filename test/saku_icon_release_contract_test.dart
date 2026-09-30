import 'package:flutter_test/flutter_test.dart';
import 'package:arus_finance/shared/saku_icon_registry.dart';

void main() {
  group('SAKU icon release contract', () {
    test('known real brands never resolve as generic SAKU fallback', () {
      for (final key in const ['brand:bca','brand:gopay','brand:grab','brand:shopee','brand:netflix','brand:chatgpt','brand:telkomsel','brand:pln']) {
        expect(SakuIconRegistry.sourceFor(key), isNot(SakuResolvedIconSource.genericFallback),
          reason: '$key must use authentic bundled artwork or stay explicitly blocked as a missing brand asset.');
      }
    });

    test('generic concepts intentionally resolve to SAKU fallback', () {
      for (final key in const ['brand:cash','brand:food','brand:health','brand:education','brand:other','brand:pbb','brand:vehicle_tax','brand:home_internet','brand:electricity','brand:water','brand:gas','brand:installment']) {
        expect(SakuIconRegistry.sourceFor(key), SakuResolvedIconSource.genericFallback,
          reason: '$key is a concept/category and must use canonical SAKU artwork rather than pretending to have a company logo.');
      }
    });

    test('starter guide is useful, unique and backed by canonical resolver', () {
      final starter = SakuIconRegistry.starterChoices;
      expect(starter.length, greaterThanOrEqualTo(30));
      expect(starter.map((item) => item.key).toSet().length, starter.length);
      for (final requiredKey in const ['brand:bca','brand:mandiri','brand:gopay','brand:dana','brand:grab','brand:shopee','brand:netflix','brand:chatgpt','brand:telkomsel','brand:pln','brand:cash']) {
        expect(starter.any((item) => item.key == requiredKey), isTrue, reason: '$requiredKey should be available as an initial user guide.');
      }
      for (final item in starter) {
        expect(SakuIconRegistry.byKey(item.key), same(item), reason: '${item.key} must come from the one canonical catalog, never a second selector mapping.');
      }
    });

    test('starter named brands cannot silently fall back', () {
      for (final item in SakuIconRegistry.starterChoices.where((item) => item.requiresOfficialAsset)) {
        expect(SakuIconRegistry.sourceFor(item.key), isNot(SakuResolvedIconSource.genericFallback),
          reason: '${item.key} is a real starter brand and must never silently use a SAKU generic icon.');
      }
    });

    test('PDAM is the sole approved custom artwork and remains required', () {
      final approved = SakuIconRegistry.choices.where((choice) => choice.isUserApprovedArtwork);
      expect(approved.map((choice) => choice.key), ['brand:pdam']);
      final pdam = approved.single;
      expect(pdam.requiresOfficialAsset, isFalse);
      expect(pdam.requiresBundledAsset, isTrue);
      expect(pdam.hasBundledAsset, isTrue);
      expect(SakuIconRegistry.sourceFor(pdam.key), SakuResolvedIconSource.bundledBrand);
      expect(SakuIconRegistry.choices.where((choice) => choice.requiresOfficialAsset), hasLength(90));
      expect(SakuIconRegistry.choices.where((choice) => choice.requiresBundledAsset), hasLength(91));
    });

    test('all supported named brands have vetted bundled artwork before release', () {
      final missing = SakuIconRegistry.missingRequiredBrandAssets;
      expect(missing, isEmpty,
        reason: 'V50 release is blocked while any required identity lacks its vetted bundled asset. Missing: ${missing.map((choice) => choice.key).join(', ')}');
    });

    test('release readiness counts all required identities including approved custom artwork', () {
      final missing = SakuIconRegistry.missingRequiredBrandAssets;
      expect(missing.every((choice) => choice.requiresBundledAsset), isTrue);
      expect(missing.every((choice) => !choice.isGeneric), isTrue);
    });
  });
}
