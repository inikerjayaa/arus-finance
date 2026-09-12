# ARUS FINANCE — LOCAL-ONLY ARCHITECTURE V4

**Status:** Normative production architecture

## Product principle

Data finansial pengguna tetap berada dalam kendali pengguna dan perangkatnya.

Kalimat **“Data Anda aman bersama Anda sendiri”** adalah ide/prinsip dasar, **bukan tagline final**. Tagline publik masih TBD dan boleh berubah tanpa mengubah arsitektur produk.

## Production architecture

```text
User Device
  └─ Flutter UI
      └─ Domain Rules
          └─ Local Repository
              └─ Encrypted SQLite Ledger
                  ├─ accounts
                  ├─ transactions / legs / splits
                  ├─ budgets
                  ├─ bills
                  ├─ recurring rules
                  └─ local preferences
```

Core app membutuhkan:

- no login;
- no account registration;
- no Arus server;
- no cloud database;
- no internet connection.

## Canonical source of truth

Canonical financial data = encrypted local database on the user's device.

A cloud service may never silently become the source of truth for the core finance engine.

## Backup and recovery

Portable recovery uses an encrypted `.arusbackup` file created by the user.

User may store that encrypted file wherever they choose:

- local Files;
- laptop;
- USB storage;
- NAS;
- iCloud Drive;
- Google Drive;
- OneDrive;
- other user-controlled storage.

Those destinations are storage chosen by the user, not an Arus financial database.

## Online capability policy

Any future online capability must be:

1. optional;
2. disabled by default;
3. transparent about what leaves the device;
4. not required for core functionality;
5. removable without making the app unusable.

Cloud/sync experiments are not part of the production MVP roadmap unless explicitly re-approved later.

## Performance principle

Local-first is also a performance decision:

- transaction save does not wait for network;
- reports query local indexed data;
- large transaction history uses pagination;
- CSV export uses batches;
- recurring uses local calendar dates;
- financial calculations do not depend on remote services.
