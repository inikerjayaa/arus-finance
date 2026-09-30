import 'package:flutter/material.dart';

import 'saku_brand.dart';

class SakuSplashScreen extends StatelessWidget {
  const SakuSplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SakuBrand.noturno,
      body: SafeArea(
        child: Center(
          child: Semantics(
            container: true,
            label: 'SAKU sedang dibuka',
            liveRegion: true,
            child: const SakuBrandLockup(markSize: 240),
          ),
        ),
      ),
    );
  }
}

/// Approved original stacked identity, including its original wordmark.
/// The historical class name is retained for existing shared-brand call sites.
class SakuBrandMark extends StatelessWidget {
  const SakuBrandMark({super.key, this.size = 32});
  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
        SakuBrand.stackedLogoAsset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        semanticLabel: SakuBrand.appName,
      );
}

/// Complete original lockup. Color/wordmark parameters remain source-compatible
/// with callers but never recolor or re-typeset the approved image.
class SakuBrandLockup extends StatelessWidget {
  const SakuBrandLockup({
    super.key,
    this.markSize = 120,
    this.wordmarkSize = 36,
    this.wordmarkColor = SakuBrand.noturno,
  });

  final double markSize;
  final double wordmarkSize;
  final Color wordmarkColor;

  @override
  Widget build(BuildContext context) => SakuBrandMark(size: markSize);
}

/// Approved horizontal identity for shared header surfaces.
class SakuBrandHorizontal extends StatelessWidget {
  const SakuBrandHorizontal({super.key, this.height = 48});
  final double height;

  @override
  Widget build(BuildContext context) => Image.asset(
        SakuBrand.horizontalLogoAsset,
        width: height * 1448 / 1086,
        height: height,
        fit: BoxFit.contain,
        semanticLabel: SakuBrand.appName,
      );
}
