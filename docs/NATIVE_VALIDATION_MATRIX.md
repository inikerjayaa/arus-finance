# Arus Finance — Native Validation Matrix (current through V25)

**Rule: NO PARTIAL PASS may be reported as production/store ready.**

Record device model, OS version, build hash, Flutter version, and result evidence for every run.

## Gate A — Build / install

| ID | Test | Expected |
|---|---|---|
| BUILD-01 | `flutter analyze` | 0 errors |
| BUILD-02 | `flutter test` | all PASS |
| BUILD-03 | Android release-mode AAB compile | PASS |
| BUILD-04 | iOS release no-codesign compile | PASS |
| BUILD-05 | Android upload-signed release AAB | PASS; not debug signed |
| BUILD-06 | iOS signed IPA archive | PASS |
| INSTALL-01 | Clean install Android API 24+ | launches, onboarding works |
| INSTALL-02 | Clean install current Android | launches, onboarding works |
| INSTALL-03 | Clean install iOS 15+ supported device/simulator where available | launches |
| INSTALL-04 | Clean install current iOS physical device | launches |

## Gate B — Financial integrity

| ID | Test | Expected |
|---|---|---|
| FIN-01 | Expense → edit → delete | balance always reconciles |
| FIN-02 | Income → refund/adjustment paths | correct financial effect |
| FIN-03 | Transfer + fee | transfer not income/expense; fee exactly once |
| FIN-04 | Credit-card payment | no double-count expense |
| FIN-05 | Loan disbursement/payment | principal/interest/fee correct |
| FIN-06 | Bill payment → refund | Bill state reconciles |
| FIN-07 | Recurring draft materialization | no duplicate occurrence |
| FIN-08 | Kill app during committed transaction boundary | committed-or-not; never half-posted |

## Gate C — APP LOCK / BIOMETRIC

| ID | Test | Expected |
|---|---|---|
| BIOMETRIC-01 | PIN only, no biometric enrolled | biometric button hidden |
| BIOMETRIC-02 | Enroll biometric then resume Arus | biometric option becomes available |
| BIOMETRIC-03 | Remove all enrolled biometrics | biometric action disappears after resume/recheck |
| BIOMETRIC-04 | Successful fingerprint/Face ID | unlock once; no duplicate prompts |
| BIOMETRIC-05 | Cancel/failed biometric | remains locked, PIN path works |
| BIOMETRIC-06 | Background during biometric prompt then resume | no stale callback unlock/relock race |
| LOCK-01 | Put app in background/app switcher | finance content hidden immediately |
| LOCK-02 | Repeated pause/resume rapidly | latest lifecycle state wins |
| LOCK-03 | Five+ wrong PIN attempts | throttling/lock window enforced |

## Gate D — Notifications / time

| ID | Test | Expected |
|---|---|---|
| NOTIFY-01 | Permission denied | reminders stay disabled; finance unaffected |
| NOTIFY-02 | Permission granted | expected reminders scheduled |
| NOTIFY-03 | Details disabled | lock-screen text contains no financial detail |
| NOTIFY-04 | Change timezone | next sync uses current device timezone |
| REBOOT-01 | Schedule reminder → reboot Android | managed reminder is restored by plugin receiver |
| REBOOT-02 | App update/reinstall-over existing data where OS permits | no duplicate managed reminder IDs |
| NOTIFY-05 | OEM background restrictions | limitation documented; no financial data corruption |

## Gate E — Recovery / storage catastrophe

| ID | Test | Expected |
|---|---|---|
| RECOVERY-01 | Portable backup → restore same device | exact semantic recovery |
| RECOVERY-02 | Portable backup → restore second device | works with passphrase; device key not required |
| RECOVERY-03 | Wrong backup passphrase | live DB unchanged |
| RECOVERY-04 | Tampered backup | rejected; live DB unchanged |
| RECOVERY-05 | Corrupt active DB with valid local generation | Safe Recovery Mode restores generation |
| RECOVERY-06 | Lost main DB key with independent recovery generation | recovery path remains available |
| STORAGE_FULL-01 | Storage fills during local recovery generation | previous generation remains valid |
| STORAGE_FULL-02 | Storage fills during portable backup write | no published partial backup |
| STORAGE_FULL-03 | Storage fills during restore preflight | live DB not mutated |
| RECOVERY-07 | Force-kill during DB quarantine/replacement | startup marker resolves/rolls back safely |

## Gate F — Upgrade / lifecycle

| ID | Test | Expected |
|---|---|---|
| MIGRATE-01 | Install historical-schema fixture then upgrade | reaches current schema without data loss |
| MIGRATE-02 | Force-kill before migration COMMIT | old schema survives; retry succeeds |
| APP-01 | 100 rapid launch/background/resume cycles | no crash, stale unlock, or DB handle leak |
| APP-02 | Device clock moved forward/backward | recurring healing prevents synthetic flood |
| APP-03 | Locale Indonesian numeric/date input | valid input remains predictable |

## Gate G — Privacy / uninstall / keys

| ID | Test | Expected |
|---|---|---|
| PRIVACY-01 | Android cloud backup/device transfer inspection | Arus app-data excluded |
| PRIVACY-02 | Inspect logs during PIN/backup/restore | no PIN/passphrase/key/financial payload leakage |
| PRIVACY-03 | Explicit local wipe | DB + WAL/SHM + recovery generations/quarantine + keys removed |
| KEY-01 | Simulate Keystore/Keychain access failure | fail closed; critical key not silently regenerated/reset |
| KEY-02 | Uninstall/reinstall | behavior documented; local device-owned data not falsely promised to survive uninstall |

## Required final evidence

Production/store release sign-off must contain:

1. source ZIP SHA-256;
2. `pubspec.lock` hash;
3. Flutter/Dart version;
4. Android Gradle/SDK/JDK versions;
5. Xcode/iOS SDK version;
6. Android signed AAB hash;
7. iOS signed IPA/archive identifier/hash where export permits;
8. completed matrix with device/OS evidence;
9. zero unresolved P0/P1 financial/security/recovery defects.
