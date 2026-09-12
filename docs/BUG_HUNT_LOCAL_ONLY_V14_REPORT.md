# Arus Finance — Local-Only V14 Deep Mine Report

**Milestone:** V14 Deep Mine — Data Survival & Self-Recovery Layer  
**Schema:** remains v9 (no schema change)  
**Date:** 2026-09-11

## Session goal

Continue from canonical V13 without reopening product design. V14 focuses on the failure class that remains after transaction/migration atomicity is already strong: what the application does when the active encrypted database itself cannot be opened, a recovery attempt is interrupted, storage fills while creating a safety copy, or the user chooses the wrong-but-valid backup.

V14 adds no cloud/server dependency. Recovery remains device-owned.

## Safe Recovery Mode

Before V14, a startup DB failure ended at a generic retry screen. That was fail-closed, but it was operationally incomplete because a user with a valid portable backup had no in-app recovery path when the active DB could not initialize.

V14 adds a dedicated **Mode Pemulihan Data** screen. It is shown only when normal initialization fails before dashboard data becomes available and is still protected by the existing PIN/biometric `LockGate`.

Available paths:

1. retry opening the current DB;
2. restore the newest local encrypted recovery generation;
3. restore a user-controlled `.arusbackup` file with passphrase.

There is intentionally no one-tap destructive delete action on this screen.

## Fresh replacement uses quarantine, not overwrite-in-place

Recovery from an unusable DB is file-level destructive, so V14 introduces a persisted recovery state machine:

```text
PREPARING
  ↓
QUARANTINED
  ↓
NEW DB CREATED + LOGICAL RESTORE
  ↓
SEMANTIC + SQLITE VALIDATION
  ↓
REPLACEMENT_VALIDATED
  ↓
FINALIZE
```

Before a fresh replacement begins, Arus closes the active DB and moves the full SQLite file family into a same-device quarantine directory:

- `arus_finance.db`
- `arus_finance.db-wal`
- `arus_finance.db-shm`

A failed or interrupted replacement therefore has an original file family to return to.

## Critical recovery-window miss found while implementing V14

The first rollback draft exposed a dangerous edge case: if the recovery marker was persisted but the process died **before the original DB was moved**, a naive rollback could delete the still-canonical DB while trying to clear a partial replacement.

V14 explicitly checks whether the quarantined original DB actually exists before deleting the canonical path. If the marker says an old DB existed but quarantine does not contain that DB, the canonical DB is treated as the only authoritative copy and is preserved.

This rule is part of the executable V14 gate.

## Recovery marker is itself crash-hardened

Recovery metadata cannot be a new single point of failure.

V14 writes marker updates through a staged `.pending` file with `flush: true`, then publishes the new marker by same-directory rename. A pending-only marker is not considered committed recovery state.

Consequences:

- crash before marker publish → previous committed marker remains authoritative;
- crash after PREPARING but before DB move → canonical DB remains untouched;
- crash after quarantine but before replacement validation → original DB family rolls back;
- crash after validation → replacement is retained.

`REPLACEMENT_VALIDATED` is not cleaned up merely because the marker says it is valid. V14 keeps the marker/quarantine until the canonical replacement successfully opens and completes schema initialization on startup. Quarantine housekeeping failure is retryable and does not make a successfully opened valid DB unavailable.

## Separate encrypted local recovery generations

Portable `.arusbackup` remains the official user-owned backup. V14 additionally creates device-local recovery generations for self-recovery.

Properties:

- encrypted with AES-256-GCM;
- protected by a dedicated 32-byte local-recovery key in secure storage;
- recovery key is separate from the encrypted DB key;
- same logical payload/semantic validation basis as portable backup;
- maximum default generations: **3**;
- candidate is written to `.pending` with flush;
- candidate must decrypt successfully before it is published;
- old generations are pruned **only after** the new generation is published and verified.

Therefore ENOSPC or process interruption while creating a new generation cannot delete the last known-good generations first.

Local recovery generations are not a replacement for portable backup. Loss/reset of secure storage can make device-local generations unavailable; a passphrase-controlled portable backup remains the cross-device/disaster path.

## Checkpoint cadence

A local recovery generation is attempted:

- after a healthy application startup (subject to age threshold);
- when the app enters background/detached state if the previous generation is old enough;
- manually from Settings;
- before a normal in-app portable restore as exact pre-restore rollback protection.

Background checkpoint failure never blocks a financial transaction or application lifecycle event.

## Wrong-but-valid backup rollback protection

A valid encrypted backup can still be the wrong backup selected by the user.

For the normal Settings restore path, V14 now performs:

```text
decrypt + structural check selected backup
→ create exact local pre-restore generation
→ only if that succeeds: mutate live DB atomically
→ semantic + SQLite validation
```

If storage is too full to create the pre-restore generation, the destructive restore is aborted before live financial data changes.

The latest local generation can also be restored directly from Settings.

## Recovery from lost DB key

V13 already failed closed when a non-empty encrypted DB existed but its secure-storage DB key was missing.

V14 now gives that state a usable recovery path:

- local recovery can work if its **separate** local-recovery key still exists;
- portable backup recovery works with the user's passphrase even if both device recovery/DB keys are lost;
- a fresh DB key is created only after the old unusable DB family has been quarantined;
- if the fresh recovery fails before validation and there was no previous DB key, the newly generated key is removed during rollback.

## Storage-full behavior

Portable backup generation and local recovery generation both use pending files.

If writing/flushing/publishing fails:

- the pending file is cleaned up best-effort;
- existing good recovery generations are not pruned;
- live DB is not modified;
- a normal destructive restore that cannot create its pre-restore generation does not proceed.

A post-validation failure to create an *additional* recovery generation during safe recovery does not falsely report that the already-validated financial replacement rolled back.

## Explicit local-data wipe and recovery material

Automatic recovery creates additional encrypted copies of financial data, so explicit local wipe semantics must include them.

V14 Settings wipe now first removes:

- recovery marker/pending marker;
- recovery quarantine directories;
- local recovery generations;
- dedicated local recovery key.

If recovery material cannot be cleaned, the main DB wipe is aborted instead of falsely claiming that all local copies were removed.

After recovery material is clean, the existing transaction-data wipe + WAL truncate + VACUUM path runs.

## New executable gate

### `tool/deep_mine_v14_survival_audit.py`

Source contract checks cover:

- recovery marker states;
- DB/WAL/SHM quarantine;
- pre-move crash protection;
- rollback of unvalidated replacement;
- lost-key rollback behavior;
- separate local recovery key;
- AES-GCM local generations;
- verify-before-prune;
- pending/flush/publish backup behavior;
- safe recovery local/portable routes;
- app-lock protection;
- startup/background checkpointing;
- explicit wipe cleanup.

Executable file-system fixtures cover:

1. marker written before DB move;
2. crash after DB/WAL/SHM quarantine;
3. failed fresh recovery when there was no original DB;
4. validated replacement retaining the new DB;
5. failed generation write preserving three existing generations;
6. successful generation publish before pruning oldest generation;
7. failed portable pending write preserving previous backup artifacts.

## Continuity

`tool/version_continuity_audit.py` is extended to V14. The V14 recovery state machine, encrypted local generations, safe recovery UI, rollback protection and cleanup semantics are now carry-forward contracts.

## Still not claimed

V14 still does **not** claim:

- `flutter analyze` PASS;
- `flutter test` PASS;
- Android Gradle/APK/AAB build PASS;
- iOS Xcode build PASS;
- real mobile-filesystem rename/fsync behavior PASS;
- physical-device ENOSPC behavior PASS;
- OS keystore/keychain loss scenario PASS;
- real forced-kill at each file-swap instruction PASS;
- flash-level secure erasure guarantee.

Those require native toolchains and physical-device fault testing. V14 closes the known source/reference recovery gaps before that gate; it does not pretend source audits are equivalent to device validation.
