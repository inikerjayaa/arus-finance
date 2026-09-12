# Arus Finance — V23 Privacy Shield UAT

## App Switcher Snapshot
- Open a screen containing balances/transaction details.
- Background the app and inspect the OS app switcher.
- Expected: no financial content is visible; only the Arus privacy shield/locked presentation appears.

## Android Screenshot / Screen Share
- On Android release build, attempt screenshot and screen capture while financial UI is visible.
- Expected: native `FLAG_SECURE` policy prevents capture/non-secure display exposure according to platform behavior.

## Biometric / System Overlay Transition
- Trigger Face ID/Touch ID/fingerprint flow, which can move the app through inactive state.
- Expected: shield may cover Arus while inactive and clears on resume without breaking LockGate authentication.

## Resume
- Return to foreground repeatedly.
- Expected: shield clears only on resumed lifecycle state and normal App Lock/controller resume processing continues.

## Native Boundary
Actual app-switcher screenshot timing, OEM capture behavior, screen share, and biometric lifecycle remain device-level proof items.
