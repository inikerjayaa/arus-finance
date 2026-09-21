# SAKU — Android Physical UAT Evidence — 2026-09-19

Status dokumen ini sengaja dibedakan antara bukti yang sudah dilakukan secara fisik dan item yang masih harus dikonfirmasi. Jangan menaikkan status menjadi `DEVICE PASS (Android)` sebelum semua item wajib di bawah selesai.

## Kandidat build awal yang sudah diuji fisik

- Main SHA: `07aae2fc5297f8f18961fac631b017e38181f5db`
- Workflow run: `#267` (`35333694588`)
- APK artifact: `arus-android-device-uat-apk-compile-only`
- APK SHA-256: `375fdf145173fb32f0abd15028a3d21bcf0c59b98e0ab0094f31f421b4265aed`
- APK signing certificate SHA-256: `539a71b0638f144393a23c365acd0f3f6990132e1b6781279734bd53d6f21873`
- Physical device: Vivo 1915
- Android: 12

## Kandidat V48 final untuk re-UAT kosmetik

- Main SHA: `869484ca9217ee87676361d30d4a79aae7216fd3`
- Native Verification: `#320` (`35539795329`) — SUCCESS
- Stable Device UAT APK: `#48` (`35540289052`) — SUCCESS
- APK artifact: `saku-android-device-uat-stable`
- Artifact digest SHA-256: `320ec73059c8dd29e227f24167f590c308fb3a724699e232f303a02c0257c1c9`
- Artifact expires: `2026-10-04T22:07:38Z`
- Physical target tetap: Vivo 1915 / Android 12

Kandidat V48 inilah yang harus dipakai untuk menutup evidence visual/device. Jangan memakai APK kandidat lama untuk keputusan `DEVICE PASS` final.

## Bukti yang sudah PASS

- Encrypted portable backup dibuat dari device utama dan disalin ke PC.
- Hash backup dihitung di PC sebelum operasi destruktif.
- Fresh Android 12 / API 31 emulator dibuat sebagai restore rehearsal target.
- Kandidat APK berhasil di-install sebagai clean install di emulator.
- Wrong-passphrase restore ditolak dan data aktif tidak rusak.
- Restore dengan passphrase benar berhasil.
- Semantic data setelah restore dibandingkan dengan device utama dan dinyatakan sama oleh user.
- `adb install -r` pada device utama mendeteksi `INSTALL_FAILED_UPDATE_INCOMPATIBLE` karena signer build lama berbeda; proses dihentikan sesuai runbook sebelum uninstall.
- Setelah restore rehearsal PASS, clean-install migration pada Vivo dilakukan secara sengaja.
- Kandidat APK final berhasil di-install pada Vivo.
- Backup berhasil dipulihkan pada Vivo.
- Core physical smoke dilaporkan PASS oleh user: app restart, lock/PIN/biometric path, background/resume, controlled transaction create/edit/delete, dan integrity check.

## Temuan kosmetik yang sudah ditangani di V48

- Copy restore tidak boleh membocorkan exception kriptografi mentah ke UI.
- Residual user-facing `Arus` telah diaudit/dibersihkan tanpa mengganti compatibility/storage keys internal `arus_*`.
- Theme, typography, spacing, card/CTA hierarchy, dan light/dark presentation mengikuti root `DESIGN.md`.
- Native Android 12+ splash generator menggunakan Noturno + SAKU mark melalui system splash API; tidak memakai artificial delay/timer.

Item di atas sudah lolos automated/native verification, tetapi hasil visual akhirnya tetap harus dikonfirmasi pada perangkat fisik.

## Re-UAT V48 — bukti fisik wajib sebelum DEVICE PASS

Lakukan dari kandidat V48 final di atas. Untuk splash, force-stop aplikasi terlebih dahulu agar yang diuji benar-benar cold start.

- [ ] Launcher name tampil `SAKU` pada home screen Vivo.
- [ ] Launcher icon SAKU tampil normal; adaptive/round mask tidak terpotong abnormal.
- [ ] Cold start menampilkan native splash Noturno + SAKU mark dengan jelas sebelum lock/PIN; tidak ada blank/dark glitch atau fake status bar.
- [ ] Light mode: dashboard/home, transaksi, settings, dan lock/security tidak overflow, clip, atau kehilangan kontras.
- [ ] Dark mode: layar yang sama tetap terbaca; selected/disabled/destructive states jelas dan tidak menjadi neon/noisy.
- [ ] Primary CTA jelas dan touch target penting tetap nyaman pada layar Vivo.
- [ ] Portable backup baru masih dapat dibuat dari kandidat V48 setelah restore/clean-install.
- [ ] Exact full backup SHA-256 dicatat ke evidence record bila ingin menutup record secara lengkap.

Jika salah satu item visual gagal, catat layar + langkah reproduksi dan jangan mengubah finance/domain/storage semantics sebagai workaround kosmetik.

## Status saat ini

`ANDROID PHYSICAL UAT: CORE PASS — V48 FINAL DEVICE EVIDENCE PENDING`

Belum boleh ditulis `DEVICE PASS (Android)` sampai checklist V48 di atas dikonfirmasi.
