# Arus Finance — V17 Native Execution Handoff

## Status

V17 source is prepared for **real native execution**, but this repository must not claim Android/iOS compile success until the exact commands below pass on real toolchains.

Pinned validation baseline:

- Flutter **3.47.2** (exact validation pin)
- Dart bundled by that Flutter SDK; project minimum Dart >= 3.12
- Android JDK 17 + SDK Platform 36
- iOS Xcode 26+ on macOS
- Swift Package Manager first; CocoaPods only when Flutter/plugin fallback creates/retains `ios/Podfile`

The exact Flutter pin lives in `toolchain/flutter_version.txt`. Bumping it is an explicit reviewed project change, never an implicit `flutter upgrade`.

## First real bootstrap

From a clean checkout/source directory:

```bash
flutter --version
./bootstrap.sh
```

Expected effects:

1. exact Flutter 3.47.2 preflight;
2. native Android/iOS shells generated outside canonical source then copied in;
3. native hardening applied;
4. non-native Arus audits pass;
5. `flutter pub get` creates `pubspec.lock`;
6. `flutter analyze` passes;
7. `flutter test` passes.

Commit/review `pubspec.lock` after the first successful real resolution. Do not hand-create it.

## Android compile proof

```bash
bash tool/native_compile_gate.sh android
```

A successful gate must create:

```text
build/app/outputs/bundle/release/app-release.aab
build/arus_evidence/android-compile.json
```

This is **COMPILE PASS (Android)** only. It is not a store-signing claim.

## Android store-release proof

Create local `android/key.properties`, keep the keystore outside version control, then:

```bash
python3 tool/configure_android_release_signing.py
python3 tool/verify_android_release_signing.py
bash tool/native_release_gate.sh android
```

The verifier uses JDK `keytool` to prove that the keystore opens, the requested alias exists, and it is a `PrivateKeyEntry`. Passwords are never printed. The final Gradle/AAB build is still required to prove the complete signing path.

Expected evidence:

```text
build/arus_evidence/android-release.json
```

## iOS compile proof

On macOS only:

```bash
bash tool/native_compile_gate.sh ios
```

Flutter 3.44+ uses Swift Package Manager by default. V17 therefore does not require CocoaPods unless the actual project has an `ios/Podfile` fallback.

After build, V17 verifies that:

- `UIApplicationSceneManifest` is active;
- UIScene is not explicitly disabled;
- Face ID usage description exists;
- iOS deployment target is 15.0+ (V25 correction to match Flutter 3.47.2 supported platforms).

Expected evidence:

```text
build/arus_evidence/ios-compile.json
```

## iOS store-release proof

On signing-configured macOS/Xcode/App Store environment:

```bash
bash tool/native_release_gate.sh ios
```

This must create a real signed IPA and:

```text
build/arus_evidence/ios-release.json
```

## Both-platform release gate

```bash
bash tool/native_release_gate.sh all
```

`all` means Android + iOS. It intentionally fails on Linux/Windows rather than silently skipping iOS.

## Evidence semantics

`tool/capture_native_evidence.py` hashes:

- native build artifact;
- canonical source/native-shell manifest;
- `pubspec.lock`;
- Flutter/Dart tool versions;
- Java or Xcode version as relevant.

It explicitly excludes:

- `android/key.properties`;
- `.jks` / `.keystore` private key files;
- build caches and dependency caches.

Evidence is generated only after the corresponding build command succeeds.

## Device proof

Compile/store artifact success is not `DEVICE PASS`. Execute `docs/NATIVE_VALIDATION_MATRIX.md` on physical Android and iOS devices, including:

- biometric enroll/remove lifecycle;
- app background/resume lock races;
- reboot notifications;
- Keystore/Keychain-loss recovery;
- forced-kill during database/recovery operations;
- real storage-full behavior;
- encrypted backup export and cross-device restore.

## Status language

- `SOURCE PASS`
- `COMPILE PASS (Android)` / `COMPILE PASS (iOS)`
- `DEVICE PASS`
- `STORE RELEASE PASS`

Never infer a higher status from a lower gate.
