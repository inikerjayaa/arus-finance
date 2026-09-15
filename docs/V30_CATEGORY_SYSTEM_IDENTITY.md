# V30 Stable Category Identity

Status: PROVISIONAL until native CI is fully green and merged.

## Goal

Separate engine-owned category identity from the user-facing display name so category rename, icon/color changes, archive state, backup/restore, and reporting do not depend on literal Indonesian labels.

## Contract

- `categories.system_key` is nullable and unique when present.
- User-created categories normally keep `system_key = NULL`.
- Built-in categories receive stable keys such as `expense.transfer_fee` and `income.salary`.
- Display `name`, `visual_icon_key`, and `visual_color_key` may change without changing `system_key`.
- Automatic transfer fees resolve `expense.transfer_fee`, never the display name `Biaya Transfer`.
- An archived system category is hidden from manual category choices but remains available to engine-owned automatic postings.
- V11+ portable backups naturally carry `system_key` because category rows are backed up with all columns.
- Legacy rows that omit `system_key` can be seeded by the V11 category insert trigger when an unclaimed built-in identity is recognized.
- A later manually created category with the same display name must never steal an already assigned system key.

## Safety gates

Before merge:

1. fresh V11 schema validation;
2. real-order V1 -> current migration validation;
3. V9 -> V10 visual identity migration validation;
4. V10 -> V11 stable identity migration validation;
5. transfer-with-fee after display-name rename;
6. automatic transfer fee after system category archive;
7. uniqueness and duplicate-name protection;
8. full Flutter analyzer/tests;
9. Android release + installable APK;
10. iOS release no-codesign compile;
11. cross-platform source/lock evidence consistency.

Category rename UI remains blocked until this contract is merged.