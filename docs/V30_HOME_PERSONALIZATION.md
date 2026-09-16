# V30 Home Personalization Contract

## Product contract

- Personalization is local-only. The display name is stored on-device and is never a login/account dependency.
- Fresh onboarding and Home share the same local `UserProfileService` instance so a newly entered name appears immediately without reopening the app.
- Home greeting follows device-local time: pagi, siang, sore, or malam. A missing legacy profile falls back to the greeting without inventing a name.
- The primary finance highlight is intentionally limited to three headline values: **Total Saldo**, **Pemasukan**, and **Pengeluaran**.
- `availableBalanceMinor` remains part of the accounting model but is not shown inside the primary Home highlight.
- The old `Ringkasan / Keuanganmu hari ini` copy and duplicate manual refresh action are removed. Pull-to-refresh remains available.

## Insight Arus

- Insight Arus is deterministic and runs entirely on-device against the local encrypted ledger.
- It has no cloud, LLM, login, analytics, or network dependency.
- It surfaces at most one useful insight during a Home session and stays quiet after dismissal or navigation until a fresh app session.
- Daily category warnings require at least four prior active days in the comparison window and a meaningful spike.
- Daily total warnings require enough prior spending-day evidence before comparing the current day.
- When evidence is weaker, monthly wording is descriptive rather than judgmental.
- Refunds offset expense values.
- Transfers do not become fake spending; only real expense legs such as explicit transfer fees may count as expense.
- Credit-card payments, loan principal movements, adjustments, and opening balances are not manufactured into spending insight.

## Verification gates

- Greeting daypart + optional name unit test.
- Primary-card widget test proves the three headline values and proves available-to-spend is absent from that card.
- Insight regression tests prove evidence thresholds, monthly descriptive composition, and transfer neutrality.
- Full non-native audit + Flutter analyzer/tests.
- Android release compile + installable APK.
- iOS release no-codesign compile.
- Cross-platform evidence consistency before merge.
