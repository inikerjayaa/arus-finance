# Arus Finance — Workflow Stress & Human-Error UAT V19

**Milestone:** V19 — Daily Workflow Stress & Human-Error Hardening  
**Date:** 2026-09-11  
**Status:** Source/reference contract ready; physical-device timing UAT remains required.

## Goal
V19 tests what happens when a normal user acts faster, changes their mind, backgrounds the app, retries after confusing feedback, or works with stale UI state. Financial correctness must not depend on perfect tap timing.

## Critical UAT scenarios

### 1. Rapid Save / Double Tap
- Open Quick Add.
- Enter a valid expense.
- Tap **Simpan** repeatedly as fast as possible.
- Expected: one committed transaction only; button becomes unavailable while the save is active.

### 2. Commit Sukses / Refresh Gagal
- Force the repository write to commit successfully.
- Force the immediate post-write UI refresh to fail.
- Expected: UI must **not** claim the transaction failed.
- Expected: user sees a non-destructive notice that data was saved and the view needs reload, with an explicit **Muat ulang tampilan** action.
- Expected: normal flow closes the successful form rather than inviting a duplicate retry.

### 3. Resume Saat Write Sedang Aktif
- Start a financial write.
- Background and immediately resume the app while the write is active.
- Expected: resume refresh is queued and runs after the active write finishes; it is not silently discarded.

### 4. Accidental Close
- Type a partial Quick Add transaction.
- Press system Back or the explicit Close action.
- Expected: one confirmation asks whether to discard.
- Spam Back/Close repeatedly.
- Expected: only one discard confirmation can be open at a time.
- While save is active, closing must not interrupt the save flow.

### 5. Stale Account / Category
- Open Quick Add or Edit Transaction.
- Change/archive the selected dependency elsewhere or after resume.
- Expected: UI normalizes invalid Quick Add selections where possible; repository remains the authoritative rejection boundary.
- Expense edit must never advertise loan/unsupported liabilities as valid destinations.

### 6. Posted-Date Human Error
- Edit an already POSTED transaction.
- Expected: date picker does not offer future dates.
- Draft flow may retain future-date capability where the domain allows it.

### 7. Posting Draft Changes Money
- From transaction detail choose **Catat sekarang** on a DRAFT.
- Expected: confirmation explicitly says posting changes balance/report.
- Cancel must leave the draft unchanged.

### 8. Repeated Destructive Actions
- Repeatedly invoke VOID/delete/archive/skip confirmations.
- Expected: global write lock prevents concurrent financial writes.
- Expected: repository latest-state checks reject stale/repeated operations safely.

### 9. Partially Filled Form
- Enter only some Quick Add fields and submit.
- Expected: inline errors identify incomplete fields; no transaction is written.
- Correct the fields and submit once.
- Expected: error state clears and one transaction is committed.

### 10. Long Background / Resume
- Leave the app backgrounded across a recurring due-date boundary.
- Resume.
- Expected: due recurring generation and full refresh happen once, including when resume originally arrived while another write was busy.

## Release acceptance
Physical-device V19 UAT is PASS only when:
- no rapid-tap path creates duplicate financial effect;
- no successful COMMIT is reported as a failed transaction because a refresh failed afterward;
- unsaved Quick Add input cannot disappear without an explicit discard decision;
- stale UI choices cannot bypass repository rules;
- background/resume timing does not permanently skip refresh work;
- destructive/reposting actions remain explicit and safe under repeated taps.

## Validation boundary
The source/reference V19 audit is executable without Flutter. Timing, system Back behavior, IME interactions, lifecycle races, and accessibility announcement timing still require real Flutter/device execution.
