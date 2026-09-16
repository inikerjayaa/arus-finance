# Arus Local Insight UX V30

## Locked product behavior

- Onboarding no longer asks what the user plans to use Arus for. Arus has no server-side personalization dependency and the old answer was not used to improve the local finance engine.
- The first-run screen remains a short local-first introduction with one `Mulai` action.
- Home greets by local device time: pagi, siang, sore, or malam.
- `Insight Arus` is generated entirely on-device from the encrypted local ledger. No finance data is sent to an AI/cloud service.
- Insight is intentionally quiet: at most one card is surfaced for a calendar day and it can be dismissed. Dismissal is stored only on-device.
- The engine must not claim overspending without a defensible comparison. Daily warnings require enough prior-day evidence; otherwise monthly composition wording is descriptive, not judgmental.

## Initial rule priority

1. Daily category spike: today category spending is at least 2x its previous-14-day daily average, with at least 4 prior active days for that category.
2. Daily total spike: today spending is at least 1.75x the previous-7-day average, with at least 4 prior days containing spending.
3. Monthly dominant category: top positive expense category is at least 35% of positive month spending.
4. Monthly cash-flow note: spending exceeds income for the current month-to-date.
5. Otherwise no insight card is shown; Arus does not manufacture a warning when the evidence is weak.

Refunds offset expense categories. Transfers, credit-card payments, loan principal movements, adjustments, and opening balances do not become fake spending in this insight engine.
