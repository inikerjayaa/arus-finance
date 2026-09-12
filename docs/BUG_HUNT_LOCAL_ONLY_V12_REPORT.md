# Arus Finance — Local-Only V12 Deep Mine Report

**Milestone:** V12 Deep Mine — Restore & Integer Boundary Hardening  
**Schema:** remains v9 (no schema change)  
**Date:** 2026-09-11

## Session goal

Continue from the canonical V11 source without restarting product design. V12 targets risks that can remain invisible in normal UI testing: missing compile-critical helpers, hostile/corrupt backup payloads, invalid calendar values, integer-money boundaries, restore rollback, and carry-forward regression from V1 through the current milestone.

## Critical miss found and corrected

V12 found a definite source-level compile blocker in V11: `BackupService.restorePortableBackup()` called `_repairLegacyLocalOnlyState(db)`, but the helper was absent from `backup_service.dart`.

This is recorded explicitly rather than hidden. The previous non-native audits were not a Dart compiler and did not detect this unresolved private call.

### V12 correction

`_repairLegacyLocalOnlyState()` is restored and runs inside the same restore transaction. It performs the V9 local-only repair contract before semantic validation:

- detach Bill payment links that reference tombstoned transactions and re-derive them as unpaid;
- detach recurring occurrence links that reference tombstoned transactions while retaining the occurrence as de-duplication history;
- convert refunds whose original is tombstoned into non-posted/VOID history with the dangling original link removed;
- physically delete legacy tombstones;
- prune empty transaction groups.

`tool/compile_risk_audit.py` now checks unresolved lower-case private helper calls in all production Dart files, while excluding declared callable fields. A future missing private helper therefore fails the non-native gate instead of silently surviving to native compilation.

## Integer-money boundary hardening

A conservative application-level envelope is now centralized in `lib/domain/money_limits.dart`:

```text
kMaxMoneyMinor = 9,000,000,000,000
```

This is a technical SQLite safety boundary, not a product promise or financial limit target. SQLite `INTEGER` is signed 64-bit; the envelope creates substantial headroom for aggregate operations while preserving exact integer arithmetic.

Repository mutation paths now reject values outside the envelope before SQLite writes, including:

- transaction primary amount;
- ledger deltas;
- splits;
- account opening balance input;
- transfer fee;
- loan interest/fee;
- reconciliation observed balance.

The IDR parser and CSV import preview enforce the same upper bound so oversized values are rejected before reaching the repository/database layer.

Important limitation: a per-value envelope materially reduces aggregate-overflow risk but is not a mathematical proof that an arbitrarily large database can never overflow a SQLite `SUM()`. Production performance/data-volume limits still require native/device stress validation.

## Backup envelope and payload hardening

Portable restore now validates the encrypted envelope before decrypt/replace:

- expected backup format/version;
- `ARGON2ID` KDF identifier;
- exact expected memory/iteration/parallelism metadata for the current format;
- 16-byte salt;
- 12-byte nonce;
- 16-byte authentication tag;
- non-empty ciphertext.

After decryption, payload metadata must also match the official Arus backup format/version and may not claim a schema newer than the running application.

The existing 64 MiB input cap remains active.

## Semantic restore firewall V12

V12 extends restore validation beyond foreign keys and transaction shape.

### Account semantics

Rejects, among other cases:

- blank account names;
- non-IDR core accounts;
- invalid boolean flags;
- impossible account-class/account-type combinations.

### Category semantics

Rejects:

- blank category names;
- self-parenting categories;
- missing parent categories;
- parent/child type mismatch.

### Import fingerprint semantics

Persisted CSV fingerprints must have the canonical 64-character lowercase hexadecimal representation.

### Money range semantics

Transactions, legs, splits, Budgets, Bills and Recurring rules must remain within the V12 integer-money envelope and preserve the existing positive/non-zero contracts.

### Date semantics

V12 validates parseability/canonical calendar form for stored transaction, planning, archive and import dates rather than trusting string length alone. Calendar-impossible values such as `2026-02-31` are rejected before live data replacement.

### Refund semantics

A POSTED refund must preserve:

- valid original linkage;
- chronology at or after the original transaction date;
- currency equality;
- the original Expense category.

Legacy repaired VOID refunds may intentionally have `original_transaction_id = NULL`; the validator distinguishes this from a POSTED refund so legitimate local-only migration history is not falsely rejected.

### Recurring occurrence semantics

The occurrence key must remain deterministic from rule + scheduled date. For linked AUTO occurrences, the linked transaction must be the exact DRAFT Expense implied by the rule: amount, currency, account sign, category and uniqueness must match.

A deliberately detached AUTO occurrence (`transaction_id = NULL`) remains valid. This is required because deleting a generated draft intentionally preserves occurrence history to prevent accidental re-generation of the same scheduled occurrence.

## Atomic restore reference

The V12 executable audit simulates a destructive restore attempt inside SQLite transaction scope, injects invalid semantic data after deleting the live rows, forces validation failure, and verifies rollback restores the original live data while the bad replacement row is absent.

This is a non-native reference proof of transaction semantics, not a substitute for device-level filesystem/crash testing.

## New/expanded executable gates

### `tool/deep_mine_v12_source_audit.py`

Checks the actual V12 source contracts and executes extracted semantic SQL against in-memory SQLite fixtures. It verifies a canonical fixture passes, then proves detection of representative corruptions including:

- impossible account type/class;
- blank category;
- malformed import fingerprint;
- over-envelope money;
- invalid calendar date;
- refund chronology/category mismatch;
- recurring occurrence mismatch;
- legacy V9 local-only repair behavior;
- restore rollback preservation.

### `tool/compile_risk_audit.py`

Now includes private-helper resolution checks for all production Dart files in addition to existing duplicate/declaration checks.

### `tool/version_continuity_audit.py`

Extended through V12 with 47 carry-forward checks so future releases fail if these fixes disappear.

## Native tests prepared

`test/finance_invariants_test.dart` includes a money-envelope regression test covering oversized Expense, Bill and reconciliation inputs. These tests are prepared for the real Flutter SDK gate; they are not claimed executed in this environment.

## Final audit requirement

V12 is accepted only after `tool/run_all_audits.sh` passes from the canonical source with:

- all historical reference/migration/import/search/notification audits;
- V9, V10, V11 and V12 deep-mine audits;
- V1→V12 continuity gate;
- source/compile-risk gates;
- native-hardening fixture.

## Still not claimed

This environment still does not contain the real Flutter/Dart/Android/iOS toolchain. V12 therefore does **not** claim:

- `flutter analyze` PASS;
- `flutter test` PASS;
- Android Gradle/APK/AAB build PASS;
- iOS Xcode build PASS;
- signing/store validation PASS;
- physical-device encryption, biometrics, notification, crash/power-loss or performance validation PASS.

Those gates remain mandatory before production release.
