# Arus Finance

> **Prinsip produk:** data finansial tetap berada dalam kendali pengguna dan perangkatnya.
>
> **Tagline publik:** TBD — akan dipilih kemudian tanpa mengubah prinsip arsitektur.

Arus Finance adalah aplikasi personal finance **100% local-first / device-owned**.
Tidak membutuhkan akun, login, cloud database, atau internet untuk fungsi inti.
Data finansial disimpan pada database lokal terenkripsi di perangkat pengguna.
Backup resmi berbentuk file `.arusbackup` terenkripsi yang dibuat dan disimpan sendiri oleh pengguna.

Working product name: **Arus**.

An offline-first personal finance app for Android/iOS derived from `docs/MASTER_BLUEPRINT_FINAL_V2.md`.

## What is implemented in this repository

- Local-first encrypted SQLite architecture (sqlite3mc build hook + key in secure storage).
- Ledger-derived balances using integer minor units.
- Expense, income, asset transfer, transfer fee, refund, adjustment/opening balance.
- Credit-card payment and loan domain operations in repository layer.
- Local-only hard-delete for user deletion, explicit VOID for retained history, and versioned transactions.
- Budget actuals, bills, recurring rules with deterministic occurrence de-duplication.
- Dashboard, quick entry, transaction timeline/detail, account/category management, planning, insights.
- PIN/biometric service with retry throttling, portable encrypted backup, local integrity check, streamed CSV export + safe CSV import.
- Differential local Bill/recurring reminders with finance details hidden by default.
- Encrypted local FTS5 transaction search for large histories; the index is derived/rebuildable from canonical ledger data.
- No cloud/outbox dependency in the production runtime; any old cloud experiments live outside `lib/` and are non-production.
- Backup restore semantic firewall validates canonical transaction shapes/account semantics before replacement.
- V12 restore hardening authenticates expected backup metadata, repairs legacy local-only tombstones, validates calendar/planning/refund/recurring semantics, and rolls back invalid replacement data atomically.
- V13 catastrophe-recovery hardening migrates true historical schemas before ensuring current indexes, fails closed on missing DB keys/schema metadata, snapshots backups consistently, and normalizes old portable-backup data before current validation.
- V14 data-survival hardening adds app-lock-protected Safe Recovery Mode, DB/WAL/SHM quarantine rollback, AES-GCM local recovery generations, pre-restore rollback points, staged recovery markers, and storage-full-safe publishing.
- V15 native-readiness hardening closes Android biometric runner/theme gaps, strengthens app-lock lifecycle ordering, fails reminder timezone resolution closed, prevents secure-storage auto-reset of critical keys, and adds a reproducible native release gate.
- V16 truthful-native-gate hardening stages generated shells outside canonical source, separates compile proof from store-release proof, blocks silent iOS skips, requires explicit Android upload signing, and hides biometric unlock when no biometric is actually enrolled.
- V17 native-execution hardening pins Flutter 3.47.2, modernizes iOS to SwiftPM-first preflight, adds UIScene post-build verification, keytool-backed Android signing proof, and secret-free hashed native build evidence.
- V18 production UX/accessibility hardening adds route-owned navigation, domain-safe Quick Add account choices, inline/live validation, large-text-safe layouts, truthful destructive-action copy, explicit confirmations, and executable Flutter accessibility guideline tests.
- V19 daily-workflow stress hardening separates committed writes from presentation refresh failures, queues resume work across active writes, protects Quick Add from rapid submit/accidental discard, and aligns transaction edit/posting UI with repository rules.
- V20 long-session hardening adds newest-request-wins timeline/full-refresh guards, serialized de-duplicated pagination, and dashboard recent-state isolation.
- V21 rebuild isolation keeps routine controller changes below the MaterialApp/Navigator root while preserving shell/fatal-recovery reactivity.
- V22 timeline query/filter/result state commits atomically only after the newest database request succeeds.
- V23 sensitive-UI privacy hardening adds Android FLAG_SECURE plus an inactive/background privacy shield for app-switcher snapshots.
- V24 is the pre-native release-candidate freeze: runtime behavior is unchanged from V23; documentation, regression gates, and handoff evidence are synchronized before compiler/device execution.
- V25 adds an official-archive pinned Flutter/Dart CI installer, shared dependency-lock compile matrix, cross-platform native evidence consistency, and corrects the active Flutter 3.47.2 iOS deployment floor to 15.0.
- V26 hardens the native handoff with immutable full-SHA GitHub Actions pins, a review-and-commit dependency-lock bootstrap, enforce-lockfile verification, and hash-bound release readiness states that fail closed on stale or missing evidence.
- V27 adds a deterministic Git bootstrap: LF-normalized canonical tree, secret/build-residue guard, reproducible Git commit/tag, portable bundle, and commit/tree/file-hash verification before any future repository import.
- Centralized integer-money safety envelope is enforced by parser/import/repository/restore layers before SQLite writes.
- Reference financial model, executable non-native audits, and automated Flutter invariant tests.

## Capability gating

AI, OCR, family sharing, bank integrations, advanced investments, dan eksperimen online apa pun tetap capability-gated sampai schema/use-case/error/test contract-nya lengkap. This follows the Master Blueprint rule: **no empty button**.

## Run locally

The repository intentionally does not contain hand-written generated Android/iOS runner templates. On a machine with Flutter installed:

```bash
./bootstrap.sh
flutter run
```

Read `docs/NATIVE_SETUP.md` first. V17+ `bootstrap.sh` generates Android/iOS shells in a temporary staging directory first, then copies only those native folders into Arus so `flutter create` cannot rewrite canonical Dart/docs/tool sources.

## Brand note

Kalimat **“Data Anda aman bersama Anda sendiri”** adalah prinsip desain produk, bukan tagline final.
Tagline publik akan dipilih kemudian. Mengganti tagline tidak boleh mengubah keputusan arsitektur berikut:

- local-first / device-owned;
- tidak perlu login;
- tidak perlu server/cloud untuk fungsi inti;
- data finansial tidak dikirim ke pengembang;
- backup terenkripsi adalah milik pengguna.
