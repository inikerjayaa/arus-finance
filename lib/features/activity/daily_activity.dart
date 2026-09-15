import '../../domain/enums.dart';
import '../../domain/models.dart';

class DailyActivitySummary {
  const DailyActivitySummary({
    required this.date,
    required this.spendingMinor,
    required this.incomingMinor,
    required this.refundMinor,
    required this.activities,
  });

  final DateTime date;
  final int spendingMinor;
  final int incomingMinor;
  final int refundMinor;
  final List<TransactionView> activities;

  int get netMinor => incomingMinor - spendingMinor;

  int get neutralActivityCount => activities.where((tx) {
        return tx.type != TransactionType.expense &&
            tx.type != TransactionType.income &&
            tx.type != TransactionType.refund;
      }).length;
}

class DailyActivityBuilder {
  const DailyActivityBuilder._();

  /// Builds a human-facing day summary without changing accounting semantics.
  ///
  /// - Spending = posted EXPENSE only.
  /// - Incoming = posted INCOME + REFUND.
  /// - Transfers, card payments, loan principal flows, adjustments, and other
  ///   internal movements may appear in the timeline but never inflate the
  ///   daily spending/income summary.
  /// - Opening balances are setup state and are intentionally hidden from the
  ///   day-activity timeline.
  static DailyActivitySummary build(
    DateTime date,
    Iterable<TransactionView> transactions,
  ) {
    final selected = DateTime(date.year, date.month, date.day);
    final activities = transactions.where((tx) {
      if (tx.status != TransactionStatus.posted || tx.deleted) return false;
      if (tx.type == TransactionType.openingBalance) return false;
      final local = tx.occurredAt.toLocal();
      return local.year == selected.year &&
          local.month == selected.month &&
          local.day == selected.day;
    }).toList(growable: false)
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

    var spending = 0;
    var income = 0;
    var refunds = 0;
    for (final tx in activities) {
      switch (tx.type) {
        case TransactionType.expense:
          spending += tx.amountMinor;
          break;
        case TransactionType.income:
          income += tx.amountMinor;
          break;
        case TransactionType.refund:
          refunds += tx.amountMinor;
          break;
        case TransactionType.transfer:
        case TransactionType.adjustment:
        case TransactionType.openingBalance:
        case TransactionType.creditCardPayment:
        case TransactionType.loanDisbursement:
        case TransactionType.loanPayment:
          break;
      }
    }

    return DailyActivitySummary(
      date: selected,
      spendingMinor: spending,
      incomingMinor: income + refunds,
      refundMinor: refunds,
      activities: List.unmodifiable(activities),
    );
  }
}
