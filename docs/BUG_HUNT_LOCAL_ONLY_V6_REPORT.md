# Bug Hunt Report — Local-Only V6 Harvest

## Product direction

Arus remains 100% device-owned/local-first. Core finance features require no login, server, cloud database, or internet.

## Newly implemented

1. Safe CSV import from Arus export format with preview before commit.
2. Import limit: 10 MB / 5,000 rows per operation.
3. Safe import supports simple POSTED expense/income only; transfers are rejected rather than guessed.
4. Import never creates unknown accounts/categories silently.
5. Exported Transaction ID is preserved when importing.
6. Re-importing the same Transaction ID is idempotent when content matches.
7. Same Transaction ID with different content is a hard conflict and rolls the entire import batch back.
8. Import fingerprint metadata is included in new encrypted backups but remains optional when restoring older backups.
9. Local notification service added for Bills and recurring drafts.
10. Notification permission is requested only when the user enables local reminders.
11. Notification content is privacy-safe by default; lock-screen body does not expose name/amount.
12. Showing detailed notification content is explicit opt-in.
13. Notification schedule state stored in SharedPreferences is a SHA-256 digest, not raw finance text.
14. Inexact Android scheduling is used; exact-alarm permission is intentionally not requested.
15. Android native hardening now configures notification permission, boot receiver, scheduled receiver, Java 17, core-library desugaring and raw-backup exclusion.
16. Recurring materialization is forced to DRAFT even for historical AUTO_CREATE rules; balance changes only after explicit posting.
17. Timeline index added for large history.
18. CSV export now writes UTC timestamps and uses the current csv 8.x API.
19. Fixed a duplicate local variable in category archive flow that could have become a Dart compile blocker.

## Executable non-native audits PASS

- financial reference contract;
- local-only production contract;
- Dart structural/import audit;
- Dart delimiter/string/comment audit;
- crash-before-COMMIT durability;
- SQLITE_FULL atomic rollback;
- fresh schema v6;
- legacy local-only v3 migration semantics;
- CSV identity/idempotency/conflict atomicity;
- local notification privacy/native contract;
- 100k-transaction timeline query-plan audit;
- native-hardening fixture, including second-run idempotency.

## Validation boundary

Still not claimed PASS until a real Flutter/native toolchain is available:

- `flutter pub get`;
- `flutter analyze`;
- `flutter test`;
- Android Gradle/APK/AAB build;
- iOS Xcode build;
- physical-device notification, biometric, encrypted-database and performance tests.
