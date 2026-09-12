# Arus Finance — Local-Only V13 Deep Mine Report

**Milestone:** V13 Deep Mine — Catastrophe Recovery & Historical Portability Hardening  
**Schema:** remains v9 (no schema change)  
**Date:** 2026-09-11

## Session goal

Continue from the canonical V12 source without reopening product design. V13 targets failure modes that can remain invisible during normal feature testing: historical database startup order, process death before COMMIT, restore interruption, lost encryption-key metadata, inconsistent backup snapshots, partial first-run seed, and portable backups produced by older Arus schemas.

The V13 acceptance rule is stricter than a normal happy-path regression: a failure must either be atomic/retryable or fail closed without silently replacing, partially migrating, or fabricating financial data.

## Critical historical startup miss found and corrected

V13 reproduced a real old-schema startup failure.

The previous startup sequence ensured every current `kSchemaStatements` object before running versioned migrations. A legitimate V1 database does not yet contain `bills.paid_transaction_id`; that column is introduced by migration v2. The current unique Bill-payment index references that column.

Therefore a true V1 database could fail during startup with:

```text
no such column: paid_transaction_id
```

before migration v2 had a chance to add it.

### V13 correction

Existing databases now use this order:

```text
read exact schema_version
→ run each historical migration atomically
→ reach current schema version
→ ensure current idempotent tables/indexes/triggers atomically
→ verify/rebuild derived FTS index
```

Fresh databases still create the current schema directly in one transaction.

`tool/reference_schema_migration_audit.py` now includes a real-order V1→current fixture so this regression can no longer be hidden by an audit that pre-builds a newer schema than the application would actually have seen.

## Migration crash/retry safety

Every version migration remains wrapped by `BEGIN IMMEDIATE` / `COMMIT`, with `ROLLBACK` on failure.

The V13 executable recovery audit starts from a v7-style Bill state, begins the v8 cleanup/index/version update, then terminates the worker process before COMMIT. Reopening the file proves all three effects rolled back together:

- schema metadata remains v7;
- duplicate historical Bill payment links remain untouched;
- the new unique index is absent.

Running the migration again then succeeds. This proves the reference failure is retryable rather than half-applied.

## Historical V3 recurring migration hardening

A deeper reverse audit found another historical edge case. V3 occurrence identity included rule version. If a recurring rule changed after a draft was materialized, two occurrence rows for the same rule/calendar date could exist with different old keys.

The old v4 migration directly normalized both keys to:

```text
rule_id:yyyy-mm-dd
```

which could collide with the UNIQUE occurrence-key constraint and abort migration.

V13 changes migration v4 to:

1. retain one de-duplication marker per rule + calendar date;
2. remove only duplicate occurrence-marker rows;
3. keep any extra DRAFT transaction itself rather than silently deleting financial/user history;
4. normalize the surviving occurrence key;
5. backfill the missing intended account leg for the surviving legacy recurring draft.

The legacy v3 executable fixture now contains the duplicate-version-key condition and must migrate successfully.

## Strict schema metadata — fail closed

For an existing database, V13 no longer guesses that missing or malformed `app_meta.schema_version` means an old known schema.

Startup requires exactly one valid integer schema-version row. Missing, duplicate/ambiguous, malformed, or impossible metadata stops startup and directs recovery through a valid backup path.

This prevents destructive migrations from being run against an unknown database layout.

## Lost encryption key — fail closed before opening the DB file

For a non-empty existing database, V13 resolves the secure-storage encryption key before `sqlite3.open(path)` is allowed to create or modify the DB file.

If the database exists but its stored key is unavailable, startup fails with an explicit recovery error. A new key is generated only for a genuinely new database.

Any startup failure after a native DB handle has been opened disposes that handle before rethrowing, preventing a failed migration/key/schema path from leaking a locked database connection.

This is source-level/native-contract hardening; physical-device keychain/keystore-loss behavior still requires device testing.

## Stronger local integrity preflight

`assertQuickIntegrity()` now requires both:

- SQLite `PRAGMA quick_check` success; and
- zero rows from `PRAGMA foreign_key_check`.

The derived FTS index integrity/coverage check remains active.

Portable backup creation therefore refuses known structurally broken references rather than preserving them into a fresh official backup.

## One committed snapshot per backup

V13 adds `AppDatabase.readSnapshot()` using a read transaction.

All tables exported into one `.arusbackup` payload are now read inside that same snapshot, and `_validateLedger(db)` runs against the same view before serialization.

The V13 SQLite fixture uses concurrent reader/writer connections to prove the reader remains pinned to one committed snapshot even after another connection commits newer rows. A backup can therefore no longer mix an account state from one commit with transaction/planning rows from a later commit.

## Restore interruption remains atomic

The executable V13 fixture starts destructive replacement inside `BEGIN IMMEDIATE`, deletes the live dataset, inserts replacement rows, and kills the worker before COMMIT.

After reopening:

- the old live account remains;
- the old live transaction remains;
- the partial replacement rows are absent;
- foreign-key integrity is clean.

This extends V12 rollback validation from semantic validation failure to abrupt process termination before SQLite COMMIT.

## First-run/reset category seed is now crash-safe

V13 found that default categories were previously inserted one transaction at a time after checking `categoryCount == 0`.

A process death after the first successful insert could leave a permanently incomplete default set, because the next boot would see a non-zero category count and skip the remaining defaults. That could later remove required operational categories such as transfer-fee or loan-interest categories.

The initial/reset default-category seed is now one atomic database transaction. The crash fixture proves an interrupted seed leaves zero rows; a full retry then creates the complete set.

The application intentionally does **not** recreate default categories on every startup, so user customizations/archives are not silently undone.

## Historical portable-backup migration

V12 validated current backup semantics but V13 found that accepting an older `schema_version` is not sufficient by itself. Older portable backups can contain data forms that were valid in their own schema but violate current constraints.

V13 adds `_repairLegacyPortableBackupState(db, schemaVersion)` before current semantic validation.

### Pre-v4 portable backups

- duplicate recurring occurrence markers are de-duplicated by rule + scheduled date;
- occurrence keys are normalized to the current deterministic rule/date identity;
- legacy recurring DRAFT transactions that lack their intended account leg receive the same backfill defined by the historical live migration.

Detached occurrence history remains valid de-duplication history; V13 does not invent a new draft merely because a link is absent.

### Pre-v5 portable backups

Recurring `next_run` timestamps are normalized to the current floating local `YYYY-MM-DD` date representation.

### Pre-v8 portable backups

Older backups may contain more than one Bill linked to the same payment because the current unique Bill-payment constraint did not yet exist. Before insertion under current constraints, V13 keeps one canonical payment link and turns later duplicates into unpaid/upcoming Bill state rather than failing the entire legitimate historical restore.

After historical normalization, the existing V9 local-only tombstone repair and current semantic firewall still run before COMMIT.

## Historical-source cross-check

The V13 reverse audit checked the archived Arus Stage-2/V2 and V3 source packages, not only current migration comments. Those historical sources corroborate the compatibility assumptions used by the new fixtures:

- v2 introduced the Bill payment-link column;
- v3 used schema version 3 and the older recurring/backup representation;
- the portable backup format already carried schema metadata and the affected tables.

This does not turn every historical package into a production-certified build; it gives V13 migration fixtures a concrete historical basis instead of invented layouts.

## New executable gate

### `tool/deep_mine_v13_recovery_audit.py`

The V13 audit combines source-contract checks with crash/recovery SQLite fixtures. It covers:

- migration-before-current-object startup ordering;
- strict schema metadata;
- lost-key fail-closed ordering;
- failed-open DB handle disposal;
- quick integrity + foreign-key integrity;
- one-snapshot backup reads + semantic preflight;
- historical portable-backup data normalization;
- interrupted migration rollback/retry;
- interrupted restore rollback;
- concurrent snapshot consistency;
- interrupted default-seed rollback/retry;
- old recurring/Bill normalization under current constraints.

The audit is mandatory from `tool/run_all_audits.sh`.

## Continuity gate

`tool/version_continuity_audit.py` is extended through V13. A future package is not accepted if V13 recovery/historical-portability guards disappear while earlier V1–V12 contracts remain green.

## Still not claimed

The current environment still does not provide the complete Flutter/Dart/Android/iOS native toolchain. V13 therefore does **not** claim:

- `flutter analyze` PASS;
- `flutter test` PASS;
- Android Gradle/APK/AAB build PASS;
- iOS Xcode build PASS;
- signing/store validation PASS;
- real encrypted-file recovery after OS key-store loss;
- physical-device forced-kill/power-loss/WAL behavior;
- physical-device notification, biometrics, filesystem and performance validation.

Those remain mandatory release gates. V13 materially reduces known pre-native recovery risk; it does not replace native validation.
