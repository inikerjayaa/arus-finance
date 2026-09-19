# Implementation Status

**Snapshot:** Android physical UAT in progress after latest main candidate  
**Rule:** `DONE` = source implemented. `CI PROVEN` = analyzer/tests + generated native shell + platform compile were proven by Arus Native Verification. `PHYSICAL UAT PASS` = a real user/device flow has been exercised successfully. CI must never be used as a substitute for physical proof.

| Capability | Status |
|---|---|
| Product/domain blueprint | DONE |
| Local-first / device-owned financial data | DONE |
| Integer-money + ledger | DONE |
| Expense / income | DONE |
| Asset transfer + transfer fee | DONE |
| Refund | DONE |
| Edit / soft delete | DONE |
| Account reconciliation | DONE |
| Credit-card payment domain + UI | DONE |
| Loan payment/disbursement domain + UI | DONE |
| Loan overpayment protection | DONE |
| Accounts / categories UI | DONE |
| Dashboard / transactions UI | DONE |
| Dashboard visibility + reorder customization | DONE |
| Advanced transaction search/filter | DONE |
| Budget / bills / recurring | DONE |
| Recurring occurrence de-dup | DONE |
| Insights | DONE |
| PIN / biometric service + app-lock gate | DONE; Android physical flow exercised |
| Privacy shield / screenshot protection contract | DONE |
| Encrypted portable backup | DONE |
| Local crash-safe recovery generations | DONE |
| Custom icon bundle in encrypted backup/restore | DONE |
| CSV export | DONE |
| CSV import + preview/dedup/atomic conflict handling | DONE |
| Local scheduled notifications | DONE |
| Local encrypted SQLite wiring | DONE, CI PROVEN |
| SAKU visible branding | DONE, CI PROVEN |
| Plus Jakarta Sans local font bundle | DONE, CI PROVEN |
| Native splash generation (Android/iOS) | DONE, CI PROVEN |
| Native launcher/app icon generation | DONE, CI PROVEN |
| Android adaptive + round launcher icon | DONE, CI PROVEN |
| `flutter analyze` / `flutter test` | CI PROVEN |
| Android release-mode compile + installable UAT APK | CI PROVEN |
| iOS release-mode no-codesign compile | CI PROVEN |
| Cross-platform canonical-source / lockfile consistency | CI PROVEN |
| Cloud/sync experiment | NON-PRODUCTION / OPTIONAL FUTURE |
| Automatic cloud account/sync UI | NOT IN PRODUCTION ROADMAP |
| AI input | GATED |
| OCR receipt | GATED |
| Family/shared workspace | GATED |
| Bank/e-wallet integration | GATED |
| Store-signed Play/App Store release | NOT DONE — signing/distribution credentials required |
| Old-device → encrypted backup → fresh Android 12 environment → restore | PHYSICAL UAT PASS |
| Wrong-passphrase restore safety | PHYSICAL UAT PASS — rejected without data mutation |
| Vivo clean-install migration after signer mismatch | PHYSICAL UAT PASS |
| Core real-device smoke: restart, lock/biometric, transaction CRUD, integrity | PHYSICAL UAT PASS |
| Final launcher/icon/native-splash appearance confirmation | PHYSICAL UAT PENDING |
| Post-restore portable-backup re-export from final candidate | PHYSICAL UAT PENDING |
| iPhone signed build + Face ID + backup restore + finance smoke | PHYSICAL UAT PENDING |

## What CI now proves

Native verification generates hardened Android/iOS shells from the canonical Flutter source, runs the audit suite, runs analyzer/tests, compiles Android and iOS release-mode targets, builds an installable Android UAT APK, and checks that Android/iOS evidence came from the same canonical source and committed lockfile.

CI proof is still not the same thing as human/device proof. It must not be used to claim launcher-mask appearance, OEM biometric behavior, physical migration, or signed-store release without a real device check.

## Physical Android evidence now proven

On 2026-09-19 the final-main Android candidate was exercised through the destructive migration path only after encrypted backup + fresh-environment restore rehearsal succeeded. The rehearsal rejected a deliberately wrong backup secret without mutating the fresh data, then successfully restored the same backup with the correct secret and matched the original semantic finance data. The Vivo update-in-place attempt correctly stopped on signer mismatch; clean install was performed only after the restore rehearsal passed, the backup was restored on the Vivo, and the core physical smoke was reported PASS.

Detailed evidence is recorded in `docs/ANDROID_PHYSICAL_UAT_2026-09-19.md`.

## Remaining release blockers

1. **Close Android final evidence:** confirm launcher name/icon/adaptive mask and native splash appearance on the Vivo, create one new encrypted portable backup from the final candidate after restore, and record the full backup SHA-256 for the evidence record.
2. **iOS physical validation:** produce a signed iOS build using Apple signing/distribution, install it on the physical iPhone, test Face ID/app-lock lifecycle, encrypted backup restore, and semantic finance smoke.
3. **Store signing/distribution:** required only for Play Store/App Store release. It is not a dependency for SAKU's local-first functionality.
4. **Final copy/cosmetic polish:** humanize technical restore errors, remove stale `Arus Finance` visible copy, remove unnecessary helper/example text, simplify backup wording, and complete the saved light/dark visual refinement after functional UAT is closed.

## Safety boundary

Do not use uninstall/clear-data as a routine test step on the user's real device. A destructive clean-install migration is allowed only after an encrypted portable backup exists outside the app sandbox and has already been proven restorable in a fresh environment.
