# Native Setup — V17 Reproducible Native Execution Gate

## Current release baseline verified 11 September 2026

- Google Play new apps/updates: **Android 16 / API 36+** target baseline.
- App Store Connect uploads: **Xcode 26+ / iOS 26 SDK+** baseline.
- Arus runtime floor: **Android API 24+** and **iOS 15.0+**.
- Android Java toolchain baseline: **JDK 17**.
- Flutter validation SDK: **Flutter 3.47.2 exactly** (`toolchain/flutter_version.txt`).
- Dart SDK required by this repository: **>= 3.12.0 < 4.0.0** (bundled Dart is used from the pinned Flutter SDK).

Re-check store policy again on the actual submission date. External store requirements are release gates, not permanent business rules.

## 1. Bootstrap native shells safely

The canonical repository intentionally stores Dart/source contracts, not hand-maintained generated platform shells.

```bash
./bootstrap.sh
```

V16 introduced staged bootstrap; V17 retains it and pins the validation toolchain:

1. Flutter/Dart preflight runs first.
2. `flutter create` runs inside a temporary directory, **outside the canonical Arus source tree**.
3. Only generated `android/` and `ios/` directories are copied back.
4. Native hardening and all Arus audits run.
5. `flutter pub get` must create `pubspec.lock`.
6. `flutter analyze` and `flutter test` must pass.

If `android/` or `ios/` already exists, bootstrap fails closed rather than silently overwriting signing/native edits. Regeneration requires explicit `ARUS_REGENERATE_NATIVE=1`.

For an application package, `pubspec.lock` is part of the reproducibility contract and must be reviewed/committed after the first real dependency resolution. V17 intentionally does not invent a lockfile without a real Flutter resolver.

## 2. Native compile proof — NOT a store release claim

Use the compile gate when the goal is to prove that real Flutter/platform compilers accept the source:

```bash
bash tool/native_compile_gate.sh android
bash tool/native_compile_gate.sh ios      # macOS only
bash tool/native_compile_gate.sh all      # macOS; proves both
```

Compile gate requires:

- exact dependency resolution via `flutter pub get --enforce-lockfile`;
- all Arus audits;
- `flutter analyze`;
- `flutter test`;
- Android release-mode AAB compilation when Android is requested;
- iOS release-mode `--no-codesign` compilation when iOS is requested.

An Android AAB produced by the compile gate is **not automatically store-ready**. It may not yet carry the intended upload/release signing identity.

## 3. Android upload/release signing

Never store passwords or private keystores in this repository.

Create `android/key.properties` locally using the standard Flutter fields:

```properties
storePassword=<secret>
keyPassword=<secret>
keyAlias=upload
storeFile=<absolute-or-local-path-to-upload-keystore>
```

`android/key.properties`, `*.jks`, and `*.keystore` are gitignored.

Patch the generated Kotlin Gradle file idempotently:

```bash
python3 tool/configure_android_release_signing.py
```

Verify the signing contract without printing secrets:

```bash
python3 tool/verify_android_release_signing.py
```

The verifier fails if:

- `key.properties` is absent/incomplete;
- the referenced keystore file does not exist;
- the release signing config is absent;
- `buildTypes.release` still points to debug signing.

For Play distribution, keep the upload keystore backed up securely and use Play App Signing.

## 4. Store-release gate

The store-release gate is intentionally stricter than the compile gate:

```bash
bash tool/native_release_gate.sh android
bash tool/native_release_gate.sh ios
bash tool/native_release_gate.sh all
```

Rules:

- `android` requires explicit upload/release signing and builds the release AAB.
- `ios` requires macOS/Xcode and builds a **signed release IPA**; it does not use `--no-codesign`.
- `all` means **Android + iOS both proved**. On a non-macOS host it fails; it never prints PASS after silently skipping iOS.

A partial platform PASS is useful evidence, but it is not an Arus production-release PASS.

## 5. Android native contract

`tool/native_hardening.py` remains idempotent and enforces:

- minSdk 24;
- compileSdk/targetSdk 36;
- Java 17 project bytecode configuration;
- raw Android app-data cloud backup/device-transfer disabled;
- `USE_BIOMETRIC`, notification, reboot permissions;
- no exact-alarm permission: Arus deliberately uses `inexactAllowWhileIdle`;
- notification reboot receivers;
- `FlutterFragmentActivity` for local authentication;
- AppCompat launch theme for biometric compatibility;
- core-library desugaring.

`flutter_secure_storage` is configured with `resetOnError: false` for critical secrets. Keystore errors fail closed into recovery rather than silently replacing encryption keys.

## 6. iOS native contract

Flutter 3.44+ uses **Swift Package Manager by default**. V17 is SwiftPM-first and only requires CocoaPods when the actual generated project contains `ios/Podfile` as a plugin/dependency fallback. After iOS build, `tool/verify_ios_modern_contract.py` requires active `UIApplicationSceneManifest` rather than an opt-out.

Native hardening enforces:

- iOS deployment target 15.0+;
- `NSFaceIDUsageDescription`;
- non-migrating `unlocked_this_device` Keychain accessibility for DB/PIN/recovery secrets.

Real App Store release still requires valid Apple signing identity, provisioning, bundle identifier, and App Store Connect configuration.

## 7. Native evidence

A successful compile/release gate writes `build/arus_evidence/*.json` containing artifact hash, canonical source-manifest hash, `pubspec.lock` hash, and tool versions. Signing secrets (`key.properties`, `.jks`, `.keystore`) are explicitly excluded from the evidence source manifest.

See `docs/NATIVE_EXECUTION_HANDOFF.md` for the exact execution sequence.

## 8. Physical-device validation

Compiler success is not enough. Execute every mandatory scenario in:

```text
docs/NATIVE_VALIDATION_MATRIX.md
```

Especially verify biometric enrollment/removal, app-switcher locking, reboot reminders, Keystore/Keychain loss paths, storage-full behavior, forced kill during write/recovery, and portable backup restore on real hardware.

## Status language

Use these labels exactly:

- **SOURCE PASS** — non-native audits only.
- **COMPILE PASS (Android/iOS)** — real analyzer/tests/platform compile passed for the named platform.
- **DEVICE PASS** — required physical-device matrix passed for the named device/OS.
- **STORE RELEASE PASS** — signing + store artifact build + required platform/device gates passed.

Never collapse a partial PASS into “production ready.”
