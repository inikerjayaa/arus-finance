# Arus Finance — V22 Atomic Timeline Presentation State

Finding closed: timeline query/filter fields were mutated before their database request succeeded. A failed request could therefore leave search/filter UI describing a result set that had never been loaded.

V22 treats query, filter and visible first-page rows as one presentation-state commit. Requested state is held locally and only becomes active after the newest matching repository request succeeds. Failed or stale requests cannot partially mutate the visible state.

No financial/domain/database schema semantics changed.
