# Arus Finance — V20 Long-Session, State Consistency & Performance Hardening

## Findings closed
1. Out-of-order timeline requests could overwrite a newer query/filter result.
2. Multiple load-more calls could request the same offset concurrently and append duplicate rows.
3. Home "Transaksi terbaru" reused filtered timeline state and could show search results instead of actual recent activity.
4. Multiple full refreshes could finish out of order and let an older dashboard/account/planning snapshot replace a newer one.
5. Pagination progress had no explicit UI state.

## Fixes
- Monotonic generation tokens for timeline requests.
- Independent generation token for full refresh snapshots.
- Single in-flight pagination request with captured offset/query/filter.
- Duplicate transaction-ID guard on append.
- Dedicated unfiltered `recentTransactions` state for Home.
- Explicit load-more progress/disabled UI.

## Boundary
No database schema, ledger, backup/recovery, import, notification privacy, or native signing semantics changed.
Flutter/device execution remains required for real frame/memory profiling and lifecycle timing validation.
