# V50 bundled brand and custom artwork — 2026-09-29

91 of 91 required catalog identities now have vetted bundled artwork: 90 official-source identities plus one original user-approved custom PDAM icon. Image assets total 1,820,379 bytes before APK compression. No runtime logo downloads, font dependencies or new Flutter dependencies.

## User-approved PDAM decision

On 2026-09-29 the user explicitly requested that PDAM be designed in-house: a water symbol, PDAM lettering below, and blue color. This supersedes the earlier requirement to identify a particular regional PDAM company for this entry only. No official company or association logo is claimed for PDAM.

The original vector is `native_artwork/brand_sources/pdam-custom.svg`; the bundled transparent PNG is `assets/brands/pdam.png` (512 x 512, 15,455 bytes). The design uses a blue drop, dark-blue water, a white wave and geometric PDAM lettering below. Every shape and letter is a vector path. Provenance records the user instruction, custom origin, source and shipped hashes, and rendering operation. The UI keeps the stable `brand:pdam` key and PDAM label.

The catalog explicitly marks only PDAM as `isUserApprovedArtwork`. Official artwork remains required for the other 90 named identities. The zero-missing release gate uses `missingRequiredBrandAssets` and still covers all 91 entries, including custom PDAM. PDAM was not removed, reclassified as generic, or excluded from the required-asset gate. The renderer continues to fail explicitly if a required image is missing or cannot load. A contract test checks that PDAM is the sole custom exception and verifies counts of 90 official / 91 required identities.

## Durable progress

- 64-logo implementation: `7b606ebc157f3ec3367b194f57bf27c85321337a`.
- BNI (65): `29d755238e10e4b237ea81e211d552d0d627fab2`.
- Official publisher icons (82): `da7b87b47a0d67af666c9bb4f6a50b6256352c79`.
- Six additional identities (88): `51cb90bd07886fb13da6caca156b3833125b2ba2`.
- QRIS (89): `baf7cde3e44ce0020d7cfabd2b46b533a7761259`, original Bank Indonesia PDF extraction with original colors/geometry/background and source coordinates/hashes recorded.
- IndiHome (90): `0a8bd3b3a0b36fe061f8e8def9464acac5c47775`, original unchanged Telkomsel PNG from its public image endpoint.
- This checkpoint: user-approved custom PDAM (91), catalog mapping, explicit origin metadata and complete required-artwork gate.

All earlier 90 provenance entries and shipped assets are unchanged. `assets/brands/provenance.json` records source URLs, linkage, original/shipped hashes, transformations, publisher variants and usage status. Format-converted source files are retained under `native_artwork/brand_sources`. Rendering preserves proportions/colors, uses contrasting backdrops without tint, and caps decoding width at 512 px.

## Validation

Local checks passed for all 91 image decodes, provenance hashes, unique IDs and catalog mappings. The new PDAM PNG was visually inspected. CI is requested for this implementation; inspect the latest PR run before claiming analyzer, Flutter or native build success.

Previous CI #399 on the 90-logo commit: https://github.com/inikerjayaa/arus-finance/actions/runs/36504913024 . Analyzer and non-native regression passed; 156 Flutter tests passed. The only failure was missing PDAM. Native jobs were skipped. This checkpoint supplies the newly approved custom artwork; the old failure must not be treated as its result. Local dependency installation previously triggered automatic approval rejection for a cloud metadata endpoint; do not retry it to bypass that check.

## Remaining acceptance sequence

The logo-list task is implemented. Preserve the new explicit PDAM exception and do not regenerate the 91 existing assets. The rest of the original V50 acceptance criteria still applies:

2. Integrate the exact approved SAKU artwork. Earlier local artwork edits were lost before commit and must not be claimed as present. Approved inputs referenced in the prior conversation: stacked `Logo Saku dengan Ilustrasi Tangan di Saku.png` (1254 x 1254) and horizontal `Logo SAKU dengan Ilustrasi Saku Oranye.png` (1448 x 1086). Recover original files, not redraws. Check splash, launcher and shared UI branding against them.
3. Verify dashboard total-saldo hero, transaction priority, spacing, existing tabbar and SAKU/white/black themes; reachable optional offline local AI; privacy lifecycle and V49 regressions.
4. Pass analyzer/tests, Android and iOS release compile, cross-platform evidence and artifact-budget gates on the final PR commit.
5. Only then merge, verify exact main and use the existing stable-device-UAT signing workflow. Verify source SHA, checksum and signing certificate against the resulting APK evidence. Reuse existing signing configuration without exposing or replacing keys.
6. Physical Vivo 1915 Android 12 testing is separate; do not claim DEVICE PASS without that evidence.

Continue from PR #75, branch `v50-local-ai-vivo-privacy`, inspecting current head first. Keep the PR draft until all acceptance stages pass. No exact-main signed APK or physical-device PASS is claimed by this icon checkpoint. User priority is finishing this logo list and continuing remaining V50 work in ordinary chat. Latest CI results are recorded in the PR description when available.
