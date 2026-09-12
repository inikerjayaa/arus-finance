# Arus Finance — Local-Only V8 Deep Mine (Rebased)

**Status:** non-native audit PASS  
**Canonical production direction:** device-owned, offline-first, no required login/server/cloud.

## Why “Rebased”
The last fully persisted source artifact available was V7. Changes described later in chat but not saved as an artifact were not treated as implemented. V8 is therefore rebuilt from the persisted V7 baseline and is the new canonical source milestone.

## V8 changes

- Schema bumped to V8.
- Added partial unique DB index ensuring one payment transaction cannot be linked to multiple Bills.
- V7→V8 migration repairs legacy duplicate Bill payment links before creating the unique index.
- `payBill()` re-checks Bill status and payment linkage inside the SQLite transaction.
- Bill payment cannot use a non-credit-card liability account.
- Refund date cannot precede the original expense date.
- Simple expense editing cannot move an expense into a loan/other non-credit-card liability.
- Legacy future-dated POSTED transactions no longer affect current account balance.
- Dashboard month-to-date income/category/spending calculations are inclusive through today and do not count future legacy records.
- Budget actual is capped at the current local date.
- Accounts/categories cannot be archived while referenced by legacy future POSTED transactions.
- Unpaid Bill state now heals in both directions when the device clock/date is corrected.
- Public simple create API only accepts POSTED or DRAFT status; unsupported direct status injection is rejected.

## Audit hardening

The audit suite now checks for:

- atomic `payBill()` re-check;
- dashboard today-inclusive income logic;
- future-POSTED archive dependency guard;
- Bill backward-clock healing;
- refund chronology guard;
- executable V7→V8 Bill-payment uniqueness migration semantics.

## Verified non-native audits

- financial reference contract — PASS
- local-only source contract — PASS
- Dart structural source audit — PASS
- Dart delimiter/string/comment audit — PASS
- SQLite crash / SQLITE_FULL atomicity — PASS
- fresh schema V8 — PASS
- legacy V3 migration semantics — PASS
- V6→V7 FTS migration — PASS
- V7→V8 Bill uniqueness migration — PASS
- CSV import idempotency / conflict rollback — PASS
- 5,000-row import reference stress — PASS
- differential local notification audit — PASS
- 100k timeline / FTS reference audit — PASS
- native-hardening fixture idempotence — PASS

## Not yet proven

- `flutter analyze`
- `flutter test`
- Android Gradle build / APK / AAB
- Xcode/iOS build
- physical-device testing

Those remain explicitly unverified until a real Flutter/native toolchain is available.
