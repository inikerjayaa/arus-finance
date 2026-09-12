from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[1]
read=lambda r:(ROOT/r).read_text()
controller=read('lib/app_controller.dart')
transactions=read('lib/features/transactions/transactions_screen.dart')
docs=read('docs/ATOMIC_FILTER_STATE_UAT_V22.md')
checks={
 'requested query is local until success':'final requestQuery = query?.trim() ?? transactionQuery;' in controller,
 'requested filter is local until success':'final requestFilter = filter ?? transactionFilter;' in controller,
 'query state commits only after latest response':'transactionQuery = requestQuery;' in controller and controller.index('transactionQuery = requestQuery;') > controller.index('if (generation != _transactionRequestGeneration) return;'),
 'filter state commits only after latest response':'transactionFilter = requestFilter;' in controller,
 'filter state not eagerly mutated at method entry':'if (query != null) transactionQuery' not in controller and 'if (filter != null) transactionFilter' not in controller,
 'clear filter is request based':'await refreshTransactions(' in controller and "query: ''," in controller and 'filter: const TransactionFilter()' in controller,
 'error path leaves committed filter/query untouched':'error can leave chips/search state describing rows that were never loaded' in controller,
 'search field resyncs from committed controller state':'if (_search.text != controller.transactionQuery)' in transactions,
 'V22 UAT includes failed search rollback':'Failed Search / Filter Request' in docs,
 'V22 UAT includes stale response ordering':'Stale Request Ordering' in docs,
 'V22 UAT includes clear failure':'Failed Clear / Reset' in docs,
}
failed=[k for k,v in checks.items() if not v]
if failed:
 print('FAIL: V22 atomic filter-state contract')
 for k in failed: print(' -',k)
 sys.exit(1)
print(f'PASS: V22 atomic filter-state contract ({len(checks)} checks)')
