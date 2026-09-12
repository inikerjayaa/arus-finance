enum AccountClass { asset, liability }
enum AccountType { cash, bank, ewallet, creditCard, loan, investment, otherAsset, otherLiability }
enum TransactionType { expense, income, transfer, refund, adjustment, openingBalance, creditCardPayment, loanDisbursement, loanPayment }
enum TransactionStatus { posted, draft, scheduled, voided }
enum CategoryType { expense, income }
enum RecurringMode { reminderOnly, autoCreate, autoCreateDraft }
enum BillStatus { upcoming, due, paid, skipped, overdue }

String enumDbName(Enum value) {
  final snake = value.name.replaceAllMapped(
    RegExp(r'([a-z0-9])([A-Z])'),
    (m) => '${m[1]}_${m[2]}',
  );
  return snake.toUpperCase();
}

T enumFromDb<T extends Enum>(String raw, List<T> values) {
  final normalized = raw.replaceAll('_', '').toLowerCase();
  return values.firstWhere(
    (v) => v.name.replaceAll('_', '').toLowerCase() == normalized,
  );
}
