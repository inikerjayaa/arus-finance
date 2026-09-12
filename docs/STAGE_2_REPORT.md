# Stage 2 Report — Transaction Control & Personalization

## Scope completed

### Advanced transaction filter

UI → repository → SQLite filter contract telah terhubung.

Filter dapat dikombinasikan:

- free text;
- transaction type;
- status;
- account;
- category;
- start/end date;
- minimum/maximum amount.

Filter hanya memengaruhi hasil list. Ledger/dashboard canonical data tidak berubah.

### Liability actions

Ditambahkan screen **Aksi Finansial** untuk:

- pembayaran kartu kredit;
- pencairan pinjaman;
- pembayaran pinjaman.

Pembayaran pinjaman memisahkan:

```text
principal = liability settlement
interest  = expense
fee       = expense
```

Principal yang melebihi outstanding loan ditolak.

Credit-card overpayment diperbolehkan hanya setelah warning karena dapat menghasilkan credit balance.

### Dashboard customization

Widget dashboard dapat:

- diaktifkan/nonaktifkan;
- diubah urutannya;
- di-reset ke default;
- disimpan secara lokal.

Widget tetap menggunakan `DashboardData` yang berasal dari repository/ledger, bukan angka dummy.

## Validation performed

- changed-file delimiter/source structural scan: PASS;
- reference financial audit: PASS;
- repository filter has regression-test coverage added;
- loan overpayment regression test added.

## Not yet validated

- Flutter analyzer;
- Flutter test runner;
- Android build;
- iOS build.

Reason: Flutter/native SDK tidak tersedia pada environment kerja saat snapshot ini.

## Next implementation gate

1. CSV import dengan preview + duplicate detection;
2. local notification engine untuk bills/recurring;
3. auth + cloud sync implementation;
4. real sync conflict UI;
5. compile/analyzer fixes ketika SDK tersedia.
