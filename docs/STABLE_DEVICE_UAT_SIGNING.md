# SAKU — Stable Device UAT Signing

## Tujuan

Workflow `SAKU Stable Device UAT APK` menghasilkan APK UAT Android dengan identitas signing yang stabil antar-build agar kandidat baru dapat di-install langsung sebagai update pada device UAT tanpa ADB dan tanpa uninstall/restore berulang.

Key ini khusus **device UAT**. Ia bukan Play Store upload key dan bukan production release key.

## Safety boundary

- Jangan commit `.jks`, `.keystore`, password, base64 key, atau `android/key.properties`.
- Jangan kirim key/password melalui issue, commit, screenshot, log, atau chat.
- Production/store signing tetap memakai identity terpisah.
- Jika UAT key hilang atau diganti, Android akan menolak update atas build UAT lama; gunakan backup/restore path sebelum operasi destruktif.

## One-time setup di Windows

Gunakan `keytool` dari JDK/Android Studio. Buat key dengan alias **tepat** `saku-uat` dan gunakan password yang sama untuk keystore + key:

```powershell
keytool -genkeypair -v `
  -keystore "$env:USERPROFILE\SAKU-UAT.jks" `
  -alias saku-uat `
  -keyalg RSA `
  -keysize 2048 `
  -validity 10000 `
  -dname "CN=SAKU UAT,O=SAKU,C=ID"
```

Masukkan password secara interaktif; jangan menuliskannya ke command history.

Salin base64 ke clipboard tanpa menampilkan isinya:

```powershell
[Convert]::ToBase64String(
  [IO.File]::ReadAllBytes("$env:USERPROFILE\SAKU-UAT.jks")
) | Set-Clipboard
```

Di GitHub repository → Settings → Secrets and variables → Actions, buat repository secrets:

- `SAKU_UAT_KEYSTORE_B64` = paste base64 dari clipboard.
- `SAKU_UAT_KEYSTORE_PASSWORD` = password keystore yang tadi dibuat.

Jangan gunakan key/password production.

## Workflow behavior

Workflow berjalan setelah `Arus Native Verification` sukses di branch `main`, lalu:

1. checkout source SHA `main` yang sudah dibuktikan CI;
2. regenerate hardened native shell;
3. materialize UAT keystore hanya di temporary runner storage;
4. patch release signing memakai `tool/configure_android_release_signing.py`;
5. fail closed bila signing config tidak valid atau APK masih memakai `Android Debug` signer;
6. build dan verify APK;
7. upload artifact `saku-android-device-uat-stable` dengan checksum, signing evidence, dan exact source SHA;
8. menghapus materialized signing files dari workspace runner.

## Device behavior

Selama key tidak diganti, build UAT berikutnya dapat dipasang langsung dari file manager/browser Android di atas build UAT sebelumnya. Data aplikasi tetap berada di sandbox yang sama karena package identity tidak berubah.

Tetap buat encrypted portable backup sebelum kandidat yang mengubah schema/data-critical behavior diuji pada device utama.
