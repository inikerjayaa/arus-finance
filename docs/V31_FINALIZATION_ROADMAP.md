# Arus Finance — V31 Finalization Roadmap

Baseline: V30 RC2 has passed native CI and physical Vivo 1915 / Android 12 authentication UAT for fingerprint and PIN.

## Finalization rule

No major feature expansion is planned before 1.0. The remaining work is stabilization, data survival, release hardening, final UI/UX polish, and release qualification. Arus remains local-first/device-owned: no login, server, or mandatory cloud dependency may be introduced.

## Stage 1 — Stability + data survival gate

Status: IN PROGRESS

Goals:
- keep real-device bug hunting active;
- prove encrypted portable backup/restore remains fail-safe;
- preserve pre-restore local recovery before destructive restore;
- preserve atomic restore: invalid data must leave current live data unchanged;
- preserve crash-safe fresh-recovery replacement and rollback;
- preserve local recovery generations and verify a new generation before pruning older good ones;
- preserve database + ledger integrity validation;
- exercise old-device -> backup -> clean/fresh-device restore as physical UAT before stage close.

Physical UAT still required:
- create encrypted backup on the current device;
- restore on a clean installation/test device state;
- confirm accounts, categories, transactions, planning data and balances survive exactly;
- verify wrong passphrase/tampered backup cannot alter live data.

## Stage 2 — Long-session + edge-case release hardening

Goals:
- extended daily-use bug hunt;
- large-history and repeated edit/refund/transfer stress;
- background/resume, rotation/process restart where supported;
- notification and recurring/bill edge cases;
- low-storage/interrupted-operation review;
- accessibility and keyboard/input regressions.

Exit rule: no known P0/P1 data-loss, security, accounting, or lock bypass defect.

## Stage 3 — Platform/release engineering

Goals:
- final Android signing/release configuration review;
- final iOS signing/archive readiness contract;
- version/build-number policy;
- permission/privacy declarations;
- release package reproducibility and dependency lock proof;
- upgrade-path test from prior candidate without losing local data.

Exit rule: signed release pipeline is ready without changing product behavior.

## Stage 4 — Final UI/UX polish

Status intentionally deferred until core stability is closed.

Goals:
- user-reported visual corrections;
- spacing/alignment/typography consistency;
- button/field hierarchy and touch targets;
- dark/light theme visual audit;
- overflow/small-screen checks;
- final Indonesian wording consistency;
- app icon/splash/store-facing visual assets where needed.

Rule: visual cleanup must not weaken accounting, privacy, security, or local-first behavior.

## Stage 5 — Final RC + 1.0 release gate

Goals:
- freeze feature scope;
- full regression suite + Android/iOS native build from the same canonical source;
- final physical-device smoke/UAT;
- backup/restore release rehearsal;
- verify no open release-blocking defects;
- produce final signed artifacts and release notes.

Exit rule: Arus Finance 1.0 is release-qualified.

## Current physical evidence

- Vivo 1915 / Android 12: PIN PASS.
- Vivo 1915 / Android 12: fingerprint PASS.
- UI/UX corrections: intentionally deferred to Stage 4 while real-use bug hunting continues.
