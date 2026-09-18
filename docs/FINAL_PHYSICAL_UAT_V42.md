# SAKU — Final Physical UAT Runbook (V42)

Tujuan dokumen ini adalah menutup gap antara **CI/compile proof** dan **physical-device proof** tanpa mempertaruhkan data finansial utama milik user.

Dokumen ini melengkapi `docs/NATIVE_VALIDATION_MATRIX.md`. CI tidak boleh dianggap `DEVICE PASS`.

## 0. Aturan keselamatan yang tidak boleh dilewati

1. **Jangan uninstall SAKU, jangan Clear storage/Clear data, dan jangan factory-reset device utama sebelum encrypted portable backup berhasil dibuat, disalin keluar app/device-private storage, dan berhasil direstore di fresh environment.**
2. Simpan backup asli sebagai immutable master. Untuk eksperimen restore/tamper gunakan salinan file, bukan file master.
3. Jangan pernah menulis PIN, backup passphrase, database key, atau secret signing key ke screenshot, log, issue, commit, atau chat.
4. Jika APK baru gagal `adb install -r` karena signature mismatch, **STOP**. Jangan menyelesaikannya dengan uninstall sebelum restore rehearsal lulus.
5. Semua mismatch saldo, jumlah transaksi, akun, kategori, recurring/bill state, atau custom icon setelah restore adalah **FAIL** sampai penyebab ditemukan.

## 1. Kunci kandidat build sebelum menyentuh HP

Gunakan hanya workflow `Arus Native Verification` yang berjalan pada branch `main` dan source SHA yang sama dengan commit `main` yang hendak diuji.

Android artifact untuk UAT fisik:

- artifact: `arus-android-device-uat-apk-compile-only`
- APK: `app-release.apk`
- checksum: `android-device-uat-apk.sha256`
- signing evidence: `android-device-uat-apk-signing.txt`

Sebelum install, catat:

```text
MAIN_SHA=
WORKFLOW_RUN=
APK_SHA256=
APK_SIGNING_CERT_FINGERPRINT=
DEVICE_MODEL=
ANDROID_VERSION=
```

### Verifikasi APK — cara utama

Setelah ZIP artifact diekstrak, dari root repo jalankan:

```powershell
python .\tool\verify_device_uat_artifact.py "C:\path\ke\folder-artifact"
```

Expected:

- output `PASS: Android device-UAT APK checksum matches CI evidence`;
- `APK_SHA256=` tercetak;
- fingerprint certificate SHA-256 ditampilkan bila format output `apksigner` dikenali.

Verifier ini hanya membaca file artifact. Ia tidak meng-install APK dan tidak menyentuh device.

### Verifikasi manual di Windows PowerShell

Jika ingin cek manual:

```powershell
Get-FileHash .\app-release.apk -Algorithm SHA256
Get-Content .\android-device-uat-apk.sha256
Get-Content .\android-device-uat-apk-signing.txt
```

Nilai SHA-256 APK harus sama persis dengan file checksum dari CI.

## 2. Backup device utama — non-destruktif

Di SAKU yang masih berisi data saat ini:

1. Buka app dan pastikan data utama tampil normal.
2. Buat **encrypted portable backup** menggunakan passphrase yang hanya diketahui user.
3. Export backup ke lokasi yang berada di luar private app storage.
4. Copy backup ke PC/drive eksternal sebelum melanjutkan.
5. Pastikan file backup memiliki ukuran > 0 dan dapat dibaca/copied oleh OS.
6. Hash file backup di PC dan catat hasilnya.

Contoh PowerShell:

```powershell
Get-FileHash "C:\path\ke\backup-saku" -Algorithm SHA256
```

Catat:

```text
BACKUP_FILE=
BACKUP_SHA256=
BACKUP_CREATED_AT=
```

**Belum boleh uninstall app pada tahap ini.**

## 3. Restore rehearsal di fresh environment — wajib sebelum operasi destruktif

Fresh environment yang disarankan:

1. Android kedua yang tidak berisi data penting; atau
2. Android emulator fresh di PC untuk membuktikan portability/semantic restore.

Install kandidat APK sebagai clean install pada target fresh:

```powershell
adb install .\app-release.apk
```

Lakukan urutan ini:

1. Sebelum restore benar, coba passphrase yang salah.
   - Expected: restore ditolak.
   - Expected: database fresh tidak menjadi setengah-terisi.
2. Restore salinan encrypted backup dengan passphrase yang benar.
3. Tutup app sepenuhnya lalu buka lagi.
4. Bandingkan data semantic dengan device utama.

Minimum comparison:

| Data | Expected |
|---|---|
| Account list | sama |
| Balance per account | sama |
| Total saldo | sama |
| Transaction count/history | sama |
| Categories | sama |
| Bills / recurring state | sama |
| Dashboard preferences | tidak merusak data keuangan |
| Custom local icons | kembali bila termasuk backup |
| PIN/biometric behavior | aman; device-bound secret tidak boleh membuat data finansial hilang |

Restore rehearsal dinyatakan **PASS** hanya jika data semantic cocok dan app tetap normal setelah restart.

## 4. Update-in-place device utama

Hanya setelah backup eksternal + restore rehearsal PASS.

Hubungkan device utama lalu coba:

```powershell
adb devices
adb install -r .\app-release.apk
```

### Jika update berhasil

Jangan uninstall. Lanjutkan smoke test pada bagian 6.

### Jika muncul signature mismatch / UPDATE_INCOMPATIBLE

1. STOP.
2. Pastikan kembali backup master masih ada di PC dan hash-nya sama.
3. Pastikan restore rehearsal sebelumnya PASS.
4. Baru lakukan clean-install path sebagai UAT migrasi yang disengaja.

Clean-install path adalah operasi destruktif pada local app data; jangan lakukan bila backup atau restore rehearsal belum PASS.

## 5. Clean-install + restore pada device utama — hanya bila memang diperlukan

Setelah seluruh guard di atas PASS:

1. Pastikan backup master masih tersimpan di PC.
2. Catat kondisi terakhir device utama.
3. Uninstall build lama hanya jika memang diperlukan untuk signature/clean-install UAT.
4. Install kandidat APK baru.
5. Buka SAKU sebagai fresh install.
6. Restore encrypted backup.
7. Restart app.
8. Bandingkan semantic data lagi seperti bagian 3.

Jika restore gagal atau data berbeda, status release = **FAIL**. Jangan membuat data finansial baru di environment gagal tersebut sebelum investigasi selesai.

## 6. Final Android physical smoke

Pada build kandidat final di device utama:

- [ ] launcher name = `SAKU`
- [ ] launcher icon = SAKU; tidak ada ikon Flutter default
- [ ] adaptive/round icon tidak terpotong secara abnormal
- [ ] native splash Noturno + mark SAKU tampil tanpa fake status bar
- [ ] Flutter first frame lanjut mulus tanpa artificial delay
- [ ] PIN unlock PASS
- [ ] fingerprint/biometric unlock PASS bila tersedia
- [ ] cancel biometric tetap locked
- [ ] background → foreground tidak membocorkan finance content
- [ ] tambah/edit/hapus transaksi test terkontrol tetap reconcile
- [ ] account/category/icon rendering normal
- [ ] scheduled reminder permission path tidak merusak fungsi finansial
- [ ] portable backup baru masih dapat dibuat setelah restore/update
- [ ] app restart beberapa kali tanpa crash/data berubah

Untuk test transaksi, gunakan data UAT yang mudah dikenali dan hapus/koreksi setelah verifikasi; jangan gunakan angka yang dapat tertukar dengan transaksi nyata.

## 7. Evidence record Android

```text
STATUS: PASS / FAIL
MAIN_SHA:
WORKFLOW_RUN:
APK_SHA256:
APK_SIGNING_CERT_FINGERPRINT:
DEVICE_MODEL:
ANDROID_VERSION:
INSTALL_PATH: update-in-place / clean-install+restore
BACKUP_SHA256:
RESTORE_REHEARSAL_TARGET:
RESTORE_REHEARSAL_RESULT:
FINAL_RESTORE_RESULT:
PIN_RESULT:
BIOMETRIC_RESULT:
LOCK_BACKGROUND_RESULT:
FINANCIAL_SMOKE_RESULT:
BRANDING_SPLASH_ICON_RESULT:
OPEN_P0_P1_DEFECTS:
NOTES:
```

`DEVICE PASS (Android)` hanya boleh dicatat bila evidence di atas lengkap dan tidak ada unresolved P0/P1 financial/security/recovery defect.

## 8. iOS boundary

`iOS release-mode no-codesign compile proof` dari CI adalah **COMPILE PASS**, bukan physical iOS `DEVICE PASS` dan bukan App Store release proof.

Final iOS sign-off tetap membutuhkan:

- signed build pada signing-configured macOS/Xcode environment;
- install pada physical iPhone supported;
- Face ID/app-lock lifecycle smoke;
- encrypted backup restore test;
- final semantic financial smoke;
- signed IPA/archive evidence untuk store-release gate.

## 9. Stop conditions

Hentikan UAT dan jangan lanjut ke release bila salah satu terjadi:

- backup file tidak bisa dipindahkan keluar device;
- backup hash berubah tanpa alasan;
- wrong-passphrase restore memutasi live/fresh DB;
- restore benar menghasilkan saldo/history berbeda;
- app meminta uninstall sebelum backup terbukti restorable;
- PIN/biometric dapat dilewati;
- finance content terlihat di background/app switcher ketika protection aktif;
- launcher/splash build tidak sesuai kandidat SAKU final;
- crash, migration failure, atau data corruption ditemukan.

## 10. Status release setelah V42

- CI green = **CI PROVEN**
- Android checklist ini PASS = **DEVICE PASS (Android)**
- iOS physical checklist PASS = **DEVICE PASS (iOS)**
- store signing gates PASS = **STORE RELEASE PASS**

Tidak ada status yang boleh dinaikkan hanya berdasarkan asumsi dari gate di bawahnya.
