# Arus Finance — Version Continuity V1 → V14

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

## Canonical rule

V14 is not a separate application. It is the current canonical source carrying forward V1–V13 contracts plus V14 hardening. The executable source of truth for this statement is:

```text
tool/version_continuity_audit.py
```

A release is rejected if any checked carry-forward contract disappears.

## V14 recovery invariants

1. A failed startup never silently replaces an existing encrypted DB.
2. Fresh recovery quarantines DB + WAL + SHM before creating replacement data.
3. If the original DB was not actually moved, rollback must not delete the canonical DB.
4. Unvalidated replacement is rolled back; validated replacement is retained.
5. Recovery marker changes are staged and flushed before publish.
6. Local recovery generations are encrypted with a key separate from the DB key.
7. A new local generation is verified before older generations can be pruned.
8. A normal portable restore requires an exact pre-restore local generation first.
9. Storage-full during safety-copy creation aborts destructive restore.
10. Explicit local wipe includes recovery generations/quarantine/recovery key.
11. Safe Recovery Mode stays behind existing app-lock controls.
12. Portable backup remains the user-controlled cross-device/disaster path.
