# Arus Finance — Version Continuity V1 → V26

V26 adalah kelanjutan satu canonical application, bukan aplikasi baru.

Semua kontrak finansial, local-first, encrypted SQLite, migration, backup/restore, recovery, UX/accessibility, workflow stress, long-session, privacy shield, native readiness, dan V25 pinned Flutter provenance tetap berlaku.

V26 menambahkan kontrak carry-forward berikut:

1. seluruh external GitHub Actions `uses:` harus memakai full 40-character audited SHA;
2. action pins disimpan di manifest terpisah dan executable verifier harus PASS;
3. `pubspec.lock` harus committed sebelum native verification;
4. dependency lock bootstrap hanya manual dan hasilnya review-only candidate;
5. native verification menggunakan `--enforce-lockfile` dan tidak boleh menyelesaikan graph baru;
6. Android/iOS harus membuktikan byte-identical committed lock sebelum compile;
7. release-readiness report harus memisahkan SOURCE, LOCK, COMPILE, DEVICE, STORE;
8. stale evidence harus ditolak bila canonical source/lock berubah;
9. physical-device status tidak boleh diturunkan dari compile/store evidence;
10. V26 executable audits dan documentation handoff harus tetap ada pada semua milestone berikutnya.
