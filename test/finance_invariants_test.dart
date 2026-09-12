import 'package:flutter_test/flutter_test.dart';
import 'package:arus_finance/core/db/app_database.dart';
import 'package:arus_finance/data/local_finance_repository.dart';
import 'package:arus_finance/domain/enums.dart';
import 'package:arus_finance/domain/models.dart';
import 'package:arus_finance/domain/money_limits.dart';

void main() {
  late AppDatabase db;
  late LocalFinanceRepository repo;
  late DateTime fakeNow;

  setUp(() async {
    db = AppDatabase.inMemory();
    fakeNow = DateTime(2026, 9, 30, 12);
    repo = LocalFinanceRepository(db, clock: () => fakeNow);
    await repo.initialize();
  });

  tearDown(() => db.close());

  Future<String> expenseCategory(String name) async =>
      (await repo.listCategories(type: CategoryType.expense)).firstWhere((c) => c.name == name).id;
  Future<String> incomeCategory(String name) async =>
      (await repo.listCategories(type: CategoryType.income)).firstWhere((c) => c.name == name).id;

  test('expense reduces asset and net worth', () async {
    final bank = await repo.createAccount(name: 'Bank', accountClass: AccountClass.asset, accountType: AccountType.bank, openingBalanceMinor: 1000000);
    await repo.createExpense(amountMinor: 100000, accountId: bank, categoryId: await expenseCategory('Makanan'), occurredAt: DateTime(2026, 9, 8));
    final account = (await repo.listAccounts()).firstWhere((a) => a.id == bank);
    final dash = await repo.dashboard(now: DateTime(2026, 9, 8));
    expect(account.balanceMinor, 900000);
    expect(dash.spendingPeriodMinor, 100000);
  });

  test('income increases asset and is not a transfer', () async {
    final bank = await repo.createAccount(name: 'Bank', accountClass: AccountClass.asset, accountType: AccountType.bank);
    await repo.createIncome(amountMinor: 500000, accountId: bank, categoryId: await incomeCategory('Gaji'), occurredAt: DateTime(2026, 9, 8));
    final dash = await repo.dashboard(now: DateTime(2026, 9, 8));
    expect(dash.incomePeriodMinor, 500000);
    expect((await repo.listAccounts()).firstWhere((a) => a.id == bank).balanceMinor, 500000);
  });

  test('asset transfer is net-worth neutral and fee is expense only', () async {
    final source = await repo.createAccount(name: 'BCA', accountClass: AccountClass.asset, accountType: AccountType.bank, openingBalanceMinor: 1000000);
    final dest = await repo.createAccount(name: 'GoPay', accountClass: AccountClass.asset, accountType: AccountType.ewallet);
    final before = (await repo.dashboard(now: DateTime(2026, 9, 8))).netWorthMinor;
    await repo.createTransfer(amountMinor: 500000, sourceAccountId: source, destinationAccountId: dest, occurredAt: DateTime(2026, 9, 8), feeMinor: 1000);
    final after = await repo.dashboard(now: DateTime(2026, 9, 8));
    final accounts = await repo.listAccounts();
    expect(accounts.firstWhere((a) => a.id == source).balanceMinor, 499000);
    expect(accounts.firstWhere((a) => a.id == dest).balanceMinor, 500000);
    expect(after.netWorthMinor, before - 1000);
    expect(after.spendingPeriodMinor, 1000);
  });

  test('credit card purchase lowers net worth and payment does not double count expense', () async {
    final bank = await repo.createAccount(name: 'Bank', accountClass: AccountClass.asset, accountType: AccountType.bank, openingBalanceMinor: 1000000);
    final card = await repo.createAccount(name: 'Visa', accountClass: AccountClass.liability, accountType: AccountType.creditCard);
    await repo.createExpense(amountMinor: 300000, accountId: card, categoryId: await expenseCategory('Belanja'), occurredAt: DateTime(2026, 9, 8));
    var dash = await repo.dashboard(now: DateTime(2026, 9, 8));
    expect(dash.spendingPeriodMinor, 300000);
    expect((await repo.listAccounts()).firstWhere((a) => a.id == card).balanceMinor, 300000);
    final netAfterPurchase = dash.netWorthMinor;
    await repo.createCreditCardPayment(amountMinor: 300000, sourceAssetAccountId: bank, creditCardAccountId: card, occurredAt: DateTime(2026, 9, 9));
    dash = await repo.dashboard(now: DateTime(2026, 9, 9));
    expect(dash.spendingPeriodMinor, 300000);
    expect(dash.netWorthMinor, netAfterPurchase);
    expect((await repo.listAccounts()).firstWhere((a) => a.id == card).balanceMinor, 0);
  });

  test('loan disbursement is not income and principal is net-worth neutral', () async {
    final bank = await repo.createAccount(name: 'Bank', accountClass: AccountClass.asset, accountType: AccountType.bank, openingBalanceMinor: 500000);
    final loan = await repo.createAccount(name: 'Loan', accountClass: AccountClass.liability, accountType: AccountType.loan);
    final before = (await repo.dashboard(now: DateTime(2026, 9, 8))).netWorthMinor;
    await repo.createLoanDisbursement(amountMinor: 1000000, assetAccountId: bank, loanAccountId: loan, occurredAt: DateTime(2026, 9, 8));
    var dash = await repo.dashboard(now: DateTime(2026, 9, 8));
    expect(dash.incomePeriodMinor, 0);
    expect(dash.netWorthMinor, before);
    await repo.createLoanPayment(
      principalMinor: 100000,
      interestMinor: 10000,
      feeMinor: 5000,
      sourceAssetAccountId: bank,
      loanAccountId: loan,
      interestCategoryId: await expenseCategory('Bunga Pinjaman'),
      feeCategoryId: await expenseCategory('Biaya Pinjaman'),
      occurredAt: DateTime(2026, 9, 9),
    );
    dash = await repo.dashboard(now: DateTime(2026, 9, 9));
    expect(dash.spendingPeriodMinor, 15000);
    expect(dash.netWorthMinor, before - 15000);
  });

  test('partial refund offsets expense and cannot exceed original', () async {
    final bank = await repo.createAccount(name: 'Bank', accountClass: AccountClass.asset, accountType: AccountType.bank, openingBalanceMinor: 500000);
    final tx = await repo.createExpense(amountMinor: 200000, accountId: bank, categoryId: await expenseCategory('Belanja'), occurredAt: DateTime(2026, 9, 8));
    await repo.createRefund(originalTransactionId: tx, amountMinor: 50000, destinationAccountId: bank, occurredAt: DateTime(2026, 9, 9));
    final dash = await repo.dashboard(now: DateTime(2026, 9, 9));
    expect(dash.spendingPeriodMinor, 150000);
    await expectLater(repo.createRefund(originalTransactionId: tx, amountMinor: 160000, destinationAccountId: bank, occurredAt: DateTime(2026, 9, 10)), throwsA(isA<StateError>()));
  });

  test('edit replaces old financial effect', () async {
    final bank = await repo.createAccount(name: 'Bank', accountClass: AccountClass.asset, accountType: AccountType.bank, openingBalanceMinor: 500000);
    final cat = await expenseCategory('Makanan');
    final tx = await repo.createExpense(amountMinor: 100000, accountId: bank, categoryId: cat, occurredAt: DateTime(2026, 9, 8));
    await repo.updateSimpleTransaction(transactionId: tx, amountMinor: 150000, accountId: bank, categoryId: cat, occurredAt: DateTime(2026, 9, 8));
    expect((await repo.listAccounts()).firstWhere((a) => a.id == bank).balanceMinor, 350000);
    expect((await repo.dashboard(now: DateTime(2026, 9, 8))).spendingPeriodMinor, 150000);
  });

  test('delete hard-removes local transaction financial effect', () async {
    final bank = await repo.createAccount(name: 'Bank', accountClass: AccountClass.asset, accountType: AccountType.bank, openingBalanceMinor: 500000);
    final tx = await repo.createExpense(amountMinor: 100000, accountId: bank, categoryId: await expenseCategory('Makanan'), occurredAt: DateTime(2026, 9, 8));
    await repo.deleteTransaction(tx);
    expect((await repo.listAccounts()).firstWhere((a) => a.id == bank).balanceMinor, 500000);
    expect((await repo.dashboard(now: DateTime(2026, 9, 8))).spendingPeriodMinor, 0);
  });

  test('recurring occurrence is generated once', () async {
    fakeNow = DateTime(2026, 9, 1, 9);
    final bank = await repo.createAccount(name: 'Bank', accountClass: AccountClass.asset, accountType: AccountType.bank, openingBalanceMinor: 500000);
    await repo.createRecurringExpenseDraft(name: 'Internet', amountMinor: 100000, accountId: bank, categoryId: await expenseCategory('Tagihan'), dayOfMonth: 8);
    final first = await repo.generateDueRecurring(now: DateTime(2026, 9, 8, 23));
    final second = await repo.generateDueRecurring(now: DateTime(2026, 9, 8, 23));
    expect(first, 1);
    expect(second, 0);
    final drafts = await repo.listTransactions(limit: 100);
    expect(drafts.where((t) => t.note?.startsWith('Recurring:') == true).length, 1);
  });

  test('transaction filter combines type, account, category, date and amount without changing ledger', () async {
    final bank = await repo.createAccount(name: 'Filter Bank', accountClass: AccountClass.asset, accountType: AccountType.bank, openingBalanceMinor: 1000000);
    final cash = (await repo.listAccounts()).firstWhere((a) => a.name == 'Cash').id;
    final food = await expenseCategory('Makanan');
    final shopping = await expenseCategory('Belanja');
    await repo.createExpense(amountMinor: 50000, accountId: bank, categoryId: food, occurredAt: DateTime(2026, 9, 1), note: 'sarapan');
    await repo.createExpense(amountMinor: 200000, accountId: bank, categoryId: shopping, occurredAt: DateTime(2026, 9, 8), note: 'sepatu');
    await repo.createExpense(amountMinor: 75000, accountId: cash, categoryId: food, occurredAt: DateTime(2026, 8, 20), note: 'makan');

    final before = await repo.dashboard(now: DateTime(2026, 9, 8));
    final filtered = await repo.listTransactions(
      filter: TransactionFilter(
        type: TransactionType.expense,
        accountId: bank,
        categoryId: shopping,
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 30),
        minAmountMinor: 100000,
        maxAmountMinor: 250000,
      ),
    );
    final after = await repo.dashboard(now: DateTime(2026, 9, 8));
    expect(filtered.length, 1);
    expect(filtered.single.note, 'sepatu');
    expect(after.spendingPeriodMinor, before.spendingPeriodMinor);
    expect(after.netWorthMinor, before.netWorthMinor);
  });

  test('loan principal cannot overpay outstanding liability', () async {
    final bank = await repo.createAccount(name: 'Loan Bank', accountClass: AccountClass.asset, accountType: AccountType.bank, openingBalanceMinor: 1000000);
    final loan = await repo.createAccount(name: 'Small Loan', accountClass: AccountClass.liability, accountType: AccountType.loan);
    await repo.createLoanDisbursement(amountMinor: 100000, assetAccountId: bank, loanAccountId: loan, occurredAt: DateTime(2026, 9, 8));
    final interestCat = await expenseCategory('Bunga Pinjaman');
    final feeCat = await expenseCategory('Biaya Pinjaman');
    await expectLater(
      repo.createLoanPayment(
        principalMinor: 100001,
        interestMinor: 0,
        feeMinor: 0,
        sourceAssetAccountId: bank,
        loanAccountId: loan,
        interestCategoryId: interestCat,
        feeCategoryId: feeCat,
        occurredAt: DateTime(2026, 9, 9),
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('recurring draft keeps intended account without affecting balance until posted', () async {
    fakeNow = DateTime(2026, 9, 1, 9);
    final bank = await repo.createAccount(name: 'Draft Bank', accountClass: AccountClass.asset, accountType: AccountType.bank, openingBalanceMinor: 500000);
    await repo.createRecurringExpenseDraft(name: 'Internet Draft', amountMinor: 100000, accountId: bank, categoryId: await expenseCategory('Tagihan'), dayOfMonth: 8);
    expect(await repo.generateDueRecurring(now: DateTime(2026, 9, 8, 23)), 1);
    final drafts = await repo.listTransactions(filter: const TransactionFilter(status: TransactionStatus.draft));
    expect(drafts.length, 1);
    final detail = await repo.getTransactionDetail(drafts.single.id);
    expect(detail.accountId, bank);
    expect((await repo.listAccounts()).firstWhere((a) => a.id == bank).balanceMinor, 500000);
    fakeNow = DateTime(2026, 9, 8, 23);
    await repo.postDraftTransaction(drafts.single.id);
    expect((await repo.listAccounts()).firstWhere((a) => a.id == bank).balanceMinor, 400000);
  });

  test('deleting a bill payment reopens the bill', () async {
    fakeNow = DateTime(2026, 9, 10, 12);
    final bank = await repo.createAccount(name: 'Bill Bank', accountClass: AccountClass.asset, accountType: AccountType.bank, openingBalanceMinor: 500000);
    final bill = await repo.createBill(name: 'Internet Bill', expectedAmountMinor: 100000, dueDate: DateTime(2026, 9, 20));
    final tx = await repo.payBill(billId: bill, amountMinor: 100000, accountId: bank, categoryId: await expenseCategory('Tagihan'), occurredAt: DateTime(2026, 9, 10));
    expect(db.db.select('SELECT status FROM bills WHERE id=?', [bill]).first['status'], 'PAID');
    await repo.deleteTransaction(tx);
    expect(db.db.select('SELECT status,paid_transaction_id FROM bills WHERE id=?', [bill]).first['status'], 'UPCOMING');
    expect(db.db.select('SELECT status,paid_transaction_id FROM bills WHERE id=?', [bill]).first['paid_transaction_id'], isNull);
  });

  test('active account and category names are unique and V1 currency is IDR only', () async {
    await repo.createAccount(name: 'Unique Bank', accountClass: AccountClass.asset, accountType: AccountType.bank);
    await expectLater(repo.createAccount(name: 'unique bank', accountClass: AccountClass.asset, accountType: AccountType.bank), throwsA(isA<StateError>()));
    await expectLater(repo.createAccount(name: 'USD Bank', accountClass: AccountClass.asset, accountType: AccountType.bank, currency: 'USD'), throwsA(isA<StateError>()));
    await repo.createCategory(name: 'Custom Food', type: CategoryType.expense);
    await expectLater(repo.createCategory(name: 'custom food', type: CategoryType.expense), throwsA(isA<StateError>()));
  });

  test('account and category used by draft cannot be archived', () async {
    final bank = await repo.createAccount(name: 'Protected Bank', accountClass: AccountClass.asset, accountType: AccountType.bank);
    final cat = await repo.createCategory(name: 'Protected Category', type: CategoryType.expense);
    await repo.createExpense(amountMinor: 1000, accountId: bank, categoryId: cat, occurredAt: DateTime(2026, 9, 9), status: TransactionStatus.draft);
    await expectLater(repo.archiveAccount(bank), throwsA(isA<StateError>()));
    await expectLater(repo.archiveCategory(cat), throwsA(isA<StateError>()));
  });

  test('recurring occurrence identity does not depend on rule version', () async {
    fakeNow = DateTime(2026, 9, 1, 9);
    final bank = await repo.createAccount(name: 'Recurring Bank', accountClass: AccountClass.asset, accountType: AccountType.bank);
    final rule = await repo.createRecurringExpenseDraft(name: 'Monthly', amountMinor: 1000, accountId: bank, categoryId: await expenseCategory('Tagihan'), dayOfMonth: 8);
    await repo.generateDueRecurring(now: DateTime(2026, 9, 8, 23));
    final key = db.db.select('SELECT occurrence_key FROM recurring_occurrences WHERE rule_id=?', [rule]).single['occurrence_key'] as String;
    expect(key, '$rule:2026-09-08');
    expect(key.contains(':v'), isFalse);
  });

  test('VOID preserves history but removes financial effect', () async {
    final bank = await repo.createAccount(name: 'Void Bank', accountClass: AccountClass.asset, accountType: AccountType.bank, openingBalanceMinor: 500000);
    final tx = await repo.createExpense(amountMinor: 100000, accountId: bank, categoryId: await expenseCategory('Makanan'), occurredAt: DateTime(2026, 9, 8));
    await repo.voidTransaction(tx, reason: 'Duplikat input');
    final account = (await repo.listAccounts()).firstWhere((a) => a.id == bank);
    final dash = await repo.dashboard(now: DateTime(2026, 9, 8));
    final detail = await repo.getTransactionDetail(tx);
    expect(account.balanceMinor, 500000);
    expect(dash.spendingPeriodMinor, 0);
    expect(detail.view.status, TransactionStatus.voided);
    expect(detail.view.note, contains('VOID: Duplikat input'));
  });

  test('VOID bill payment reopens bill', () async {
    fakeNow = DateTime(2026, 9, 10, 12);
    final bank = await repo.createAccount(name: 'Void Bill Bank', accountClass: AccountClass.asset, accountType: AccountType.bank, openingBalanceMinor: 500000);
    final bill = await repo.createBill(name: 'Void Bill', expectedAmountMinor: 100000, dueDate: DateTime(2026, 9, 20));
    final tx = await repo.payBill(billId: bill, amountMinor: 100000, accountId: bank, categoryId: await expenseCategory('Tagihan'), occurredAt: DateTime(2026, 9, 10));
    await repo.voidTransaction(tx, reason: 'Pembayaran salah');
    final row = db.db.select('SELECT status,paid_transaction_id FROM bills WHERE id=?', [bill]).single;
    expect(row['status'], 'UPCOMING');
    expect(row['paid_transaction_id'], isNull);
  });

  test('recurring day 31 clamps to month end', () async {
    fakeNow = DateTime(2026, 9, 1, 9);
    final bank = await repo.createAccount(name: 'Month End Bank', accountClass: AccountClass.asset, accountType: AccountType.bank);
    final rule = await repo.createRecurringExpenseDraft(name: 'Month End', amountMinor: 1000, accountId: bank, categoryId: await expenseCategory('Tagihan'), dayOfMonth: 31);
    expect(await repo.generateDueRecurring(now: DateTime(2026, 9, 30, 23)), 1);
    final key = db.db.select('SELECT occurrence_key FROM recurring_occurrences WHERE rule_id=?', [rule]).single['occurrence_key'];
    expect(key, '$rule:2026-09-30');
    expect(db.db.select('SELECT next_run FROM recurring_rules WHERE id=?', [rule]).single['next_run'], '2026-10-31');
  });

  test('extreme clock jump does not flood years of recurring drafts', () async {
    fakeNow = DateTime(2026, 9, 1, 9);
    final bank = await repo.createAccount(name: 'Clock Jump Bank', accountClass: AccountClass.asset, accountType: AccountType.bank);
    final rule = await repo.createRecurringExpenseDraft(name: 'Clock Jump', amountMinor: 1000, accountId: bank, categoryId: await expenseCategory('Tagihan'), dayOfMonth: 8);
    final generated = await repo.generateDueRecurring(now: DateTime(2036, 9, 15, 12));
    expect(generated, 1);
    final occurrenceCount = db.db.select('SELECT COUNT(*) AS c FROM recurring_occurrences WHERE rule_id=?', [rule]).single['c'];
    expect(occurrenceCount, 1);
    expect(db.db.select('SELECT next_run FROM recurring_rules WHERE id=?', [rule]).single['next_run'], '2036-10-08');
  });

  test('CSV import preserves source transaction ID and is idempotent', () async {
    final bank = await repo.createAccount(
      name: 'Import Bank',
      accountClass: AccountClass.asset,
      accountType: AccountType.bank,
    );
    final category = await expenseCategory('Makanan');
    final row = ImportTransactionDraft(
      fingerprint: 'fp-import-1',
      sourceTransactionId: 'source-tx-1',
      type: TransactionType.expense,
      amountMinor: 12345,
      accountId: bank,
      categoryId: category,
      occurredAt: DateTime.utc(2026, 9, 9, 12),
      note: 'imported',
    );

    final first = await repo.importSimpleTransactionsAtomically([row]);
    final second = await repo.importSimpleTransactionsAtomically([row]);

    expect(first.imported, 1);
    expect(second.imported, 0);
    expect(second.skippedDuplicates, 1);
    expect((await repo.getTransactionDetail('source-tx-1')).view.amountMinor, 12345);
  });

  test('CSV import conflict rolls back the whole batch', () async {
    final bank = await repo.createAccount(
      name: 'Import Conflict Bank',
      accountClass: AccountClass.asset,
      accountType: AccountType.bank,
    );
    final category = await expenseCategory('Makanan');

    await repo.importSimpleTransactionsAtomically([
      ImportTransactionDraft(
        fingerprint: 'fp-existing',
        sourceTransactionId: 'conflict-id',
        type: TransactionType.expense,
        amountMinor: 1000,
        accountId: bank,
        categoryId: category,
        occurredAt: DateTime.utc(2026, 9, 9, 10),
      ),
    ]);

    await expectLater(
      repo.importSimpleTransactionsAtomically([
        ImportTransactionDraft(
          fingerprint: 'fp-would-be-rolled-back',
          sourceTransactionId: 'new-before-conflict',
          type: TransactionType.expense,
          amountMinor: 2000,
          accountId: bank,
          categoryId: category,
          occurredAt: DateTime.utc(2026, 9, 9, 11),
        ),
        ImportTransactionDraft(
          fingerprint: 'fp-conflicting-copy',
          sourceTransactionId: 'conflict-id',
          type: TransactionType.expense,
          amountMinor: 9999,
          accountId: bank,
          categoryId: category,
          occurredAt: DateTime.utc(2026, 9, 9, 10),
        ),
      ]),
      throwsA(isA<StateError>()),
    );

    expect(
      db.db.select(
        "SELECT COUNT(*) AS c FROM transactions WHERE id='new-before-conflict'",
      ).single['c'],
      0,
    );
  });

  test('recurring scheduler never changes balance without explicit post', () async {
    fakeNow = DateTime(2026, 9, 1, 9);
    final bank = await repo.createAccount(
      name: 'Recurring Safety Bank',
      accountClass: AccountClass.asset,
      accountType: AccountType.bank,
      openingBalanceMinor: 500000,
    );
    final rule = await repo.createRecurringExpenseDraft(
      name: 'Safety recurring',
      amountMinor: 50000,
      accountId: bank,
      categoryId: await expenseCategory('Tagihan'),
      dayOfMonth: 8,
    );
    db.db.execute("UPDATE recurring_rules SET mode='AUTO_CREATE' WHERE id=?", [rule]);

    await repo.generateDueRecurring(now: DateTime(2026, 9, 8, 23));
    final tx = db.db.select(
      'SELECT t.status,t.id FROM transactions t JOIN recurring_occurrences r ON r.transaction_id=t.id WHERE r.rule_id=?',
      [rule],
    ).single;

    expect(tx['status'], 'DRAFT');
    expect(
      (await repo.listAccounts()).firstWhere((a) => a.id == bank).balanceMinor,
      500000,
    );

    fakeNow = DateTime(2026, 9, 8, 23);
    await repo.postDraftTransaction(tx['id'] as String);
    expect(
      (await repo.listAccounts()).firstWhere((a) => a.id == bank).balanceMinor,
      450000,
    );
  });

  test('future dated POSTED transaction is rejected until scheduled flow exists', () async {
    fakeNow = DateTime(2026, 9, 9, 12);
    final bank = await repo.createAccount(
      name: 'Future Guard Bank',
      accountClass: AccountClass.asset,
      accountType: AccountType.bank,
      openingBalanceMinor: 100000,
    );
    final category = await expenseCategory('Makanan');
    await expectLater(
      repo.createExpense(
        amountMinor: 1000,
        accountId: bank,
        categoryId: category,
        occurredAt: DateTime(2026, 9, 10, 8),
      ),
      throwsA(isA<StateError>()),
    );
    expect((await repo.listAccounts()).firstWhere((a) => a.id == bank).balanceMinor, 100000);
  });
  test('refund cannot predate original', () async {
    final bank = await repo.createAccount(
      name: 'Refund Date Bank',
      accountClass: AccountClass.asset,
      accountType: AccountType.bank,
      openingBalanceMinor: 200000,
    );
    final tx = await repo.createExpense(
      amountMinor: 100000,
      accountId: bank,
      categoryId: await expenseCategory('Makanan'),
      occurredAt: DateTime(2026, 9, 8),
    );
    await expectLater(
      repo.createRefund(
        originalTransactionId: tx,
        amountMinor: 10000,
        destinationAccountId: bank,
        occurredAt: DateTime(2026, 9, 7),
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('recurring expense rejects loan liability account', () async {
    final loan = await repo.createAccount(
      name: 'Recurring Loan',
      accountClass: AccountClass.liability,
      accountType: AccountType.loan,
    );
    await expectLater(
      repo.createRecurringExpenseDraft(
        name: 'Invalid loan recurring',
        amountMinor: 10000,
        accountId: loan,
        categoryId: await expenseCategory('Tagihan'),
        dayOfMonth: 5,
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('inactive recurring cannot reactivate after its account is archived', () async {
    final bank = await repo.createAccount(
      name: 'Archived Recurring Bank',
      accountClass: AccountClass.asset,
      accountType: AccountType.bank,
    );
    final rule = await repo.createRecurringExpenseDraft(
      name: 'Archived dependency',
      amountMinor: 10000,
      accountId: bank,
      categoryId: await expenseCategory('Tagihan'),
      dayOfMonth: 5,
    );
    await repo.setRecurringActive(rule, false);
    await repo.archiveAccount(bank);
    await expectLater(repo.setRecurringActive(rule, true), throwsA(isA<StateError>()));
  });

  test('paid bill cannot be manually changed to skipped', () async {
    final bank = await repo.createAccount(
      name: 'Paid Bill Bank',
      accountClass: AccountClass.asset,
      accountType: AccountType.bank,
      openingBalanceMinor: 200000,
    );
    final bill = await repo.createBill(
      name: 'Paid Bill Guard',
      expectedAmountMinor: 50000,
      dueDate: DateTime(2026, 10, 5),
    );
    await repo.payBill(
      billId: bill,
      amountMinor: 50000,
      accountId: bank,
      categoryId: await expenseCategory('Tagihan'),
      occurredAt: DateTime(2026, 9, 30),
    );
    await expectLater(
      repo.markBillStatus(bill, BillStatus.skipped),
      throwsA(isA<StateError>()),
    );
    expect(db.db.select('SELECT status FROM bills WHERE id=?', [bill]).single['status'], 'PAID');
  });


  test('money safety envelope rejects oversized values before SQLite write', () async {
    final bank = await repo.createAccount(
      name: 'Money Boundary Bank',
      accountClass: AccountClass.asset,
      accountType: AccountType.bank,
    );
    final category = await expenseCategory('Makanan');
    await expectLater(
      repo.createExpense(
        amountMinor: kMaxMoneyMinor + 1,
        accountId: bank,
        categoryId: category,
        occurredAt: DateTime(2026, 9, 8),
      ),
      throwsA(isA<ArgumentError>()),
    );
    await expectLater(
      repo.createBill(
        name: 'Too large bill',
        expectedAmountMinor: kMaxMoneyMinor + 1,
        dueDate: DateTime(2026, 10, 1),
      ),
      throwsA(isA<ArgumentError>()),
    );
    await expectLater(
      repo.reconcileAccount(
        accountId: bank,
        observedBalanceMinor: kMaxMoneyMinor + 1,
        occurredAt: DateTime(2026, 9, 8),
        reason: 'Boundary test',
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

}
