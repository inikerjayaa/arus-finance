# SAKU — Android Physical UAT Evidence — 2026-09-19

Status dokumen ini sengaja dibedakan antara bukti yang sudah dilakukan secara fisik dan item yang masih harus dikonfirmasi. Jangan menaikkan status menjadi `DEVICE PASS (Android)` sebelum semua item wajib di bawah selesai.

## Kandidat build

- Main SHA: `07aae2fc5297f8f18961fac631b017e38181f5db`
- Workflow run: `#267` (`35333694588`)
- APK artifact: `arus-android-device-uat-apk-compile-only`
- APK SHA-256: `375fdf145173fb32f0abd15028a3d21bcf0c59b98e0ab0094f31f421b4265aed`
- APK signing certificate SHA-256: `539a71b0638f144393a23c365acd0f3f6990132e1b6781279734bd53d6f21873`
- Physical device: Vivo 1915
- Android: 12

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

## Temuan non-blocking untuk tahap final copy/cosmetic polish

- Wrong-passphrase restore saat ini masih menampilkan detail exception kriptografi mentah (`SecretBoxAuthenticationError` / MAC) setelah pesan aman. Ini tidak mengubah data dan akan dihumanisasi pada tahap final copy polish.
- Beberapa label lama `Arus Finance` masih terlihat di area Settings/About dan akan dibersihkan pada tahap final branding/copy polish.
- Copy/helper yang berlebihan, contoh placeholder yang tidak perlu, istilah teknis seperti `passphrase`, spacing, typography, light/dark mode refinement, dan konsistensi visual disimpan untuk tahap kosmetik akhir.

## Masih perlu bukti fisik eksplisit sebelum DEVICE PASS

- [ ] Launcher name benar-benar tampil `SAKU` pada home screen Vivo.
- [ ] Launcher icon SAKU tampil normal; adaptive/round mask tidak terpotong secara abnormal.
- [ ] Native splash Noturno + mark SAKU tampil pada cold start dan tidak menampilkan fake status bar / glitch abnormal.
- [ ] Portable backup baru masih dapat dibuat dari kandidat final setelah restore/clean-install.
- [ ] Exact full backup SHA-256 dicatat ke evidence record bila ingin menutup record secara lengkap.

## Status saat ini

`ANDROID PHYSICAL UAT: CORE PASS — FINAL DEVICE EVIDENCE PENDING`

Belum boleh ditulis `DEVICE PASS (Android)` sampai item pending di atas dikonfirmasi.
