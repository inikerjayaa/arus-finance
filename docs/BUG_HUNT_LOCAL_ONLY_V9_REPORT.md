# Arus Finance — Local-Only V9 Deep Mine Report

## Milestone intent
V9 memperdalam reliability local-only. Fokusnya bukan fitur kosmetik, tetapi lifecycle transaksi, recovery planning, cleanup data era sync, dan kualitas audit.

## Perbaikan utama
- Delete transaksi sekarang hard-delete fisik untuk build local-only.
- VOID tetap tersedia sebagai pilihan jika user ingin jejak historis.
- Hard-delete membersihkan recurring occurrence link dan Bill payment link secara atomik.
- Refund aktif memblok penghapusan original; refund VOID dapat ikut dibersihkan ketika original dihapus.
- Full refund atas payment Bill membuka kembali Bill berdasarkan due date.
- Partial refund mempertahankan Bill PAID.
- VOID/delete refund merekonsiliasi ulang status Bill dari canonical data.
- Bill yang payment lamanya sudah fully-refunded boleh dibayar ulang.
- Recurring cursor yang terdorong >2 bulan ke depan akibat device-clock error dipulihkan ke kalender bulan berjalan.
- Backup input dibatasi 64 MiB untuk mengurangi risiko memory spike.
- Backup semantic validation ditambah: orphan posted refund, over-refund, dan PAID Bill yang payment-nya tidak valid/fully-refunded.
- Schema v9 membersihkan tombstone `deleted_at` era sync untuk user yang upgrade.
- Restore backup lama menjalankan cleanup local-only yang sama sebelum integrity validation.
- Compile-risk audit baru mendeteksi duplicate method/declaration/statement patch artefacts.
- Migration audit parser diperbaiki agar double-quoted Dart migration strings benar-benar dieksekusi.
- Fixture V8→V9 membuktikan cleanup tombstone tanpa menghapus transaksi aktif.

## Audit status
Seluruh audit non-native pada milestone ini PASS.

Native Flutter analyzer/test, Android Gradle, APK/AAB, Xcode dan physical-device tests masih memerlukan toolchain native dan tidak diklaim PASS pada milestone ini.
