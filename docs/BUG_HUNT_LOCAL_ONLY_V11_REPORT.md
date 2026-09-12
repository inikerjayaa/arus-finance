# Arus Finance — Local-Only V11 Deep Mine Report

**Milestone:** V11 Deep Mine — Atomic Planning Integrity  
**Schema:** remains v9 (no schema change)  
**Date:** 2026-09-11

## Session goal

Verify that the canonical V10 source still carries the important V1→V10 contracts, then continue hardening the local-only financial core. V11 focuses on stale-state/atomic rechecks, planning-domain invariants, stricter backup group semantics, and pre-native compile-risk hygiene.

## Continuity result

A new executable `tool/version_continuity_audit.py` verifies 38 carry-forward contracts spanning:

- V1/V2 finance/domain baseline and invariant test presence;
- V3 local-only/device-owned architecture;
- V4 recurring/migration/IDR safeguards;
- V5 WAL/FULL durability, VOID and integrity checks;
- V6 CSV import, private local notifications, recurring DRAFT safety and timeline indexing;
- V7 FTS5, secure-delete, future-POSTED guard and bounded import lookups;
- V8 Bill payment uniqueness, atomic Bill recheck, refund chronology and future-record exclusion;
- V9 hard-delete, Bill/refund reconciliation, clock healing, backup cap and tombstone migration;
- V10 composite VOID/refund/semantic firewall;
- V11 atomic/planning/group additions.

Result: **PASS — 38/38 carry-forward checks.**

Important interpretation: V1/V2 are specification/baseline generations, V3 locks the local-only architecture, and V4 onward are source hardening milestones. The current source is one forward-moving canonical implementation, not ten independent apps.

## Miss found during reverse verification

The deeper continuity review found a real stale patch artifact in `test/finance_invariants_test.dart`: literal `\\n` text had been inserted outside a Dart string near the end of the file. That would be a compile-risk once `flutter test` is run. The malformed tail also referenced a `bank` variable that was not declared in that test scope.

### V11 fix

- Replaced the malformed tail with valid Dart tests.
- Added explicit local account setup to the refund chronology test.
- Removed the redundant malformed future-date test because a valid future-POSTED guard test already exists immediately above it.
- Renamed the old test description from “using tombstone” to the current local-only hard-delete terminology.
- Hardened `tool/dart_delimiter_audit.py` so any backslash occurring in Dart code state (outside strings/comments) fails the audit. This specifically prevents escaped-newline patch artifacts from silently passing again.

This is why V11 does **not** retroactively claim that V10 was native-compile clean; it claims the issue is now corrected at source level and guarded by the non-native audit suite.

## Financial/domain hardening

### 1. Refund stale-state / over-refund recheck is now inside the write transaction

V10 performed a good preflight check before entering the SQLite transaction, but the canonical state was not re-read inside the write transaction.

V11 rechecks inside the same atomic transaction:

- original still exists;
- original is still POSTED EXPENSE;
- cumulative active refund total;
- original amount;
- original split/category;
- refund currency compatibility.

This makes the write contract robust against stale preflight state and guarantees the final over-refund decision is made at the mutation boundary.

### 2. Simple transaction edit rechecks active refunds inside the transaction

Before replacing legs/splits, V11 rechecks that:

- the transaction still exists;
- it is still a simple Expense/Income, not a group member;
- the new amount is not below the current active refund total.

### 3. Loan principal outstanding is rechecked inside the write transaction

The repository still performs the user-friendly preflight check, but V11 also recomputes the loan outstanding inside the transaction immediately before the LOAN_PAYMENT group is inserted. This closes stale-state risk between validation and mutation.

### 4. Recurring expense account semantics are now repository-level invariants

A recurring expense may use only:

- an active ASSET account; or
- an active CREDIT_CARD liability.

Loan/other liabilities are rejected by:

- recurring rule creation;
- recurring reactivation;
- recurring materialization before a DRAFT is generated.

This aligns recurring behavior with normal Expense semantics instead of relying on UI filtering.

### 5. Manual Bill status mutation is restricted

`markBillStatus()` is now a narrow manual **SKIPPED** operation only. UPCOMING/DUE/OVERDUE come from due-date derivation, and PAID comes from `payBill()`.

A Bill with an active payment cannot be manually skipped. This prevents the repository from creating a state that its own restore semantic firewall would later reject.

## Backup semantic firewall V11

Restore validation now additionally rejects:

### Budget corruption
- blank Budget name;
- non-positive limit;
- non-IDR Budget;
- end date before start date;
- Budget category that is not EXPENSE.

### Bill corruption
- blank Bill name;
- non-positive expected amount;
- non-IDR Bill;
- malformed basic due-date field length.

### Recurring-rule corruption
- blank name;
- non-positive amount;
- invalid active flag;
- account/category missing;
- rule/account currency mismatch;
- non-EXPENSE category;
- recurring target account that is neither ASSET nor CREDIT_CARD liability;
- active rule pointing to archived account/category;
- malformed basic `next_run` field length.

### Composite group corruption
- TRANSFER_WITH_FEE must contain exactly one primary TRANSFER plus one child EXPENSE;
- LOAN_PAYMENT must contain one primary LOAN_PAYMENT and only EXPENSE children, with 1–3 total members;
- group members must share the primary transaction status;
- standalone transactions may not carry `group_primary=0`;
- LOAN_PAYMENT may not exist outside a LOAN_PAYMENT group;
- non-primary group members must be EXPENSE transactions.

## New executable audits

### `tool/deep_mine_v11_source_audit.py`

Verifies the V11 repository guards and executes the actual V11 backup SQL against an in-memory SQLite fixture. It proves a canonical fixture passes, then injects representative corruptions for Budget, Bill, Recurring and composite transaction groups and proves each corruption is detected.

### `tool/version_continuity_audit.py`

Checks 37 major carry-forward contracts from V1/V2 through V11 so future releases can detect accidental feature/rule loss.

## Native regression tests prepared

`test/finance_invariants_test.dart` now also contains source-level test cases for:

- refund cannot predate original;
- recurring expense cannot target a loan liability;
- inactive recurring cannot reactivate after its account is archived;
- a PAID Bill cannot be manually changed to SKIPPED.

These tests are prepared for the real Flutter SDK gate; they are not claimed executed here.

## Audit result

After all V11 changes, the entire non-native audit suite is rerun from the project root. Required result:

- all legacy financial/reference audits PASS;
- all schema migration audits PASS;
- V9 PASS;
- V10 PASS;
- V11 PASS;
- V1→V11 continuity PASS;
- Dart delimiter/source audits PASS;
- native-hardening fixture PASS.

## Still not claimed

This environment still has no Flutter/Dart/Android/iOS native toolchain. Therefore V11 still does **not** claim:

- `flutter analyze` PASS;
- `flutter test` PASS;
- Android Gradle/APK/AAB PASS;
- iOS Xcode build PASS;
- store signing PASS;
- physical-device encryption/biometric/notification/performance PASS.

Those remain mandatory before calling the application production-ready.
