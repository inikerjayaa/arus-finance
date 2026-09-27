import 'package:flutter/material.dart';

import 'brand_icon_catalog.dart';

enum SakuResolvedIconSource {
  userCustom,
  bundledBrand,
  genericFallback,
  missingBrandAsset,
}

class SakuIconChoice {
  const SakuIconChoice({
    required this.key,
    required this.label,
    required this.group,
    required this.fallbackIcon,
    this.keywords = const <String>[],
    this.assetPath,
  });

  final String key;
  final String label;
  final SakuIconGroup group;
  final IconData fallbackIcon;
  final List<String> keywords;
  final String? assetPath;

  bool get hasBundledAsset => assetPath != null && assetPath!.isNotEmpty;
  bool get isGeneric => group == SakuIconGroup.generic;
  bool get requiresOfficialAsset => !isGeneric;
}

/// Canonical resolver for SAKU's A-I icon catalog.
///
/// Real named brands and generic SAKU concepts are deliberately different
/// states. A known real brand without a vetted bundled asset is never reported
/// as a valid generic fallback: it remains [missingBrandAsset] until its
/// authentic local artwork is bundled. This keeps release audits honest and
/// prevents a known company from silently shipping with a misleading icon.
/// Runtime networking is never required.
abstract final class SakuIconRegistry {
  static const brandPrefix = 'brand:';
  static const customPrefix = 'custom:';
  static final RegExp _customKeyPattern = RegExp(
    r'^custom:[0-9a-f]{64}\.(png|jpg|webp)$',
  );

  static final List<SakuIconChoice> choices = List<SakuIconChoice>.unmodifiable(
    SakuBrandIconCatalog.items.map(
      (item) => SakuIconChoice(
        key: '$brandPrefix${item.id}',
        label: item.name,
        group: item.group,
        fallbackIcon: _fallbackForGroup(item.group),
        keywords: item.keywords,
        assetPath: item.assetPath,
      ),
    ),
  );

  static final Map<String, SakuIconChoice> _byKey = {
    for (final choice in choices) choice.key: choice,
  };

  static SakuIconChoice? byKey(String? key) {
    if (key == null || key.isEmpty) return null;
    return _byKey[key];
  }

  static bool isBrandKey(String? key) =>
      key != null && key.startsWith(brandPrefix) && byKey(key) != null;

  static bool isCustomKey(String? key) =>
      key != null && _customKeyPattern.hasMatch(key);

  static SakuResolvedIconSource sourceFor(String? key) {
    if (isCustomKey(key)) return SakuResolvedIconSource.userCustom;
    final choice = byKey(key);
    if (choice == null) return SakuResolvedIconSource.genericFallback;
    if (choice.hasBundledAsset) return SakuResolvedIconSource.bundledBrand;
    if (choice.requiresOfficialAsset) {
      return SakuResolvedIconSource.missingBrandAsset;
    }
    return SakuResolvedIconSource.genericFallback;
  }

  /// Real named brands that are not release-ready yet.
  ///
  /// CI/release audits can require this to be empty without treating generic
  /// SAKU categories as missing company logos.
  static List<SakuIconChoice> get missingOfficialBrandAssets => choices
      .where((choice) => choice.requiresOfficialAsset && !choice.hasBundledAsset)
      .toList(growable: false);

  static bool get officialBrandAssetsReleaseReady =>
      missingOfficialBrandAssets.isEmpty;

  static List<SakuIconChoice> search(
    String query, {
    SakuIconGroup? group,
    int limit = 80,
  }) {
    if (limit <= 0) return const [];
    final needle = _normalize(query);
    final candidates = choices.where(
      (choice) => group == null || choice.group == group,
    );
    if (needle.isEmpty) return candidates.take(limit).toList(growable: false);

    final ranked = <({SakuIconChoice choice, int score})>[];
    for (final choice in candidates) {
      final label = _normalize(choice.label);
      final key = _normalize(choice.key.substring(brandPrefix.length));
      final keywords = choice.keywords
          .map(_normalize)
          .where((value) => value.isNotEmpty)
          .toList(growable: false);
      final keywordPhrase = _normalize(choice.keywords.join(' '));

      final keywordExact =
          keywordPhrase == needle || keywords.any((value) => value == needle);
      final keywordPrefix = keywordPhrase.startsWith(needle) ||
          keywords.any((value) => value.startsWith(needle));
      final keywordContains = keywordPhrase.contains(needle) ||
          keywords.any((value) => value.contains(needle));

      var score = -1;
      if (label == needle || key == needle) {
        score = 100;
      } else if (keywordExact) {
        score = 90;
      } else if (label.startsWith(needle) || key.startsWith(needle)) {
        score = 80;
      } else if (keywordPrefix) {
        score = 70;
      } else if (label.contains(needle) || key.contains(needle)) {
        score = 60;
      } else if (keywordContains) {
        score = 50;
      }
      if (score >= 0) ranked.add((choice: choice, score: score));
    }
    ranked.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.choice.label.toLowerCase().compareTo(
            b.choice.label.toLowerCase(),
          );
    });
    return ranked.take(limit).map((row) => row.choice).toList(growable: false);
  }

  static String _normalize(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static IconData _fallbackForGroup(SakuIconGroup group) {
    return switch (group) {
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
}
