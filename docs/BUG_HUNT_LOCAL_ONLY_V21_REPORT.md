# Arus Finance — V21 Root Rebuild & Lifecycle Isolation

V21 removes the historical dependency on rebuilding the entire MaterialApp for every AppController notification.

Root rebuilds are now limited to state that can actually change the app's top-level mode: initialization and fatal recovery. Routine updates are propagated through AppScope/InheritedNotifier and an AppShell-level AnimatedBuilder, preserving busy/error/notice/navigation reactivity without recreating the root Navigator tree.

No financial, database, backup, recovery or schema semantics changed.
