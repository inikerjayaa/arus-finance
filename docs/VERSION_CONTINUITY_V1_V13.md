# Arus Finance — Version Continuity V1 → V13

**Date:** 2026-09-11  
**Canonical source milestone:** V13 Deep Mine — Catastrophe Recovery & Historical Portability Hardening

## Continuity model

Arus does not maintain thirteen independent application branches.

- **V1/V2** = product, financial-domain and implementation baseline.
- **V3** = normative local-only/device-owned architecture pivot.
- **V4–V13** = forward hardening milestones on one canonical source tree.

“No version is missed” means every still-applicable contract is carried by current source, migrations, tests/audits, or an explicit superseding decision. Older packages are historical evidence, not parallel production branches.

## Continuity matrix

| Generation | Contract carried forward into V13 | Verification |
|---|---|---|
| V1/V2 | Integer-money ledger; Expense/Income/Transfer/Refund; card/loan/reconciliation; invariant tests; Master Blueprint | PASS |
| V3 | Core without login/server/cloud; encrypted device-owned SQLite; user-owned encrypted backup | PASS |
| V4 | Recurring identity/migration; legacy DRAFT leg backfill; active-name/IDR safeguards | PASS |
| V5 | WAL + synchronous FULL; explicit VOID; integrity checks | PASS |
| V6 | CSV import/idempotency; private local notifications; recurring DRAFT; timeline indexing | PASS |
| V7 | FTS5; secure-delete; bounded import; future POSTED guard; differential reminders | PASS |
| V8 | Unique Bill payment; atomic Bill recheck; refund chronology; future-record reporting guard | PASS |
| V9 | Local hard-delete; Bill/refund reconciliation; clock healing; 64 MiB backup cap; tombstone cleanup | PASS |
| V10 | Composite VOID refund guard; refund destination invariant; transaction semantic restore firewall | PASS |
| V11 | Atomic refund/edit/loan rechecks; recurring target invariant; Bill state safety; planning/group restore semantics; syntax artifact guard | PASS |
| V12 | Restore-helper compile fix; authenticated backup envelope; money envelope; account/category/date/refund/occurrence firewall; private-helper compile-risk gate | PASS |
| V13 | True old-schema startup order; migration/restore/seed crash atomicity; strict schema metadata; lost-key fail-closed; consistent backup snapshots; historical portable-backup migration | PASS |

## Traceable corrections discovered by reverse audit

### V11 correction of V10 test source

V11 found and corrected literal `\\n` patch text plus invalid test-scope code in `finance_invariants_test.dart`. Structural auditing was expanded so this class of patch artifact fails thereafter.

### V12 correction of V11 backup source

V12 found that portable restore called `_repairLegacyLocalOnlyState(db)` without a definition. The helper was restored according to the V9 local-only repair contract, and unresolved private-helper detection became a permanent non-native gate.

### V13 correction of historical migration/startup assumptions

V13 reproduced three compatibility/recovery gaps instead of retroactively calling old milestones perfect:

1. A true V1 database could hit the current Bill index before migration v2 added `paid_transaction_id`.
2. A V3 database with two versioned occurrence markers for one rule/date could collide while migration v4 normalized both keys.
3. Portable backups from older schemas required data normalization before insertion/validation under current constraints; merely accepting an older schema number was insufficient.

V13 fixes all three and adds executable crash/recovery fixtures. Historical V2/V3 source packages were inspected to corroborate the old layouts used by these compatibility tests.

## Executable continuity gate

Run:

```bash
python3 tool/version_continuity_audit.py
```

Current result: **PASS — 61/61 carry-forward checks.** The executable audit is also required by `tool/run_all_audits.sh`.

## Validation boundary

A green continuity/recovery audit proves protected source and SQLite reference contracts remain present. It does not prove native compilation or actual device power-loss behavior. Still mandatory:

- `flutter analyze`;
- `flutter test`;
- Android Gradle/APK/AAB build;
- iOS Xcode build;
- signing/store validation;
- physical-device encrypted DB/key-store recovery, forced-kill/power-loss, notifications, biometrics and performance validation.
