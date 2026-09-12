# Arus Finance V25 — Reproducible Native CI Handoff

## Status

V25 does **not** claim that Android/iOS compilation has passed inside the current ChatGPT execution host. The host cannot download/run the 1.5 GiB Flutter SDK bundle or provide Xcode/device hardware. V25 converts that external blocker into an executable, reproducible CI contract.

## Locked toolchain

- Flutter: **3.47.2 stable**
- Flutter release git hash: `d3b14c876900e553bc736ca19295fc09e3853e8e`
- Bundled Dart: **3.13.2**
- Linux x64 Flutter archive SHA-256: `447878859d01ca9bfdb99a85f245af07ed8a15fedcd9d189c4749e8e92d1f185`
- Android: JDK 17, API 36, build-tools 36.0.0
- iOS deployment floor: **15.0+**
- iOS CI host: `macos-26`, Xcode 26+

The iOS 15 floor supersedes the historical V15/V17 iOS 13 assumption. Flutter 3.47.2's current supported-platform matrix no longer supports iOS 14 and earlier.

## SDK provenance

`tool/install_pinned_flutter_ci.py` downloads from Flutter's official release manifest/archive only. Before extraction it verifies:

1. channel = stable;
2. exact Flutter version;
3. exact Flutter release git hash;
4. exact bundled Dart version;
5. official release SHA-256;
6. additionally, the known Linux x64 SHA-256 pin.

Tar extraction uses Python's safe `data` filter; ZIP extraction rejects path traversal.

## Dependency-lock flow

The CI resolves `pubspec.lock` once in the `resolve-lock` job. That exact file plus its SHA-256 is then passed to Android and iOS jobs. Both platform jobs verify the hash before `bootstrap.sh`, and bootstrap uses `flutter pub get --enforce-lockfile` whenever a lockfile is already present.

This prevents Android and iOS from silently resolving different dependency graphs during the same verification run.

## Compile-only workflow

Workflow: `.github/workflows/native-verify.yml`

Jobs:

1. `resolve-lock`
   - installs pinned Flutter from the official archive;
   - validates Flutter/Dart pins;
   - resolves `pubspec.lock`;
   - runs all non-native audits;
   - runs `flutter analyze`;
   - runs `flutter test`;
   - publishes the exact lockfile artifact.

2. `android-compile`
   - JDK 17;
   - Android API 36/build-tools 36.0.0;
   - exact shared lockfile;
   - hardened native bootstrap;
   - `tool/native_compile_gate.sh android`;
   - uploads compile-only AAB + cryptographic evidence.

3. `ios-compile`
   - `macos-26`;
   - exact shared lockfile;
   - hardened native bootstrap;
   - `tool/native_compile_gate.sh ios`;
   - UIScene/iOS 15/Face ID verifier;
   - uploads no-codesign `Runner.app` + cryptographic evidence.

4. `evidence-consistency`
   - requires both platform jobs;
   - proves both compiled the same canonical source hash;
   - proves both compiled the same dependency-lock hash;
   - proves both used Flutter 3.47.2 / Dart 3.13.2.

## CI security boundary

The compile workflow:

- uses `pull_request`, not `pull_request_target`;
- has `contents: read` permission only;
- does not reference GitHub signing secrets;
- keeps store signing in the separate existing release gate;
- uses exact semver releases of GitHub-maintained actions;
- never interprets compile success as store-release success.

## Truth states after V25

Until the workflow actually runs successfully in a GitHub repository or another equivalent native host:

- SOURCE / NON-NATIVE: **PASS**
- REPRODUCIBLE CI HANDOFF: **PASS**
- `flutter analyze`: **UNPROVEN on real Flutter SDK**
- `flutter test`: **UNPROVEN on real Flutter SDK**
- Android COMPILE: **UNPROVEN**
- iOS COMPILE: **UNPROVEN**
- DEVICE: **UNPROVEN**
- STORE RELEASE: **UNPROVEN**

A green CI run moves only the relevant compiler gates to PASS. It does not move DEVICE or STORE RELEASE gates automatically.
