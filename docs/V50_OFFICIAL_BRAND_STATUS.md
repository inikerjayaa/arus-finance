# V50 official brand assets — 2026-09-28

64 official-site logos are now bundled and wired into the existing catalog and resolver. Image files total 737,293 bytes (before APK compression). No runtime network logo requests or new Flutter dependencies.

Provenance: `assets/brands/provenance.json` contains official page URL, asset URL, original source SHA-256, shipped SHA-256, transformations and usage status. SVG and ICO originals are retained under `native_artwork/brand_sources`. Bitmaps retain original bytes. SVG/ICO format conversion preserves colors, geometry and aspect ratio. Brand rendering always contains the artwork, uses a contrasting background, never applies a color tint, and caps decode width at 512 px. Known missing/failed logos never silently become generic icons.

## Validation

Local: all 64 files decode and match provenance hashes; retained original SVG/ICO hashes also match. Flutter bundle-decode/hash and rendering tests are included for repository CI. The local dependency installation path was previously rejected by automatic approval review for attempting a cloud metadata endpoint, so it is not retried.

## Remaining release blockers

The existing zero-missing release gate is preserved. 27 catalog entries still lack verified original artwork:

bri, bni, btn, bsi, permata, ocbc, neobank, motionbanking, linkaja, isaku, sakuku, qris, maxim, tiket, tokopedia, blibli, bukalapak, tiktok_shop, microsoft_365, perplexity, midjourney, im3, first_media, indihome, myrepublic, pdam, bpjs

Some official sites reject automated requests (403/502), and several candidates were rejected because their visible identity did not match the named product. PDAM also needs a specific provider identity; the current name does not designate one unique water company.

No merge, native build success, device-UAT pass, exact-main signature or final APK is claimed by this checkpoint. Full original V50 acceptance criteria remain required before release, including approved SAKU artwork integration, complete official assets, full CI, exact-main verification and stable signing.

## Latest verified CI and continuation checkpoint

Implementation commit: `7b606ebc157f3ec3367b194f57bf27c85321337a`.
CI #397: https://github.com/inikerjayaa/arus-finance/actions/runs/36409289946
Analyzer and non-native regression passed. Job 108885411531 reported 156 Flutter tests passed and one failure: the unchanged official-artwork completeness gate (27 missing). Android/iOS compile and cross-platform evidence jobs were skipped after that failure. These results belong to the implementation commit, not to any later documentation-only checkpoint.

Continue from branch `v50-local-ai-vivo-privacy`, PR #75. Do not regenerate the 64 committed assets or repeat completed implementation work. Inspect current head first to preserve any newer changes.

### Next unfinished asset: BNI

BNI's original image was downloaded and visually inspected immediately before the Work session interruption, but was NOT committed or included in the 64 count.

- Official page: https://www.bni.co.id/ppid/informasi-publik/informasi-yang-diumumkan-secara-berkala/informasi-profil-bni
- Original image URL observed in that page's DOM: https://www.bni.co.id/Portals/6/bni-logo-id.png?ver=f1UrUlisTWi3t-IozhcSzA%3d%3d
- Verified downloaded file: PNG, 170 x 60, 4,279 bytes; orange BNI symbol, teal BNI wordmark and tagline.
- Previous transient path: `/workspace/scratch/3e28655d-eb24-40ba-9f05-5c2ae3fd78fb/f3ac6304-8565-4732-b796-1e644eaebe39`.
- On resumption, use that file if still present; otherwise retrieve the original from the recorded official source through an available authorized path. Compute SHA-256, add original bytes to `assets/brands/bni.png`, append provenance and set BNI's catalog assetPath. Do not fabricate the hash or reconstruct the image.
- The Work execution environment became unavailable before these changes could be saved. GitHub remains the durable source of completed work.

The last attempted browser navigation to BRI was not executed: automatic approval review could not complete because of a usage limit. This was a review failure, not a determination that the BRI page was unsafe. Do not bypass that check. BTN returned a request-rejected page in the prior browser session. BSI Salam Digital loaded but its visible logo was for Salam Digital; it was not substituted for the BSI bank logo.

### Remaining acceptance sequence

1. Finish the 27 missing official identities above, starting with the recovered BNI source. PDAM requires the user's specific provider identity. Preserve the zero-missing gate; do not remove/reclassify brands or insert approximate/generic substitutes to pass it.
2. Integrate the exact approved SAKU artwork. Earlier local artwork edits were lost before commit and must not be claimed as present. Approved inputs referenced in the prior conversation: stacked `Logo Saku dengan Ilustrasi Tangan di Saku.png` (1254 x 1254) and horizontal `Logo SAKU dengan Ilustrasi Saku Oranye.png` (1448 x 1086). Recover original files, not redraws. Check splash, launcher and shared UI branding against them.
3. Verify dashboard total-saldo hero, transaction priority, spacing, existing tabbar and SAKU/white/black themes; reachable optional offline local AI; privacy lifecycle and V49 regressions.
4. Pass analyzer/tests, Android and iOS release compile, cross-platform evidence and artifact-budget gates on the final PR commit.
5. Only then merge, verify exact main and use the existing stable-device-UAT signing workflow. Verify source SHA, checksum and signing certificate against the resulting APK evidence. Reuse existing signing configuration without exposing or replacing keys.
6. Physical Vivo 1915 Android 12 testing is separate; do not claim DEVICE PASS without that evidence.

User priority: continue directly, conserve resources, preserve progress in small durable commits, and enable continuation in ordinary chat. This checkpoint is documentation only; it does not add a logo, pass a release gate or produce an APK.
