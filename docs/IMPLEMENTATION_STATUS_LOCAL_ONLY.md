> Canonical persisted milestone: **V27 — Immutable Git Bootstrap Handoff**

# Implementation Status — Local-Only

## Product architecture — LOCKED

- [x] Core finance works without account/login/cloud/server.
- [x] Financial data is device-owned and stored in encrypted local SQLite.
- [x] Official portable backup is the user-controlled encrypted `.arusbackup` file.
- [x] Production `lib/` and `pubspec.yaml` have no Supabase/CloudSync runtime dependency.
- [x] Historical sync outbox/conflict state is removed by local-only migrations.
- [x] Canonical balances are ledger-derived using integer IDR units.

## Core financial/domain behavior

- [x] Expense / income / asset transfer / transfer fee.
- [x] Refund with cumulative over-refund protection.
- [x] Adjustment / opening balance / reconciliation.
- [x] Credit-card payment and credit-card credit-balance semantics.
- [x] Loan disbursement / principal / interest / fee semantics.
- [x] Composite transaction group handling.
- [x] User delete is physical hard-delete in local-only builds.
- [x] Explicit VOID preserves history while removing financial effect.
- [x] Group delete and group VOID are all-or-nothing across refund dependencies.
- [x] Refund destination is restricted at repository level to asset or credit-card liability.
- [x] Refund and simple-edit refund limits are rechecked at the atomic write boundary.
- [x] Loan principal outstanding is rechecked inside the LOAN_PAYMENT write transaction.

## Planning / daily use

- [x] Budget actuals and category-scoped budgets.
- [x] Bills with linked actual payment and refund-aware status reconciliation.
- [x] Recurring monthly draft generation with deterministic occurrence keys.
- [x] Clock-drift recovery prevents years of synthetic recurring drafts.
- [x] Local Bill/recurring reminders; notification text is private-by-default.
- [x] Differential reminder scheduler uses stable per-reminder IDs.
- [x] Blank Budget/Bill/Recurring names are rejected in the repository.
- [x] New Bills derive UPCOMING/DUE/OVERDUE from the actual due date immediately.
- [x] Recurring expense account semantics are enforced in repository create/reactivate/materialize paths.
- [x] Manual Bill status mutation is restricted to safe SKIPPED state and cannot override an active payment.

## Data movement / search / privacy

- [x] CSV export is batched/streamed.
- [x] CSV import preview + atomic commit + idempotent fingerprints.
- [x] Arus Transaction ID is preserved across export/import.
- [x] 5,000-row import preflight uses bounded SQLite bind batches.
- [x] Temporary export/backup share files are deleted after share completion.
- [x] Local FTS5 search indexes note/type/amount/account/category.
- [x] FTS is derived and rebuildable from the canonical ledger.
- [x] SQLite + FTS secure-delete are enabled.
- [x] Destructive wipe truncates WAL and VACUUMs before reseeding defaults.

## Backup / restore hardening

- [x] Backup input is capped at 64 MiB.
- [x] Restore is atomic; live data remains unchanged if insertion/validation fails.
- [x] Foreign keys, posted-leg coverage, IDR consistency, duplicate active names, enum values, split totals, refund integrity and Bill-payment integrity are validated.
- [x] V10 semantic firewall validates simple transaction leg/split shape.
- [x] V10 semantic firewall validates Expense/Income/Refund account sign + category semantics.
- [x] V10 semantic firewall validates Transfer/Adjustment/Opening/CC/Loan leg shape and account semantics.
- [x] V10 semantic firewall validates transaction-group primary shape.
- [x] V10 semantic firewall rejects an unpaid Bill that still has an active non-refunded payment.
- [x] Restore of legacy local-only backups runs tombstone cleanup before integrity validation.
- [x] V11 firewall validates Budget/Bill/Recurring planning semantics.
- [x] V11 firewall validates exact composite group member/type/status semantics.
- [x] V12 restores the V9 legacy local-only repair helper used during portable restore.
- [x] V12 validates encrypted backup KDF/nonce/salt/tag metadata and payload format/schema metadata.
- [x] V12 firewall validates account/category/import-fingerprint/date/refund/recurring-occurrence semantics.
- [x] V12 firewall rejects stored money values outside the centralized integer-money safety envelope.
- [x] Restore failure remains atomic: invalid replacement data rolls back without replacing live data.
- [x] V13 portable restore migrates historical recurring/Bill representations before current semantic validation.
- [x] V13 backup serialization reads all exported tables from one committed SQLite snapshot and validates that same snapshot first.
- [x] Existing encrypted DB + missing secure-storage key fails closed before opening/modifying the DB file.
- [x] V14 Safe Recovery Mode provides retry + local-generation + portable-backup recovery paths behind app lock.
- [x] Fresh replacement quarantines DB/WAL/SHM and uses a persisted recovery state machine.
- [x] Local recovery generations are AES-GCM encrypted with a dedicated secure-storage key and capped at three by default.
- [x] Recovery generation candidates are verified before older generations are pruned.
- [x] Normal portable restore requires an exact pre-restore local recovery point; storage-full aborts before mutation.
- [x] Explicit local wipe purges recovery generations/quarantine/recovery key before resetting the main DB.

## Migration / audit status

- [x] Fresh schema **v9** audit PASS.
- [x] Legacy v3 migration semantics PASS.
- [x] v6 → v7 FTS migration PASS.
- [x] v7 → v8 Bill uniqueness migration PASS.
- [x] v8 → v9 local-only tombstone cleanup PASS.
- [x] Reference financial contract PASS.
- [x] Crash-before-COMMIT / SQLITE_FULL rollback reference PASS.
- [x] CSV import idempotency/conflict rollback PASS.
- [x] 100k timeline + FTS reference audits PASS.
- [x] V9 lifecycle/deletion/refund audit PASS.
- [x] V10 group-VOID/refund/backup semantic firewall audit PASS.
- [x] V11 atomic/planning/group semantic audit PASS.
- [x] V12 restore/money/date/helper/atomic audit PASS.
- [x] V13 catastrophe/recovery + historical portability audit PASS.
- [x] V14 data-survival/self-recovery + storage/interruption audit PASS.
- [x] V15 native-readiness/device-boundary source audit PASS.
- [x] V16 truthful-native-gate/first-build readiness source audit PASS.
- [x] V17 native-execution readiness source/fixture audit PASS.
- [x] V18 production UX/accessibility source audit PASS.
- [x] V18 Flutter accessibility guideline tests are retained for Android/iOS tap targets, labels, contrast, and large-text regression; execution awaits Flutter SDK.
- [x] V19 commit-success/refresh-failure separation prevents duplicate-inducing false failure feedback.
- [x] V19 Quick Add rapid-submit, accidental-close, repeated-close, and posted-edit/date workflow guards retained.
- [x] V19 background-resume work is queued when a write is active instead of being silently skipped.

- [x] V20 newest-request-wins search/full-refresh guards, serialized de-duplicated pagination, and unfiltered Home recent-state isolation retained.
- [x] V21 root MaterialApp/Navigator rebuild isolation retained while AppShell remains controller-reactive.
- [x] V22 query/filter/result presentation state commits atomically only after successful newest request.
- [x] V23 Android FLAG_SECURE + cross-platform inactive/background privacy shield retained.
- [x] V24 pre-native RC documentation/test/continuity freeze synchronized through V23 runtime behavior.
- [x] Android biometric runner/theme/platform-floor native fixture PASS.
- [x] Native compile gate requires dependency lock + analyze/test/build before compile PASS.
- [x] Store-release gate cannot silently skip iOS and requires explicit Android upload signing / signed iOS IPA path.
- [x] Android release-signing configure/verify fixture is idempotent and fails closed without credentials.
- [x] Real-order legacy v1→current startup migration PASS.
- [x] Interrupted migration/restore/default-seed SQLite rollback/retry fixtures PASS.
- [x] V1→V25 continuity audit PASS.
- [x] Dart structural audit rejects literal backslash patch artifacts outside strings/comments.
- [x] Compile-risk audit detects unresolved private helper calls in all production Dart files.

## V27 immutable Git bootstrap handoff

- [x] Canonical Git text normalization is explicit through `.gitattributes`.
- [x] Git bootstrap is created from a temporary copy, not by mutating the canonical source directory.
- [x] Signing/private files and cache/build/VCS residue are rejected before Git history creation.
- [x] Commit metadata is deterministic and the `main` branch plus `arus-v27-bootstrap` lightweight tag point to the same commit.
- [x] Git bundle, commit SHA, tree SHA, bundle SHA-256 and tracked-file SHA-256 manifest are verified through a fresh clone.
- [x] Git transport proof remains separate from Flutter/native/device/store proof.

## V26 release orchestration / immutable CI

- [x] External GitHub Actions workflow dependencies are pinned to audited full 40-character commit SHAs.
- [x] `tool/verify_ci_action_pins.py` rejects mutable tags, unapproved actions, wrong SHAs, and stale pin-manifest entries.
- [x] Native verification refuses to run without a committed `pubspec.lock`.
- [x] First dependency resolution is isolated in a manual review-only lock bootstrap workflow.
- [x] Android/iOS compare their checked-out lockfile byte-for-byte with verified lock evidence before compile.
- [x] Native verification uses `flutter pub get --enforce-lockfile` and does not silently re-resolve dependencies.
- [x] `tool/release_readiness_report.py` separates SOURCE, LOCK, COMPILE, DEVICE, and STORE truth states and rejects stale evidence.
- [x] `tool/release_orchestrator.sh` provides source/status/compile/store entry points without collapsing those truth states.
- [x] Dependabot may propose GitHub Actions pin updates, but every update must pass the immutable-pin audit again.
- [x] V1→V26 continuity audit includes the V26 contracts.

## V25 native CI / provenance hardening

- [x] Flutter 3.47.2 release git hash and bundled Dart 3.13.2 are pinned.
- [x] Official Flutter archive SHA-256 is verified before extraction.
- [x] Linux x64 Flutter 3.47.2 archive checksum has an independent local pin.
- [x] Active iOS deployment floor corrected to 15.0 for Flutter 3.47.2 support.
- [x] One resolved `pubspec.lock` artifact is shared by Android and iOS compile jobs.
- [x] Bootstrap enforces a supplied lockfile instead of re-resolving it.
- [x] Native compile workflow uses normal PR context, read-only repository permission, and no signing secrets.
- [x] Android/iOS compile evidence records canonical source + lockfile hashes for cross-platform comparison.
- [x] Offline installer/evidence fixtures prove fail-closed behavior without claiming a real native build.

## Still not claimed

- [ ] `flutter analyze` with a real Flutter SDK.
- [ ] `flutter test` with a real Flutter SDK.
- [ ] Android Gradle / APK / AAB build.
- [ ] iOS Xcode build.
- [ ] Physical-device security/performance validation.

The current execution environment does not contain Flutter/Dart native toolchains. V25 retains the V16/V17 truthful native gates: SOURCE PASS is not COMPILE PASS, DEVICE PASS, or STORE RELEASE PASS. Source/reference audits remain mandatory safeguards, but they are **not** substitutes for compiler, platform SDK, signing, and physical-device validation.
