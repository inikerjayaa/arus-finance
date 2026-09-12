# Arus Finance — Version Continuity V1 → V15

**Date:** 2026-09-11  
**Purpose:** ensure the canonical source remains one forward-moving implementation. A newer milestone may harden or refactor earlier work, but must not silently drop financial/domain/privacy/recovery contracts from earlier versions.

## Milestone chain

- **V1/V2:** product/domain baseline, integer ledger, core financial semantics, production acceptance rules.
- **V3:** local-only/device-owned pivot; no required login/cloud/server for core finance.
- **V4:** recurring identity/data integrity and archive correctness.
- **V5:** WAL/durability, explicit VOID, security hardening.
- **V6:** CSV import, private local notifications, recurring DRAFT behavior, large-history indexing.
- **V7:** differential notifications, FTS5, secure-delete, bounded import, future-POSTED guard.
- **V8:** Bill-payment uniqueness and time-correct reporting guardrails.
- **V9:** local-only lifecycle cleanup, hard-delete, refund/Bill reconciliation, clock healing.
- **V10:** transaction semantic firewall + composite VOID integrity.
- **V11:** atomic latest-state rechecks + planning/group integrity.
- **V12:** restore semantic/integer/date/compiler-risk hardening.
- **V13:** true historical startup/portable migration + catastrophe rollback fixtures.
- **V14:** data-survival/self-recovery state machine, encrypted local generations, quarantine rollback, storage-full safe publishing and Safe Recovery Mode.
- **V15:** native readiness/device-boundary hardening: biometric runner/theme/floors, app-lock lifecycle anti-race, timezone fail-closed reminders, secure-storage fail-closed behavior, reproducible native release gate.

## Canonical rule

V15 is not a separate application. It is the current canonical source carrying forward V1–V14 contracts plus V15 hardening. The executable source of truth for this statement is:

```text
tool/version_continuity_audit.py
```

A release is rejected if any checked carry-forward contract disappears.

## V15 native-readiness invariants

1. Android biometric runner uses `FlutterFragmentActivity`.
2. Android `LaunchTheme` is AppCompat-compatible for biometric dialogs.
3. Android runtime floor is API 24; current Play target is API 36.
4. iOS runtime floor is 13.0; current submission SDK baseline is iOS 26 / Xcode 26+.
5. Biometric unlock is offered only when an actual biometric is enrolled.
6. Background lifecycle locks synchronously when app lock is enabled; stale async callbacks cannot override a newer lifecycle generation.
7. Secure-storage failures do not auto-reset the DB/recovery/PIN keys.
8. Reminder scheduling never silently substitutes UTC for an unreadable device timezone.
9. Exact-alarm privilege is intentionally not requested; reminders use inexact scheduling.
10. Production release requires a committed dependency lockfile and exact locked resolution.
11. Native release status cannot be PASS until real analyze/test/Android/iOS build gates run.
12. V3 future-optional continuity is represented by a real sentinel file so checkpoint ZIPs preserve it.
