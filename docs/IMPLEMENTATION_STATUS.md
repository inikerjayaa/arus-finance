# Implementation Status

**Snapshot:** post-native-branding / release-readiness hardening  
**Rule:** `DONE` = source implemented. `CI PROVEN` = analyzer/tests + generated native shell + platform compile were proven by Arus Native Verification. `PHYSICAL UAT` = cannot be truthfully replaced by CI and still needs a real device/user flow.

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
| PIN / biometric service + app-lock gate | DONE; physical device flow previously exercised |
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
| Old-device → encrypted backup → fresh environment → restore | PHYSICAL UAT REQUIRED |
| Final real-device smoke after latest native branding/icon changes | PHYSICAL UAT REQUIRED |

## What CI now proves

The repository no longer stops at source-level structural confidence. Native verification generates hardened Android/iOS shells from the canonical Flutter source, runs the audit suite, runs analyzer/tests, compiles Android and iOS release-mode targets, builds an installable Android UAT APK, and checks that Android/iOS evidence came from the same canonical source and committed lockfile.

CI proof is still not the same thing as a human/device proof. It must not be used to claim that migration, biometrics on every OEM, launcher-mask appearance, or a signed-store release has been physically validated.

## Remaining release blockers

1. **Physical encrypted migration UAT:** create encrypted portable backup on the existing device, restore into a genuinely fresh environment/device, verify ledger/accounts/categories/custom icons/settings, then verify local recovery state remains healthy.
2. **Final device smoke:** launch from cold start, confirm SAKU native splash/launcher appearance, PIN/biometric lock, core transaction flows, notification permission/behavior, backup export/import, and restart/background/resume behavior.
3. **Store signing/distribution:** only needed when preparing Play Store/App Store distribution; not a dependency for local-first app functionality or local device UAT.

## Safety boundary

Do not use uninstall/clear-data as a routine test step on the user's real device. For any destructive fresh-environment test, first verify that an encrypted portable backup exists outside the app sandbox and that its passphrase is known.
