# Arus Finance — Local-Only V18 Production UX & Accessibility Report

Date: 2026-09-11

## Objective
Harden the user-facing daily workflow without changing ledger semantics, schema, backup cryptography, or the V14–V17 native/recovery contracts.

## Findings fixed
1. Accounts, Settings, and Financial Actions were pushed as full routes without owning a Scaffold/AppBar, leaving no visible in-app Back affordance.
2. Quick Add exposed account types that repository rules would always reject (for example income -> liability and expense -> loan/other liability).
3. Dashboard metric values used `FittedBox(scaleDown)`, which could shrink financial text instead of respecting accessibility text scaling.
4. Quick Add validation depended mainly on SnackBars/repository errors rather than persistent inline field feedback.
5. Global/Quick Add/recovery status changes lacked a consistent live-region contract for assistive technology.
6. Transaction hard-delete wording understated permanence even though the local-only repository performs actual deletion.
7. VOID could be submitted from UI with an empty reason and only fail later in domain validation.
8. Budget archive and Bill skip lacked explicit confirmation in the UI.
9. Full local wipe confirmation was not strong enough when no PIN was configured; V18 adds typed `HAPUS` confirmation, plus PIN when enabled.
10. Empty Transactions state had no direct Add action.
11. Onboarding and Lock layouts were not explicitly scroll-safe for large text / small displays.

## Changes
- Route-owned AppBars for Accounts, Settings, and Financial Actions.
- Domain-safe account filtering in Quick Add, Bill payment, and Recurring setup.
- Inline validation and assistive-technology live regions in Quick Add.
- Semantics labels for metric cards and transaction rows.
- Removed scale-down behavior from financial metric text.
- 48dp minimum interactive-control theme contract.
- Large-text-safe onboarding/lock scrolling.
- Explicit confirmations for budget archive, bill skip, hard-delete, and local wipe.
- Recovery progress/status semantics.
- Added executable Flutter accessibility guideline tests and V18 UAT matrix.

## Source validation
- V18 source contract: 27 checks PASS.
- All V1–V17 non-native regression audits must remain PASS before packaging.
- Flutter accessibility/widget tests are present but not claimed PASS on this host because Flutter SDK remains unavailable.

## Non-claims
V18 does not claim TalkBack, VoiceOver, Android Accessibility Scanner, Xcode Accessibility Inspector, physical-device large-text behavior, or Flutter widget-test PASS until executed on the appropriate toolchain/device.
