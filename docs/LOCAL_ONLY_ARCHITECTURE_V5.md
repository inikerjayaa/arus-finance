# ARUS FINANCE — LOCAL-ONLY ARCHITECTURE V5

**Permanent product principle:** financial data stays under the user’s control; the public tagline remains TBD.

## Canonical production path

```text
User → Flutter UI → Domain rules → Local repository → Encrypted SQLite ledger
```

Core finance requires no account, login, Arus server, cloud database, or internet connection.

## Durability

- SQLite3MultipleCiphers (`sqlite3mc`) build source.
- WAL journaling.
- `synchronous=FULL` for committed finance writes.
- atomic `BEGIN IMMEDIATE` repository writes.
- portable encrypted `.arusbackup` recovery.
- local `PRAGMA quick_check` before backup and after restore.
- executable reference tests for app-kill-before-COMMIT and SQLITE_FULL rollback behavior.

## Security

- database key in platform secure storage; iOS uses non-migrating `unlocked_this_device` Keychain accessibility;
- PIN hashing via Argon2id;
- persistent wrong-PIN throttling;
- biometric unlock optional;
- LockGate re-checks PIN state across lifecycle changes;
- generated Android runner disables raw OS app-data backup/device transfer via native hardening.

## Data semantics

- integer minor-unit money;
- ledger-derived account balances;
- transfer is not expense/income;
- credit-card/loan settlement uses explicit domain operations;
- DRAFT has intended account/category but no current balance effect;
- VOID preserves history but removes current financial effect;
- delete is a local lifecycle tombstone/hide operation;
- V1 reporting is IDR-only until a real exchange-rate engine exists.

## Recurring safety

- floating local calendar-date schedule;
- deterministic occurrence key;
- month-end clamping;
- app resume re-runs due generation;
- extreme clock jumps do not generate years of synthetic drafts.

Any future online capability remains optional and outside the canonical production path.
