# Arus Finance — Local-Only V16 Truthful Native Gate & First-Build Readiness Report

**Date:** 2026-09-11  
**Schema:** v9 (unchanged)  
**Scope:** deterministic native bootstrap, truthful compile/release status, Android signing proof, native toolchain preflight, biometric UI correctness, physical-device validation contract.

## Why V16

V15 hardened source-level native requirements, but a source gate can still overstate what was actually proven. V16 focuses on truthfulness: a compile proof, a store-signing proof, and a physical-device proof are different states and must never collapse into one generic PASS.

No production financial-domain semantics or schema were changed in V16.

## Findings fixed

### 1. `all` release gate could silently skip iOS and still report PASS

V15's `native_release_gate.sh all` skipped the iOS compile on non-macOS hosts and still ended in PASS. That contradicted the project's own release definition.

V16 changes the contract:

- `all` means Android **and** iOS both proved;
- `all` fails immediately on non-macOS;
- Android-only and iOS-only evidence use explicit platform modes;
- partial evidence may be recorded, but never called a full store-release PASS.

### 2. Release AAB compilation did not prove production/upload signing

A successful `flutter build appbundle --release` is not by itself proof that the AAB uses the intended upload/release signing identity. Flutter's generated Android project can initially point release builds at debug signing until release signing is configured.

V16 adds:

- `tool/configure_android_release_signing.py` — idempotent Kotlin-Gradle signing patch using local `android/key.properties`;
- `tool/verify_android_release_signing.py` — fail-closed verifier for required signing metadata, keystore existence, release signing config, and debug-signing rejection;
- `tool/reference_android_signing_audit.py` — disposable idempotence/failure fixture;
- gitignore coverage for `android/key.properties` and private key material.

No secret value is printed or embedded by these tools.

### 3. Compile proof and store-release proof were conflated

V16 separates them:

- `tool/native_compile_gate.sh` proves dependency lock + audits + analyze + tests + release-mode platform compilation;
- `tool/native_release_gate.sh` additionally requires store signing and builds a signed Android AAB / signed iOS IPA path.

The compile gate explicitly says that its Android AAB is **not a store-signing claim**.

### 4. Bootstrap could let `flutter create` touch the canonical source tree

V15 ran `flutter create ... .` directly inside Arus. Even when Flutter normally behaves as expected, a generated-project command should not be allowed to rewrite canonical source/docs/tool files implicitly.

V16 stages `flutter create` under a temporary directory and copies back only `android/` and `ios/`. If native shells already exist, bootstrap fails closed unless regeneration is explicitly requested via `ARUS_REGENERATE_NATIVE=1`.

### 5. Lock screen still displayed biometric action without an enrolled biometric

V15 fixed capability detection in `SecurityService`, but the lock screen still rendered the biometric button unconditionally.

V16 adds `_biometricAvailable`, checks `canUseBiometrics()` during initial lock-state load and every resume, and only renders the biometric action while an actual biometric remains enrolled.

### 6. Native environment assumptions were not an executable preflight

V16 adds `tool/native_toolchain_preflight.sh`:

- Dart >= 3.12;
- Android gate: JDK 17 + Android Platform 36;
- iOS gate: macOS + Xcode 26+ + CocoaPods;
- `all` means both toolchains.

This turns documentation assumptions into a fail-closed command.

### 7. Physical-device validation was not a single explicit executable-release contract

V16 adds `docs/NATIVE_VALIDATION_MATRIX.md` covering:

- build/install;
- financial integrity;
- App Lock/biometric lifecycle;
- reboot/timezone notifications;
- recovery/storage-full/forced-kill behavior;
- migration/clock/lifecycle stress;
- privacy/uninstall/Keystore-Keychain failure;
- final artifact evidence.

Rule: **NO PARTIAL PASS may be reported as production/store ready.**

## Current V16 gate vocabulary

- **SOURCE PASS** — non-native source/reference audits pass.
- **COMPILE PASS (platform)** — real analyzer/tests/platform compile passed for that platform.
- **DEVICE PASS (platform/device)** — required physical-device scenarios passed.
- **STORE RELEASE PASS** — required signing/store artifact + compile/device gates passed.

## External facts rechecked for V16

- Flutter/Dart application packages should commit `pubspec.lock`; production dependency retrieval should use `--enforce-lockfile`.
- Google Play prefers Android App Bundles and release distribution requires signing.
- Android release configuration must not rely on debug signing for store distribution.
- `local_auth` 3.0.2 supports Android API 24+ and iOS 13+ and distinguishes hardware capability from enrolled biometrics.
- `flutter_local_notifications` scheduled Android notifications require reboot receiver setup; Arus intentionally uses inexact scheduling and does not request exact-alarm permission.

## Still not claimed

This environment still does not contain Flutter/Dart/Android/iOS native toolchains. V16 therefore does **not** claim:

- real `flutter analyze` PASS;
- real `flutter test` PASS;
- Android Gradle/AAB compile PASS;
- Android upload-signed AAB PASS;
- Xcode/iOS compile PASS;
- signed IPA PASS;
- physical-device biometric/Keychain/Keystore/notification/storage/recovery PASS.

V16 makes those missing proofs explicit rather than simulating them.

## Final executable result

- V16 truthful-native audit: **32/32 PASS**.
- V1→V16 continuity: **102/102 PASS**.
- Android signing configure/verify disposable fixture: **PASS**.
- Full non-native Arus suite: **PASS**.
- Paranoid V15→V16 diff: **0 removed files**; 9 intentional additions; 10 intentional modifications.
- Current-environment native preflight: **FAIL-CLOSED as expected** because Flutter SDK is not installed; no native PASS claimed.
