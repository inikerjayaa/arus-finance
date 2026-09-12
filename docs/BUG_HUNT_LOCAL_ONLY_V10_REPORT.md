# Arus Finance — Local-Only V10 Deep Mine Report

**Milestone:** V10 Deep Mine — Semantic Firewall
**Schema:** remains v9 (no schema change)
**Date:** 2026-09-11

## Session goal

Continue directly from V9 and deepen financial correctness without adding cosmetic or online features. V10 focuses on composite VOID safety, refund domain enforcement, restore-time semantic validation, and source hygiene ahead of eventual native Flutter validation.

## Bugs / risks closed

### 1. Composite VOID + child refund integrity
V9 checked active refunds only for the transaction ID selected by the caller before voiding a whole transaction group. A composite group could therefore contain another child transaction with an active POSTED refund. Voiding the group would make that refund point to a non-POSTED original.

**V10 fix:** every member of the group is checked inside the same atomic database transaction before any member is VOIDed. Any active refund blocks the entire group operation.

### 2. Refund destination was UI-safe but repository-permissive
The UI already offered only assets and credit cards as refund destinations, but the repository itself accepted any active account with matching currency. A direct/internal caller could therefore send a refund into a loan or other liability and distort liability principal.

**V10 fix:** repository-level invariant now allows only:
- asset accounts; or
- CREDIT_CARD liability accounts.

### 3. Backup restore semantic firewall was not strict enough
V9 validated foreign keys, currencies, refund totals, Bill links, enums and split totals, but a structurally valid database could still encode financially impossible leg/category shapes.

**V10 fix:** restore validation now also rejects:
- malformed Expense/Income/Refund leg/split counts;
- wrong category type or wrong signed account effect for Expense/Income/Refund;
- categorized Transfer/Adjustment/Opening/CC/Loan records;
- invalid leg counts for non-categorized transaction types;
- invalid asset/liability signs for Transfer, credit-card payment, loan draw/payment;
- invalid original-transaction links;
- malformed transaction groups (unknown type, zero members, multiple/no primary);
- unpaid Bills that still point at an active payment that has not been fully refunded;
- split currency mismatches.

### 4. Planning object data quality
Repository now rejects blank names for Budget, Bill, and Recurring rules. New Bill status is derived immediately from due date rather than being inserted as UPCOMING unconditionally and waiting for a later list refresh to heal it.

### 5. Pre-native analyzer hygiene
Removed obvious unused locals found by source review (`oldVersion`, dashboard `end/endIso`, recurring `version`, unused Categories theme variable). This does not claim analyzer PASS; it reduces avoidable analyzer noise before the real SDK run.

## Executable audit added

`tool/deep_mine_v10_source_audit.py` now:
- verifies the new repository guards exist;
- extracts the actual V10 semantic SQL from `backup_service.dart`;
- runs it against a canonical in-memory SQLite fixture;
- proves valid canonical data passes;
- injects representative corruptions and proves each firewall detects them.

## Audit result

All non-native audits PASS, including V10.

## Still not claimed

This environment does not contain Flutter/Dart native toolchains. The project still does **not** claim:
- `flutter analyze` PASS;
- `flutter test` PASS;
- Android Gradle/APK/AAB PASS;
- iOS Xcode PASS;
- store signing PASS;
- physical-device security/performance PASS.

These remain the next production gate once the project is executed on a machine with the required SDKs.
