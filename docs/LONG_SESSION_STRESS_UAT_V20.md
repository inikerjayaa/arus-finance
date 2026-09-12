# Arus Finance — V20 Long-Session / State-Consistency UAT

Status: executable source contract + native/device matrix pending Flutter/device execution.

## Rapid Search / Filter Race
- Submit query A, immediately query B, then reset/filter while A is still loading.
- Expected: only the newest request may change the visible list.
- A late result from A must never overwrite B/reset state.

## Repeated Pagination
- On a history with thousands of rows, rapidly tap **Muat transaksi lebih lama**.
- Expected: at most one page request is active; the same page cannot be appended twice.
- Start a new search while a page is loading; the old page must be discarded.

## Dashboard Isolation
- Apply a narrow transaction filter/search, navigate back to Home.
- Expected: **Transaksi terbaru** remains the latest unfiltered activity, not the current timeline search subset.

## Repeated Resume / Refresh
- Alternate background/resume, pull-to-refresh, transaction writes, and navigation for a long session.
- Expected: an older full-refresh snapshot can never replace a newer snapshot.
- Local reminder refresh failures remain non-blocking to finance state.

## 100.000 Transaction History
- Seed/reference-test 100.000 transactions.
- Verify indexed first-page timeline remains bounded and the UI initially materializes only one page.
- Search uses FTS5 and does not scan/render the whole history.
- Pagination uses a stable loaded-row offset and duplicate-ID guard.

## Repeated Navigation
- Home → Transactions → Detail → Back → Planning → Home repeatedly.
- Verify no filter state leaks into Home recent activity.
- Verify loading state clears after pagination succeeds, fails, or becomes stale.

## Long Session Acceptance
- No stale search overwrite.
- No duplicate page append.
- No filtered dashboard recent list.
- No permanent pagination spinner/disabled state.
- No financial write regression.
- No schema change required.
