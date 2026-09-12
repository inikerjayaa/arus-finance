# BUG HUNT — V26 Release Orchestration

## Temuan

### 1. Mutable GitHub Action tags
V25 memakai exact semver tags. Exact semver lebih baik daripada floating major tag, tetapi masih bukan immutable action reference. V26 mengganti seluruh external `uses:` ke full 40-character commit SHA dan menambahkan executable pin verifier.

### 2. Lockfile reproducibility hanya berlaku di dalam satu CI run
V25 membuat `pubspec.lock` di job pertama lalu membagikannya ke Android/iOS. Ini menjaga konsistensi lintas platform pada run yang sama, tetapi dependency resolution dapat berbeda pada run berikutnya. V26 memisahkan manual lock bootstrap dari normal verification dan mewajibkan committed lockfile.

### 3. Release status belum teragregasi dari evidence
V26 menambahkan release-readiness report yang menolak evidence stale dan menjaga SOURCE / LOCK / COMPILE / DEVICE / STORE sebagai status terpisah.

## Runtime impact

Tidak ada perubahan pada `lib/`, schema database, financial semantics, backup, restore, migration, atau recovery engine.

## Status

LOCKED setelah seluruh V1→V26 continuity + non-native regression suite PASS.
