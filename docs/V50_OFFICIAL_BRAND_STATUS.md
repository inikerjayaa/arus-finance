# V50 official brand assets — 2026-09-29

89 of 91 official brand identities are bundled and mapped in the catalog. Image files total 1,782,184 bytes before APK compression. Remaining: IndiHome and PDAM. No runtime logo downloads or new Flutter dependencies.

## Durable progress

- 64-logo implementation: `7b606ebc157f3ec3367b194f57bf27c85321337a`.
- BNI added: `29d755238e10e4b237ea81e211d552d0d627fab2`.
- 17 official publisher icons added (82 total): `da7b87b47a0d67af666c9bb4f6a50b6256352c79`.
- Six additional official identities (88 total): `51cb90bd07886fb13da6caca156b3833125b2ba2`.
- This checkpoint integrates QRIS from the original Bank Indonesia PDF, with original colors, geometry and source background retained. Page 1 clip coordinates and both original PDF and shipped asset hashes are in provenance. The page SVG export is retained separately as a derived source.

`assets/brands/provenance.json` records official source URLs, original and shipped hashes, transformations, usage status and publisher icon variants. Sources are retained under `native_artwork/brand_sources`. Current official publisher app icons are explicitly identified as variants rather than corporate wordmarks. BRI uses a dark backdrop for its white official logo. The renderer preserves proportions and colors, does not tint, and caps decoding at 512 px. Missing or failed named brands show an explicit error, never a generic substitute.

## Validation and unresolved work

Local asset hash, decoding and catalog consistency checks cover all 89 bundled identities. The unchanged zero-missing release gate still blocks on two identities. Flutter/native CI has not passed for this new checkpoint.

Latest completed CI evidence remains #397 on the 64-logo commit: https://github.com/inikerjayaa/arus-finance/actions/runs/36409289946 . Analyzer and non-native regression passed; 156 Flutter tests passed and the completeness test failed (27 missing at that commit). Android/iOS and cross-platform jobs were skipped. Later logo batches used skip-ci checkpoints; these old results must not be attributed to the newer assets. Local dependency installation previously triggered automatic approval rejection for a cloud metadata endpoint and must not be retried to bypass it.

IndiHome: current official pages redirect to Telkomsel and mostly expose the Telkomsel logo. Do not substitute it. Candidate official service page: https://graparionline.telkomsel.com/service/indihome-paybills . Official addon page https://www.telkomsel.com/indihome/addon links https://assets.telkomsel.com/public/2023-06/icon--indihome-tv.png ; inspect identity before considering it because an IndiHome TV variant may not represent broadband.

PDAM: ask for the specific city/company; PDAM is not a single unique water company. Do not select an arbitrary provider or reclassify/remove this brand to pass the gate.

## Remaining acceptance sequence

1. Finish the two missing official identities: IndiHome and PDAM. PDAM requires the user's specific provider identity. Preserve the zero-missing gate; do not remove/reclassify brands or insert approximate/generic substitutes to pass it.
2. Integrate the exact approved SAKU artwork. Earlier local artwork edits were lost before commit and must not be claimed as present. Approved inputs referenced in the prior conversation: stacked `Logo Saku dengan Ilustrasi Tangan di Saku.png` (1254 x 1254) and horizontal `Logo SAKU dengan Ilustrasi Saku Oranye.png` (1448 x 1086). Recover original files, not redraws. Check splash, launcher and shared UI branding against them.
3. Verify dashboard total-saldo hero, transaction priority, spacing, existing tabbar and SAKU/white/black themes; reachable optional offline local AI; privacy lifecycle and V49 regressions.
4. Pass analyzer/tests, Android and iOS release compile, cross-platform evidence and artifact-budget gates on the final PR commit.
5. Only then merge, verify exact main and use the existing stable-device-UAT signing workflow. Verify source SHA, checksum and signing certificate against the resulting APK evidence. Reuse existing signing configuration without exposing or replacing keys.
6. Physical Vivo 1915 Android 12 testing is separate; do not claim DEVICE PASS without that evidence.

Continue directly from PR #75, branch `v50-local-ai-vivo-privacy`. Inspect current head first; do not regenerate committed assets. Keep the PR draft until the acceptance sequence passes. No final signed APK, exact-main verification or physical-device PASS is claimed. User priority is completing logos first, preserving durable progress, then continuing the rest in ordinary chat.
