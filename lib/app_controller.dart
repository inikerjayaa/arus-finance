import 'dart:async';
import 'package:flutter/foundation.dart' show ChangeNotifier;

import 'core/services/local_notification_service.dart';

import 'domain/enums.dart';
import 'domain/finance_repository.dart';
import 'domain/models.dart';

class AppController extends ChangeNotifier {
  AppController(this.repository, {LocalNotificationService? notifications})
    : notifications = notifications ?? LocalNotificationService();

  final FinanceRepository repository;
  final LocalNotificationService notifications;

  bool initializing = true;
  bool busy = false;
  String? errorMessage;
  String? noticeMessage;
  int navigationIndex = 0;

  List<Account> accounts = const [];
  List<Category> expenseCategories = const [];
  List<Category> incomeCategories = const [];
  List<TransactionView> transactions = const [];
  List<TransactionView> recentTransactions = const [];
  String transactionQuery = '';
  TransactionFilter transactionFilter = const TransactionFilter();
  bool hasMoreTransactions = false;
  static const int _transactionPageSize = 250;
  int _transactionRequestGeneration = 0;
  int _refreshRequestGeneration = 0;
  int _loadedTransactionCount = 0;
  bool _loadingMoreTransactions = false;
  bool get loadingMoreTransactions => _loadingMoreTransactions;
  List<BudgetModel> budgets = const [];
  List<BillModel> bills = const [];
  List<RecurringRuleModel> recurring = const [];
  DashboardData? dashboardData;
  bool _processingResume = false;
  bool _resumeRefreshPending = false;

  Future<void> initialize() async {
    initializing = true;
    errorMessage = null;
    notifyListeners();
    try {
      await repository.initialize();
      await repository.generateDueRecurring();
      await refresh();
    } catch (e) {
      errorMessage = _message(e);
    } finally {
      initializing = false;
      notifyListeners();
    }
  }

  Future<void> processAppResume() async {
    if (initializing) return;
    if (busy || _processingResume) {
      _resumeRefreshPending = true;
      return;
    }
    _processingResume = true;
    _resumeRefreshPending = false;
    try {
      await repository.generateDueRecurring();
      await refresh();
    } catch (e) {
      errorMessage = _message(e);
      notifyListeners();
    } finally {
      _processingResume = false;
      if (_resumeRefreshPending && !busy) {
        _resumeRefreshPending = false;
        unawaited(processAppResume());
      }
    }
  }

  Future<void> refresh() async {
    // A full refresh also becomes the newest timeline request. Older search/filter
    // responses must not be allowed to overwrite it after they complete.
    final refreshGeneration = ++_refreshRequestGeneration;
    final timelineGeneration = ++_transactionRequestGeneration;
    final timelineQuery = transactionQuery;
    final timelineFilter = transactionFilter;
    final results = await Future.wait<dynamic>([
      repository.listAccounts(),
      repository.listCategories(type: CategoryType.expense),
      repository.listCategories(type: CategoryType.income),
      repository.listTransactions(
        query: timelineQuery,
        filter: timelineFilter,
        limit: _transactionPageSize + 1,
      ),
      // Dashboard recent activity is intentionally independent from the
      // transaction screen's search/filter state.
      repository.listTransactions(limit: 5),
      repository.dashboard(),
      repository.listBudgets(),
      repository.listBills(),
      repository.listRecurringRules(),
    ]);
    // More than one full refresh can be triggered by pull-to-refresh, resume,
    // or a post-write refresh. An older snapshot must never replace a newer one.
    if (refreshGeneration != _refreshRequestGeneration) return;
    accounts = results[0] as List<Account>;
    expenseCategories = results[1] as List<Category>;
    incomeCategories = results[2] as List<Category>;
    if (timelineGeneration == _transactionRequestGeneration) {
      final firstPage = results[3] as List<TransactionView>;
      hasMoreTransactions = firstPage.length > _transactionPageSize;
      transactions = firstPage.take(_transactionPageSize).toList();
      _loadedTransactionCount = transactions.length;
    }
    recentTransactions = results[4] as List<TransactionView>;
    dashboardData = results[5] as DashboardData;
    budgets = results[6] as List<BudgetModel>;
    bills = results[7] as List<BillModel>;
    recurring = results[8] as List<RecurringRuleModel>;
    notifyListeners();
    unawaited(_syncLocalReminders());
  }

  Future<void> _syncLocalReminders() async {
    try {
      await notifications.syncSchedules(bills: bills, recurring: recurring);
    } catch (_) {
      // Reminder failure must never block financial writes or refresh.
    }
  }

  Future<void> refreshTransactions({
    String? query,
    TransactionFilter? filter,
  }) async {
    // Query/filter are presentation state for the currently visible result set.
    // Do not commit them until the matching database request succeeds; otherwise
    // an error can leave chips/search state describing rows that were never loaded.
    final requestQuery = query?.trim() ?? transactionQuery;
    final requestFilter = filter ?? transactionFilter;
    final generation = ++_transactionRequestGeneration;
    try {
      final page = await repository.listTransactions(
        query: requestQuery,
        filter: requestFilter,
        limit: _transactionPageSize + 1,
      );
      // Search/filter requests may finish out of order during a long session.
      // Only the latest request is allowed to mutate visible timeline state.
      if (generation != _transactionRequestGeneration) return;
      transactionQuery = requestQuery;
      transactionFilter = requestFilter;
      hasMoreTransactions = page.length > _transactionPageSize;
      transactions = page.take(_transactionPageSize).toList();
      _loadedTransactionCount = transactions.length;
      notifyListeners();
    } catch (e) {
      if (generation != _transactionRequestGeneration) return;
      errorMessage = _message(e);
      notifyListeners();
    }
  }

  Future<void> loadMoreTransactions() async {
    if (!hasMoreTransactions || busy || _loadingMoreTransactions) return;
    _loadingMoreTransactions = true;
    notifyListeners();
    final generation = _transactionRequestGeneration;
    final requestQuery = transactionQuery;
    final requestFilter = transactionFilter;
    final requestOffset = _loadedTransactionCount;
    try {
      final page = await repository.listTransactions(
        query: requestQuery,
        filter: requestFilter,
        limit: _transactionPageSize + 1,
        offset: requestOffset,
      );
      // If a newer search/filter/full refresh started while this page loaded,
      // the page belongs to obsolete state and must be discarded.
      if (generation != _transactionRequestGeneration) return;
      final next = page.take(_transactionPageSize).toList();
      final existingIds = transactions.map((tx) => tx.id).toSet();
      final uniqueNext = next.where((tx) => existingIds.add(tx.id)).toList();
      _loadedTransactionCount = requestOffset + next.length;
      hasMoreTransactions = page.length > _transactionPageSize;
      transactions = [...transactions, ...uniqueNext];
      notifyListeners();
    } catch (e) {
      if (generation != _transactionRequestGeneration) return;
      errorMessage = _message(e);
      notifyListeners();
    } finally {
      _loadingMoreTransactions = false;
      notifyListeners();
    }
  }

  Future<void> clearTransactionFilters() async {
    await refreshTransactions(query: '', filter: const TransactionFilter());
  }

  void setNavigation(int index) {
    navigationIndex = index;
    notifyListeners();
  }

  Future<T?> run<T>(
    Future<T> Function() operation, {
    bool refreshAfter = true,
  }) async {
    if (busy) return null;
    busy = true;
    errorMessage = null;
    noticeMessage = null;
    notifyListeners();

    try {
      late T value;
      try {
        // The financial write and the presentation refresh are deliberately
        // separated. Once operation() returns, callers must never be told that
        // the write failed merely because the subsequent UI refresh failed;
        // otherwise a reasonable retry can duplicate an already-committed write.
        value = await operation();
      } catch (e) {
        errorMessage = _message(e);
        notifyListeners();
        return null;
      }

      if (refreshAfter) {
        try {
          await refresh();
        } catch (_) {
          noticeMessage =
              'Perubahan sudah tersimpan, tetapi tampilan belum berhasil dimuat ulang. Muat ulang sebelum mengulangi aksi.';
          notifyListeners();
        }
      }

      return value;
    } finally {
      busy = false;
      notifyListeners();
      if (_resumeRefreshPending && !_processingResume) {
        _resumeRefreshPending = false;
        unawaited(processAppResume());
      }
    }
  }

  void clearError() {
    errorMessage = null;
    notifyListeners();
  }

  void clearNotice() {
    noticeMessage = null;
    notifyListeners();
  }

  Future<void> retryPresentationRefresh() async {
    if (busy) return;
    try {
      await refresh();
      noticeMessage = null;
      errorMessage = null;
      notifyListeners();
    } catch (e) {
      errorMessage = _message(e);
      notifyListeners();
    }
  }

  String _message(Object error) {
    final raw = error.toString();
    return raw
        .replaceFirst('Bad state: ', '')
        .replaceFirst('Invalid argument(s): ', '')
        .replaceFirst('Invalid argument: ', '');
  }
}
