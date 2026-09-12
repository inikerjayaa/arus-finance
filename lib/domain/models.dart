import 'enums.dart';

class Account {
  const Account({
    required this.id,
    required this.name,
    required this.accountClass,
    required this.accountType,
    required this.currency,
    required this.balanceMinor,
    required this.includeInAvailable,
    required this.includeInNetWorth,
    this.archivedAt,
  });
  final String id;
  final String name;
  final AccountClass accountClass;
  final AccountType accountType;
  final String currency;
  final int balanceMinor;
  final bool includeInAvailable;
  final bool includeInNetWorth;
  final DateTime? archivedAt;
}

class Category {
  const Category({required this.id, required this.name, required this.type, this.parentId, this.archivedAt});
  final String id;
  final String name;
  final CategoryType type;
  final String? parentId;
  final DateTime? archivedAt;
}


class TransactionFilter {
  const TransactionFilter({
    this.type,
    this.status,
    this.accountId,
    this.categoryId,
    this.startDate,
    this.endDate,
    this.minAmountMinor,
    this.maxAmountMinor,
  });

  final TransactionType? type;
  final TransactionStatus? status;
  final String? accountId;
  final String? categoryId;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? minAmountMinor;
  final int? maxAmountMinor;

  bool get isActive =>
      type != null ||
      status != null ||
      accountId != null ||
      categoryId != null ||
      startDate != null ||
      endDate != null ||
      minAmountMinor != null ||
      maxAmountMinor != null;

  TransactionFilter copyWith({
    TransactionType? type,
    TransactionStatus? status,
    String? accountId,
    String? categoryId,
    DateTime? startDate,
    DateTime? endDate,
    int? minAmountMinor,
    int? maxAmountMinor,
    bool clearType = false,
    bool clearStatus = false,
    bool clearAccount = false,
    bool clearCategory = false,
    bool clearStartDate = false,
    bool clearEndDate = false,
    bool clearMinAmount = false,
    bool clearMaxAmount = false,
  }) {
    return TransactionFilter(
      type: clearType ? null : (type ?? this.type),
      status: clearStatus ? null : (status ?? this.status),
      accountId: clearAccount ? null : (accountId ?? this.accountId),
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      minAmountMinor: clearMinAmount ? null : (minAmountMinor ?? this.minAmountMinor),
      maxAmountMinor: clearMaxAmount ? null : (maxAmountMinor ?? this.maxAmountMinor),
    );
  }
}

class TransactionView {
  const TransactionView({
    required this.id,
    required this.type,
    required this.status,
    required this.amountMinor,
    required this.currency,
    required this.occurredAt,
    required this.accountName,
    this.destinationAccountName,
    this.categoryName,
    this.note,
    this.originalTransactionId,
    this.groupId,
    this.childExpenseMinor = 0,
    this.deleted = false,
  });
  final String id;
  final TransactionType type;
  final TransactionStatus status;
  final int amountMinor;
  final String currency;
  final DateTime occurredAt;
  final String accountName;
  final String? destinationAccountName;
  final String? categoryName;
  final String? note;
  final String? originalTransactionId;
  final String? groupId;
  final int childExpenseMinor;
  final bool deleted;
}


class TransactionDetail {
  const TransactionDetail({
    required this.view,
    this.accountId,
    this.destinationAccountId,
    this.categoryId,
    this.refundedMinor = 0,
  });
  final TransactionView view;
  final String? accountId;
  final String? destinationAccountId;
  final String? categoryId;
  final int refundedMinor;

  bool get canEditSimple =>
      view.groupId == null &&
      (view.type == TransactionType.expense || view.type == TransactionType.income);
  bool get canRefund =>
      view.type == TransactionType.expense &&
      view.status == TransactionStatus.posted &&
      !view.deleted &&
      refundedMinor < view.amountMinor;
}

class DashboardData {
  const DashboardData({
    required this.availableBalanceMinor,
    required this.netWorthMinor,
    required this.spendingPeriodMinor,
    required this.incomePeriodMinor,
    required this.spendingTodayMinor,
    required this.currency,
    required this.largestCategory,
    required this.largestCategoryAmountMinor,
  });
  final int availableBalanceMinor;
  final int netWorthMinor;
  final int spendingPeriodMinor;
  final int incomePeriodMinor;
  final int spendingTodayMinor;
  final String currency;
  final String? largestCategory;
  final int largestCategoryAmountMinor;
}

class BudgetModel {
  const BudgetModel({required this.id, required this.name, required this.limitMinor, required this.actualMinor, required this.start, required this.end, this.categoryId});
  final String id;
  final String name;
  final int limitMinor;
  final int actualMinor;
  final DateTime start;
  final DateTime end;
  final String? categoryId;
  int get remainingMinor => limitMinor - actualMinor;
  double get progress => limitMinor <= 0 ? 0 : actualMinor / limitMinor;
  int safePerDayMinor(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final last = DateTime(end.year, end.month, end.day);
    if (today.isAfter(last)) return 0;
    final days = last.difference(today).inDays + 1;
    if (days <= 0 || remainingMinor <= 0) return 0;
    return remainingMinor ~/ days;
  }
}

class BillModel {
  const BillModel({required this.id, required this.name, required this.expectedAmountMinor, required this.currency, required this.dueDate, required this.status});
  final String id;
  final String name;
  final int expectedAmountMinor;
  final String currency;
  final DateTime dueDate;
  final BillStatus status;
}

class RecurringRuleModel {
  const RecurringRuleModel({required this.id, required this.name, required this.mode, required this.amountMinor, required this.currency, required this.nextRun, required this.active});
  final String id;
  final String name;
  final RecurringMode mode;
  final int amountMinor;
  final String currency;
  final DateTime nextRun;
  final bool active;
}


class ImportTransactionDraft {
  const ImportTransactionDraft({
    required this.fingerprint,
    required this.type,
    required this.amountMinor,
    required this.accountId,
    required this.categoryId,
    required this.occurredAt,
    this.note,
    this.sourceTransactionId,
  });

  final String fingerprint;
  final TransactionType type;
  final int amountMinor;
  final String accountId;
  final String categoryId;
  final DateTime occurredAt;
  final String? note;
  final String? sourceTransactionId;
}

class ImportCommitResult {
  const ImportCommitResult({
    required this.imported,
    required this.skippedDuplicates,
  });

  final int imported;
  final int skippedDuplicates;
}
