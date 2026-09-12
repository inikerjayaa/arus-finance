# Arus Finance — V24 Pre-Native Release Candidate

## Status
**SOURCE / NON-NATIVE RC: READY** after all source/reference/regression gates pass.

This status is intentionally not equivalent to:
- Flutter analyzer PASS;
- Flutter widget/unit test PASS;
- Android COMPILE/DEVICE/STORE PASS;
- iOS COMPILE/DEVICE/STORE PASS.

## Runtime freeze
V24 introduces no intentional runtime behavior change relative to audited V23. It synchronizes documentation, test matrix, continuity, release-readiness evidence, and handoff instructions.

## Canonical architecture
- device-owned/local-only financial core;
- encrypted local SQLite;
- ledger-derived integer money;
- encrypted portable backup + local encrypted recovery generations;
- schema v9;
- Flutter toolchain validation pin 3.47.2;
- truthful SOURCE / COMPILE / DEVICE / STORE release states.

## Native execution blockers in this environment
The current host cannot truthfully complete the native gate unless it has the pinned Flutter/Dart toolchain, Android SDK/JDK/signing material, and for iOS macOS/Xcode/signing/device access.

## Handoff order on a capable machine
1. Extract V24 source and verify package SHA-256.
2. Install/verify exact pinned Flutter toolchain.
3. Run bootstrap/native hardening.
4. Resolve and commit `pubspec.lock` with enforced dependency resolution.
5. Run `tool/run_all_audits.sh`.
6. Run Flutter analyze/tests, including accessibility tests.
7. Build Android release; configure/verify real upload signing; run device validation matrix.
8. On macOS/Xcode, build/sign iOS and run device validation matrix.
9. Capture native evidence JSON/hashes and only then promote COMPILE/DEVICE/STORE statuses.

## Promotion rule
Any native failure reopens the project at the exact failing gate. Do not bypass a failed gate by changing the status label.
