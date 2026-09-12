# Arus Finance — Local-Only V19 Workflow Stress Report

**Date:** 2026-09-11  
**Milestone:** V19 — Daily Workflow Stress & Human-Error Hardening

## Critical finding — committed write could look like a failed transaction
`AppController.run()` previously wrapped both the financial operation and the subsequent presentation refresh in one catch block. A repository write could COMMIT successfully, then `refresh()` could fail, causing `run()` to return `null`. A reasonable user retry could then create a second financial effect.

V19 separates the two phases:
1. financial operation failure → error / no success result;
2. financial operation success → success result is preserved;
3. post-commit refresh failure → non-destructive notice telling the user the change was saved and the view needs reload; the notice includes an explicit refresh action.

This is a workflow correctness fix, not merely UX copy.

## Resume race hardening
If the app resumes while a financial operation or another resume pass is active, V19 records a pending resume refresh and executes it afterward. Lifecycle timing no longer silently drops the refresh/generate-due-recurring pass.

## Quick Add hardening
- local `_submitting` guard in addition to global controller busy state;
- modal cannot be dismissed by barrier tap or drag;
- explicit Close action;
- dirty state protected by `PopScope`;
- discard confirmation for unsaved input;
- repeated Back/Close cannot stack multiple discard dialogs;
- successful save clears dirty state before closing.

## Edit/posting hardening
- Expense Edit only offers Asset or Credit Card accounts, matching repository rules.
- POSTED transaction date picker cannot select future dates.
- Posting a DRAFT now requires explicit confirmation that balance/report will change.

## Regression / acceptance
V19 adds:
- `tool/deep_mine_v19_workflow_stress_audit.py`;
- `docs/WORKFLOW_STRESS_UAT_V19.md`;
- V19 checks to the V1→V19 continuity gate;
- V19 audit to `tool/run_all_audits.sh`.

Physical-device timing remains required for actual rapid tap, system Back, background/resume, keyboard/IME, and long-background UAT.
