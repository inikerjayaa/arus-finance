# Arus Finance — Local-Only V7 Gold Harvest Report

Date: 2026-09-09

## Product principle

Financial data remains device-owned. No login, cloud database, or developer-hosted server is required for core finance behavior.

## V7 additions / fixes

- Differential local-notification scheduler with stable per-reminder IDs.
- Only changed/new reminders are scheduled; stale Arus reminders are cancelled individually.
- Legacy V6 notification IDs are cleaned once without using global cancel-all behavior.
- Notification scheduling state persists hashes only, not raw bill/recurring finance text.
- CSV preview checks already-known import fingerprints in batched queries.
- 5,000-row import preflight uses bounded SQLite bind batches instead of thousands of one-row duplicate lookups.
- Source transaction-ID conflict checks are fetched in bounded batches before the atomic write transaction.
- Temporary plaintext CSV export is deleted after the platform share flow completes.
- Temporary encrypted backup working file is also deleted after sharing.
- Future-dated POSTED transactions are blocked until a complete scheduled-transaction lifecycle exists.
- Quick Add date picker no longer offers future transaction dates.
- SQLite FTS5 local full-text search indexes note, type, amount, account, and category.
- Schema upgraded to v7 with executable v6 → v7 FTS migration coverage.
- FTS5 search index is derived data: startup verifies coverage/integrity and can rebuild it from canonical transactions/legs/splits.
- Core SQLite `secure_delete` enabled.
- FTS5 `secure-delete` enabled.
- Destructive local wipe performs WAL truncate + VACUUM before default seed data is recreated.

## Executable non-native audits

All PASS:

- Financial reference contract.
- Local-only source contract.
- Dart import/structure audit.
- Dart delimiter/string/comment audit.
- Crash-before-COMMIT and SQLITE_FULL rollback reference.
- Fresh schema v7.
- Legacy v3 migration semantics.
- v6 → v7 FTS migration semantics.
- CSV idempotency and conflict rollback.
- 5,000-row import reference scale.
- Differential notification privacy/native source contract.
- 100k timeline index reference.
- 100k FTS5 search reference.
- Native-hardening fixture idempotence.

Reference environment search result during final V7 audit:

- 100k timeline: ~0.36 ms
- 100k FTS5 search: ~1.89 ms

These are regression-reference measurements in the audit environment, not device performance guarantees.

## Still not claimed

The environment used to produce this milestone does not provide a full Flutter/Android/iOS native toolchain, therefore V7 does **not** claim:

- `flutter analyze` PASS,
- `flutter test` PASS,
- Android Gradle/APK/AAB build PASS,
- iOS Xcode build PASS,
- physical-device security/performance validation.

Those remain mandatory before production release.
