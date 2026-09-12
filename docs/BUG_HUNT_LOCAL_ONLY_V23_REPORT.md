# Arus Finance — V23 Sensitive UI Privacy Shield

V23 closes a privacy boundary not covered by encryption-at-rest: sensitive finance values could otherwise appear in screenshots, screen sharing, or OS app-switcher snapshots.

- Android native shell receives `FLAG_SECURE` through the idempotent hardener.
- Flutter root overlays an opaque privacy shield whenever the app is inactive/hidden/paused/detached and removes it on resume.
- Existing App Lock, recovery checkpoint, finance, backup and schema behavior are unchanged.

Device-level behavior remains UNPROVEN until native execution.
