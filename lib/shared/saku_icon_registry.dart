import 'package:flutter/material.dart';

import 'brand_icon_catalog.dart';

enum SakuResolvedIconSource { userCustom, bundledBrand, genericFallback, missingBrandAsset }

class SakuIconChoice {
  const SakuIconChoice({required this.key, required this.label, required this.group, required this.fallbackIcon, required this.requiresOfficialAsset, this.keywords = const <String>[], this.assetPath});
  final String key;
  final String label;
  final SakuIconGroup group;
  final IconData fallbackIcon;
  final bool requiresOfficialAsset;
  final List<String> keywords;
  final String? assetPath;
  bool get hasBundledAsset => assetPath != null && assetPath!.isNotEmpty;
  bool get isGeneric => group == SakuIconGroup.generic;
}

/// One offline source of truth for every brand-bearing SAKU surface.
abstract final class SakuIconRegistry {
  // Backdrop only; original brand pixels are never tinted.
  static Color brandBackdropFor(String? key) => const {
    'brand:bri', 'brand:cimb_niaga', 'brand:dana', 'brand:ovo', 'brand:vidio',
  }.contains(key) ? const Color(0xFF001621) : Colors.white;

  static const brandPrefix = 'brand:';
  static const customPrefix = 'custom:';
  static final RegExp _customKeyPattern = RegExp(r'^custom:[0-9a-f]{64}\.(png|jpg|webp)$');

  static const Set<String> _genericConceptIds = <String>{
    'pbb', 'vehicle_tax', 'home_internet', 'electricity', 'water', 'gas', 'installment',
  };

  /// Small, useful first-run guide. This is deliberately not the whole catalog:
  /// search remains the route to the long tail. The IDs all come from the same
  /// canonical catalog/resolver, so selectors and transaction surfaces cannot
  /// drift to a second logo mapping.
  static const List<String> _starterIds = <String>[
    'bca', 'mandiri', 'bri', 'bni', 'bsi', 'bank_jago', 'seabank', 'jenius',
    'gopay', 'dana', 'ovo', 'shopeepay', 'linkaja',
    'gojek', 'grab', 'traveloka',
    'tokopedia', 'shopee', 'lazada',
    'netflix', 'spotify', 'youtube_premium',
    'chatgpt', 'gemini',
    'telkomsel', 'im3', 'xl', 'indihome', 'biznet',
    'pln', 'bpjs',
    'cash', 'bank_account', 'digital_wallet', 'credit_card',
  ];

  static bool _requiresOfficialAsset(SakuBrandIcon item) =>
      item.group != SakuIconGroup.generic && !_genericConceptIds.contains(item.id);

  static final List<SakuIconChoice> choices = List<SakuIconChoice>.unmodifiable(
    SakuBrandIconCatalog.items.map((item) => SakuIconChoice(
      key: '$brandPrefix${item.id}', label: item.name, group: item.group,
      fallbackIcon: _fallbackForGroup(item.group), requiresOfficialAsset: _requiresOfficialAsset(item),
      keywords: item.keywords, assetPath: item.assetPath,
    )),
  );

  static final Map<String, SakuIconChoice> _byKey = {for (final choice in choices) choice.key: choice};

  static List<SakuIconChoice> get starterChoices => List<SakuIconChoice>.unmodifiable(
    _starterIds.map((id) => _byKey['$brandPrefix$id']).whereType<SakuIconChoice>(),
  );

  static SakuIconChoice? byKey(String? key) => key == null || key.isEmpty ? null : _byKey[key];
  static bool isBrandKey(String? key) => key != null && key.startsWith(brandPrefix) && byKey(key) != null;
  static bool isCustomKey(String? key) => key != null && _customKeyPattern.hasMatch(key);

  static SakuResolvedIconSource sourceFor(String? key) {
    if (isCustomKey(key)) return SakuResolvedIconSource.userCustom;
    final choice = byKey(key);
    if (choice == null) return SakuResolvedIconSource.genericFallback;
    if (choice.hasBundledAsset) return SakuResolvedIconSource.bundledBrand;
    if (choice.requiresOfficialAsset) return SakuResolvedIconSource.missingBrandAsset;
    return SakuResolvedIconSource.genericFallback;
  }

  static List<SakuIconChoice> get missingOfficialBrandAssets => choices
      .where((choice) => choice.requiresOfficialAsset && !choice.hasBundledAsset).toList(growable: false);
  static bool get officialBrandAssetsReleaseReady => missingOfficialBrandAssets.isEmpty;

  static List<SakuIconChoice> search(String query, {SakuIconGroup? group, int limit = 80}) {
    if (limit <= 0) return const [];
    final needle = _normalize(query);
    final candidates = choices.where((choice) => group == null || choice.group == group);
    if (needle.isEmpty) return candidates.take(limit).toList(growable: false);
    final ranked = <({SakuIconChoice choice, int score})>[];
    for (final choice in candidates) {
      final label = _normalize(choice.label);
      final key = _normalize(choice.key.substring(brandPrefix.length));
      final keywords = choice.keywords.map(_normalize).where((v) => v.isNotEmpty).toList(growable: false);
      final keywordPhrase = _normalize(choice.keywords.join(' '));
      var score = -1;
      if (label == needle || key == needle) {
        score = 100;
      } else if (keywordPhrase == needle || keywords.any((v) => v == needle)) {
        score = 90;
      } else if (label.startsWith(needle) || key.startsWith(needle)) {
        score = 80;
      } else if (keywordPhrase.startsWith(needle) || keywords.any((v) => v.startsWith(needle))) {
        score = 70;
      } else if (label.contains(needle) || key.contains(needle)) {
        score = 60;
      } else if (keywordPhrase.contains(needle) || keywords.any((v) => v.contains(needle))) {
        score = 50;
      }
      if (score >= 0) ranked.add((choice: choice, score: score));
    }
    ranked.sort((a, b) {
      final score = b.score.compareTo(a.score);
      return score != 0 ? score : a.choice.label.toLowerCase().compareTo(b.choice.label.toLowerCase());
    });
    return ranked.take(limit).map((row) => row.choice).toList(growable: false);
  }

  static String _normalize(String value) => value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

  static IconData _fallbackForGroup(SakuIconGroup group) => switch (group) {
    SakuIconGroup.bank => Icons.account_balance_rounded,
    SakuIconGroup.wallet => Icons.account_balance_wallet_rounded,
    SakuIconGroup.transport => Icons.directions_transit_rounded,
    SakuIconGroup.marketplace => Icons.shopping_bag_rounded,
    SakuIconGroup.subscription => Icons.subscriptions_rounded,
    SakuIconGroup.ai => Icons.auto_awesome_rounded,
    SakuIconGroup.telco => Icons.signal_cellular_alt_rounded,
    SakuIconGroup.utility => Icons.receipt_long_rounded,
    SakuIconGroup.generic => Icons.category_rounded,
  };
}
