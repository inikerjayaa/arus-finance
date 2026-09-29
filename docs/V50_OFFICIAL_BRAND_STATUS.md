# V50 official brand assets — 2026-09-29

90 of 91 official brand identities are bundled and mapped in the catalog. Image files total 1,804,924 bytes before APK compression. Remaining: PDAM, pending the user's specific city/company or supplied official logo. No runtime logo downloads or new Flutter dependencies.

## Durable progress

- 64-logo implementation: `7b606ebc157f3ec3367b194f57bf27c85321337a`.
- BNI added: `29d755238e10e4b237ea81e211d552d0d627fab2`.
- 17 official publisher icons added (82 total): `da7b87b47a0d67af666c9bb4f6a50b6256352c79`.
- Six additional official identities (88 total): `51cb90bd07886fb13da6caca156b3833125b2ba2`.
- QRIS added (89 total): `baf7cde3e44ce0020d7cfabd2b46b533a7761259`. Extracted from the original Bank Indonesia PDF with original colors, geometry and source background retained. Page 1 clip coordinates and original PDF/shipped asset hashes are in provenance; the SVG page export is recorded as a derived source.
- This checkpoint adds the original 298 x 120 PNG IndiHome by Telkomsel wordmark from Telkomsel's own public image endpoint, unchanged. The public landing page's JavaScript links the exact navbar image URL; source linkage is recorded in provenance. Do not repeat the earlier unsuccessful logo search.

`assets/brands/provenance.json` records official source URLs, original and shipped hashes, transformations, usage status and publisher icon variants. Retained sources are under `native_artwork/brand_sources`. Current official publisher app icons are explicitly identified as variants rather than corporate wordmarks. BRI uses a dark backdrop for its white official logo. Rendering preserves proportions and colors, does not tint, and caps decoding at 512 px. Missing or failed named brands show an explicit error, never a generic substitute.

## Validation and unresolved work

Local validation passed for all 90 bundled identities: image decoding, provenance hashes, unique IDs and catalog mappings. The unchanged zero-missing release gate remains blocked by PDAM. CI for this IndiHome checkpoint is requested; do not attribute the previous results below to this new source until that run completes.

Latest completed CI #398 on the 89-logo commit `baf7cde3e44ce0020d7cfabd2b46b533a7761259`: https://github.com/inikerjayaa/arus-finance/actions/runs/36501867616 . Analyzer and non-native regression passed; 156 Flutter tests passed and one completeness test failed with exactly `brand:indihome` and `brand:pdam`. The bundle decode/hash and rendering tests passed. Android/iOS and cross-platform jobs were skipped after that gate. Local dependency installation previously triggered automatic approval rejection for a cloud metadata endpoint; do not retry it to bypass that check.

PDAM: prior-context retrieval on 2026-09-29 found no city/company, supplied official logo, or permission to select an arbitrary provider. The earlier illustrated icon catalog named only PDAM. Ask for the specific city/company or original official logo. Do not choose an unrelated water company, substitute an association logo, or reclassify/remove this brand to pass the gate. All other named brands are now bundled.

## Remaining acceptance sequence

1. Finish the one missing official identity: PDAM. PDAM requires the user's specific provider identity. Preserve the zero-missing gate; do not remove/reclassify brands or insert approximate/generic substitutes to pass it.
2. Integrate the exact approved SAKU artwork. Earlier local artwork edits were lost before commit and must not be claimed as present. Approved inputs referenced in the prior conversation: stacked `Logo Saku dengan Ilustrasi Tangan di Saku.png` (1254 x 1254) and horizontal `Logo SAKU dengan Ilustrasi Saku Oranye.png` (1448 x 1086). Recover original files, not redraws. Check splash, launcher and shared UI branding against them.
3. Verify dashboard total-saldo hero, transaction priority, spacing, existing tabbar and SAKU/white/black themes; reachable optional offline local AI; privacy lifecycle and V49 regressions.
4. Pass analyzer/tests, Android and iOS release compile, cross-platform evidence and artifact-budget gates on the final PR commit.
5. Only then merge, verify exact main and use the existing stable-device-UAT signing workflow. Verify source SHA, checksum and signing certificate against the resulting APK evidence. Reuse existing signing configuration without exposing or replacing keys.
6. Physical Vivo 1915 Android 12 testing is separate; do not claim DEVICE PASS without that evidence.

Continue from PR #75, branch `v50-local-ai-vivo-privacy`, inspecting current head first. Do not regenerate the 90 committed assets. Keep the PR draft until the acceptance sequence passes. No final signed APK, exact-main verification or physical-device PASS is claimed. User priority remains finishing logos first, conserving resources, and then continuing the rest in ordinary chat.
