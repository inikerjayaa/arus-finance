# Arus Finance — Version Continuity V1 → V16

**Date:** 2026-09-11  
**Purpose:** ensure the current canonical source carries every locked financial/privacy/recovery/native-readiness contract forward without silently turning unproven native behavior into a PASS.

## Milestone chain

- **V1/V2:** product/domain baseline and production acceptance rules.
- **V3:** local-only/device-owned pivot.
- **V4:** recurring identity/data integrity.
- **V5:** durability/VOID/security hardening.
- **V6:** CSV/private notifications/large-history indexing.
- **V7:** differential notifications/FTS5/secure-delete/bounded import.
- **V8:** Bill uniqueness/time-reporting guardrails.
- **V9:** local lifecycle cleanup/hard-delete/refund-clock healing.
- **V10:** semantic firewall/composite VOID integrity.
- **V11:** atomic latest-state/planning/group integrity.
- **V12:** restore/integer/date/compiler-risk hardening.
- **V13:** historical startup/portable migration + catastrophe rollback.
- **V14:** Safe Recovery Mode/encrypted recovery generations/storage-full survival.
- **V15:** source-level native/device-boundary hardening.
- **V16:** truthful native gates, deterministic staged bootstrap, explicit Android upload signing proof, enrolled-biometric UI gate, and physical-device validation matrix.

## V16 invariants

1. `flutter create` is staged outside the canonical source tree.
2. Existing native shells are never overwritten without explicit regeneration intent.
3. Dependency lock creation/resolution is mandatory for real native proof.
4. Compile PASS and Store Release PASS are separate states.
5. `all` platform release can never silently skip iOS.
6. Android store-release gate requires explicit non-debug upload/release signing.
7. iOS store-release path builds a signed IPA, not `--no-codesign`.
8. Android signing secrets remain local and gitignored.
9. Toolchain preflight enforces Dart/Java/SDK/Xcode baseline before native claims.
10. Biometric action is visible only with actual enrolled biometric availability.
11. Physical-device matrix is mandatory before production/store-ready status.
12. A partial platform/device PASS must never be summarized as a global production PASS.

## Canonical executable contract

```text
tool/version_continuity_audit.py
```

**Current executable result: 102/102 carry-forward checks PASS.**

A newer milestone may strengthen implementation or release gates, but must not remove earlier financial/domain/privacy/recovery contracts.
