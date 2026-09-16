import 'package:arus_finance/core/db/app_database.dart';
import 'package:arus_finance/data/local_finance_repository.dart';
import 'package:arus_finance/domain/enums.dart';
import 'package:arus_finance/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late LocalFinanceRepository repo;

  setUp(() async {
    db = AppDatabase.inMemory();
    repo = LocalFinanceRepository(
      db,
      clock: () => DateTime(2026, 9, 16, 17, 0),
    );
    await repo.initialize();
  });

  tearDown(() => db.close());

  test('balance adjustment updates balance and keeps automatic audit note', () async {
    final accountId = await repo.createAccount(
      name: 'UAT Cash',
      accountClass: AccountClass.asset,
      accountType: AccountType.cash,
      openingBalanceMinor: 216000,
    );
    const note = 'Penyesuaian saldo UAT Cash: Rp 216.000 → Rp 215.000';

    final id = await repo.reconcileAccount(
      accountId: accountId,
      observedBalanceMinor: 215000,
      occurredAt: DateTime(2026, 9, 16, 17, 0),
      reason: note,
    );

    final account = (await repo.listAccounts())
        .firstWhere((item) => item.id == accountId);
    expect(account.balanceMinor, 215000);

    final adjustments = await repo.listTransactions(
      filter: const TransactionFilter(type: TransactionType.adjustment),
    );
    final adjustment = adjustments.firstWhere((item) => item.id == id);
    expect(adjustment.note, note);
    expect(adjustment.amountMinor, 1000);
  });
}
