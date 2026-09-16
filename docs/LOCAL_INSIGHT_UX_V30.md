# Arus Local Insight UX V30

## Locked product behavior

- Onboarding no longer asks what the user plans to use Arus for. The answer had no local product effect and no server-side personalization dependency exists.
- First use is intentionally short: enter a local display name, create and confirm a mandatory 4–8 digit Arus PIN, then enter Home.
- The display name stays on-device and is used only for local personalization such as the Home greeting.
- Home greets by local device time and name, for example `Selamat pagi, Ema`.
- `Insight Arus` is generated entirely on-device from the encrypted local ledger. No finance data is sent to an AI/cloud service.
- Insight is intentionally quiet: at most one insight is surfaced on the first Home visit of the current app session. Once the user closes it or navigates away, it stays quiet until a fresh app session. It is not a repeating notification or modal.
- The engine must not call spending "too much" without a defensible comparison. Daily warnings require enough prior-day evidence; otherwise monthly composition wording stays descriptive, not judgmental.
- Settings keeps only user-facing controls at the top level. Technical recovery/integrity actions live under a collapsed advanced data section. `Tentang Arus` is the final Settings section.
- New installs keep app lock enabled by design: Settings exposes PIN change rather than a normal disable-lock action.
- `Tentang Arus` stays short: `Arus Finance`, `Dibuat oleh Akbar bersama Bantuan AI`, and the local-first statement.

## Initial rule priority

1. Daily category spike: today category spending is at least 2x its previous-14-day active-day average, with at least 4 prior active days for that category.
2. Daily total spike: today spending is at least 1.75x the previous-7-day average, with at least 4 prior days containing spending.
3. Monthly dominant category: top positive expense category is at least 35% of positive month spending.
4. Monthly cash-flow note: month-to-date spending exceeds month-to-date income.
5. Otherwise no insight is shown; Arus does not manufacture a warning when evidence is weak.

Refunds offset expense categories. Transfers, credit-card payments, loan principal movements, adjustments, and opening balances do not become fake spending in this insight engine.
