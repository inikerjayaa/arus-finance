# Arus Finance — Local-Only V15 Native Readiness & Device Boundary Report

**Date:** 2026-09-11  
**Schema:** v9 (unchanged)  
**Scope:** native readiness, device lifecycle, biometric correctness, reminder timezone safety, dependency/build reproducibility.

## Why V15

V14 hardened data survival when database/recovery operations fail. V15 moves the boundary outward: source can be financially correct yet still fail on Android/iOS because native runner requirements, lifecycle ordering, plugin compatibility, or dependency resolution were incomplete.

V15 does **not** claim a real Flutter/Android/iOS build. It hardens every native contract that can be proven from source and adds an executable gate for the first real native toolchain run.

## Findings fixed

### 1. Android biometric runner was incomplete

`local_auth` requires `FlutterFragmentActivity`, but the V14 hardener only added biometric permission. V15 patches generated Kotlin/Java `MainActivity` to `FlutterFragmentActivity` and verifies it in an idempotent disposable fixture.

### 2. Android biometric theme contract was incomplete

The Android local-auth integration requires an AppCompat `LaunchTheme` on Android 8 and below. V15 changes generated `LaunchTheme` parents to `Theme.AppCompat.DayNight` and adds stable AndroidX AppCompat 1.8.0.

### 3. Native platform floors were implicit

V15 makes them explicit and executable:

- Android minSdk 24;
- Android compileSdk 36;
- Android targetSdk 36;
- Java 17;
- iOS deployment target 13.0;
- Face ID usage description.

### 4. Biometric capability check confused hardware with enrollment

`canCheckBiometrics` alone does not mean a fingerprint/face is enrolled. V15 only exposes biometric unlock when `getAvailableBiometrics()` returns at least one enrolled biometric.

### 5. App-lock lifecycle had an async race window

Background/resume callbacks previously performed secure-storage checks asynchronously. A late callback could theoretically re-lock after a successful biometric result, and locking did not happen synchronously at the lifecycle edge.

V15 adds:

- immediate background lock when PIN is enabled;
- foreground state tracking;
- lifecycle generation token;
- one-biometric-prompt-at-a-time guard;
- unlock only while actually foreground.

### 6. Reminder timezone failure silently fell back to UTC

UTC fallback could shift an 08:00 local reminder by hours. V15 fails reminder scheduling closed when device timezone cannot be resolved. Finance writes and refresh remain independent.

### 7. Secure-storage auto-reset was unsafe for database keys

Current flutter_secure_storage Android defaults permit `resetOnError=true`. For Arus, auto-reset can destroy the only local DB/recovery key. V15 sets `AndroidOptions(resetOnError: false)` for DB/recovery and PIN storage. Native storage errors now fail closed into recovery instead of silently erasing secrets.

### 8. V14 ZIP exposed an empty-folder continuity weakness

The V3 continuity audit depended on an empty `future_optional` directory. ZIP does not reliably preserve empty directories. V15 adds `future_optional/README.md` as a persistent non-runtime sentinel and updates continuity to check the file, not an empty folder.

### 9. Release dependency graph was not yet reproducibility-gated

V15 raises the flutter_secure_storage baseline to `^11.1.0` and adds `tool/native_release_gate.sh`. A release candidate must contain `pubspec.lock` and use `flutter pub get --enforce-lockfile` before analyze/test/build.

## Current external release baseline verified on 2026-09-11

- Google Play new apps/updates: Android 16 / target API 36+.
- App Store Connect: Xcode 26+ with iOS 26 SDK+.
- Local-auth support floor: Android 24+, iOS 13+.

These requirements are documented in `docs/NATIVE_SETUP.md` and must be rechecked on the actual submission date.

## Executable gates added/expanded

- `tool/deep_mine_v15_native_readiness_audit.py`
- expanded `tool/native_hardening.py`
- expanded `tool/reference_native_hardening_audit.py`
- `tool/native_release_gate.sh`
- V1→V15 continuity contract

## Still not claimed

Until executed on real toolchains/devices, V15 does not claim:

- `flutter analyze` PASS;
- `flutter test` PASS;
- Gradle/AAB PASS;
- Xcode/iOS compile PASS;
- Android runtime biometric PASS;
- iOS Face ID runtime PASS;
- Keystore/Keychain loss/reinstall behavior on physical hardware;
- reboot/background notification delivery on physical hardware;
- real device storage-full/forced-kill behavior.
