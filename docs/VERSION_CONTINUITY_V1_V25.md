# Arus Finance — Version Continuity V1 → V25

V25 continues the single canonical Arus Finance application. All V1–V24 financial, local-only, migration, recovery, security, UX, workflow, long-session, privacy and truthful-release contracts remain required.

V25 adds the native CI/provenance layer and makes one explicit current-platform correction: the active iOS deployment floor is now **15.0**, superseding the historical iOS 13 assumption from V15/V17 because Flutter 3.47.2's supported-platform matrix now starts at iOS 15.

V25 keeps database schema **v9** and does not alter financial ledger semantics.
