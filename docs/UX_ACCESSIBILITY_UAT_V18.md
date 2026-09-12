# Arus Finance — V18 UX & Accessibility UAT

Status: source-ready; Flutter/device execution still required.

## Goal
Prove that the daily finance flow remains understandable, reachable, and safe with screen readers, large text, small screens, keyboard/IME interaction, dark mode, and destructive actions.

## Automated Flutter gate (run when Flutter 3.47.2 is available)

```bash
flutter pub get
flutter test test/accessibility_guidelines_test.dart
flutter test
```

The accessibility smoke test uses Flutter's official guideline matchers for:
- Android tap targets;
- iOS tap targets;
- labeled tap targets;
- text contrast;
- large-text layout regression.

## Manual device matrix
Run on at least one Android API 24 device/emulator, one current Android/API 36 device/emulator, and one iOS 13+ / one current iOS target when macOS/Xcode is available.

### UAT-01 — First launch
1. Fresh install.
2. Complete onboarding with largest OS text size.
3. Confirm every goal option and the Start button remain reachable by scrolling.
4. Confirm no login/network prompt is required.
5. Confirm Home opens with a usable default Cash account and categories.

Expected: no overflow, clipped controls, or unreachable action.

### UAT-02 — Quick expense target
1. Home -> Add.
2. Enter amount.
3. Verify Account and Category are already valid defaults.
4. Save.

Measure from sheet-ready to successful save. Product target remains 2–4 seconds for a repeat expense; do not claim PASS until measured on real device.

### UAT-03 — Domain-safe account choices
- Income must list asset accounts only.
- Expense may list assets and credit cards only.
- Transfer must list asset accounts only and source/destination cannot be the same.
- Bill payment and recurring expense must not offer loan/other-liability accounts.

Expected: UI never offers a selection the repository is guaranteed to reject.

### UAT-04 — Screen reader
With TalkBack / VoiceOver enabled:
- navigate onboarding;
- open Quick Add;
- read dashboard metric cards;
- open transaction rows;
- force an invalid Quick Add submit;
- trigger a recoverable global error.

Expected: buttons have meaningful labels, metric cards are announced coherently, and errors/status changes are announced as live regions.

### UAT-05 — Large text / display scale
At the largest supported OS font size and enlarged display scale:
- Onboarding;
- Lock screen;
- Home metrics;
- Transactions;
- Accounts;
- Planning;
- Settings;
- Recovery Mode.

Expected: content may wrap/scroll but critical actions never disappear or shrink text below the user's chosen scale.

### UAT-06 — Navigation escape paths
Open Accounts, Financial Actions, Settings, Categories, Customize Dashboard, and Transaction Detail.

Expected: every pushed page exposes a visible system-consistent Back action and system back/gesture also works.

### UAT-07 — Destructive action safety
- Delete transaction: wording must say permanent local deletion and mention backup.
- VOID: blank reason must be rejected.
- Archive budget: explicit confirmation.
- Skip bill: explicit confirmation.
- Wipe all local data: confirmation dialog + typed `HAPUS`; if PIN is active, PIN is additionally required.

Expected: no irreversible operation is triggered by a single ambiguous tap.

### UAT-08 — Dark mode / contrast
Repeat core flow in light and dark mode. Run Android Accessibility Scanner and iOS Accessibility Inspector audit.

Expected: no critical contrast or unlabeled-control finding. Automated Flutter text-contrast guideline must also pass.

### UAT-09 — Keyboard / IME
- Quick Add amount field autofocuses.
- Opening the keyboard does not hide Save or critical fields; sheet remains scrollable.
- Large keyboard + large text combination remains usable.
- Search action submits transaction search.

### UAT-10 — Empty/loading/error states
Validate:
- empty transaction list offers direct Add action;
- empty/filtered transaction state explains what happened;
- loading indicators carry semantic labels;
- Recovery Mode communicates progress/result;
- global error banner can be dismissed and is announced.

## Release rule
V18 source audits are not a substitute for the Flutter guideline test, TalkBack/VoiceOver inspection, Accessibility Scanner, Xcode Accessibility Inspector, and physical-device large-text UAT.
