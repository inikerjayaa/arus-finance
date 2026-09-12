# Arus Finance — Version Continuity V1 → V11

**Date:** 2026-09-11  
**Canonical source milestone:** V11 Deep Mine — Atomic Planning Integrity

## How version continuity is interpreted

Arus does not maintain eleven independent application branches.

- **V1/V2** = product, financial-domain and implementation blueprint baseline.
- **V3** = normative local-only/device-owned architecture pivot.
- **V4–V11** = forward source hardening milestones on one canonical implementation.

Therefore “no version is missed” means every important rule that remains applicable is still represented in the canonical source, migration path, tests/audits or explicit superseding architecture decision.

## Continuity matrix

| Generation | Contract carried forward into V11 | Verification |
|---|---|---|
| V1/V2 | Integer-money ledger model; Expense/Income/Transfer/Refund; card/loan/reconciliation; financial invariant tests; Master Blueprint retained | PASS |
| V3 | Core requires no login/server/cloud; encrypted device-owned SQLite; user-owned encrypted backup | PASS |
| V4 | Recurring occurrence identity normalization; recurring DRAFT leg migration; active-name/IDR safeguards | PASS |
| V5 | WAL + synchronous FULL; explicit VOID; local integrity checks; device-owned security direction | PASS |
| V6 | CSV import/preview/idempotency; local private notifications; recurring materialization as DRAFT; timeline indexing | PASS |
| V7 | FTS5; secure-delete; bounded import preflight; future POSTED guard; differential reminder architecture | PASS |
| V8 | Unique Bill payment link; atomic Bill recheck; refund chronology; future legacy records excluded from current balances/reports | PASS |
| V9 | Local hard-delete; Bill/refund reconciliation; clock-jump healing; 64 MiB backup cap; tombstone migration cleanup | PASS |
| V10 | Composite VOID refund guard; refund destination invariant; transaction semantic restore firewall | PASS |
| V11 | Atomic refund/edit/loan rechecks; recurring target invariant; safe Bill status mutation; planning/group restore semantics; stronger source syntax guard | PASS |

## Reverse-audit finding corrected in V11

The V10 source package still contained a malformed tail in `test/finance_invariants_test.dart`: literal `\\n` patch text outside a Dart string and an undeclared test-scope variable. This was not a financial runtime mutation, but it could block `flutter test` compilation.

V11 corrected the test source and hardened the Dart structural audit so a backslash outside strings/comments fails immediately.

This finding is recorded rather than hidden because continuity should mean traceable correction, not retroactive claims that an older package was perfect.

## Executable continuity gate

Run:

```bash
python3 tool/version_continuity_audit.py
```

Current result:

```text
PASS: V1→V11 continuity contract (38 carry-forward checks)
```

The continuity audit is also part of `tool/run_all_audits.sh`, so future milestones fail if a protected carry-forward contract disappears.

## Validation boundary

Continuity and non-native source/reference audits are now green, but they do not replace the real toolchain. The following remain unproven in this environment:

- `flutter analyze`;
- `flutter test`;
- Android Gradle/APK/AAB build;
- iOS Xcode build;
- signing/store validation;
- physical-device encryption, biometrics, notifications and performance.

No release should be called production-ready until those gates pass.
