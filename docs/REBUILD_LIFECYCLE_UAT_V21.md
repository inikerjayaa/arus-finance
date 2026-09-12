# Arus Finance — V21 Rebuild / Lifecycle UAT

## Search / Pagination Rebuild Boundary
- Run repeated search, filter, pagination, busy and notice changes.
- Expected: AppShell/screen state updates, but root MaterialApp/Navigator is not rebuilt only because routine controller state changed.

## Navigation Reactivity
- Change bottom navigation repeatedly.
- Busy progress, error banner, notice banner and selected NavigationBar item must remain reactive via AppShell's controller listener.

## Fatal Recovery Transition
- Simulate startup DB failure before dashboard exists.
- Root must transition to RecoveryScreen.
- Retry/initialize must still transition root back through loading into normal shell.

## Listener Lifecycle
- Rebuild ArusApp with a replacement controller in a widget test.
- Old controller listener must be detached; new controller listener attached.
- Dispose must detach the active listener.

## Long Session
- Repeat controller notifications for search/pagination over an extended session.
- Verify Navigator stack remains stable and there is no route reset caused by root MaterialApp rebuilds.
