# ARUS FINANCE — LOCAL-ONLY ARCHITECTURE V3

**Normative product rule:** `Data Anda aman bersama Anda sendiri.`

This document overrides any older production requirement that assumes login, cloud database, remote sync, or a vendor backend.

## Production Architecture

```text
User Device
  └─ Flutter UI
      └─ Domain / Repository
          └─ Encrypted SQLite ledger
              ├─ accounts
              ├─ transactions + legs + splits
              ├─ budgets
              ├─ bills
              ├─ recurring rules
              └─ preferences
```

Core behavior requires **no login, no account, no server, and no internet**.

## Data ownership

- Canonical financial data lives on the user's device.
- Arus does not require a cloud copy.
- Arus does not upload transaction amounts, balances, notes, categories, merchants, or receipts to an Arus server.
- Portable recovery uses a user-created encrypted `.arusbackup` file.
- The user may personally place that encrypted file in Files, USB storage, NAS, iCloud Drive, Google Drive, OneDrive, or another location. Those locations are not Arus databases.

## Security model

- encrypted local SQLite database;
- database key stored using platform secure storage;
- PIN / biometric app lock;
- persistent throttling after repeated wrong PIN attempts;
- portable backup encrypted with a user passphrase;
- raw sync/outbox state is not included in portable backup;
- app continues functioning without network access.

## Product promise

> **Data Anda aman bersama Anda sendiri.**
>
> Arus membantu pengguna memahami dan mengatur keuangan tanpa mewajibkan mereka menyerahkan salinan data finansial kepada server Arus.

## Future features

Any future online capability must be optional, capability-gated, disabled by default, and unable to become a prerequisite for core finance functions. A future feature may not silently change the canonical source of truth away from the device.
