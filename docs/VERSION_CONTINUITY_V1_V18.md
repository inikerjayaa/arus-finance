# Arus Finance — Version Continuity V1 → V18

**Canonical source milestone:** V18 — Production UX, Accessibility & Daily-Use UAT Hardening  
**Date:** 2026-09-11  
**Schema:** v9

## Continuity principle
Arus Finance V18 is one canonical application carrying forward the product/domain baseline, local-only architecture, financial correctness, migration, backup/recovery, native-readiness, and UX/accessibility hardening accumulated from V1 through V18. Older versions are milestones, not separate products.

## Carry-forward chain
- V1/V2 — product, financial-domain, UX and architecture baseline.
- V3 — local-only/device-owned core locked.
- V4–V8 — financial correctness, migration, import/search/notification hardening.
- V9–V13 — lifecycle, semantic restore, atomicity, integer/date, catastrophe and historical portability hardening.
- V14 — data-survival and self-recovery layer.
- V15 — native/device-boundary readiness.
- V16 — truthful native release gates and signing proof.
- V17 — reproducible native-execution readiness and evidence contracts.
- V18 — production UX/accessibility and daily-use UAT hardening.

## V18 carry-forward proof
Executable continuity audit:

```bash
python3 tool/version_continuity_audit.py
```

Current expected result:

```text
PASS: V1→V18 continuity contract (131 carry-forward checks)
```

The complete non-native regression gate is:

```bash
bash tool/run_all_audits.sh
```

V18 packaging is blocked if either continuity or any inherited non-native audit fails.

## V18 UX/accessibility additions
V18 adds route-owned navigation exits, domain-safe Quick Add choices, inline/live validation, large-text-safe layouts, explicit destructive-action confirmations, 48dp minimum control sizing, recovery semantics, and executable Flutter accessibility guideline tests.

These additions do **not** replace or weaken financial-domain rules. Repository/ledger/database semantics remain the source of truth when UI convenience conflicts with financial correctness.

## Validation boundary
V18 source/reference audits passing does not imply Flutter/native execution PASS. The following still require a host/device with the appropriate toolchain:
- `flutter analyze`;
- `flutter test`, including `test/accessibility_guidelines_test.dart`;
- Android Gradle/APK/AAB build;
- iOS Xcode build;
- TalkBack/VoiceOver and platform accessibility scanners;
- physical-device large-text, keyboard/IME, biometric, notification, storage, recovery and performance UAT.

Until those are executed, the truthful status remains **SOURCE PASS / NATIVE EXECUTION UNPROVEN**.
