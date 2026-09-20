# SAKU — Privacy Shield + Screenshot Toggle UAT

## App Switcher Snapshot
- Open a screen containing balances/transaction details.
- Background the app and inspect the OS app switcher.
- Expected: no financial content is visible; only the SAKU privacy shield/locked presentation appears.
- Repeat this test with Android screenshot protection ON and OFF.
- Expected: app-switcher privacy remains protected in both modes. The lifecycle shield is independent from the screenshot toggle.

## Android Screenshot / Screen Share — Default OFF
- Install a fresh Android release build or clear only the screenshot-protection preference state.
- Open `Pengaturan → Privasi layar`.
- Expected: `Lindungi screenshot & rekaman layar` is OFF by default when the Android runtime bridge is supported.
- While SAKU is active, normal Android/OEM screenshot behavior is allowed until the user explicitly enables protection.
- Expected: the UI truthfully reports that screenshot protection is nonaktif.

## Android Screenshot Toggle — ON
- In `Pengaturan → Privasi layar`, switch protection ON.
- Expected: no warning is required to enable protection.
- While financial UI is visible, attempt screenshot and screen capture.
- Expected: native `FLAG_SECURE` prevents capture/non-secure display exposure according to Android/OEM platform behavior.
- Restart SAKU.
- Expected: the ON preference survives restart.

## Android Screenshot Toggle — OFF again
- Switch protection OFF.
- Expected: SAKU shows an explicit warning before disabling protection.
- Confirm `Matikan perlindungan`.
- Expected: the active-window screenshot restriction is removed and the OFF preference survives app restart.
- Background SAKU and inspect the app switcher again.
- Expected: financial content remains hidden by the independent Flutter lifecycle shield.

## Unsupported Platform / iOS Truthfulness
- Open `Privasi layar` where the runtime native bridge is unavailable.
- Expected: the toggle is disabled and SAKU explicitly says runtime screenshot protection is not verified/available on that platform.
- Do not record iOS screenshot blocking as PASS unless a separate native iOS implementation is added and device-proven.
- The app-switcher lifecycle shield remains a separate cross-platform protection.

## Biometric / System Overlay Transition
- Trigger Face ID/Touch ID/fingerprint flow, which can move the app through inactive state.
- Expected: shield may cover SAKU while inactive and clears on resume without breaking LockGate authentication.

## Resume
- Return to foreground repeatedly.
- Expected: shield clears only on resumed lifecycle state and normal App Lock/controller resume processing continues.

## Native Boundary
Actual app-switcher snapshot timing, OEM capture behavior, screen share, biometric lifecycle, and persistence of the Android runtime flag remain device-level proof items. Do not convert native compile success into physical-device PASS.
