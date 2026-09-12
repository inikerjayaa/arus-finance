# Bug Hunt Report — Local-Only V4

## Problems found and corrected

1. Recurring DRAFT did not preserve intended account data.
2. Editing a DRAFT could remove the intended account leg.
3. Recurring occurrence identity included rule version and could duplicate after rule edits.
4. Recurring schedule stored an absolute timestamp, creating timezone-shift risk for calendar-day obligations.
5. Deleting a Bill payment could leave the Bill marked PAID.
6. Account/category archive did not consider DRAFT/SCHEDULED dependencies.
7. Account type and asset/liability class could be inconsistent.
8. Duplicate active account/category names could create ambiguous UI/reporting.
9. Non-IDR accounts could enter a reporting engine without exchange-rate support.
10. Transaction detail loaded up to 1,000,000 transactions before locating one ID.
11. CSV export loaded up to 1,000,000 transactions into memory.
12. Long transaction history had no repository/UI pagination path.
13. Backup restore lacked a maximum file-size guard.
14. Backup restore integrity checks were too narrow.
15. Backup creation asked for a passphrase only once.
16. Restore replacement and destructive wipe needed stronger explicit confirmation.
17. Documentation still treated cloud as a future required stage after the product pivot.

## Verified without Flutter SDK

- Fresh SQLite schema v5: PASS.
- Legacy local-only schema v3 → v5 recurring migration simulation: PASS.
- SQLite foreign-key check after migration simulation: PASS.
- Production cloud dependency grep: 0.
- Million-row transaction-query grep: 0.

## Validation boundary

Native compile/analyze/test remains unverified until Flutter + Android/iOS toolchains are available.
