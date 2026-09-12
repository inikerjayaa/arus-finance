# Implementation Status

**Snapshot:** Stage 2 — transaction control + liability UI + dashboard personalization  
**Rule:** `DONE` berarti source nyata tersedia. `NEEDS NATIVE VALIDATION` berarti belum dibuktikan dengan Flutter/Android/iOS SDK pada environment ini.

| Capability | Status |
|---|---|
| Product/domain blueprint | DONE |
| Integer-money + ledger | DONE |
| Expense / income | DONE |
| Asset transfer + transfer fee | DONE |
| Refund | DONE |
| Edit / soft delete | DONE |
| Account reconciliation | DONE |
| Credit-card payment domain | DONE |
| Credit-card payment UI | DONE |
| Loan payment/disbursement domain | DONE |
| Loan payment/disbursement UI | DONE |
| Loan overpayment protection | DONE |
| Accounts / categories UI | DONE |
| Dashboard / transactions UI | DONE |
| Dashboard visibility + reorder customization | DONE |
| Advanced transaction search/filter | DONE |
| Budget / bills / recurring | DONE |
| Recurring occurrence de-dup | DONE |
| Insights | DONE |
| PIN / biometric service | DONE |
| App-lock gate | DONE |
| Encrypted portable backup | DONE |
| CSV export | DONE |
| CSV import + preview/dedup | NEXT |
| Local encrypted DB wiring | DONE, NEEDS NATIVE VALIDATION |
| Cloud/sync experiment | NON-PRODUCTION / OPTIONAL FUTURE |
| Automatic cloud account/sync UI | NOT IN PRODUCTION ROADMAP |
| Local scheduled notifications | NEXT |
| AI input | GATED |
| OCR receipt | GATED |
| Family/shared workspace | GATED |
| Bank/e-wallet integration | GATED |
| `flutter analyze` / `flutter test` | NEEDS FLUTTER SDK |
| Store-signed APK/IPA | NEEDS NATIVE VALIDATION + signing |

## Stage 2 completed

1. Search/filter turun sampai query SQLite, bukan client-only filter.
2. Filter mendukung type, status, account, category, date range, min/max amount, dan free-text query.
3. Filter state dipertahankan saat refresh sampai user reset.
4. Credit-card payment mempunyai UI khusus sehingga tidak disalahgunakan sebagai generic transfer.
5. Loan disbursement/payment mempunyai UI khusus dengan principal/interest/fee terpisah.
6. Loan principal tidak boleh melewati outstanding liability.
7. Dashboard widgets dapat disembunyikan dan diurutkan; pilihan persisten via SharedPreferences.
8. Transaction group subtitle membedakan transfer fee vs loan interest/fee.
9. Reference financial contract tetap PASS setelah perubahan.

## Validation boundary

Belum boleh mengklaim compile/native PASS sampai source dijalankan dengan Flutter SDK + platform SDK yang sesuai. Source-level delimiter audit untuk file yang berubah pada Stage 2 sudah PASS, tetapi itu bukan pengganti Dart analyzer.
