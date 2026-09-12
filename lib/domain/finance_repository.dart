import 'enums.dart';
import 'models.dart';

abstract interface class FinanceRepository {
  Future<void> initialize();
  Future<List<Account>> listAccounts({bool includeArchived = false});
  Future<List<Category>> listCategories({CategoryType? type, bool includeArchived = false});
  Future<List<TransactionView>> listTransactions({String? query, TransactionFilter? filter, int limit = 100, int offset = 0});
  Future<TransactionDetail> getTransactionDetail(String transactionId);
  Future<DashboardData> dashboard({DateTime? now});
  Future<List<BudgetModel>> listBudgets({DateTime? now});
  Future<List<BillModel>> listBills({DateTime? now});
  Future<List<RecurringRuleModel>> listRecurringRules();

  Future<String> createAccount({required String name, required AccountClass accountClass, required AccountType accountType, String currency = 'IDR', int openingBalanceMinor = 0});
  Future<String> createCategory({required String name, required CategoryType type});

  Future<String> createExpense({required int amountMinor, required String accountId, required String categoryId, required DateTime occurredAt, String? note, TransactionStatus status = TransactionStatus.posted});
  Future<String> createIncome({required int amountMinor, required String accountId, required String categoryId, required DateTime occurredAt, String? note, TransactionStatus status = TransactionStatus.posted});
  Future<String> createTransfer({required int amountMinor, required String sourceAccountId, required String destinationAccountId, required DateTime occurredAt, int feeMinor = 0, String? note});
  Future<String> createRefund({required String originalTransactionId, required int amountMinor, required String destinationAccountId, required DateTime occurredAt, String? note});
  Future<String> createCreditCardPayment({required int amountMinor, required String sourceAssetAccountId, required String creditCardAccountId, required DateTime occurredAt, String? note});
  Future<String> createLoanDisbursement({required int amountMinor, required String assetAccountId, required String loanAccountId, required DateTime occurredAt, String? note});
  Future<String> createLoanPayment({required int principalMinor, required int interestMinor, required int feeMinor, required String sourceAssetAccountId, required String loanAccountId, required String interestCategoryId, required String feeCategoryId, required DateTime occurredAt, String? note});
  Future<String> reconcileAccount({required String accountId, required int observedBalanceMinor, required DateTime occurredAt, required String reason});

  Future<void> updateSimpleTransaction({required String transactionId, required int amountMinor, required String accountId, required String categoryId, required DateTime occurredAt, String? note});
  Future<void> deleteTransaction(String transactionId);
  Future<void> voidTransaction(String transactionId, {required String reason});
  Future<void> postDraftTransaction(String transactionId);

  Future<String> createBudget({required String name, required int limitMinor, String? categoryId, required DateTime start, required DateTime end});
  Future<void> archiveBudget(String budgetId);
  Future<String> createBill({required String name, required int expectedAmountMinor, required DateTime dueDate, String currency = 'IDR'});
  Future<void> markBillStatus(String billId, BillStatus status);
  Future<String> payBill({required String billId, required int amountMinor, required String accountId, required String categoryId, required DateTime occurredAt});
  Future<String> createRecurringExpenseDraft({required String name, required int amountMinor, required String accountId, required String categoryId, required int dayOfMonth, String currency = 'IDR'});
  Future<void> setRecurringActive(String recurringRuleId, bool active);
  Future<int> generateDueRecurring({DateTime? now});
  Future<ImportCommitResult> importSimpleTransactionsAtomically(List<ImportTransactionDraft> rows);
  Future<Set<String>> existingImportFingerprints(Iterable<String> fingerprints);

  Future<void> archiveAccount(String accountId);
  Future<void> archiveCategory(String categoryId);
  Future<void> wipeLocalFinanceData();
}
