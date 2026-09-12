# Arus Finance — Version Continuity V1 → V12

**Date:** 2026-09-11  
**Canonical source milestone:** V12 Deep Mine — Restore & Integer Boundary Hardening

## Continuity model

Arus does not maintain twelve independent application branches.

- **V1/V2** = product, financial-domain and implementation blueprint baseline.
- **V3** = normative local-only/device-owned architecture pivot.
- **V4–V12** = forward hardening milestones on one canonical source tree.

Therefore “no version is missed” means every still-applicable contract is represented in current source, migration logic, tests/audits, or an explicit superseding decision.

## Continuity matrix

| Generation | Contract carried forward into V12 | Verification |
|---|---|---|
| V1/V2 | Integer-money ledger; Expense/Income/Transfer/Refund; card/loan/reconciliation; invariant tests; Master Blueprint | PASS |
| V3 | Core without login/server/cloud; encrypted device-owned SQLite; user-owned encrypted backup | PASS |
| V4 | Recurring identity/migration; DRAFT leg backfill; active-name/IDR safeguards | PASS |
| V5 | WAL + synchronous FULL; explicit VOID; integrity checks | PASS |
| V6 | CSV import/idempotency; private local notifications; recurring DRAFT; timeline indexing | PASS |
| V7 | FTS5; secure-delete; bounded import; future POSTED guard; differential reminders | PASS |
| V8 | Unique Bill payment; atomic Bill recheck; refund chronology; future-record reporting guard | PASS |
| V9 | Local hard-delete; Bill/refund reconciliation; clock healing; 64 MiB backup cap; tombstone cleanup | PASS |
| V10 | Composite VOID refund guard; refund destination invariant; transaction semantic restore firewall | PASS |
| V11 | Atomic refund/edit/loan rechecks; recurring target invariant; Bill state safety; planning/group restore semantics; syntax artifact guard | PASS |
| V12 | Restore-helper compile fix; backup envelope/payload validation; money envelope; account/category/date/refund/recurring-occurrence firewall; private-helper compile-risk gate | PASS |

## Traceable corrections discovered by reverse audit

### V11 correction of V10 test source

V11 found and corrected literal `\\n` patch text and an invalid test-scope reference in `finance_invariants_test.dart`. The structural audit was hardened so that class of patch artifact fails thereafter.

### V12 correction of V11 backup source

V12 found that `restorePortableBackup()` called `_repairLegacyLocalOnlyState(db)` without a definition. That is a real source-level compile blocker even though the previous reference audits passed. V12 restores the helper according to the V9 local-only migration contract and adds a private-helper resolution audit to prevent recurrence.

These findings are preserved because continuity means traceable correction, not retroactive claims that an older package was perfect.

## Executable continuity gate

Run:

```bash
python3 tool/version_continuity_audit.py
```

Current result: **PASS — 47/47 carry-forward checks.** The executable audit is also run from `tool/run_all_audits.sh`.

## Validation boundary

A green continuity audit proves protected source contracts are still present. It does not prove native compilation or device behavior. Still mandatory:

- `flutter analyze`;
- `flutter test`;
- Android Gradle/APK/AAB build;
- iOS Xcode build;
- signing/store validation;
- physical-device encryption, biometrics, notification, crash/power-loss and performance validation.
