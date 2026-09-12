# Arus Finance — Local-Only Architecture V6

## Permanent product principle

Financial data remains under the user's control. The public tagline is intentionally TBD and may change; the architecture does not.

## Production data path

```text
Flutter UI
  ↓
Domain validation
  ↓
Local repository
  ↓
Encrypted SQLite / sqlite3mc
  ↓
User device
```

No mandatory account, login, Arus server, cloud database, or internet connection exists in the core path.

## Recovery

```text
Local encrypted database
  ↓ user action
Portable encrypted .arusbackup
  ↓
Storage chosen by user
```

Cloud file providers, when chosen by the user via the OS share/files UI, are only destinations for the encrypted backup file. They are not Arus databases.

## Notifications

Bill and recurring reminders are local OS notifications. The reminder setting is opt-in. Finance details are hidden by default on notification surfaces.

## CSV portability

CSV is not the canonical backup format. It is a human-readable interchange/export format. Safe import intentionally supports only simple expense/income transactions and refuses ambiguous financial structures.
