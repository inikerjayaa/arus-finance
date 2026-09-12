# Test Matrix

Required financial invariants:

1. Expense reduces asset and net worth.
2. Income increases asset and net worth.
3. Asset transfer is net-worth neutral.
4. Transfer fee is expense only.
5. Credit-card purchase increases liability and lowers net worth.
6. Credit-card payment does not count as a second expense.
7. Loan disbursement is not income.
8. Loan principal payment is net-worth neutral.
9. Loan interest/fee are expenses.
10. Refund reduces original expense and reverses account effect.
11. Edit replaces old effect instead of stacking effects.
12. Local-only Delete hard-deletes the transaction/group and its financial effect; VOID is the retained-history path.
13. Opening liability lowers baseline net worth.
14. Adjustment changes balance but not normal income/expense reports.
15. Draft/scheduled/void transactions have no current ledger effect.
16. Recurring occurrence keys prevent duplicate generation.
17. Backup restore must be atomic and preserve ledger totals.
18. VOID removes financial effect while keeping a visible business-history record.
19. Deleting/voiding a Bill payment reopens the Bill.
20. App-kill before SQLite COMMIT leaves no partial financial write.
21. SQLITE_FULL rolls back the whole write group.
22. Recurring day 29/30/31 clamps to the last valid calendar day.
23. Extreme device-clock jumps must not flood years of synthetic recurring drafts.
24. Portable backup creation must refuse a database that fails local integrity checks.
25. PIN lock status is re-read across app lifecycle changes.


26. Composite VOID must refuse the entire group if any member has an active POSTED refund.
27. Refund destination must be an asset or credit-card liability at repository level, not only filtered by UI.
28. Backup restore must reject invalid Expense/Income/Refund leg/split/account/category semantics.
29. Backup restore must reject invalid Transfer/Credit-card/Loan/Adjustment/Opening transaction shapes.
30. Backup restore must reject invalid transaction-group primary structure.
31. Backup restore must reject an unpaid Bill that still points at a non-fully-refunded active payment.
32. Budget, Bill, and Recurring rule names cannot be blank.
33. Recurring expense rule must target an active ASSET or CREDIT_CARD liability; loan/other liabilities are rejected.
34. Reactivating recurring must fail when its account/category dependency is archived or invalid.
35. Refund limit and original validity must be rechecked inside the atomic write transaction.
36. Simple transaction edit must recheck current active refunds at the write boundary.
37. Loan principal outstanding must be rechecked inside the LOAN_PAYMENT transaction.
38. PAID Bill cannot be manually changed to SKIPPED while its payment is active.
39. Backup restore must reject invalid Budget/Bill/Recurring semantic state.
40. Backup restore must reject composite group member/type/status mismatches.
41. Source audit must reject literal backslash patch artifacts in Dart code outside strings/comments.
42. V1→current continuity manifest must pass before a new milestone is packaged.

43. Existing historical schemas must complete versioned migrations before current indexes/triggers that depend on newer columns are ensured.
44. Missing/ambiguous/corrupt schema-version metadata must fail closed rather than guess a migration origin.
45. An existing non-empty encrypted DB with a missing secure-storage key must fail closed before the DB file is opened/modified.
46. Process death before migration COMMIT must leave both data and schema version at the previous committed state and permit retry.
47. Process death during destructive restore before COMMIT must leave the previous live dataset intact.
48. Portable backup table reads must come from one committed SQLite read snapshot.
49. Initial/reset default-category seed must be atomic and retryable after process death.
50. Historical V3 recurring occurrence duplicates must migrate without UNIQUE-key collision and without silently deleting the extra draft transaction.
51. Historical portable backups must normalize pre-v4 recurring identity/legs, pre-v5 next-run dates, and pre-v8 duplicate Bill payment links before current semantic validation.
52. Quick database integrity must include foreign-key integrity in addition to SQLite quick_check/FTS coverage.
53. Safe Recovery Mode must never delete the canonical DB unless a verified original family is already quarantined.
54. Recovery-state markers must be staged and atomically committed; a partial marker write cannot drive destructive recovery.
55. Local recovery generations must be encrypted, verified after write, and only then permit pruning of older generations.
56. Normal portable restore must create an exact pre-restore recovery point before mutating live data.
57. Background recovery checkpoint failure must never fail or roll back an active financial transaction.
58. Android biometric integration must use a FragmentActivity/AppCompat-compatible shell and only advertise biometrics when enrolled.
59. Secure-storage failures must fail closed instead of silently resetting database/recovery secrets.
60. Native release status must distinguish SOURCE, COMPILE, DEVICE, and STORE RELEASE evidence; `all` cannot silently skip a platform.
61. Android store readiness must verify an actual private-key signing alias rather than merely the existence of a keystore file.
62. Native validation must pin the declared Flutter SDK baseline and record artifact/source/lockfile hashes as evidence.
63. iOS validation must support Swift Package Manager-first projects and require CocoaPods only when a Podfile fallback is actually present.
64. Pushed full-screen routes must own a visible in-app navigation exit such as an AppBar Back affordance.
65. Quick Add must not offer account choices that repository financial rules will deterministically reject.
66. Financial metric layouts must remain usable under large text scaling and must not hide overflow by scaling text down.
67. Validation and recovery errors must remain visible inline and be announced through assistive-technology live regions where appropriate.
68. Destructive financial/data actions must state their real consequence and require confirmation proportional to impact.
69. Empty transaction state must provide a direct path to the primary task: recording a transaction.
70. Flutter accessibility guideline tests for tap targets, labels, contrast, and large-text layout must remain part of the native test suite.
71. A successfully committed write must remain a success even if the immediate presentation refresh fails afterward; retry guidance must not imply the write failed.
72. App resume arriving during an active write must queue a later recurring/refresh pass rather than being silently discarded.
73. Quick Add must block rapid re-entry while submitting and must not permit barrier/drag dismissal of partially entered data.
74. Dirty Quick Add state must require an explicit discard decision, with only one discard confirmation allowed at a time.
75. Expense Edit must not advertise loan/unsupported liabilities as valid account choices.
76. Editing a POSTED transaction must not offer future dates.
77. Posting a DRAFT must explicitly confirm that the action will affect balance and reports.
78. V19 workflow-stress UAT and source/reference audit must remain part of the regression gate.

79. Out-of-order timeline requests must not overwrite newer search/filter state.
80. Only one pagination request may be active; stale pages must be discarded and duplicate IDs must not append twice.
81. Home recent transactions must remain independent from transaction timeline search/filter state.
82. Older full-refresh snapshots must not overwrite newer account/dashboard/planning state.
83. Routine controller notifications must not rebuild the root MaterialApp/Navigator; shell busy/error/notice/navigation state must remain reactive.
84. Failed timeline search/filter/reset requests must leave the previously committed query/filter/result state intact.
85. Android financial UI must use native secure-window capture protection in the generated shell.
86. Inactive/hidden/paused financial UI must be covered by an opaque privacy shield before app-switcher snapshot exposure; resume must clear it.
87. V20–V23 milestone source audits and V1→current continuity audit must remain part of the regression gate.
88. Pre-native RC packaging must contain no transient/cache/merge-conflict artifacts and must not change runtime source relative to the audited V23 runtime baseline.
89. Active iOS native hardening must enforce deployment target 15.0 for Flutter 3.47.2; the historical iOS 13 assumption is superseded.
90. The CI Flutter installer must reject a release whose Flutter git hash, bundled Dart version, or SHA-256 does not match the pinned provenance contract.
91. Flutter SDK archives must be extracted with path-traversal-safe handling.
92. Android and iOS compile jobs must consume the same verified `pubspec.lock` artifact and may not independently re-resolve dependencies.
93. Native compile CI must use unprivileged pull-request context, read-only repository permission, and no signing secrets.
94. Android and iOS native evidence must agree on canonical source hash, lockfile hash, Flutter 3.47.2 and Dart 3.13.2 before cross-platform compile proof is accepted.
95. A successful compiler CI run may advance COMPILE evidence only; DEVICE and STORE RELEASE status remain independent gates.

96. Every external GitHub Actions `uses:` reference must be pinned to an audited full 40-character commit SHA; semver tags are rejected by source audit.
97. The normal native verification workflow must fail before Flutter setup if committed `pubspec.lock` is absent.
98. Initial dependency resolution must occur only in the manual lock-bootstrap workflow and its output must be labeled review-only, not compile/release proof.
99. Android and iOS compile jobs must compare their checkout `pubspec.lock` byte-for-byte with the verified shared lock artifact before compiling.
100. Native verification must use `flutter pub get --enforce-lockfile` and must not silently resolve a different graph on a later CI run.
101. Release readiness must keep SOURCE, DEPENDENCY_LOCK, Android/iOS COMPILE, DEVICE, and STORE artifact states separate.
102. Native evidence from an older canonical source or different committed lockfile must become STALE and cannot satisfy the current release gate.
103. Physical-device PASS must never be inferred from compiler or store-artifact evidence and requires both Android and iOS device evidence.
104. GitHub Actions dependency updates may be proposed automatically but must re-enter the audited full-SHA pin contract before merge.
105. V26 release-orchestration source/reference audits and V1→current continuity must remain in the full regression gate.

### V27 — Immutable Git bootstrap
106. `.gitattributes` must normalize text to LF while exempting binary/archive formats.
107. Git bootstrap must fail if private signing/config files or build/cache/VCS residue exist in canonical source.
108. Canonical Git commit metadata, branch and lightweight tag must be deterministic.
109. `git fsck --full` and `git bundle verify` must pass before bootstrap artifacts are accepted.
110. Fresh clone from bundle must match manifest commit/tree and remain clean.
111. Every tracked file must match the exported tracked-file SHA-256 manifest.
112. Git bootstrap evidence must not upgrade Flutter/native/device/store readiness states.
