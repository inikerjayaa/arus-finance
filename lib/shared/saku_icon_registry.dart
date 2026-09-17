import 'package:flutter/material.dart';

import 'brand_icon_catalog.dart';

enum SakuResolvedIconSource { userCustom, bundledBrand, genericFallback }

class SakuIconChoice {
  const SakuIconChoice({
    required this.key,
    required this.label,
    required this.group,
    required this.fallbackIcon,
    this.assetPath,
  });

  final String key;
  final String label;
  final SakuIconGroup group;
  final IconData fallbackIcon;
  final String? assetPath;

  bool get hasBundledAsset => assetPath != null && assetPath!.isNotEmpty;
}

/// Canonical resolver for SAKU's A-I icon catalog.
///
/// Stable keys are deliberately independent from artwork. A brand can be
/// selected before a vetted local logo asset is bundled; the UI renders the
/// local Material fallback until the asset is available. Runtime networking is
/// never required.
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
    final brand = byKey(key);
    if (brand?.hasBundledAsset == true) {
      return SakuResolvedIconSource.bundledBrand;
    }
    return SakuResolvedIconSource.genericFallback;
  }

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
      var score = -1;
      if (label == needle || key == needle) {
        score = 100;
      } else if (label.startsWith(needle) || key.startsWith(needle)) {
        score = 80;
      } else if (label.contains(needle) || key.contains(needle)) {
        score = 60;
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
