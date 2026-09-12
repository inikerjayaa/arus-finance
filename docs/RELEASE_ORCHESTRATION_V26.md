# Arus Finance V26 — Release Orchestration & Immutable CI Supply Chain

## Tujuan

V26 tidak mengklaim native compiler/device/store PASS. V26 memperkeras handoff V25 supaya ketika source dijalankan pada host native, dependency graph, GitHub Actions supply chain, evidence, dan status release semuanya fail-closed dan dapat diverifikasi ulang.

## Koreksi atas V25

1. **GitHub Actions sekarang dipin ke full 40-character commit SHA.** Tag semver tetap dicatat sebagai komentar manusia, tetapi workflow tidak mengeksekusi tag mutable.
2. **`pubspec.lock` harus committed sebelum native verification.** Native verification tidak lagi membuat lockfile baru setiap run.
3. **Dependency Lock Bootstrap dipisahkan menjadi workflow manual.** Workflow ini hanya menghasilkan kandidat lockfile untuk review; kandidat bukan compile/release proof.
4. **Android dan iOS membandingkan lockfile checkout dengan artifact lock yang diverifikasi.** Keduanya wajib membangun source dengan graph dependency committed yang sama.
5. **Release readiness menjadi status terukur.** SOURCE, DEPENDENCY_LOCK, Android/iOS COMPILE, DEVICE, dan STORE tidak boleh disimpulkan satu sama lain.

## GitHub Actions immutable pins

Pin manifest: `toolchain/github_actions_pins.json`

- `actions/checkout` v7.0.1 → `3d3c42e5aac5ba805825da76410c181273ba90b1`
- `actions/upload-artifact` v7.0.1 → `043fb46d1a93c77aae656e7c1c64a875d1fc6a0a`
- `actions/download-artifact` v8.0.1 → `3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c`
- `actions/setup-java` v6.0.1 → `de7274f081f381c8f8158605e0321c36c376e2e6`

`tool/verify_ci_action_pins.py` menolak:

- semver tag seperti `@v7.0.1`;
- SHA yang bukan 40 hex;
- action yang belum ada di audited pin manifest;
- SHA yang berbeda dari pin manifest;
- pin manifest yang sudah tidak dipakai workflow.

Dependabot tetap boleh membuka PR update GitHub Actions melalui `.github/dependabot.yml`, tetapi update tidak otomatis dipercaya: SHA + human version harus di-review dan audit V26 harus PASS lagi.

## Dependency lock flow

### First lock bootstrap

Jalankan workflow manual **Arus Dependency Lock Bootstrap** hanya ketika `pubspec.lock` belum committed.

Workflow tersebut:

1. memasang Flutter 3.47.2 dari official pinned archive;
2. memverifikasi Flutter/Dart pin;
3. menjalankan satu kali `flutter pub get`;
4. menghasilkan `pubspec.lock`, SHA-256, dan warning bahwa artifact hanya kandidat;
5. user/reviewer memeriksa perubahan dependency dan commit `pubspec.lock` ke repository.

### Native verification

`Arus Native Verification` sekarang langsung FAIL jika `pubspec.lock` tidak ada di checkout.

Setelah lock committed:

1. `flutter pub get --enforce-lockfile`;
2. non-native audits;
3. `flutter analyze`;
4. `flutter test`;
5. upload exact committed lock + hash;
6. Android dan iOS download artifact tersebut;
7. masing-masing membandingkan byte-for-byte dengan `pubspec.lock` checkout;
8. compile evidence kedua platform harus sepakat pada canonical source + lock hash + pinned toolchain.

## Release truth states

`tool/release_readiness_report.py` memisahkan:

- `SOURCE_NON_NATIVE`
- `DEPENDENCY_LOCK`
- `ANDROID_COMPILE`
- `IOS_COMPILE`
- `CROSS_PLATFORM_COMPILE`
- `DEVICE_VALIDATION`
- `ANDROID_STORE_ARTIFACT`
- `IOS_STORE_ARTIFACT`
- `STORE_ARTIFACTS`

Evidence lama otomatis menjadi `STALE` jika canonical source hash atau committed lock hash berubah.

Physical-device PASS tidak boleh diinfer dari compiler/store artifact. Device evidence harus mencakup Android **dan** iOS dan cocok dengan source + lock yang sama.

## One-command orchestration

- `bash tool/release_orchestrator.sh source` — immutable-pin check + seluruh non-native audit + readiness report.
- `bash tool/release_orchestrator.sh status` — tampilkan readiness tanpa mengklaim source PASS baru.
- `bash tool/release_orchestrator.sh compile android|ios|all` — jalankan native compile gate lalu refresh readiness.
- `bash tool/release_orchestrator.sh store android|ios|all` — jalankan store-release gate lalu refresh readiness.

## Current truthful status in this package

Karena source V26 belum dapat menjalankan Flutter pada host ChatGPT ini dan `pubspec.lock` belum pernah dihasilkan oleh Flutter 3.47.2:

- SOURCE / NON-NATIVE: harus dibuktikan oleh audit V26 package;
- DEPENDENCY_LOCK: **BLOCKED** sampai candidate dihasilkan, direview, dan committed;
- Android COMPILE: **UNPROVEN**;
- iOS COMPILE: **UNPROVEN**;
- DEVICE: **UNPROVEN**;
- STORE: **UNPROVEN**.

Ini adalah blocker eksternal yang disengaja dan lebih aman daripada CI yang menyelesaikan dependency graph baru diam-diam setiap run.
