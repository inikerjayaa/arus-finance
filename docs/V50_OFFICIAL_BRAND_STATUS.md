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

CI #395 (54-logo commit): analyzer and non-native regression passed; 156 Flutter tests passed; only the unchanged completeness gate failed. This follow-up adds six verified official logos; 31 remain missing.

Further official-site favicon recovery adds Adobe, Bank Jago, iCloud and by.U, with original ICOs retained. Remaining coverage gate: 27.
