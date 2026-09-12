# V25 Report — Reproducible Native CI Handoff + iOS 15 Floor Correction

## Goal

Turn the V24 external Flutter/Xcode blocker into an executable native verification pipeline without weakening Arus's truthful PASS semantics.

## Findings

### 1. Historical iOS 13 floor is no longer valid for Flutter 3.47.2

The current Flutter 3.47.2 supported-platform matrix supports iOS 15–26. V25 updates the active native hardener, verifier, fixture, setup documentation and continuity contract to iOS 15.0. Historical reports remain historical evidence of what earlier versions assumed.

### 2. Flutter version pin alone was insufficient provenance

V17 pinned `3.47.2`, but did not pin the Flutter git release hash, bundled Dart patch version, or official Linux archive SHA. V25 records all of these and validates them before SDK extraction.

### 3. Android/iOS independent dependency resolution could drift

A native CI matrix that independently runs `pub get` can theoretically resolve different dependency graphs. V25 resolves one lockfile once, hashes it, and requires both platform jobs to compile that exact artifact with `--enforce-lockfile`.

### 4. Native evidence needed a cross-platform canonical hash

The previous source evidence included generated native shells. V25 retains that full native hash but adds `canonical_source_manifest`, excluding generated Android/iOS shells, so Android and iOS can prove they compiled the same canonical Arus source.

### 5. CI compile should not have signing-secret access

The new compile workflow consumes no signing secrets, uses read-only repository permission and normal `pull_request`. Store signing remains a separate, explicit release gate.

## Status

- V25 source/reference audit: PASS
- Native CI workflow structure/security audit: PASS
- Pinned-SDK installer positive fixture: PASS
- Wrong Flutter release hash fixture: rejected
- Wrong archive SHA-256 fixture: rejected
- Cross-platform evidence equality fixture: PASS
- Mismatched lockfile evidence fixture: rejected
- Real Flutter/Android/iOS compilation on this host: UNPROVEN due external toolchain/network boundary
