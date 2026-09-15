import 'package:arus_finance/domain/enums.dart';
import 'package:arus_finance/domain/models.dart';
import 'package:arus_finance/features/activity/daily_activity.dart';
import 'package:flutter_test/flutter_test.dart';

TransactionView tx({
  required String id,
  required TransactionType type,
  required int amount,
  required DateTime at,
  TransactionStatus status = TransactionStatus.posted,
  bool deleted = false,
}) {
  return TransactionView(
    id: id,
    type: type,
    status: status,
    amountMinor: amount,
    currency: 'IDR',
    occurredAt: at,
    accountName: 'Test Account',
    deleted: deleted,
  );
}

void main() {
  test('daily activity counts real spending and incoming without double counting internal money movement', () {
    final summary = DailyActivityBuilder.build(
      DateTime(2026, 9, 15),
      <TransactionView>[
        tx(id: 'expense', type: TransactionType.expense, amount: 100000, at: DateTime(2026, 9, 15, 8)),
        tx(id: 'income', type: TransactionType.income, amount: 500000, at: DateTime(2026, 9, 15, 9)),
        tx(id: 'refund', type: TransactionType.refund, amount: 20000, at: DateTime(2026, 9, 15, 10)),
        tx(id: 'transfer', type: TransactionType.transfer, amount: 1000000, at: DateTime(2026, 9, 15, 11)),
        tx(id: 'card-payment', type: TransactionType.creditCardPayment, amount: 200000, at: DateTime(2026, 9, 15, 12)),
        tx(id: 'opening', type: TransactionType.openingBalance, amount: 999999, at: DateTime(2026, 9, 15, 13)),
        tx(id: 'draft-expense', type: TransactionType.expense, amount: 700000, at: DateTime(2026, 9, 15, 14), status: TransactionStatus.draft),
        tx(id: 'deleted-expense', type: TransactionType.expense, amount: 800000, at: DateTime(2026, 9, 15, 15), deleted: true),
      ],
    );

    expect(summary.spendingMinor, 100000);
    expect(summary.incomingMinor, 520000);
    expect(summary.refundMinor, 20000);
    expect(summary.netMinor, 420000);
    expect(summary.activities.map((item) => item.id), <String>[
      'card-payment',
      'transfer',
      'refund',
      'income',
      'expense',
    ]);
    expect(summary.neutralActivityCount, 2);
  });

  test('daily activity isolates the selected local calendar date', () {
    final summary = DailyActivityBuilder.build(
      DateTime(2026, 9, 15),
      <TransactionView>[
        tx(id: 'yesterday', type: TransactionType.expense, amount: 1000, at: DateTime(2026, 9, 14, 23, 59)),
        tx(id: 'today', type: TransactionType.expense, amount: 2000, at: DateTime(2026, 9, 15, 0, 1)),
        tx(id: 'tomorrow', type: TransactionType.income, amount: 3000, at: DateTime(2026, 9, 16, 0, 1)),
      ],
    );

    expect(summary.activities.single.id, 'today');
    expect(summary.spendingMinor, 2000);
    expect(summary.incomingMinor, 0);
  });

  test('empty day has a stable zero summary', () {
    final summary = DailyActivityBuilder.build(DateTime(2026, 9, 15), const []);
    expect(summary.activities, isEmpty);
    expect(summary.spendingMinor, 0);
    expect(summary.incomingMinor, 0);
    expect(summary.netMinor, 0);
  });
}
