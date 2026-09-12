# Arus Finance — Local-Only V17 Native Execution Readiness Report

Date: 2026-09-11

## Session goal

Turn V16's truthful native gates into a **reproducible execution contract** that is modern for Flutter 3.47 and produces auditable build evidence, while refusing to fabricate native PASS on a host without Flutter/Xcode.

## Findings fixed

1. **CocoaPods false requirement on modern Flutter iOS.** Flutter 3.44+ is SwiftPM-first. V16 required `pod` unconditionally, so a valid modern iOS build host could fail preflight. V17 requires CocoaPods only when an actual `ios/Podfile` fallback is present.
2. **Toolchain drift.** V16 accepted any Flutter carrying Dart >=3.12. V17 pins validation to Flutter 3.47.2 through `toolchain/flutter_version.txt` and a matching pubspec Flutter constraint.
3. **No post-build UIScene proof.** V17 adds a post-build iOS verifier that rejects missing/disabled `UIApplicationSceneManifest` and retains Face ID/iOS13 contracts.
4. **Build PASS had no cryptographic evidence record.** V17 writes secret-free native evidence JSON only after build artifact existence is proven.
5. **Android keystore verifier only checked file/config existence.** V17 uses JDK `keytool` to prove keystore readability, alias presence, and `PrivateKeyEntry` type without printing credentials.

## Executable V17 fixtures

PASS coverage includes:

- exact Flutter 3.47.2 accepted;
- Flutter 3.47.1 rejected;
- Android JDK17/API36 preflight without iOS shell;
- SwiftPM-first iOS path without CocoaPods;
- Podfile fallback rejected without CocoaPods and accepted with it;
- UIScene present accepted / missing rejected;
- build evidence excludes signing secrets;
- changing `key.properties` does not alter canonical source manifest hash;
- Android signing fixture uses a real temporary JKS + alias/private-key proof.

## Real native boundary in this environment

The current host has Java but no Flutter/Dart SDK, Android SDK/Gradle toolchain, macOS, or Xcode. Therefore V17 does **not** claim:

- `flutter pub get` / real `pubspec.lock` resolution;
- `flutter analyze`;
- `flutter test`;
- Android Gradle/AAB compile;
- iOS Xcode compile;
- device validation.

Those remain mandatory external/native gates. The failure is preserved as evidence rather than converted into a simulated PASS.

## Schema

Database schema remains **v9**. V17 changes native execution tooling, not financial storage semantics.
