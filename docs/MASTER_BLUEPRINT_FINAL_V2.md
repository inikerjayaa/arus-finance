# PERSONAL FINANCE APP — MASTER BLUEPRINT FINAL V2

> **ARCHITECTURE OVERRIDE — LOCAL-ONLY V4**
> Sections in this historical V2 blueprint that describe mandatory cloud, login, server sync, or cloud account behavior are superseded by `LOCAL_ONLY_ARCHITECTURE_V4.md`. Production core is 100% device-owned and requires no cloud.

**Status:** Consolidated, reverse-audited, implementation-ready blueprint  
**Platform:** Android + iOS  
**Primary Client:** Flutter  
**Local Data:** SQLite relational database + typed data/repository layer (Drift-compatible); encryption-at-rest wajib disediakan oleh solusi/platform yang memang mendukung encryption, bukan diasumsikan berasal dari Drift itu sendiri  
**Cloud Data:** PostgreSQL; backend dapat menggunakan Supabase-compatible services selama domain/repository tidak terkunci pada vendor  
**Architecture Goal:** Offline-first, privacy-aware, sync-safe, extensible  
**Document Date:** 2026-09-08  
**Document Role:** Single Source of Truth (SSOT) untuk product, UX/UI, business rules, financial domain, database, backend, sync, security, testing, dan release  
**Source Consolidation:** V1 + V1.1 Reverse Audit + original product notes  
**Reverse Audit:** Completed  
**External Policy Snapshot:** Verified on 2026-09-08; mandatory re-check immediately before store submission


---

# BLUEPRINT MAP — CARA MEMBACA DOKUMEN

Dokumen ini sengaja menyatukan **tampilan yang akan dilihat pengguna** dan **program/backend yang membuat tampilan itu benar**.

Urutan evaluasi setiap feature:

```text
Product Need
↓
User Flow
↓
Screen / UI State
↓
Use Case
↓
Validation
↓
Financial Domain Rule
↓
Database / Ledger
↓
Offline Operation
↓
Sync / Conflict
↓
Report / Derived Data
↓
Error & Recovery
↓
Automated Test
↓
Kembali ke UI
```

Tidak ada feature yang dianggap “jadi” hanya karena screen-nya sudah ada.

## Blueprint Layers

| Layer | Isi |
|---|---|
| Product | tujuan, target user, positioning, scope |
| UX/UI | navigation, onboarding, quick add, dashboard, state, accessibility |
| Financial Domain | expense, income, transfer, refund, credit card, loan, budget |
| Data | schema, ledger, money type, constraints, migrations |
| Runtime | local-first, sync, idempotency, conflict, backup |
| Security | auth, app lock, encryption, privacy, deletion |
| Quality | unit/invariant/integration/E2E/security/performance testing |
| Release | CI/CD, rollout, Play Store/App Store compliance |

## Non-Negotiable Build Rule

```text
Requirement
UI Flow
Domain Rule
Schema
Use Case
Offline Rule
Sync Rule
Error State
Automated Test
```

Semua harus tersedia sebelum capability dinyatakan implementation-ready.


# 0. TUJUAN DOKUMEN

Dokumen ini bukan daftar ide dan bukan mockup sementara.

Dokumen ini menjadi acuan utama untuk membangun aplikasi personal finance yang:

- benar-benar bisa dipakai sehari-hari;
- tetap cepat seperti Monefy;
- lebih fleksibel dan modern;
- aman untuk data finansial;
- tetap berfungsi saat offline;
- tidak mudah menghasilkan saldo salah;
- bisa berkembang menjadi family/shared finance;
- dapat dipublikasikan ke Google Play dan App Store;
- mempunyai aturan yang jelas ketika terjadi error, edit, delete, sync, refund, transfer, dan edge case.

## 0.1 Prinsip Dokumentasi

Jika implementasi berbeda dengan dokumen ini, maka salah satu harus diperbarui:

1. implementasi dikoreksi agar mengikuti spesifikasi; atau
2. spesifikasi direvisi secara eksplisit dan diberi version history.

Jangan membiarkan “aturan tersembunyi” hanya diketahui developer.

---

# 1. PRODUCT VISION

## 1.1 Product Positioning

Aplikasi bukan hanya:

> Expense Tracker

Tetapi:

> Personal Finance Operating System

Namun pengalaman permukaan harus tetap sangat sederhana.

Prinsip utama:

> **Simple first → powerful when needed.**

Pengguna baru cukup memahami:

> **Rp → Kategori → Simpan**

Pengguna yang lebih advanced dapat memakai:

- multiple accounts;
- budget;
- recurring transaction;
- bill;
- subscription;
- saving goals;
- credit card;
- debt;
- split expense;
- family/shared workspace;
- multi-currency;
- reports;
- receipt scan;
- AI quick entry;
- forecasting;
- smart category;
- financial health;
- export/backup;
- multi-device sync.

---

# 2. MASALAH YANG DISELESAIKAN

Banyak aplikasi finansial gagal karena salah satu dari dua ekstrem:

1. terlalu sederhana dan tidak berkembang saat kebutuhan user bertambah; atau
2. terlalu kompleks sehingga user malas mencatat transaksi harian.

Aplikasi ini harus menyelesaikan keduanya.

## 2.1 Problem Statements

User membutuhkan cara untuk:

- mencatat pengeluaran dalam beberapa detik;
- mengetahui uang tersedia sekarang;
- melihat uang habis ke mana;
- mengetahui apakah pengeluaran masih aman;
- merencanakan budget;
- mengetahui tagihan yang akan datang;
- mengontrol subscription;
- mengetahui target tabungan;
- melacak beberapa rekening;
- menggunakan aplikasi tanpa internet;
- tidak kehilangan data;
- mengakses data dari perangkat lain;
- mengekspor data kapan saja;
- memahami insight tanpa harus paham accounting.

---

# 3. PRODUCT PRINCIPLES

## P1 — Quick Entry First

Transaksi normal harus dapat disimpan dalam **2–4 detik** setelah aplikasi siap digunakan.

## P2 — Progressive Disclosure

Advanced field disembunyikan sampai dibutuhkan.

## P3 — Financial Correctness > Visual Convenience

Jika UX yang “mudah” berpotensi membuat saldo salah, correctness lebih penting.

## P4 — Offline Is a First-Class Mode

Offline bukan error state.

## P5 — User Owns the Data

User harus dapat:

- melihat;
- mengedit;
- mengekspor;
- backup;
- restore;
- menghapus data;
- menghapus account.

## P6 — Explainable Intelligence

AI dan smart insight harus dapat dijelaskan.

## P7 — Never Hide Money Errors

Conflict, duplicate, sync failure, atau mismatch tidak boleh diam-diam diabaikan.

## P8 — Simple Dashboard

Homepage hanya perlu menjawab:

1. berapa uang saya sekarang?
2. berapa yang saya keluarkan?
3. apakah saya masih aman sampai akhir periode?

---

# 4. TARGET USERS

## 4.1 Casual Tracker

Kebutuhan:

- catat pengeluaran;
- lihat saldo;
- lihat kategori terbesar.

Tidak perlu fitur advanced.

## 4.2 Budget Conscious User

Kebutuhan:

- budget kategori;
- notifikasi;
- weekly limit;
- daily safe-to-spend.

## 4.3 Multi-Account User

Kebutuhan:

- Cash;
- Bank;
- E-wallet;
- Credit card;
- transfer.

## 4.4 Family / Couple

Kebutuhan:

- shared wallet;
- shared budget;
- attribution per member;
- private personal transactions.

## 4.5 Advanced Personal Finance User

Kebutuhan:

- net worth;
- goals;
- debt;
- multi-currency;
- forecasting;
- export;
- advanced reporting.

---

# 5. SUCCESS METRICS

## 5.1 Product Metrics

- median quick-entry duration;
- transaction completion rate;
- D1/D7/D30 retention;
- transactions logged per active user;
- recurring users;
- percentage users activating budget;
- percentage users activating backup/sync;
- crash-free sessions;
- sync success rate.

## 5.2 Financial Integrity Metrics

Target:

- duplicate caused by sync: **0**;
- unexplained balance mutation: **0**;
- ledger reconciliation failure: **0**;
- silent financial conflict: **0**.

---

# 6. SCOPE

## 6.1 MVP Production Scope

MVP harus memiliki:

- onboarding;
- guest/local mode;
- account creation optional untuk sync;
- expense;
- income;
- transfer;
- multiple accounts;
- opening balance;
- custom categories;
- subcategories;
- quick add;
- transaction timeline;
- search/filter;
- edit/delete;
- refunds;
- dashboard;
- monthly reports;
- budget;
- recurring transactions;
- bills;
- notifications;
- offline local database;
- backup;
- cloud sync;
- biometric/PIN;
- dark mode;
- CSV export;
- data import dasar;
- error handling;
- sync conflict handling;
- analytics tanpa financial payload;
- crash reporting tanpa nilai transaksi.

## 6.2 Post-MVP

- receipt OCR;
- AI natural language input;
- subscriptions;
- saving goals;
- family/shared workspace;
- split bill;
- credit card advanced;
- debt;
- net worth;
- multi-currency advanced;
- forecast;
- anomaly detection;
- financial health;
- XLSX/PDF reporting;
- bank/e-wallet integrations.

---

# 7. INFORMATION ARCHITECTURE

Bottom navigation:

| Tab | Fungsi |
|---|---|
| Beranda | Ringkasan keuangan |
| Transaksi | Timeline dan pencarian |
| + | Quick Add |
| Rencana | Budget dan bills; goals muncul setelah capability diaktifkan |
| Insight | Reports dan analisis |

Settings/Profile berada di app bar.

---

# 8. ONBOARDING

## 8.1 Flow

```text
Splash
  ↓
Welcome
  ↓
Pilih tujuan
  ↓
Pilih mata uang utama
  ↓
Buat account pertama
  ↓
Isi saldo awal (optional)
  ↓
Home
```

## 8.2 Login Tidak Wajib

Default:

> Continue locally

Cloud account hanya diperlukan untuk:

- sync;
- family sharing;
- cloud backup;
- multi-device.

## 8.3 Onboarding Rules

User tidak diwajibkan mengisi:

- nama lengkap;
- income;
- pekerjaan;
- alamat;
- semua budget;
- seluruh kategori.

---

# 9. HOME / DASHBOARD

## 9.1 Default Dashboard

Urutan default:

1. total available balance;
2. spending this month;
3. safe-to-spend;
4. budget progress;
5. today transactions;
6. upcoming bills;
7. smart insight.

### Definisi Total Available Balance

`Total Available Balance` bukan Net Worth.

Formula:

```text
SUM(balance account ASSET
    where include_in_available_balance = true)
```

Default:

- Cash = included;
- Bank = included;
- E-wallet = included;
- Investment = excluded dari available balance;
- Credit Card = excluded;
- Loan = excluded.

Net Worth ditampilkan sebagai widget terpisah.

Jika user belum mempunyai budget, `safe-to-spend` tidak menampilkan angka palsu. Widget berubah menjadi CTA untuk membuat budget.

## 9.2 Custom Widgets

Widget dapat:

- ditambah;
- dihapus;
- dipindah;
- disembunyikan;
- diubah ukuran bila layout mendukung.

Contoh:

- Total Balance
- Spending Today
- Spending Month
- Budget
- Cash Flow
- Upcoming Bills
- Largest Category
- Daily Average
- Goals
- Subscription
- Net Worth
- Weekly Trend
- Monthly Trend

## 9.3 Privacy Mode

User dapat menekan ikon mata untuk menyembunyikan:

- balance;
- transaction amount;
- goals;
- chart labels.

---

# 10. QUICK ADD TRANSACTION

## 10.1 UX Requirement

Keyboard nominal langsung aktif.

```text
Rp 85.000

Kategori:
[Makan] [Cafe] [Belanja] [Transport]

Account:
BCA

[+ Detail]

[SIMPAN]
```

## 10.2 Default Selection

Aplikasi boleh mengingat:

- account terakhir;
- category prediction;
- current date/time.

Tetapi tidak boleh membuat transaksi tanpa tindakan Simpan kecuali user mengaktifkan explicit one-tap shortcut.

## 10.3 Advanced Fields

Core fields yang boleh tersedia sejak MVP:

- merchant;
- note;
- tags;
- subcategory;
- recurring;
- split.

Capability-gated / post-MVP:

- attachment / receipt;
- project;
- person;
- location;
- reimbursement.

Field capability-gated **tidak boleh muncul di UI** sebelum model data, permission, sync, dan reporting rule-nya tersedia.

---

# 11. TRANSACTION TYPES

Canonical transaction types:

```text
EXPENSE
INCOME
TRANSFER
REFUND
ADJUSTMENT
OPENING_BALANCE
CREDIT_CARD_PAYMENT
LOAN_DISBURSEMENT
LOAN_PAYMENT
```

## 11.1 Expense

Expense menurunkan Net Worth dengan salah satu cara:

- mengurangi asset; atau
- menambah liability.

## 11.2 Income

Income adalah **economic inflow / gain** yang menaikkan Net Worth.

Normal case:

- menambah asset, misalnya gaji masuk ke Bank/Cash.

Pengurangan liability **tidak otomatis disebut income**. Pembayaran kartu kredit dan pembayaran pokok pinjaman adalah settlement/payment, bukan income.

Pengurangan liability hanya dapat diperlakukan sebagai income/gain bila memang terjadi economic gain yang nyata, misalnya debt forgiveness, dan fitur tersebut harus mempunyai transaction type/business rule eksplisit sebelum dipakai.

Default MVP:

> INCOME harus menghasilkan penambahan asset.

Contoh income/cashback yang dikreditkan langsung ke credit card dapat mengurangi outstanding liability.

## 11.3 Transfer

Memindahkan value antar account.

**Tidak dihitung sebagai income atau expense.**

Default generic `TRANSFER` digunakan untuk pemindahan value antar account **asset ↔ asset**.

Pembayaran kartu kredit memakai `CREDIT_CARD_PAYMENT`, pembayaran pinjaman memakai `LOAN_PAYMENT`, dan pencairan pinjaman memakai `LOAN_DISBURSEMENT`. Jangan memakai generic TRANSFER untuk menyamarkan settlement liability karena reporting dan ledger semantics akan berbeda.

## 11.4 Refund

Membalik sebagian atau seluruh expense sebelumnya.

Refund idealnya linked ke transaksi original.

## 11.5 Adjustment

Dipakai untuk rekonsiliasi manual.

Adjustment harus memiliki reason.

Adjustment tidak masuk income/expense report kecuali user secara eksplisit memilih membuat koreksi sebagai transaksi income/expense biasa.

## 11.6 Opening Balance

Saldo awal ketika account dibuat.

Tidak dihitung sebagai income regular.

Untuk ASSET, opening balance positif berarti asset tersedia.

Untuk LIABILITY, opening balance positif berarti outstanding debt.

---

# 12. LEDGER MODEL — SUMBER KEBENARAN

**Saldo account tidak disimpan sebagai angka mutable utama.**

Saldo dihitung dari ledger entries.

## 12.1 Account Class

```text
ASSET
LIABILITY
```

### Asset

- Cash
- Bank
- E-wallet
- Investment

### Liability

- Credit Card
- Loan

## 12.2 Ledger Rule

`delta_minor` berarti:

### Asset

- positif = asset bertambah;
- negatif = asset berkurang.

### Liability

- positif = utang bertambah;
- negatif = utang berkurang.

## 12.3 Examples

Expense Rp100.000 dari BCA:

```text
BCA ASSET
delta = -100000
```

Income Rp1.000.000:

```text
BCA ASSET
delta = +1000000
```

Transfer BCA → GoPay:

```text
BCA   -200000
GoPay +200000
```

Credit card purchase:

```text
Credit Card LIABILITY
delta = +500000
```

Credit card payment:

```text
BCA         -500000
Credit Card -500000
```

## 12.4 Net Worth

```text
Net Worth
=
Total Asset Balances
-
Total Liability Balances
```

---

# 13. MONEY DATA TYPE

**Dilarang memakai floating point untuk amount.**

Gunakan integer minor units.

Contoh IDR:

```text
Rp 85.000
amount_minor = 85000
currency = IDR
```

Untuk mata uang dengan decimal:

```text
USD 12.34
amount_minor = 1234
```

Currency metadata menentukan exponent.

Exchange rate disimpan sebagai decimal/string-safe representation, bukan binary float.

---

# 14. ACCOUNT MODULE

## 14.1 Account Types

```text
CASH
BANK
EWALLET
CREDIT_CARD
LOAN
INVESTMENT
OTHER_ASSET
OTHER_LIABILITY
```

## 14.2 Account Fields

- id
- workspace_id
- name
- account_class
- account_type
- currency
- institution
- icon
- color
- include_in_available_balance
- include_in_net_worth
- archived_at
- created_at
- updated_at

## 14.3 Delete Account Rule

Account yang memiliki history **tidak di-hard-delete dari flow normal**.

Default dan primary action:

> Archive Account.

Bulk move hanya tersedia melalui advanced migration tool dan harus:

- menjaga currency compatibility;
- menjaga transaction-group integrity;
- memvalidasi transfer source/destination;
- memvalidasi linked refund;
- dilakukan atomically.

Penghapusan seluruh history account hanya termasuk pada explicit workspace/data-erasure flow, bukan aksi biasa pada Account Detail.

## 14.4 Archived Account

- tidak muncul di quick add;
- tetap muncul pada historical report;
- tidak merusak histori;
- dapat dipulihkan.

---

# 15. CATEGORY MODULE

## 15.1 Category Types

```text
EXPENSE
INCOME
```

Transfer tidak memakai expense category.

## 15.2 Fields

- id
- workspace_id
- parent_id
- type
- name
- icon
- color
- sort_order
- is_system
- archived_at

## 15.3 Archive Rule

Kategori yang sudah dipakai tidak dihapus secara fisik.

Default:

> Archive.

## 15.4 Merge Category

Merge:

```text
Cafe → Dining Out
```

Semua historical splits dipindahkan dalam atomic operation.

Referensi lain yang memakai kategori sumber juga harus ditangani:

- active budget scope;
- recurring rule;
- bill;
- merchant/category rule.

User melihat preview perubahan sebelum merge.

---

# 16. TRANSACTION SPLIT

Satu transaksi dapat memiliki banyak category allocation.

Contoh supermarket Rp300.000:

```text
Groceries     200.000
Household      70.000
Personal Care  30.000
```

Invariant:

```text
SUM(split.amount_minor)
=
transaction expense amount
```

Kecuali explicit rounding adjustment multi-currency.

---

# 17. TRANSFER RULES

## 17.1 Same Currency

Source amount harus sama dengan destination amount untuk nilai transfer utama.

Contoh:

```text
BCA → GoPay
Transfer 500.000
Fee        1.000
```

Canonical model:

```text
Transaction Group TG-001

TRANSFER
BCA   -500000
GoPay +500000

linked EXPENSE
BCA     -1000
Category = Biaya Transfer
```

Transfer dan fee dibuat dalam **satu atomic transaction group** agar:

- transfer tetap murni bukan expense;
- fee tetap masuk expense report;
- category rules tidak bertentangan;
- jika salah satu write gagal, seluruh group rollback.

`transaction_group_id` bersifat optional dan digunakan untuk composite financial events.

## 17.2 Different Currency

Source dan destination amount disimpan terpisah.

```text
IDR source amount
USD destination amount
rate
fee
```

Jangan menghitung destination hanya dari current exchange rate setelah transaksi tersimpan.

Historical rate harus tetap tersimpan.

---

# 18. EDIT TRANSACTION

Edit tidak boleh membuat entry baru tanpa menghapus/membalik efek lama.

Process atomic:

```text
Begin transaction
Validate version
Update transaction
Replace/reconcile ledger entries
Replace/reconcile splits
Update search index
Commit
```

Jika gagal:

> seluruh perubahan rollback.

Jika transaction merupakan bagian `transaction_group_id`, UI harus mengedit logical group melalui group-aware use case. Child financial transaction tidak diedit bebas apabila dapat merusak invariant group.

---

# 19. DELETE TRANSACTION

Default:

> Soft delete / tombstone.

Tujuan:

- sync multi-device;
- audit;
- restore;
- conflict resolution.

Deleted transaction:

- tidak masuk balance;
- tidak masuk report;
- tombstone tetap disync.

Hard delete dilakukan sesuai retention policy.

Dependency rules:

- transaksi yang menjadi bagian composite group dihapus/void melalui group-aware flow;
- original expense dengan linked refund tidak boleh dihapus diam-diam;
- user harus memilih membatalkan original beserta linked refund secara atomic atau menyelesaikan dependency lebih dulu.

---

# 20. REFUND

Refund sebaiknya linked ke original transaction.

Fields:

- original_transaction_id
- refund_amount
- refund_date

Rules:

- partial refund allowed;
- multiple refunds allowed;
- total linked refund default tidak boleh melebihi original expense;
- override hanya melalui adjustment dengan warning;
- original expense tidak boleh diedit menjadi lebih kecil dari total refund yang masih aktif;
- refund ke asset menambah asset;
- refund ke credit-card/liability account mengurangi liability.

Report:

> Refund mengurangi expense category original.

Bukan dianggap income biasa.

---

# 21. RECURRING TRANSACTIONS

## 21.1 Modes

```text
REMINDER_ONLY
AUTO_CREATE
AUTO_CREATE_DRAFT
```

Default:

> Reminder / Draft.

Auto-create perlu explicit user opt-in.

Jika `AUTO_CREATE` dipilih, recurring rule itu sendiri merupakan explicit posting authorization. Scheduler dapat membuat transaksi POSTED sesuai rule. Jika `AUTO_CREATE_DRAFT`, scheduler hanya membuat DRAFT.

## 21.2 Frequency

- daily
- weekly
- monthly
- yearly
- custom interval

## 21.3 Monthly Edge Cases

Jika schedule tanggal 31:

bulan tanpa tanggal 31 menggunakan:

> last valid day of month

Rule harus konsisten.

## 21.4 Timezone

Recurring schedule disimpan berdasarkan workspace timezone.

## 21.5 Recurring Occurrence Idempotency

Setiap occurrence wajib memiliki deterministic unique identity, misalnya:

```text
recurrence_occurrence_key
=
rule_id + scheduled_local_date + scheduled_local_time + sequence/version
```

Server/database harus mempunyai unique constraint yang mencegah Device A dan Device B membuat occurrence yang sama dua kali.

`AUTO_CREATE` atau `AUTO_CREATE_DRAFT` tidak boleh mengandalkan “device mana yang lebih dulu online” sebagai mekanisme anti-duplikasi.

---

# 22. BILLS

Bill berbeda dari recurring expense.

Bill dapat berstatus:

```text
UPCOMING
DUE
PAID
SKIPPED
OVERDUE
```

Bill dapat:

- memiliki estimated amount;
- recurring;
- dibayar dengan transaksi;
- memiliki reminder.

Jika dibayar:

> create/link actual transaction.

---

# 23. SUBSCRIPTIONS

Subscription fields:

- merchant;
- plan;
- interval;
- expected amount;
- currency;
- next billing;
- account;
- category;
- active status.

Subscription dapat berasal dari:

- manual input;
- recurring detection.

Auto-detection tidak boleh langsung mengaktifkan subscription tanpa konfirmasi user.

---

# 24. BUDGET ENGINE

## 24.1 Budget Types

```text
OVERALL
CATEGORY
SUBCATEGORY
TAG
CUSTOM_GROUP
```

## 24.2 Periods

- weekly;
- monthly;
- custom start day.

## 24.3 Actual Spending

Budget actual menggunakan:

- expense split;
- minus linked refunds.

Tidak termasuk:

- transfer;
- opening balance;
- credit card payment;
- loan principal movement.

## 24.4 Safe-to-Spend

Contoh:

```text
remaining_budget = budget - actual - committed_upcoming
remaining_days = period_end - today + 1

safe_to_spend =
remaining_budget / remaining_days
```

Committed upcoming bersifat configurable.

## 24.5 Rollover

Budget dapat:

- no rollover;
- positive rollover;
- positive + negative rollover.

Default:

> no rollover.

---

# 25. GOALS

Goal types:

- emergency fund;
- purchase;
- travel;
- education;
- custom.

Fields:

- name;
- target amount;
- currency;
- target date;
- linked account optional;
- contribution rule.

Goal contribution harus dibedakan dari expense.

Jika user hanya memindahkan uang BCA → Saving Account:

> itu transfer, bukan expense.

---

# 26. CREDIT CARD

Credit card adalah LIABILITY account.

Liability balance normal bernilai positif ketika ada utang. Sistem **boleh mendukung credit balance negatif** (misalnya refund melebihi outstanding balance), tetapi UI harus memberi label jelas sebagai saldo kredit/kelebihan bayar dan Net Worth calculation tetap mengikuti signed liability balance.

## 26.1 Purchase

Purchase menambah liability.

## 26.2 Payment

Payment:

```text
Asset decreases
Liability decreases
```

Tidak dihitung sebagai expense kedua kali.

Expense sudah dihitung saat purchase terjadi.

## 26.3 Statement Support

Advanced:

- statement closing date;
- due date;
- minimum payment;
- statement balance.

---

# 27. LOAN / DEBT

Loan disimpan sebagai liability.

## 27.1 Loan Disbursement

Menerima pinjaman:

```text
Asset +X
Liability +X
```

Bukan income operasional.

## 27.2 Loan Payment

Pisahkan:

```text
Principal
Interest
Fee
```

Canonical composite model:

```text
Transaction Group

LOAN_PAYMENT (principal)
Asset     -principal
Liability -principal

linked EXPENSE (interest)
Asset     -interest
Category  Interest

linked EXPENSE (fee, bila ada)
Asset     -fee
Category  Loan Fee
```

Semua bagian disimpan atomically dalam satu `transaction_group_id`.

Principal:

> mengurangi liability.

Interest/fee:

> expense.

---

# 28. WORKSPACES

Workspace types:

```text
PERSONAL
FAMILY
COUPLE
SHARED
```

## 28.1 Roles

```text
OWNER
ADMIN
MEMBER
VIEWER
```

## 28.2 Permissions

OWNER:

- full access;
- billing;
- member management;
- delete workspace.

ADMIN:

- manage finance;
- categories;
- budgets;
- members limited.

MEMBER:

- create/edit allowed data.

VIEWER:

- read only.

## 28.3 Personal Privacy

Transaksi personal tidak otomatis terlihat di family workspace.

Cross-workspace movement dibuat sebagai explicit transfer/settlement workflow.

---

# 29. SHARED WALLET

Shared account mempunyai:

- members;
- permissions;
- attribution;
- audit history.

Setiap transaction memiliki:

```text
created_by
paid_by optional
```

---

# 30. SPLIT EXPENSE / RECEIVABLE

Contoh:

```text
Total bill: 600.000
User share: 150.000
Receivable: 450.000
```

Post-MVP model dapat memakai settlement records.

Debt antar teman jangan dicampur dengan bank account balance tanpa rule yang jelas.

---

# 31. TRANSACTION TIMELINE

Default grouping:

```text
TODAY
YESTERDAY
DATE
```

Actions:

- tap → detail;
- swipe → configurable;
- long press → selection mode.

Supported:

- edit;
- duplicate;
- refund;
- split;
- attach;
- delete.

---

# 32. SEARCH & FILTER

Search:

- amount;
- merchant;
- note;
- category;
- account;
- tag.

Filters:

- date;
- type;
- account;
- category;
- amount range;
- member;
- attachment;
- recurring;
- sync status.

---

# 33. INSIGHT

Insight harus actionable.

Examples:

- kategori naik 56%;
- spending pace terlalu cepat;
- subscription total;
- expected bills;
- daily safe-to-spend;
- comparison month-over-month.

## 33.1 No Misleading Comparison

Jika bulan berjalan belum selesai:

bandingkan dengan:

> tanggal 1–8 bulan ini vs tanggal 1–8 bulan lalu

Bukan seluruh bulan sebelumnya tanpa label jelas.

---

# 34. REPORTING RULES

## 34.1 Expense Report

Termasuk:

- expense;
- interest;
- fees.

Dikurangi:

- linked refunds.

Tidak termasuk:

- transfer;
- account balance adjustment;
- credit card payment principal;
- loan principal.

## 34.2 Income Report

Tidak termasuk:

- transfer;
- opening balance;
- loan disbursement.

## 34.3 Cash Flow

```text
operating inflow - operating outflow
```

Financing dan internal transfer dapat ditampilkan terpisah.

---

# 35. DATE / TIME MODEL

Store:

```text
occurred_at_utc
timezone_id
local_date
local_time
```

Financial reports memakai:

> workspace timezone.

Jangan hanya memakai device timezone saat query historical report.

---

# 36. MULTI-CURRENCY

Setiap account memiliki currency.

Workspace memiliki reporting/base currency.

Historical reporting menggunakan:

- stored transaction exchange rate;
- atau rate snapshot yang applicable.

Jangan menghitung ulang histori memakai today's rate tanpa label.

---

# 37. MERCHANTS

Merchant dapat:

- disimpan manual;
- dipelajari;
- memiliki preferred category.

Smart rule:

```text
Starbucks → Cafe
Pertamina → Fuel
```

User correction menjadi training signal.

---

# 38. SMART CATEGORY

Priority:

1. user explicit rule;
2. merchant rule;
3. local learned pattern;
4. AI suggestion;
5. default category.

AI tidak pernah mengoverride user rule.

---

# 39. AI QUICK ENTRY

Example:

```text
tadi makan siang 85 ribu pakai bca
```

Parse:

```text
type = EXPENSE
amount = 85000
category = Makan
account = BCA
date = today
```

## 39.1 Safety Rule

Sebelum save:

> tampilkan parsed result.

AI tidak boleh diam-diam menyimpan transaksi ambigu.

## 39.2 Confidence

Jika confidence rendah:

```text
"Apakah Rp850.000 atau Rp85.000?"
```

Dalam fully automated flow, ambiguous input menjadi draft.

---

# 40. RECEIPT OCR

Flow:

```text
Camera
↓
Crop
↓
OCR
↓
Extract total/date/merchant
↓
Review
↓
Save
```

Never trust OCR blindly.

User harus dapat mengoreksi.

## 40.1 Duplicate Receipt

Gunakan:

- image hash;
- merchant;
- amount;
- date/time;
- similarity.

Jika kemungkinan duplicate:

> warning, bukan auto-delete.

---

# 41. NOTIFICATION ENGINE

Notification types:

- bill due;
- budget threshold;
- recurring reminder;
- goal milestone;
- daily logging reminder;
- sync issue;
- backup status.

## 41.1 Anti-Spam

Rules:

- quiet hours;
- per-notification toggle;
- daily cap;
- do not send same warning repeatedly without change.

---

# 42. OFFLINE-FIRST

Local DB adalah immediate application source.

Flow:

```text
User Action
   ↓
Local DB transaction
   ↓
UI updated immediately
   ↓
Outbox operation
   ↓
Sync when connected
```

Internet tidak diperlukan untuk:

- add expense;
- edit local data;
- search;
- report local history;
- category;
- budget local.

---

# 43. SYNC ARCHITECTURE

## 43.1 IDs

Gunakan globally unique IDs, misalnya UUIDv7-compatible.

ID tidak dibuat ulang setelah server sync.

## 43.2 Outbox

Setiap local write membuat operation:

```text
operation_id
entity_type
entity_id
operation
base_version
payload/hash
created_at
retry_count
```

## 43.3 Idempotency

Server harus menyimpan operation_id.

Operation yang terkirim ulang:

> tidak boleh diterapkan dua kali.

---

# 44. SYNC CONFLICT POLICY

## 44.1 Financial Entities

Untuk:

- transaction;
- ledger;
- split;
- transfer;

**Dilarang silent last-write-wins.**

Gunakan version check.

Jika dua device mengedit transaksi sama:

```text
Device A base version 3 → edit
Device B base version 3 → edit

Server receives A → version 4
Server receives B → conflict
```

B menghasilkan conflict record.

User dapat memilih:

- keep A;
- keep B;
- review details.

## 44.2 Low-Risk Preferences

Untuk:

- widget order;
- theme;
- view preference;

boleh last-write-wins.

---

# 45. DELETE SYNC

Soft-delete memakai tombstone:

```text
deleted_at
deleted_by
version
```

Device offline lama harus menerima tombstone ketika kembali online.

Tombstone tidak boleh hilang terlalu cepat.

---

# 46. DUPLICATE PREVENTION

Layers:

1. unique operation_id;
2. unique client-generated transaction id;
3. server constraints;
4. import duplicate detection;
5. receipt duplicate detection.

---

# 47. BACKUP

## 47.1 Local Backup

Optional encrypted backup file.

Isi:

- metadata;
- accounts;
- transactions;
- ledger;
- categories;
- budgets;
- recurring;
- settings.

## 47.2 Restore

Restore flow:

1. verify file integrity;
2. verify schema version;
3. decrypt;
4. run migration;
5. preview summary;
6. restore atomically;
7. validate ledger.

Never overwrite current DB partially.

---

# 48. EXPORT

Supported roadmap:

- CSV;
- XLSX;
- PDF report;
- encrypted full backup.

CSV export minimum fields:

```text
Date
Time
Type
Account
Destination Account
Category
Subcategory
Merchant
Amount
Currency
Note
Tags
Created By
```

---

# 49. IMPORT

Supported:

- CSV mapping;
- app backup restore.

Import wizard:

```text
Select file
↓
Map columns
↓
Preview
↓
Duplicate detection
↓
Validation
↓
Import
```

Never import invalid rows silently.

Provide:

- imported;
- skipped;
- errors.

---

# 50. AUTHENTICATION

Modes:

- local guest;
- email OTP/passwordless;
- Sign in with Apple;
- Google sign-in.

Cloud sync requires authenticated identity.

## 50.1 Session

Use:

- short-lived access token;
- refresh token;
- secure storage;
- token rotation where supported.

---

# 51. APP LOCK

Independent of account login.

Options:

- PIN;
- biometric;
- automatic lock timer.

Biometric unlock uses secure platform API.

PIN should not be stored plaintext.

---

# 52. LOCAL ENCRYPTION

Financial local database should use encryption-at-rest where practical.

Encryption key:

- generated locally;
- stored via Android Keystore / iOS Keychain;
- never logged.

Attachments may also be encrypted or protected by OS storage model.

---

# 53. CLOUD SECURITY

Required:

- TLS;
- row-level authorization;
- workspace membership validation;
- object storage authorization;
- rate limiting;
- audit log for sensitive actions.

Never trust client-provided workspace permission.

---

# 54. PRIVACY

Collect minimum necessary data.

Do not send to analytics:

- transaction amount;
- merchant names;
- notes;
- account balance;
- receipt contents.

Crash reports must redact:

- tokens;
- financial payloads;
- personal notes.

---

# 55. ACCOUNT DELETION

Settings:

```text
Account
→ Delete Account
```

Flow:

1. explain consequence;
2. export option;
3. re-authenticate;
4. explicit confirmation;
5. revoke sessions;
6. process cloud deletion;
7. local secure wipe;
8. confirmation.

If Sign in with Apple is used:

> token revocation must be part of account deletion implementation.

---

# 56. DEVICE MANAGEMENT

Settings:

```text
Devices
```

Show:

- device name;
- platform;
- last active;
- current device;
- revoke button.

Revoked device loses cloud access on next auth validation.

---

# 57. AUDIT LOG

Audit log for:

- shared workspace edits;
- member changes;
- destructive operations;
- financial conflict resolutions.

Audit log is not shown as noisy transaction list by default.

---

# 58. DATA MODEL — CORE TABLES

Recommended canonical tables:

```text
users
devices
workspaces
workspace_members

accounts
categories
tags
merchants

transaction_groups
transactions
transaction_legs
transaction_splits
transaction_tags
attachments

budgets
budget_scopes

recurring_rules
bills
subscriptions

goals
goal_contributions

exchange_rate_snapshots

sync_operations
sync_conflicts
audit_logs

notification_preferences
app_preferences
```

---

# 59. TABLE: TRANSACTIONS

Core fields:

```text
id UUID
transaction_group_id UUID NULL
workspace_id UUID
type ENUM
status ENUM
primary_amount_minor BIGINT
primary_currency TEXT
occurred_at_utc TIMESTAMP
timezone_id TEXT
local_date DATE
local_time TIME
merchant_id UUID NULL
note TEXT NULL
original_transaction_id UUID NULL
created_by UUID
created_at TIMESTAMP
updated_at TIMESTAMP
deleted_at TIMESTAMP NULL
version BIGINT
```

Status:

```text
POSTED
DRAFT
SCHEDULED
VOID
```

---

# 60. TABLE: TRANSACTION_LEGS

```text
id
transaction_id
account_id
leg_role ENUM
delta_minor
currency
exchange_rate_snapshot_id NULL
created_at
```

Financial invariant:

> setiap posted transaction harus menghasilkan valid account impact sesuai transaction type.

---

# 61. TABLE: TRANSACTION_SPLITS

```text
id
transaction_id
category_id
amount_minor
currency
note NULL
```

---

# 62. DATABASE CONSTRAINTS

Examples:

- `primary_amount_minor` adalah integer >= 0; arah uang ditentukan transaction type/ledger, bukan negative user input;
- `primary_currency` wajib valid;
- setiap transaction leg currency harus sama dengan currency account yang terkena leg;
- category semantic harus cocok: EXPENSE memakai expense category, INCOME memakai income category, REFUND memakai expense category original/compatible; TRANSFER, OPENING_BALANCE, dan CREDIT_CARD_PAYMENT tidak memiliki expense category langsung;
- transaction workspace matches account workspace;
- normal transfer tidak boleh melintasi workspace;
- destination account cannot equal source for transfer;
- archived account cannot receive normal new transaction unless explicitly restored;
- posted transaction must have valid legs;
- version increments on mutation;
- deleted entity not mutated except restore workflow.

---

# 63. DATABASE MIGRATIONS

Every schema change:

- versioned;
- reversible when feasible;
- tested using old production snapshot;
- never destructive without migration strategy.

App should know:

```text
local_schema_version
server_schema_compatibility
```

---

# 64. APPLICATION ARCHITECTURE

Recommended:

```text
Presentation
    ↓
Application / Use Cases
    ↓
Domain
    ↓
Repository Interfaces
   ↙        ↘
Local       Remote
DB          API
```

UI does not call database directly.

---

# 65. FLUTTER STRUCTURE

Example:

```text
lib/
  app/
  core/
    database/
    network/
    security/
    sync/
    analytics/
  features/
    onboarding/
    dashboard/
    transactions/
    accounts/
    categories/
    budgets/
    bills/
    goals/
    insights/
    settings/
  shared/
    widgets/
    theme/
    utils/
```

---

# 66. STATE MANAGEMENT

Use one consistent state-management strategy.

Do not mix multiple patterns without reason.

Recommended characteristics:

- testable;
- dependency injection;
- async state;
- predictable lifecycle.

---

# 67. API CONTRACT

Backend interface should be versioned:

```text
/v1/...
```

Core capabilities:

```text
auth
sync pull
sync push
transactions
accounts
categories
budgets
workspace
attachments
account deletion
```

If backend direct-database API is used, repository layer must still isolate UI/domain from vendor-specific calls.

---

# 68. ERROR MODEL

Canonical error categories:

```text
VALIDATION
AUTH
PERMISSION
NETWORK
CONFLICT
NOT_FOUND
RATE_LIMIT
SERVER
STORAGE
CORRUPT_DATA
UNKNOWN
```

UI error message must be human-readable.

Technical detail goes to sanitized logs.

---

# 69. SYSTEM STATES

Every screen must define:

- loading;
- content;
- empty;
- offline;
- error;
- permission denied;
- syncing;
- stale data.

Tidak boleh ada screen yang hanya dirancang untuk “happy path”.

---

# 70. EMPTY STATES

Example Transactions:

> Belum ada transaksi. Tekan + untuk mencatat pengeluaran pertama.

Example Budget:

> Belum ada budget. Buat budget pertama untuk mulai mengontrol pengeluaran.

CTA harus jelas.

---

# 71. OFFLINE STATE

Do not show scary red error.

Example:

> Offline — perubahan tersimpan di perangkat dan akan disinkronkan saat internet tersedia.

---

# 72. SYNC ERROR STATE

Example:

> 2 perubahan belum tersinkron.

Actions:

- retry;
- details.

Financial conflict:

> “Transaksi ini diedit di perangkat lain. Tinjau sebelum memilih versi.”

---

# 73. DESIGN SYSTEM

## 73.1 Principles

- clean;
- calm;
- elegant;
- low visual noise;
- finance trustworthy;
- touch friendly.

## 73.2 Spacing

Use consistent 4/8pt-based spacing.

Example tokens:

```text
4
8
12
16
24
32
40
48
```

## 73.3 Radius

Consistent semantic radius, not random per component.

## 73.4 Typography

Define:

- Display
- H1
- H2
- H3
- Body
- Label
- Caption
- Amount Large
- Amount Small

Financial numbers require tabular numeric support if font provides it.

---

# 74. COLOR SYSTEM

Use semantic tokens:

```text
background
surface
surface_alt
text_primary
text_secondary
border

positive
negative
warning
info

income
expense
transfer
```

Do not hardcode semantic meaning using random hex throughout code.

---

# 75. DARK MODE

Dark mode must be designed, not inverted automatically.

Verify:

- charts;
- cards;
- divider;
- text contrast;
- disabled states;
- input fields.

---

# 76. ACCESSIBILITY

Minimum requirements:

- semantic labels;
- screen reader support;
- scalable text;
- sufficient contrast;
- color not sole status indicator;
- touch target approximately platform-accessible size;
- reduced motion support where applicable.

---

# 77. INTERACTION RULES

Primary actions:

- one clear primary button;
- destructive action separated;
- confirmation only for meaningful destructive operations.

Do not ask confirmation for every trivial save.

---

# 78. ANIMATIONS

Animations should:

- explain transition;
- reinforce success;
- never block entry.

Quick Add must remain fast even with animations disabled.

---

# 79. PERFORMANCE TARGETS

Targets on supported mid-range devices:

- app usable quickly after launch;
- quick-add open without noticeable delay;
- local transaction save near-instant;
- long transaction list virtualized/paginated;
- large reports computed efficiently.

Do not block UI on cloud request.

---

# 80. ANALYTICS

Allowed examples:

- screen viewed;
- feature enabled;
- transaction_created event **without amount/category/merchant payload**;
- budget_created;
- sync_failed category.

Do not capture raw financial content.

---

# 81. CRASH MONITORING

Crash reporting required in production.

Sanitize breadcrumbs.

Never record:

- access token;
- note text;
- receipt text;
- amount;
- balance.

---

# 82. FEATURE FLAGS

Use feature flags for risky post-MVP features:

- AI;
- OCR;
- forecast;
- family beta.

Benefits:

- gradual rollout;
- kill switch.

---

# 83. NOTIFICATION PERMISSIONS

Ask notification permission contextually.

Example:

User creates first bill reminder:

> “Aktifkan notifikasi agar kami bisa mengingatkan sebelum jatuh tempo.”

Jangan meminta semua permissions saat first launch.

---

# 84. CAMERA / PHOTO PERMISSION

Ask only when user uses receipt scan/attachment.

If denied:

- allow manual entry;
- show retry path.

---

# 85. LOCATION

Location is optional.

The finance app should function completely without location permission.

---

# 86. LOCALIZATION

All user-facing text uses localization resources.

Never hardcode strings throughout widgets.

Initial:

- Indonesian;
- English.

---

# 87. NUMBER FORMATTING

IDR:

```text
Rp 85.000
```

Locale-aware.

Do not assume:

```text
1,000.00
```

for all users.

---

# 88. FINANCIAL PERIOD

Workspace settings:

- timezone;
- week start;
- monthly period start.

Default:

```text
week_start = Monday
monthly_start = 1
```

Can be changed later.

---

# 89. FORECAST

Forecast is post-MVP.

Inputs:

- current balance;
- known bills;
- recurring income;
- recurring expenses;
- user budget pace.

Forecast result must be labelled:

> estimate, not guaranteed.

---

# 90. FINANCIAL HEALTH

If implemented:

- scoring formula documented;
- weights visible;
- user can inspect why score changes.

No opaque judgement.

---

# 91. DATA QUALITY CHECKS

Periodic internal checks:

- orphan transaction legs;
- split mismatch;
- missing currency;
- invalid workspace relationship;
- impossible version;
- duplicate operation;
- ledger balance integrity.

If corruption detected:

> do not silently “fix” financial history without audit.

---

# 92. RECONCILIATION

User can set observed account balance.

If computed balance differs:

```text
Calculated: Rp5.000.000
Observed:   Rp4.975.000
Difference: Rp25.000
```

Options:

- inspect transactions;
- create adjustment Rp-25.000.

Adjustment requires reason.

---

# 93. BACKDATED TRANSACTIONS

Allowed.

When backdated transaction is created:

- historical report changes;
- current balance changes;
- affected budget period recalculates.

---

# 94. FUTURE TRANSACTIONS

Future transaction defaults to:

```text
SCHEDULED
```

Not included in actual current balance unless explicitly posted.

Can appear in forecast.

---

# 95. TIME EDIT EDGE CASE

If user edits transaction date across financial period:

- old period recalculates;
- new period recalculates;
- budget recalculates;
- insights invalidate cache.

---

# 96. APP CACHE

Cache may improve reports, but cache is not source of truth.

Every derived cache must be rebuildable from canonical data.

---

# 97. ATTACHMENTS

Attachment metadata:

- transaction_id;
- mime;
- size;
- checksum;
- local_path;
- cloud_object_key;
- encryption metadata;
- sync status.

Large upload must not block transaction save.

---

# 98. RATE LIMITING

Backend should protect:

- auth attempts;
- OCR;
- AI;
- file upload;
- sync abuse.

Rate-limited user gets clear retry message.

---

# 99. DATA RETENTION

Define separately for:

- active data;
- tombstones;
- audit;
- backups;
- account deletion.

Retention must comply with applicable law and published privacy policy.

---

# 100. TESTING STRATEGY

## 100.1 Unit

Test:

- money math;
- transfer;
- refund;
- split;
- budget;
- recurring;
- date;
- currency;
- net worth.

## 100.2 Repository

Test:

- local save;
- rollback;
- soft delete;
- migration.

## 100.3 Integration

Test:

- app → local DB → sync → server → second device.

## 100.4 UI

Test critical flows:

- onboarding;
- add expense;
- edit;
- delete;
- transfer;
- budget;
- offline.

## 100.5 End-to-End

Production-like environment.

---

# 101. FINANCIAL INVARIANT TESTS

Mandatory.

## Invariant 1

Transfer tanpa fee:

```text
Net worth effect = 0
```

## Invariant 2

Credit card payment:

```text
Expense effect = 0
```

Karena expense terjadi saat purchase.

## Invariant 3

Refund:

```text
Expense report reduced by refund
```

## Invariant 4

Edit amount:

```text
New balance effect = new amount only
```

Bukan old + new.

## Invariant 5

Delete:

```text
Deleted transaction effect = 0
```

## Invariant 6

Split:

```text
sum(splits) = expense amount
```

## Invariant 7

Loan disbursement:

```text
Income report effect = 0
```

---

# 102. SYNC TEST MATRIX

Test:

1. offline create → online;
2. offline edit → online;
3. offline delete → online;
4. device A create → device B receives;
5. same transaction edit A+B;
6. delete A while edit B;
7. retry same operation 10x;
8. app killed during sync;
9. internet interrupted;
10. token expires during push;
11. migration during pending outbox.

Expected:

> no duplicate financial effect.

---

# 103. MIGRATION TESTING

Test upgrade from:

```text
N-2
N-1
N
```

using realistic large database.

Must verify:

- total balances equal before/after;
- transaction counts equal;
- ledger invariant remains valid.

---

# 104. PERFORMANCE TESTING

Datasets:

- 1,000 transactions;
- 10,000 transactions;
- 100,000 transactions.

Test:

- launch;
- timeline;
- search;
- monthly report;
- sync.

---

# 105. SECURITY TESTING

Include:

- auth bypass;
- workspace privilege escalation;
- insecure direct object reference;
- token exposure;
- attachment URL leakage;
- backup encryption;
- local DB extraction resistance;
- logging review.

---

# 106. UX TESTING

Tasks:

- first expense;
- transfer;
- refund;
- budget;
- find old transaction;
- correct wrong account;
- reconcile account;
- restore backup.

Measure:

- completion;
- error;
- time;
- confusion.

---

# 107. DEFINITION OF DONE — FEATURE

Feature belum selesai jika hanya UI sudah tampil.

Feature selesai jika:

- UX implemented;
- validation implemented;
- offline works;
- sync works if applicable;
- error states handled;
- analytics privacy reviewed;
- unit tests;
- integration tests;
- accessibility reviewed;
- copy localized;
- no critical bugs.

---

# 108. DEVELOPMENT ENVIRONMENTS

Use:

```text
DEV
STAGING
PRODUCTION
```

Never use production financial data for development.

---

# 109. CI/CD

Pipeline minimum:

1. formatting/lint;
2. unit tests;
3. build;
4. integration tests critical;
5. security/static checks;
6. staging deploy;
7. signed production build.

---

# 110. RELEASE VERSIONING

Use semantic or defined product version strategy.

Example:

```text
1.0.0
1.0.1
1.1.0
2.0.0
```

Database schema version is separate.

---

# 111. ROLLBACK STRATEGY

Backend deployment must support rollback.

Mobile release cannot instantly rollback on every user device.

Therefore:

- backward-compatible API window;
- feature flags;
- staged rollout.

---

# 112. GOOGLE PLAY RELEASE CHECK

**Snapshot 2026-09-08 — verify again immediately before release.**

As of this document date, new apps/app updates submitted after 2026-08-31 need to target Android 16 / API level 36 or higher for standard Android mobile distribution.

Checklist:

- target API compliant;
- app signing;
- Data Safety form;
- privacy policy;
- screenshots;
- content rating;
- testing track;
- crash check;
- permission declarations.

---

# 113. APP STORE RELEASE CHECK

**Snapshot 2026-09-08 — verify again immediately before release.**

Include:

- App Store privacy disclosure;
- valid privacy manifests for applicable app/SDK dependencies;
- in-app account deletion if account creation exists;
- Sign in with Apple token revocation on account deletion if used;
- permission purpose strings;
- screenshots;
- metadata;
- TestFlight;
- review notes.

---

# 114. PRIVACY POLICY REQUIREMENTS

Privacy policy must describe:

- data collected;
- why;
- storage;
- sharing;
- analytics;
- OCR/AI processing;
- retention;
- deletion;
- contact;
- international transfer where applicable.

---

# 115. TERMS

Terms should cover:

- application is budgeting/personal finance tool;
- user responsibility for input;
- forecast not financial guarantee;
- sync/backup limitations;
- prohibited misuse;
- subscription terms if later monetized.

Legal wording requires qualified legal review before production publication.

---

# 116. MONETIZATION — FUTURE-SAFE

Architecture may support:

```text
FREE
PLUS
FAMILY
```

Core local data access should not be hostage to temporary server outage.

Potential premium:

- cloud sync;
- advanced reports;
- AI;
- OCR;
- family;
- unlimited advanced automation.

Final pricing not part of V1 technical correctness.

---

# 117. DEVELOPMENT PHASES

## PHASE 0 — Blueprint

Deliver:

- master spec;
- user flow;
- ERD;
- design system;
- technical architecture.

Gate:

> no unresolved core financial logic.

## PHASE 1 — Local Core

Build:

- accounts;
- categories;
- transaction engine;
- ledger;
- timeline;
- edit/delete;
- transfer;
- refund.

Gate:

> all financial invariant tests pass.

## PHASE 2 — Daily UX

Build:

- dashboard;
- quick add;
- search;
- filters;
- themes;
- accessibility.

## PHASE 3 — Planning

Build:

- budgets;
- recurring;
- bills;
- notifications.

## PHASE 4 — Backup & Import/Export

Build:

- backup;
- restore;
- CSV;
- import.

## PHASE 5 — Auth & Cloud Sync

Build:

- identity;
- outbox;
- sync;
- conflict;
- multi-device.

Gate:

> duplicate financial effect = 0 in sync stress tests.

## PHASE 6 — Security Hardening

- encryption;
- device management;
- account deletion;
- RLS/permissions;
- audit.

## PHASE 7 — Production MVP

- analytics/privacy;
- crash reporting;
- performance;
- store preparation;
- beta.

## PHASE 8 — Goals / Subscription / Credit

Advanced personal finance.

## PHASE 9 — Family / Shared

Workspace sharing.

## PHASE 10 — Smart Features

AI/OCR/smart category.

## PHASE 11 — Advanced Insights

Forecast/net worth/financial health.

## PHASE 12 — Polish

Animation, widgets, delight, deep UX cleanup.

---

# 118. SCREEN INVENTORY

Minimum production screens:

```text
Splash
Welcome
Onboarding Goal
Currency
Create First Account

Home
Customize Dashboard

Quick Add
Transaction Detail
Transaction Edit
Transaction Split
Refund
Transfer

Transaction Timeline
Search
Filter

Accounts
Account Detail
Account Reconciliation
Account Archive

Categories
Category Editor

Budget List
Budget Detail
Budget Editor

Bills
Bill Detail

Recurring Rules

Insights
Report Detail

Notifications Settings
Security Settings
Privacy
Backup
Import
Export
Devices
Sync Status
Conflict Resolution
Profile
Delete Account
About
```

Capability-gated screens:

```text
Goals
Goal Detail
Subscriptions
Subscription Detail
Tag Manager
Merchant Manager
Receipt Review
Shared Workspace
Member Management
Shared Audit History
Net Worth
Multi-Currency Rate Review
```

---

# 119. USER FLOW — ADD EXPENSE

```text
Home
 ↓
+
 ↓
Amount
 ↓
Category
 ↓
Account
 ↓
Save
 ↓
Local DB commit
 ↓
Ledger generated
 ↓
Outbox queued
 ↓
UI update
 ↓
Background sync
```

If local commit fails:

> transaction is not shown as saved.

---

# 120. USER FLOW — TRANSFER

```text
+
↓
Transfer
↓
From account
↓
To account
↓
Amount
↓
Fee optional
↓
Save
↓
Atomic transaction/group write
↓
Source + destination ledger effects
↓
Linked fee expense if any
↓
Outbox
```

Jika ada fee, Timeline tetap menampilkan **satu logical transfer card** dengan breakdown fee, sementara reporting menghitung fee sebagai expense.

Validation:

- from != to;
- source/destination exist;
- currencies valid.

---

# 121. USER FLOW — EDIT

```text
Timeline
↓
Transaction
↓
Edit
↓
Change
↓
Save
↓
Version validation
↓
Ledger reconcile
↓
Outbox
```

---

# 122. USER FLOW — DELETE

```text
Transaction
↓
Delete
↓
Meaningful confirmation
↓
Soft-delete
↓
Ledger effect removed
↓
Tombstone sync
```

---

# 123. USER FLOW — RECONCILE

```text
Account
↓
Reconcile
↓
Enter observed balance
↓
Show difference
↓
Review transactions
or
Create adjustment
```

---

# 124. USER FLOW — RESTORE BACKUP

```text
Settings
↓
Restore
↓
Select file
↓
Verify/decrypt
↓
Preview
↓
Confirm
↓
Atomic restore
↓
Migration
↓
Integrity check
↓
Success
```

If integrity fails:

> existing database remains intact.

---

# 125. BUSINESS RULE PRIORITY

Jika terjadi konflik antara rules:

1. security;
2. financial integrity;
3. user data preservation;
4. explicit user intent;
5. convenience;
6. visual preference.

---

# 126. DANGEROUS DESIGN DECISIONS — DILARANG

Do not:

- store balance as only source of truth;
- use float for money;
- count transfer as expense;
- count credit card payment as expense twice;
- count loan proceeds as income;
- hard delete used categories casually;
- silent overwrite financial sync conflict;
- block transaction save on internet;
- rely on device current timezone for historical period;
- allow OCR/AI to silently save ambiguous amount;
- log financial payload to analytics;
- make backup restore partially overwrite live DB.

---

# 127. EDGE CASE CHECKLIST

Must test:

- Rp0 transaction;
- negative input;
- extremely large amount;
- account archived during draft;
- category archived during edit;
- transfer currency mismatch;
- monthly recurring on 29/30/31;
- leap year;
- timezone travel;
- refund after category archived;
- refund after account archived;
- multiple partial refunds;
- transfer fee;
- transaction edited while offline;
- transaction deleted on another device;
- app killed mid-save;
- database full;
- attachment upload failure;
- duplicate import;
- network flapping;
- expired token;
- workspace member removed while offline;
- device clock wrong;
- server clock difference.

---

# 128. DEVICE CLOCK SAFETY

Client local date is important for user intent, but server timestamps provide operation ordering.

Store both:

- occurred date chosen by user;
- created server timestamp;
- client operation timestamp.

Do not rewrite transaction date simply because server clock differs.

---

# 129. IDEMPOTENT SAVE

Every create action has client transaction ID before local save.

Double tapping Save must not create two expenses.

UI should disable/reconcile duplicate submit and DB should use unique ID.

---

# 130. UNDO

For low-risk destructive actions like transaction delete:

Allow short local undo when possible.

Undo must generate explicit restoration operation, not erase sync history silently.

---

# 131. DATA CORRUPTION RECOVERY

If local DB validation fails:

1. stop risky writes;
2. preserve encrypted copy;
3. attempt safe recovery;
4. offer restore from backup/cloud;
5. never overwrite last good backup.

---

# 132. SUPPORT DIAGNOSTICS

User may generate sanitized diagnostic package:

- app version;
- device OS;
- sync operation status;
- schema version;
- error codes.

Exclude:

- amounts;
- merchant names;
- notes;
- receipts;
- tokens.

---

# 133. OBSERVABILITY

Backend dashboards:

- auth failure;
- sync latency;
- sync conflicts;
- operation retry;
- server errors;
- attachment failures;
- deletion pipeline.

No financial values.

---

# 134. FEATURE OWNERSHIP

Every major feature should have:

- product owner;
- technical owner;
- test owner;
- spec section;
- acceptance criteria.

Even for solo development, these responsibilities remain as checklist roles.

---

# 135. ACCEPTANCE CRITERIA — MVP

MVP dianggap usable bila:

- new user can start without account;
- first expense < 1 minute including onboarding;
- repeat expense target 2–4 seconds;
- expense/income/transfer correct;
- edit/delete correct;
- refunds correct;
- account balance reconciles;
- budgets correct;
- recurring works;
- offline works;
- app restart does not lose committed data;
- backup/restore works;
- sync works across two devices;
- conflict visible;
- no duplicate on retries;
- app lock works;
- export works;
- account deletion works;
- no blocker accessibility issue;
- no critical crash;
- no known financial integrity bug.

---

# 136. PRODUCTION DEFINITION OF DONE

Production release is allowed only if:

```text
[ ] Core financial invariants PASS
[ ] Offline stress PASS
[ ] Sync stress PASS
[ ] Migration PASS
[ ] Backup restore PASS
[ ] Security review PASS
[ ] Privacy review PASS
[ ] Performance PASS
[ ] Critical accessibility PASS
[ ] Android production build PASS
[ ] iOS production build PASS
[ ] Store metadata ready
[ ] Privacy policy ready
[ ] Account deletion tested
[ ] Crash monitoring active
[ ] Staged rollout plan ready
[ ] Rollback/kill switch ready
```

---

# 137. RELEASE GATE SEVERITY

## P0

- financial data corruption;
- unauthorized financial data access;
- transaction duplication;
- app cannot launch.

Release blocked.

## P1

- balance incorrect;
- sync loses committed transaction;
- backup restore broken;
- account deletion broken.

Release blocked.

## P2

- non-critical feature malfunction;
- visual issue.

May release only with explicit product decision.

---

# 138. POST-RELEASE OPERATIONS

Monitor:

- crash-free rate;
- sync errors;
- auth errors;
- conflict rate;
- review feedback;
- store rejection;
- backup restore incidents.

Use staged rollout rather than 100% immediate release for high-risk changes.

---

# 139. CHANGE MANAGEMENT

Any change to:

- transaction type;
- ledger;
- refund;
- transfer;
- money storage;
- currency;
- sync;

requires:

1. specification update;
2. migration plan;
3. invariant tests;
4. regression tests.

---

# 140. OPEN QUESTIONS POLICY

Production core should not carry hidden “TODO business rule”.

If a decision is truly deferred:

```text
DEFERRED
Reason:
Safe current default:
Future migration impact:
```

---

# 141. RESOLVED DEFAULT DECISIONS

To prevent ambiguity, V1 uses these defaults:

```text
Core mode                 = offline-first
Login                     = optional until cloud feature
Money storage             = integer minor units
Canonical balance         = ledger-derived
Delete history            = soft-delete
Used account/category     = archive by default
Transfer                  = not expense/income
Refund                    = offsets expense
Credit card payment       = not second expense
Loan proceeds             = not income
Budget rollover           = off
Recurring                 = reminder/draft by default
Financial sync conflict   = explicit review
Preference sync conflict  = last-write-wins allowed
Reporting timezone        = workspace timezone
AI ambiguous transaction  = review/draft
OCR                       = review before save
```

---

# 142. RECOMMENDED TECH STACK

## Client

Flutter.

## Local

Encrypted SQLite-style relational database with repository abstraction.

## Backend

PostgreSQL.

A managed platform such as Supabase can accelerate:

- auth;
- database;
- storage;
- row-level security;
- realtime/sync support components.

But business logic must remain portable through repository/service interfaces.

## Server Functions

Use server-side functions for:

- destructive account deletion;
- secure AI/OCR proxy;
- invitation;
- complex sync validation;
- billing future;
- sensitive token handling.

---

# 143. WHY RELATIONAL DATABASE

Financial data benefits from:

- foreign keys;
- constraints;
- transactions;
- atomic writes;
- relational reporting;
- migrations;
- integrity checks.

Avoid free-form document storage as the only source of truth for finance core.

---

# 144. MINIMUM BACKEND AUTHORIZATION RULES

Every query must prove:

```text
user is workspace member
AND
role permits action
```

Attachment access must also be workspace-scoped.

Never accept `workspace_id` alone as authorization proof.

---

# 145. AI ARCHITECTURE PRIVACY

AI feature should receive only data required for that request.

Default:

- do not send full financial history;
- redact unnecessary personal fields;
- disclose when cloud AI processing is used;
- allow disabling AI.

---

# 146. RECEIPT DATA PRIVACY

Receipt can contain:

- address;
- card digits;
- phone;
- loyalty ID.

OCR pipeline should minimize retention.

Provide:

- delete attachment;
- clear extracted text where appropriate.

---

# 147. FUTURE BANK INTEGRATION

Treat bank import as separate ingestion layer.

Imported record must still become canonical transaction via validation/dedup pipeline.

Do not let bank provider-specific object become source of truth.

---

# 148. FUTURE AUTOMATION RULE ENGINE

Examples:

```text
IF merchant = Starbucks
THEN category = Cafe

IF amount > 1,000,000 AND category = Shopping
THEN notify

IF merchant contains Netflix
THEN suggest subscription
```

Rules versioned and user-editable.

---

# 149. DASHBOARD INSIGHT QUALITY

Do not show:

> “Pengeluaran terbesar: Rp0”

when actual expense exists.

Widgets must define:

- data source;
- period;
- inclusion rules;
- fallback;
- empty state.

Example Largest Expense:

```text
Period = selected dashboard period
Eligible = posted EXPENSE minus void/deleted
Refund treatment = net
Result = max eligible transaction
```

---

# 150. REPORT CONSISTENCY

The same filter set must produce compatible totals across:

- Home;
- Transactions;
- Budget;
- Insights;
- Export.

If totals differ, reason must be explicitly labelled, e.g.:

> “Forecast includes scheduled bills.”

---

# 151. FINAL PRODUCT PHILOSOPHY

Aplikasi harus terasa:

- ringan;
- cepat;
- tenang;
- terpercaya;
- tidak seperti software accounting;
- tetapi memiliki financial engine yang jauh lebih disiplin daripada UI-nya terlihat.

Target pengalaman:

> User tidak perlu memahami ledger, reconciliation, sync conflict, atau minor-unit arithmetic.

Namun sistem di belakang harus memahami semuanya dengan benar.

---

# 152. FINAL BUILD ORDER

Urutan implementasi yang **tidak boleh dibalik tanpa alasan teknis kuat**:

```text
1. Master Spec
2. Financial Domain Model
3. Ledger + Money Types
4. Local Database
5. Transaction Engine
6. Invariant Tests
7. Core UX
8. Budget/Recurring
9. Backup/Restore
10. Authentication
11. Sync
12. Sync Conflict Tests
13. Security
14. Production Observability
15. Store Compliance
16. Beta
17. Production
18. Smart/AI Features
```

Alasan:

> Fitur “wow” tidak berguna jika saldo, transfer, backup, dan sync belum benar.

---

# 153. FINAL PRE-CODING CHECKLIST

Sebelum membuat production code:

```text
[ ] ERD final digambar
[ ] Transaction state machine final
[ ] Sync state machine final
[ ] Account types final
[ ] Money type implemented/tested
[ ] Ledger invariants defined as automated tests
[ ] Design tokens defined
[ ] Navigation wireframe final
[ ] Database migration framework ready
[ ] Local encryption decision implemented
[ ] Dev/Staging/Prod isolated
```

---

# 154. FINAL PRE-BETA CHECKLIST

```text
[ ] 2-device sync tested
[ ] airplane-mode tested
[ ] app-kill-during-sync tested
[ ] double-tap-save tested
[ ] refund tested
[ ] credit card tested
[ ] transfer fee tested
[ ] reconciliation tested
[ ] 31st recurring tested
[ ] locale IDR tested
[ ] dark mode tested
[ ] large dataset tested
[ ] backup restore tested
[ ] old schema migration tested
```

---

# 155. FINAL PRE-STORE CHECKLIST

```text
[ ] No P0/P1 bugs
[ ] Privacy policy published
[ ] Terms reviewed
[ ] Account deletion available
[ ] Analytics privacy reviewed
[ ] Crash logs sanitized
[ ] Android target requirement rechecked
[ ] Apple current SDK/Xcode requirements rechecked
[ ] Privacy manifests checked
[ ] Data Safety/App Privacy answers match implementation
[ ] Permission strings accurate
[ ] Store screenshots final
[ ] Support contact active
[ ] Staged rollout configured
```

---

# 156. SOURCE-OF-TRUTH RULE

The canonical hierarchy is:

```text
Master Specification
       ↓
Domain Rules
       ↓
Automated Tests
       ↓
Implementation
       ↓
UI
```

UI screenshot is **not** the source of truth for financial behavior.

---

# 157. VERSION HISTORY

## V1.1 — 2026-09-08

Reverse-audited baseline. Added UI↔backend traceability, logical amount contract, available-balance definition, composite-event presentation, dependency rules, local profile isolation, portable backup contract, capability gating, and reverse simulation gates.

## V1 — 2026-09-08

Initial production-grade baseline covering:

- product;
- UX;
- ledger;
- accounts;
- transactions;
- budget;
- recurring;
- bills;
- credit card;
- debt;
- shared workspace;
- offline;
- sync;
- conflicts;
- backup;
- security;
- privacy;
- database;
- architecture;
- testing;
- release;
- production acceptance.

---

# 158. NEXT ARTIFACTS TO DERIVE FROM THIS MASTER SPEC

Dokumen ini menjadi induk untuk membuat:

```text
01_PRODUCT_REQUIREMENTS.md
02_USER_FLOWS.md
03_SCREEN_SPECIFICATIONS.md
04_DESIGN_SYSTEM.md
05_DATABASE_ERD.md
06_DATABASE_SCHEMA.md
07_FINANCIAL_RULES.md
08_SYNC_PROTOCOL.md
09_API_CONTRACT.md
10_SECURITY_PRIVACY.md
11_TEST_PLAN.md
12_RELEASE_CHECKLIST.md
```

Dokumen turunan tidak boleh membuat business rule baru yang bertentangan dengan Master Spec.

---

# 159. MASTER SIGN-OFF PRINCIPLE

Sebuah aplikasi personal finance dianggap **benar-benar siap digunakan** bukan ketika tampilannya sudah bagus, tetapi ketika:

- user dapat memasukkan data dengan cepat;
- saldo dapat dijelaskan dari transaksi;
- transaksi tidak hilang;
- transaksi tidak terduplikasi;
- edit/delete tidak merusak saldo;
- transfer tidak dianggap pengeluaran;
- refund tidak dianggap income palsu;
- kartu kredit tidak double-count;
- backup bisa dipulihkan;
- offline aman;
- sync aman;
- konflik tidak disembunyikan;
- user dapat mengekspor data;
- user dapat menghapus account;
- release memenuhi kebijakan platform saat tanggal publikasi.

**Itulah Definition of Ready/Usable untuk aplikasi ini.**

---

# 160. CROSS-SYSTEM AUDIT — KOREKSI SETELAH REVIEW

Bagian ini mencatat audit konsistensi antara UX, business rules, ledger, sync, dan reporting.

## 160.1 Transfer Fee — RESOLVED

Masalah yang ditemukan:

> TRANSFER didefinisikan tidak memakai expense category, tetapi versi awal contoh fee mencoba memasukkan fee langsung ke kategori expense pada transfer.

Keputusan final:

> transfer utama dan fee dibuat sebagai transaksi terhubung dalam `transaction_group_id`.

Group ditulis atomically.

## 160.2 Loan Interest — RESOLVED

Masalah serupa berlaku pada pembayaran pinjaman.

Keputusan final:

- principal = LOAN_PAYMENT;
- interest = linked EXPENSE;
- fee = linked EXPENSE;
- seluruhnya satu atomic transaction group.

## 160.3 Refund Category — RESOLVED

REFUND boleh memakai kategori expense original/compatible.

Reporting sign:

```text
normal expense  = +expense
linked refund   = -expense
```

Refund tidak menjadi income biasa.

## 160.4 VOID vs DELETE — RESOLVED

`VOID` berarti transaksi sengaja dibatalkan tetapi record dipertahankan.

Rules:

- VOID tidak mempengaruhi current ledger/report;
- deleted transaction juga tidak mempengaruhi ledger/report;
- VOID adalah business status;
- deleted adalah lifecycle/tombstone status.

Jangan memakai keduanya secara acak untuk tujuan yang sama.

## 160.5 Composite Transaction Atomicity — RESOLVED

Untuk transaction group:

```text
Begin DB transaction
Create group
Create all child transactions
Create all ledger legs
Create all splits
Validate invariants
Commit
```

Jika satu child gagal:

> rollback seluruh group.

---

# 161. LOGIN / GUEST DATA MIGRATION

Saat user mulai local-only lalu membuat cloud account:

```text
Local Workspace
↓
Authenticate
↓
Create/claim cloud workspace
↓
Preserve existing UUIDs
↓
Upload via idempotent sync
↓
Server validation
↓
Mark synced
```

Jangan membuat ulang transaction ID saat login.

Setiap authenticated user mempunyai local data namespace/cache terisolasi. Data milik user A tidak boleh terbuka ketika user B login pada device yang sama.

## 161.1 Duplicate Cloud Data

Jika user login ke account yang sudah memiliki cloud data sementara device juga memiliki local data:

Tawarkan:

```text
Use cloud data
Merge local data
Keep local as separate workspace
```

`Merge` menjalankan duplicate detection dan preview.

Tidak boleh silent merge.

---

# 162. LOGOUT RULE

Logout tidak boleh otomatis menghapus data lokal tanpa penjelasan.

Flow:

```text
Log out

○ Keep encrypted data on this device
○ Remove local data after logout
```

Jika device shared/public, user bisa memilih remove.

Cloud data tetap mengikuti account retention policy.

Jika user memilih `Keep encrypted data on this device`, cache tetap terikat ke identity + encryption key user tersebut dan tidak dapat dibaca oleh account lain yang login kemudian.

---

# 163. BACKUP + CLOUD RESTORE RULE

Full backup mempertahankan canonical IDs.

Restore modes:

```text
REPLACE_LOCAL
MERGE_AS_IMPORT
RESTORE_OFFLINE_COPY
```

Jika cloud sync aktif:

- restore tidak boleh meng-upload duplicate copies dengan ID baru;
- preserved IDs + version metadata dipakai untuk reconcile;
- destructive replace cloud membutuhkan flow khusus dan confirmation.

Portable backup yang dimaksud untuk dipindahkan ke device lain harus memakai encryption yang dapat dipulihkan lintas-device, misalnya user passphrase/recovery key atau secure wrapped backup key. Backup yang hanya dienkripsi dengan device Keystore/Keychain tidak dianggap portable.

---

# 164. BACKGROUND SYNC REALITY

Android/iOS dapat membatasi background execution.

Karena itu correctness tidak boleh bergantung pada background sync selalu berjalan.

Mandatory sync triggers:

- app foreground;
- user pull-to-refresh;
- after local write when network available;
- OS-permitted background opportunity.

Status local write tetap valid walau background sync tertunda.

---

# 165. TRANSACTION STATUS EFFECT MATRIX

| Status | Ledger Effect | Report | Sync |
|---|---:|---:|---:|
| DRAFT | No | No | Yes |
| SCHEDULED | No | Forecast only | Yes |
| POSTED | Yes | Yes | Yes |
| VOID | No | No | Yes |
| DELETED/TOMBSTONE | No | No | Yes |

Scheduled transaction berubah menjadi POSTED hanya melalui explicit posting rule. Explicit rule dapat berupa tindakan user atau recurring rule yang sudah diberi `AUTO_CREATE` authorization.

---

# 166. REPORTING CONSISTENCY MATRIX

| Event | Expense | Income | Account Balance | Net Worth |
|---|---:|---:|---:|---:|
| Expense from asset | + | 0 | Asset ↓ | ↓ |
| Income to asset | 0 | + | Asset ↑ | ↑ |
| Transfer asset→asset | 0 | 0 | Move only | 0 |
| Transfer fee | + | 0 | Asset ↓ | ↓ |
| Credit card purchase | + | 0 | Liability ↑ | ↓ |
| Credit card payment | 0 | 0 | Asset ↓, Liability ↓ | 0 |
| Loan disbursement | 0 | 0 | Asset ↑, Liability ↑ | 0 |
| Loan principal payment | 0 | 0 | Asset ↓, Liability ↓ | 0 |
| Loan interest | + | 0 | Asset ↓ | ↓ |
| Expense refund to asset | − expense | 0 | Asset ↑ | ↑ |
| Expense refund to liability | − expense | 0 | Liability ↓ | ↑ |
| Opening asset balance | 0 | 0 | Asset set via ledger | baseline |
| Opening liability | 0 | 0 | Liability set via ledger | baseline |
| Adjustment | 0 default | 0 default | Changes target account | Changes accordingly |

This matrix must be covered by automated regression tests.

---

# 167. TRANSACTION GROUP TABLE

Add canonical table:

```text
transaction_groups
```

Fields:

```text
id UUID
workspace_id UUID
group_type ENUM
created_by UUID
created_at TIMESTAMP
updated_at TIMESTAMP
version BIGINT
```

Possible group types:

```text
TRANSFER_WITH_FEE
LOAN_PAYMENT
COMPOSITE
```

Group is optional.

Normal expense does not require a group.

UI rule:

> satu transaction group = satu logical event card pada Timeline, kecuali user membuka breakdown detail.

Edit/delete/void terhadap composite event dilakukan pada group level.

---

# 168. DOUBLE-SUBMIT & RAPID INPUT TEST

Must test:

- tap Save twice rapidly;
- app freeze then user taps again;
- network reconnect during save;
- OS resumes after background.

Expected:

> one logical user action = one transaction ID = one financial effect.

---

# 169. DATA LOSS PREVENTION ON APP UPDATE

Before destructive local migration:

1. validate available storage;
2. preserve migration recovery point when feasible;
3. run migration transactionally;
4. run integrity check;
5. only then mark new schema active.

If migration fails:

> app must not pretend upgrade succeeded.

---

# 170. MONTH-END / YEAR-END RULE

There is no special “closing” required for personal usage.

Reports are derived from transaction dates.

Optional period lock may be added for advanced users.

If period lock enabled:

- historical edits require unlock/confirmation;
- lock is per period, not global;
- one month's lock must never accidentally change all months.

---

# 171. PERIOD LOCK — FUTURE ADVANCED FEATURE

Fields:

```text
workspace_id
period_start
period_end
status = OPEN | LOCKED
locked_by
locked_at
```

Do not store only one global `month_status`.

This prevents the class of bug where editing May status changes every month.

---

# 172. FINANCIAL CACHE INVALIDATION

Any change to:

- transaction date;
- amount;
- account;
- category;
- status;
- refund;
- split;

must invalidate affected:

- dashboard aggregate;
- budget period;
- reports;
- insights;
- account balance cache if used.

Caches are derived and rebuildable.

---

# 173. ARCHIVE VS DELETE CONSISTENCY

Default historical entities:

- accounts → archive;
- categories → archive;
- merchants → merge/archive;
- tags → archive/delete only if unused.

Historical transaction display uses snapshot/reference fallback so archived entities remain readable.

---

# 174. USER-FACING SYNC STATUS

Do not expose technical jargon by default.

Examples:

```text
All changes saved
Saved on this device
Syncing…
2 items need review
```

Technical operation IDs only appear in diagnostics.

---

# 175. FINAL INTERNAL AUDIT RESULT

After cross-checking the V1 flows, the following core contradictions have been resolved:

```text
[RESOLVED] Transfer fee vs category semantics
[RESOLVED] Loan principal vs interest reporting
[RESOLVED] Refund category/report sign
[RESOLVED] VOID vs DELETE responsibility
[RESOLVED] Guest → cloud migration
[RESOLVED] Backup restore vs sync duplicates
[RESOLVED] Background sync dependency
[RESOLVED] Monthly status must not be global
[RESOLVED] Composite transaction atomicity
```

Remaining policy-dependent items are intentionally marked as **revalidate before release**, especially Google Play/App Store requirements, because platform rules change over time.

The core financial architecture itself is now specified so implementation can be validated by automated invariants rather than assumptions.

---

# 176. REVERSE AUDIT METHOD — UI ⇄ BACKEND ⇄ REQUIREMENT

V1.1 melakukan pengecekan terbalik, bukan hanya membaca requirement dari awal ke akhir.

Dua arah wajib:

```text
A. USER/UI
   ↓
Use Case
   ↓
Validation
   ↓
Local Transaction
   ↓
Ledger/Data
   ↓
Outbox/Sync
   ↓
Server
   ↓
Report/Derived Data
   ↓
kembali ke USER/UI
```

dan:

```text
B. BACKEND ENTITY/RULE
   ↓
Siapa yang memicu?
   ↓
Di screen apa?
   ↓
Apa yang user lihat?
   ↓
Bagaimana user memperbaiki error?
   ↓
Apakah hasil akhirnya memenuhi kebutuhan awal?
```

Suatu fitur dianggap lengkap secara desain hanya jika kedua arah mempunyai jawaban.

---

# 177. REVERSE TRACEABILITY — UI KE BACKEND

| UI / Angka / Aksi | Use Case | Canonical Data | Rule Utama | Reverse Check |
|---|---|---|---|---|
| Total Available Balance | CalculateAvailableBalance | accounts + transaction_legs | asset included only | Tidak tercampur liability/investment |
| Spending This Month | BuildExpenseReport | transactions + splits + refunds | POSTED, net refund, workspace timezone | Sama dengan filtered transaction total |
| Net Worth | CalculateNetWorth | accounts + legs | assets − liabilities | Transfer/payment principal net zero |
| Quick Add Expense | CreateExpense | transaction + legs + split | atomic local write | Timeline dan balance berubah sekali |
| Income | CreateIncome | transaction + legs + split | raises net worth | Tidak dianggap transfer |
| Transfer | CreateTransfer | transaction/group + legs | income/expense zero | source↓ destination↑ |
| Transfer Fee | CreateTransferGroup | group + transfer + expense child | fee expense only | UI satu logical card |
| Refund | CreateRefund | refund linked original | total refund <= original | expense report berkurang |
| Edit | EditTransaction/Group | versioned entities | replace old effect | tidak double-count |
| Delete | DeleteTransaction/Group | tombstone | removes report/ledger effect | sync tombstone |
| Account Balance | CalculateAccountBalance | transaction_legs | ledger-derived | bukan mutable saldo |
| Reconcile | ReconcileAccount | adjustment | reason required | selisih menjadi 0 setelah adjustment |
| Budget Progress | CalculateBudgetActual | split/refund | transfer excluded | cocok dengan report filter yang sama |
| Safe-to-Spend | CalculateSafeToSpend | budget + bills | no budget = no fake number | UI CTA jika belum setup |
| Upcoming Bills | QueryBills | bills | status/date | scheduled tidak mengubah balance |
| Recurring | RunRecurringRule | recurring_rules | draft/post by mode | generated once/idempotent |
| Search | SearchTransactions | canonical/search index | deleted excluded | hasil membuka transaction detail yang sama |
| Backup | CreateBackup | canonical local DB | encrypted, integrity hash | restore menghasilkan ledger yang sama |
| Sync Status | SyncCoordinator | sync_operations/conflicts | idempotent | UI status sesuai outbox |
| Conflict Review | ResolveConflict | sync_conflicts | no silent overwrite finance | selected version revalidated |

---

# 178. REVERSE TRACEABILITY — BACKEND KE UI

| Backend Element | Harus Muncul/Diakses Melalui | Jika Tidak Ada UI |
|---|---|---|
| transaction_groups | logical event detail | child rows akan membingungkan/double-looking |
| transaction_legs | account detail/reconciliation secara derived | jangan expose raw leg ke user biasa |
| transaction_splits | Split editor/detail | report kategori tidak dapat dijelaskan |
| tombstones | Sync status/undo lifecycle | tidak perlu tampil sebagai transaksi aktif |
| sync_conflicts | Conflict Resolution | financial edit berisiko hilang |
| recurring_rules | Recurring Rules | user tak bisa mematikan automation |
| bills | Bills/Plan | reminder tanpa sumber jelas |
| budgets | Budget screens | dashboard budget tak dapat dikontrol |
| devices | Devices | user tidak dapat revoke session |
| audit_logs | Shared Audit History / diagnostics | wajib sebelum shared workspace production |
| exchange rate snapshots | Transaction/Rate detail bila multi-currency enabled | histori kurs tidak dapat dijelaskan |
| notification_preferences | Notification Settings | notifikasi menjadi spam |
| app_preferences | Settings / Customize Dashboard | custom UI tidak persisten |

---

# 179. DASHBOARD FORMULA CONTRACT

## 179.1 Available Balance

```text
available_balance(currency C)
=
SUM(account_balance)
WHERE
account_class = ASSET
AND include_in_available_balance = true
AND reporting conversion rule valid
```

Credit limit bukan uang tersedia milik user dan tidak masuk Available Balance.

## 179.2 Spending This Month

```text
posted expense allocations
- linked posted refunds
```

Excluded:

- transfer;
- opening balance;
- adjustment default;
- credit-card payment;
- loan principal;
- scheduled/draft/void/deleted.

## 179.3 Today

`Today` menggunakan workspace timezone/local_date, bukan UTC date mentah.

## 179.4 Net Worth

```text
included assets
-
included liabilities
```

Investment dapat masuk Net Worth tetapi tidak Available Balance.

---

# 180. LOGICAL AMOUNT CONTRACT

Reverse audit menemukan transaksi membutuhkan nilai logical amount yang eksplisit untuk:

- display;
- validation;
- split invariant;
- duplicate detection;
- export;
- conflict comparison.

Karena itu `transactions` memiliki:

```text
primary_amount_minor
primary_currency
```

Rules:

- user input nominal selalu non-negative;
- arah ditentukan transaction type;
- EXPENSE/INCOME/REFUND mempunyai primary logical amount;
- transfer primary amount adalah source amount;
- destination amount berasal dari destination leg untuk multi-currency;
- split sum menggunakan primary amount untuk simple categorized transaction.

Ledger legs tetap menjadi canonical account-balance effect.

---

# 181. COMPOSITE EVENT PRESENTATION

Backend dapat memiliki beberapa child transaction untuk satu aktivitas user.

Examples:

```text
Transfer + Fee
Loan Principal + Interest + Fee
```

UI:

```text
Transfer ke GoPay       Rp500.000
Biaya transfer            Rp1.000
Total keluar             Rp501.000
```

Timeline menampilkan satu card.

Detail membuka children.

Reporting:

- transfer component excluded expense;
- fee component included expense.

Edit/delete dilakukan atomically pada group.

---

# 182. ACCOUNT LIFECYCLE DEPENDENCY CHECK

Saat Archive Account:

System memeriksa:

- active recurring rules;
- bills;
- subscriptions;
- scheduled transaction;
- transfer shortcuts;
- goals linked account.

UI menawarkan:

```text
Reassign
Disable affected rule
Cancel
```

Archive tidak boleh membuat automation terus menulis ke account tersembunyi.

---

# 183. CATEGORY LIFECYCLE DEPENDENCY CHECK

Saat archive/merge category:

Check:

- budget scopes;
- recurring rules;
- bills;
- merchant rules;
- scheduled drafts.

Merge preview menunjukkan jumlah reference yang akan dipindahkan.

Operation atomic.

---

# 184. REFUND DEPENDENCY CONTRACT

Jika original expense mempunyai active refund:

### Edit original amount

Allowed hanya jika:

```text
new_original_amount >= active_refund_total
```

### Delete/void original

Tidak boleh meninggalkan orphan refund.

Pilihan:

- cancel;
- void original + linked refunds atomically;
- resolve refunds first.

### Refund account

Refund dapat dikreditkan ke account berbeda hanya melalui explicit user choice dan tetap linked ke original.

---

# 185. ACCOUNT MOVE / BULK MIGRATION SAFETY

Bulk move transaction bukan aksi sederhana.

Rules minimum:

- target account same workspace;
- compatible currency;
- composite group handled as whole;
- transfer tidak berubah menjadi self-transfer;
- linked refund stays valid;
- affected reports recalculated;
- operation atomic;
- preview before commit.

Karena risiko tinggi, default Account screen hanya menyediakan Archive.

---

# 186. FEATURE CAPABILITY GATING

Backend future-ready tidak berarti UI harus menampilkan semua fitur.

Capability examples:

```text
receipt_attachments
goals
subscriptions
credit_card_advanced
loans
multi_currency
shared_workspace
ai_input
ocr
projects
persons
reimbursements
location
```

Rule:

> tidak ada tombol/field feature sebelum capability memiliki schema + use case + error handling + test + sync rule.

Ini mencegah “informasi kosong” atau menu yang belum benar-benar bekerja.

---

# 187. LOCAL PROFILE ISOLATION

Device dapat memiliki:

```text
Guest Local Profile
Authenticated User A Cache
Authenticated User B Cache
```

Masing-masing storage namespace terisolasi.

Logout `Keep data`:

- lock cache user A;
- user B tidak dapat membukanya;
- login A kembali dapat membuka setelah auth/key validation.

Ini wajib untuk privacy pada shared device.

---

# 188. PORTABLE BACKUP CONTRACT

Dua kategori backup:

## Device Recovery Backup

Boleh bergantung pada platform/device secure storage.

## Portable Encrypted Backup

Harus dapat dipindah lintas device dengan:

- user passphrase/recovery key; atau
- cryptographically wrapped portable backup key.

Restore selalu:

```text
Verify
Decrypt
Schema migration
Preview
Atomic restore
Ledger integrity audit
```

Jika gagal, existing live database tidak berubah.

---

# 189. USER FLOW COVERAGE MATRIX

| Flow | UI | Domain | DB | Offline | Sync | Error | Test |
|---|---:|---:|---:|---:|---:|---:|---:|
| Onboarding/local start | ✓ | ✓ | ✓ | ✓ | n/a | ✓ | Required |
| Create expense | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | Required |
| Create income | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | Required |
| Transfer | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | Required |
| Transfer + fee | ✓ V1.1 | ✓ | ✓ | ✓ | ✓ | ✓ | Required |
| Edit | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | Required |
| Delete/void | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | Required |
| Refund | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | Required |
| Reconcile | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | Required |
| Budget | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | Required |
| Bills | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | Required |
| Recurring | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | Required |
| Backup/restore | ✓ | ✓ | ✓ | ✓ | optional | ✓ | Required |
| Login local→cloud | ✓ | ✓ | ✓ | partial | ✓ | ✓ | Required |
| Logout/switch user | ✓ V1.1 | ✓ | ✓ | ✓ | ✓ | ✓ | Required |
| Sync conflict | ✓ | ✓ | ✓ | generated offline | ✓ | ✓ | Required |
| Account archive | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | Required |
| Category merge/archive | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | Required |
| Import | ✓ | ✓ | ✓ | ✓ | later sync | ✓ | Required |
| Export | ✓ | ✓ | read-only | ✓ | n/a | ✓ | Required |

---

# 190. REVERSE SIMULATION TEST SET

Sebelum ada production code, domain specification diuji menggunakan simplified reference model.

Scenarios yang harus menghasilkan hasil yang sama pada implementasi nyata:

```text
PASS — Expense reduces asset and net worth
PASS — Income increases asset and net worth
PASS — Asset transfer has zero net-worth effect
PASS — Transfer fee is expense only
PASS — Credit-card purchase lowers net worth
PASS — Credit-card payment does not double-count expense
PASS — Loan disbursement is not income
PASS — Loan principal payment is net-worth neutral
PASS — Loan interest is expense
PASS — Partial refund reduces expense
PASS — Credit-card refund reduces liability
PASS — Edit replaces old effect, not adds new effect
PASS — Delete removes financial effect
PASS — Opening liability reduces baseline net worth
PASS — Adjustment changes balance but not default expense/income
PASS — Draft has no balance/report effect
```

Production implementation must reproduce these results with automated tests against the real domain/repository layer.

---

# 191. REVERSE AUDIT FINDINGS — RESOLVED IN V1.1

Reverse checking identified and resolved:

```text
[FIXED] Available Balance was ambiguous vs Net Worth
[FIXED] Income definition did not cover liability reduction
[FIXED] Credit-card refund path was not explicit
[FIXED] Transaction logical amount was not explicit in core table
[FIXED] Transfer fee backend group had no clear single-card UI contract
[FIXED] Composite edit/delete needed group-level semantics
[FIXED] Account delete/move flow was too dangerous
[FIXED] Archive Account did not define recurring/bill dependencies
[FIXED] Category merge did not define budget/rule dependencies
[FIXED] Original expense vs linked refund edit/delete constraints incomplete
[FIXED] Guest/authenticated local cache isolation was not explicit
[FIXED] Portable backup encryption across devices was not explicit
[FIXED] Future fields existed in Quick Add without finalized domain models
[FIXED] Scheduled AUTO_CREATE authorization needed explicit definition
[FIXED] Investment vs spendable balance needed explicit separation
```

---

# 192. REVERSE AUDIT SIGN-OFF

Setelah V1.1, setiap core finance surface mempunyai jalur yang dapat ditelusuri:

```text
User action
→ use case
→ validation
→ canonical transaction
→ ledger effect
→ report/dashboard
→ sync
→ error/recovery
→ kembali ke user
```

Dan setiap backend core entity mempunyai alasan keberadaan serta surface/recovery path yang jelas.

**Batas validasi:**

Dokumen dapat divalidasi secara logika dan dengan reference-model tests sebelum coding.

Namun setelah aplikasi dibangun, “benar-benar benar” hanya boleh dinyatakan jika implementation lulus:

- automated financial invariant tests;
- repository tests;
- migration tests;
- two-device sync tests;
- backup/restore tests;
- security tests;
- UI/E2E tests;
- beta testing pada Android dan iOS.

Jadi V1.1 adalah **implementation-ready specification**, bukan klaim bahwa software yang belum ditulis sudah bebas bug.

---

# 193. V1.1 BUILD CONTRACT

Mulai coding hanya dari capability yang memenuhi:

```text
Requirement
✓
UI Flow
✓
Domain Rule
✓
Schema
✓
Use Case
✓
Offline Rule
✓
Sync Rule
✓
Error State
✓
Automated Test Case
✓
```

Jika satu kotak belum ada:

> feature belum boleh dianggap siap implementasi.

Ini menjadi aturan utama untuk mencegah “tampilan sudah ada tetapi backend kosong” maupun “backend ada tetapi user tidak punya cara memakai/memperbaikinya”.

---

# 194. FOUNDATIONAL PRODUCT NOTES — KONSEP AWAL YANG WAJIB TETAP TERCATAT

Bagian ini menjaga ide awal agar tidak hilang saat dokumen menjadi semakin teknis.

## 194.1 Benchmark Monefy

Benchmark yang diambil dari Monefy adalah **friksi input yang sangat rendah**, bukan menyalin visual atau arsitekturnya.

Pola benchmark:

```text
Amount
→ Account bila perlu
→ Category
→ Save
```

Tujuan produk kita:

> mempertahankan kecepatan pencatatan, lalu memberi kedalaman yang lebih baik ketika user membutuhkannya.

Feature benchmark yang relevan pada Monefy saat audit dokumen:

- expense/income quick entry;
- categories;
- multiple accounts;
- budget;
- recurring transaction;
- transfer;
- backup/sync;
- passcode/biometric;
- manual data ownership/export.

Benchmark merupakan referensi kompetitif, **bukan requirement yang mengikat**. Product kita boleh berbeda jika UX atau financial correctness lebih baik.

## 194.2 Konsep Home Awal

```text
┌─────────────────────────────┐
│ Selamat Siang              ◉│
│                             │
│ Total Saldo Tersedia        │
│ Rp 18.450.000               │
│                             │
│ Pengeluaran Bulan Ini       │
│ Rp 4.230.000                │
│ ███████████░░ 68% Budget    │
│                             │
│ Hari ini                    │
│ Rp 185.000                  │
│                             │
│ 🍜 Makan       Rp 85.000    │
│ 🚗 Transport   Rp 50.000    │
│ ☕ Cafe         Rp 50.000    │
│                             │
│ Insight                     │
│ Makan naik 17% minggu ini   │
├─────────────────────────────┤
│ Home Transaksi ＋ Plan Insight│
└─────────────────────────────┘
```

Mockup ini **bukan pixel-final UI**. Ia mendokumentasikan hierarchy:

1. uang tersedia;
2. spending;
3. budget/safe-to-spend;
4. activity;
5. insight.

## 194.3 Quick Add Philosophy

Target repeat transaction:

> **2–4 detik sebagai product performance/UX target, bukan jaminan absolut pada semua device/user.**

Default surface:

```text
Rp 85.000
Makan
BCA

[Tambah Detail]
[Simpan]
```

Advanced fields muncul melalui progressive disclosure.

## 194.4 Default Category Starter Set

Contoh starter categories:

```text
Makanan
Transport
Belanja
Rumah
Tagihan
Kesehatan
Hiburan
Pendidikan
Travel
Lainnya
```

User boleh rename/archive/customize.

Category tidak boleh hardcoded sebagai satu-satunya struktur yang dapat dipakai.

## 194.5 Subcategory Example

```text
Makanan
├── Cafe
├── Restaurant
├── Delivery
├── Groceries
└── Snack
```

## 194.6 Custom Dashboard Intent

User casual dapat memilih hanya:

- available balance;
- spending today;
- monthly budget;
- upcoming bills.

User advanced dapat menambah:

- cash flow;
- net worth;
- goal;
- trend;
- subscription;
- category analysis.

Satu aplikasi dapat terlihat berbeda sesuai kebutuhan tanpa membuat navigation utama menjadi penuh.

## 194.7 Smart Insight Intent

Insight harus menjawab pertanyaan, bukan hanya menggambar chart.

Contoh:

```text
Pengeluaran Cafe naik 56% dibanding periode setara bulan lalu.
```

atau:

```text
73% budget Cafe sudah terpakai sementara 42% periode telah berjalan.
```

atau:

```text
Budget makan tersisa Rp450.000 untuk 9 hari.
Safe-to-spend sekitar Rp50.000/hari.
```

Semua insight wajib dapat ditelusuri ke formula dan source data.

## 194.8 Timeline Interaction Intent

Core:

- tap → detail;
- search/filter;
- edit;
- duplicate;
- refund;
- delete.

Swipe shortcut boleh disediakan jika tidak mengganggu accessibility dan mempunyai setting yang aman.

## 194.9 Initial Onboarding Choice Intent

Contoh goal selector:

```text
○ Mencatat pengeluaran
○ Mengatur budget
○ Menabung
○ Mengontrol tagihan
○ Semuanya
```

Pilihan ini digunakan untuk personalization, **bukan untuk mengunci feature secara permanen**.

---

# 195. FINANCIAL SEMANTIC CORRECTIONS — FINAL V2

## 195.1 Income

Default income menambah asset.

Liability settlement bukan income.

Debt forgiveness/gain hanya boleh masuk bila nanti ada domain rule eksplisit.

## 195.2 Generic Transfer

Default:

```text
TRANSFER = asset ↔ asset internal movement
```

Gunakan type khusus untuk:

```text
CREDIT_CARD_PAYMENT
LOAN_PAYMENT
LOAN_DISBURSEMENT
```

## 195.3 Credit Card Credit Balance

Refund atau overpayment dapat membuat credit card liability balance negatif.

Meaning:

```text
positive liability = user owes money
zero               = settled
negative liability = issuer owes/credits user
```

UI harus membedakan “credit balance” dari “utang negatif” yang membingungkan.

## 195.4 Composite Financial Events

Contoh:

```text
Transfer + Fee
Loan Principal + Interest + Fee
```

Satu logical event bagi user, beberapa canonical child transactions di backend.

Semua child:

> atomic.

---

# 196. RECURRING MULTI-DEVICE DEDUPLICATION CONTRACT

Recurring adalah area risiko duplicate yang tinggi.

Mandatory:

```text
rule_id
occurrence_key
scheduled_local_datetime
rule_version
```

Database/server:

```text
UNIQUE(rule_id, occurrence_key)
```

Jika dua device mencoba generate occurrence sama:

- satu diterima;
- satu menjadi idempotent no-op / fetch existing result;
- financial effect hanya satu.

Recurring job juga harus aman ketika:

- device offline lama;
- app dibuka setelah beberapa occurrence terlewat;
- timezone berubah;
- rule diedit;
- rule dihentikan;
- occurrence manual diedit.

Catch-up policy harus eksplisit per mode sebelum implementasi.

---

# 197. FEATURE VISIBILITY CONTRACT

Feature tidak boleh tampil sebagai tombol kosong.

Capability hanya visible jika:

```text
schema ready
use case ready
UI flow ready
offline behavior ready
sync behavior ready
permission behavior ready
error/recovery ready
test ready
```

Contoh capability-gated:

- OCR;
- AI;
- projects;
- persons;
- reimbursement;
- location;
- family;
- multi-currency advanced;
- goals bila belum masuk release scope tertentu.

---

# 198. UI NUMBER TRACEABILITY CONTRACT

Setiap angka utama di aplikasi wajib mempunyai definisi tertulis.

Minimum:

```text
Available Balance
Net Worth
Spending Today
Spending Period
Income Period
Budget Actual
Budget Remaining
Safe-to-Spend
Upcoming Bills
Largest Expense
Largest Category
Cash Flow
Goal Progress
Credit Card Outstanding
Loan Outstanding
```

Untuk setiap metric wajib ada:

1. formula;
2. period;
3. timezone;
4. included transaction types;
5. excluded transaction types;
6. refund handling;
7. currency conversion;
8. empty-state;
9. reconciliation test.

Ini mencegah kasus dashboard menampilkan `0` padahal transaksi sebenarnya ada.

---

# 199. EXTERNAL PLATFORM POLICY SNAPSHOT — VERIFIED 2026-09-08

Kebijakan platform berubah dari waktu ke waktu. Bagian ini adalah **snapshot terverifikasi pada tanggal dokumen**, bukan aturan yang boleh diasumsikan berlaku selamanya.

## 199.1 Google Play — Standard Android Mobile

Verified official source on 2026-09-08:

- mulai **31 Agustus 2026**, new apps dan app updates untuk Android mobile standard harus target **Android 16 / API level 36 atau lebih tinggi**;
- existing apps mempunyai availability requirements yang berbeda;
- Google menyatakan extension sampai **1 November 2026** dapat tersedia bagi developer yang memenuhi kondisi terkait.

Official source:

`https://support.google.com/googleplay/android-developer/answer/11926878`

Release rule:

> re-check official Play Console requirements immediately before submission.

## 199.2 Apple App Store

Verified official Apple sources on 2026-09-08:

- apps yang support account creation harus menyediakan cara untuk **memulai account deletion di dalam app**;
- bila memakai Sign in with Apple, token revocation harus ditangani sesuai integration/account deletion flow;
- App Store privacy disclosures harus mencerminkan data collection app **dan third-party partners/SDKs**;
- privacy manifest / required-reason API rules harus dipenuhi sesuai SDK dan API yang benar-benar digunakan;
- third-party SDKs tertentu memerlukan privacy manifest dan signature.

Official sources:

`https://developer.apple.com/documentation/technotes/tn3194-handling-account-deletions-and-revoking-tokens-for-sign-in-with-apple`

`https://developer.apple.com/support/third-party-SDK-requirements/`

`https://developer.apple.com/app-store/app-privacy-details/`

`https://developer.apple.com/app-store/review/guidelines/`

Release rule:

> Xcode/SDK submission minimums, privacy requirements, dan App Review rules harus dicek ulang saat build release dibuat.

---

# 200. CONSOLIDATION & LOSS-PREVENTION AUDIT

Master Blueprint V2 dibentuk dari:

```text
PERSONAL_FINANCE_APP_MASTER_SPEC_V1
+
PERSONAL_FINANCE_APP_MASTER_SPEC_V1_1_REVERSE_AUDITED
+
REVERSE_AUDIT_REPORT_V1_1
+
original product concept notes from this project conversation
+
V2 correctness corrections
```

## 200.1 Coverage Rule

Seluruh heading dari V1.1 harus tetap tersedia di V2.

V2 boleh:

- memperjelas;
- mengoreksi;
- menambah;
- menggabungkan informasi redundan.

V2 tidak boleh menghapus business rule tanpa correction log.

## 200.2 What Was Corrected Instead of Preserved Literally

Informasi lama **tidak dipertahankan secara literal jika berpotensi salah**.

Contoh:

- “Income dapat berarti pengurangan liability” diperketat agar settlement liability tidak salah diklasifikasikan sebagai income;
- “encrypted SQLite/Drift” diperjelas karena Drift adalah data/persistence layer dan encryption harus dipenuhi oleh storage/encryption solution yang nyata;
- generic transfer dibatasi agar pembayaran liability tidak salah masuk transfer;
- recurring anti-duplicate diperkuat untuk multi-device.

Tujuan “tidak ada yang hilang” berarti:

> tidak ada kebutuhan/aturan penting yang hilang — **bukan** mempertahankan kalimat lama yang ternyata kurang tepat.

---

# 201. MASTER BLUEPRINT FINAL SIGN-OFF

Dokumen ini adalah SSOT untuk memulai implementasi.

Namun software baru dapat disebut production-ready jika implementation nyata lulus gate berikut:

```text
Financial invariant tests       PASS
Database/repository tests       PASS
Migration tests                 PASS
Offline stress tests            PASS
Two-device sync tests           PASS
Recurring dedup tests           PASS
Backup/restore tests            PASS
Security tests                  PASS
Privacy review                  PASS
UI/E2E tests                    PASS
Accessibility checks            PASS
Performance tests               PASS
Android beta                    PASS
iOS beta                        PASS
Store compliance re-validation  PASS
```

Final engineering rule:

> **UI dan backend tidak dibangun sebagai dua proyek yang dicocokkan belakangan. Keduanya harus berasal dari domain contract yang sama.**


