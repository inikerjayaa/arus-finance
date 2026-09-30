# Approved SAKU artwork integration

The three approved originals are committed byte-for-byte, at their original resolution and colors. Source names, Library identities, dimensions and SHA-256 hashes are recorded in `native_artwork/saku/provenance.json`.

- `assets/saku/stacked.png`: original 1254 x 1254 stacked identity; canonical shared mark, onboarding, live splash and launcher source.
- `assets/saku/horizontal.png`: original 1448 x 1086 horizontal identity; app header and About branding.
- `native_artwork/saku/splash-reference.png`: original 941 x 1672 approved screen reference. Its photographed clock/carrier/battery row is not shown in the live app; the real OS supplies system status.

The former Flutter painter and native vector/scanline logo reconstruction are removed. Shared widgets contain the complete original images without tint or crop; text is no longer re-typeset over/alongside the image wordmark. Android and iOS splash image files are exact copies of the stacked original. Android 12/adaptive icons contain the full original inside a safe-area inset.

The originals are never resized or rewritten. Platform-required launcher raster sizes (including the iOS 1024 px marketing slot) are generated only into the disposable native shell at build time, using the original image pixels. No reconstructed shape, substitute font, palette change or crop is used. Generation uses the Python standard library, without a network/image-tool dependency, and verifies all original hashes before producing resources.

Focused checks: `python3 tool/test_saku_artwork.py -v` tests exact approved hashes, known-pixel rendering, native splash byte identity, native XML, and all Android/iOS icon slots. The V38/V39/V40 branding audits pass. Flutter splash/onboarding tests now assert original asset use rather than a separately rendered text wordmark. Local Flutter execution is unavailable in this environment; the PR CI runs those tests after push.

The completed 91/91 brand assets, their provenance, catalog and resolver are unchanged. This commit addresses approved SAKU branding only; no broad release re-audit, merge or exact-main signed APK is claimed.
