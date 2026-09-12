# Arus Finance — V22 Atomic Timeline Presentation State UAT

## Failed Search / Filter Request
- Start from a known visible query/filter/result set.
- Submit a new query/filter and force repository failure.
- Expected: active chips, controller query/filter and visible rows remain the previously committed set; error is shown.
- Search input resynchronizes to committed query state.

## Stale Request Ordering
- Start query A then query B; let B finish first.
- Expected: B commits query/filter/results. A completion is ignored entirely.

## Failed Clear / Reset
- With an active filter, tap Reset while database request is forced to fail.
- Expected: old filter remains active and still describes the visible rows. Reset is committed only after successful data load.

## Successful Clear / Reset
- When the reset request succeeds, active query/filter and rows switch together in one presentation-state commit.
