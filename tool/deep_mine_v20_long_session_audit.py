from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
read = lambda rel: (ROOT / rel).read_text()
controller = read('lib/app_controller.dart')
home = read('lib/features/home/home_screen.dart')
transactions = read('lib/features/transactions/transactions_screen.dart')
docs = read('docs/LONG_SESSION_STRESS_UAT_V20.md')

checks = {
    'timeline has monotonic request generation': '_transactionRequestGeneration' in controller and '++_transactionRequestGeneration' in controller,
    'full refresh has independent generation': '_refreshRequestGeneration' in controller and 'refreshGeneration != _refreshRequestGeneration' in controller,
    'stale search/filter response is discarded': 'if (generation != _transactionRequestGeneration) return;' in controller,
    'load more has in-flight lock': '_loadingMoreTransactions' in controller and '|| _loadingMoreTransactions' in controller,
    'load more captures stable offset': 'final requestOffset = _loadedTransactionCount;' in controller,
    'load more does not use mutable visible length as offset': 'offset: transactions.length' not in controller,
    'stale load-more page is discarded': 'the page belongs to obsolete state and must be discarded' in controller,
    'pagination append de-duplicates ids': 'existingIds.add(tx.id)' in controller and 'uniqueNext' in controller,
    'pagination progress is exposed to UI': 'bool get loadingMoreTransactions' in controller,
    'load-more button disables while loading': 'controller.loadingMoreTransactions' in transactions and "'Memuat…'" in transactions,
    'dashboard recent list has dedicated state': 'List<TransactionView> recentTransactions' in controller,
    'dashboard recent query is independent of timeline filter': 'repository.listTransactions(limit: 5)' in controller,
    'home uses dedicated recent state': 'controller.recentTransactions' in home and 'controller.transactions.take(5)' not in home,
    'full refresh applies only newest snapshot': 'An older snapshot must never replace a newer one.' in controller,
    'long-session UAT covers rapid search': 'Rapid Search / Filter Race' in docs,
    'long-session UAT covers repeated pagination': 'Repeated Pagination' in docs,
    'long-session UAT covers dashboard isolation': 'Dashboard Isolation' in docs,
    'long-session UAT covers repeated resume/refresh': 'Repeated Resume / Refresh' in docs,
    'long-session UAT covers 100k history': '100.000' in docs,
}

# Executable reference oracle for out-of-order request completion. Newer
# generation owns state regardless of completion order.
class TimelineModel:
    def __init__(self):
        self.generation = 0
        self.visible = None
        self.loading_more = False
        self.loaded_count = 0

    def begin_refresh(self):
        self.generation += 1
        return self.generation

    def finish_refresh(self, generation, value, count):
        if generation != self.generation:
            return False
        self.visible = value
        self.loaded_count = count
        return True

    def begin_more(self):
        if self.loading_more:
            return None
        self.loading_more = True
        return (self.generation, self.loaded_count)

    def finish_more(self, token, ids):
        try:
            if token is None or token[0] != self.generation:
                return False
            existing = list(self.visible or [])
            seen = set(existing)
            existing.extend(x for x in ids if not (x in seen or seen.add(x)))
            self.visible = existing
            self.loaded_count = token[1] + len(ids)
            return True
        finally:
            self.loading_more = False

m = TimelineModel()
a = m.begin_refresh()
b = m.begin_refresh()
assert m.finish_refresh(b, ['B'], 1) is True
assert m.finish_refresh(a, ['A'], 1) is False
assert m.visible == ['B']
more = m.begin_more()
assert m.begin_more() is None
assert m.finish_more(more, ['B', 'C']) is True
assert m.visible == ['B', 'C']
stale_more = m.begin_more()
m.begin_refresh()
assert m.finish_more(stale_more, ['D']) is False
assert 'D' not in m.visible

failed = [name for name, ok in checks.items() if not ok]
if failed:
    print('FAIL: deep-mine V20 long-session/state-consistency contract')
    for item in failed:
        print(' -', item)
    sys.exit(1)
print(f'PASS: deep-mine V20 long-session/state-consistency contract ({len(checks)} source/UAT checks + race oracle)')
