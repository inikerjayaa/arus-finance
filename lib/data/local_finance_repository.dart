import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

import '../core/db/app_database.dart';
import '../domain/enums.dart';
import '../domain/finance_repository.dart';
import '../domain/models.dart';
import '../domain/money_limits.dart';

class LocalFinanceRepository implements FinanceRepository {
  LocalFinanceRepository(this._database, {Uuid? uuid, DateTime Function()? clock})
      : _uuid = uuid ?? const Uuid(),
        _clock = clock ?? DateTime.now;

  final AppDatabase _database;
  final Uuid _uuid;
  final DateTime Function() _clock;

  Database get _db => _database.db;

  @override
  Future<void> initialize() async {
    await _database.open();
    await _seedDefaultsIfNeeded();
  }

  Future<void> _seedDefaultsIfNeeded() async {
    final accountCount = _db.select('SELECT COUNT(*) AS c FROM accounts').first['c'] as int;
    final categoryCount = _db.select('SELECT COUNT(*) AS c FROM categories').first['c'] as int;
    if (accountCount == 0) {
      await createAccount(
        name: 'Cash',
        accountClass: AccountClass.asset,
        accountType: AccountType.cash,
        currency: 'IDR',
      );
    }
    if (categoryCount == 0) {
      const expenses = [
        'Makanan',
        'Transport',
        'Belanja',
        'Rumah',
        'Tagihan',
        'Kesehatan',
        'Hiburan',
        'Pendidikan',
        'Travel',
        'Biaya Transfer',
        'Bunga Pinjaman',
        'Biaya Pinjaman',
        'Lainnya',
      ];
      const incomes = ['Gaji', 'Bonus', 'Penjualan', 'Hadiah', 'Lainnya'];

      // First-run/reset seed must be all-or-nothing. If the process dies in
      // the middle, SQLite rolls the whole seed back so the next startup can
      // retry instead of mistaking one surviving category for a complete set.
      _database.transaction((db) {
        final now = _now();
        for (final name in expenses) {
          db.execute(
            'INSERT INTO categories(id,type,name,created_at,updated_at,version) VALUES (?,?,?,?,?,1)',
            [_id(), enumDbName(CategoryType.expense), name, now, now],
          );
        }
        for (final name in incomes) {
          db.execute(
            'INSERT INTO categories(id,type,name,created_at,updated_at,version) VALUES (?,?,?,?,?,1)',
            [_id(), enumDbName(CategoryType.income), name, now, now],
          );
        }
      });
    }
  }

  String _id() => _uuid.v7();
  String _iso(DateTime value) => value.toUtc().toIso8601String();
  String _localDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  String _now() => _clock().toUtc().toIso8601String();

  Map<String, Object?> _accountRow(String id) {
    final rows = _db.select('SELECT * FROM accounts WHERE id = ?', [id]);
    if (rows.isEmpty) throw StateError('Account tidak ditemukan.');
    return rows.first;
  }

  Map<String, Object?> _categoryRow(String id) {
    final rows = _db.select('SELECT * FROM categories WHERE id = ?', [id]);
    if (rows.isEmpty) throw StateError('Kategori tidak ditemukan.');
    return rows.first;
  }

  void _requireMoneyMagnitude(int amountMinor, String label) {
    if (amountMinor < -kMaxMoneyMinor || amountMinor > kMaxMoneyMinor) {
      throw ArgumentError('$label melebihi batas keamanan nominal local database.');
    }
  }

  void _requireNonNegativeMoney(int amountMinor, String label) {
    _requireMoneyMagnitude(amountMinor, label);
    if (amountMinor < 0) throw ArgumentError('$label tidak boleh negatif.');
  }

  void _requirePositive(int amountMinor, String label) {
    _requireMoneyMagnitude(amountMinor, label);
    if (amountMinor <= 0) throw ArgumentError('$label harus lebih besar dari 0.');
  }

  void _requireSameCurrency(Map<String, Object?> a, Map<String, Object?> b) {
    if (a['currency'] != b['currency']) {
      throw StateError('Operasi ini saat ini hanya mendukung account dengan currency yang sama.');
    }
  }

  void _requireActiveAccount(Map<String, Object?> row) {
    if (row['archived_at'] != null) throw StateError('Account sudah diarsipkan.');
  }

  void _requireRefundDestination(Map<String, Object?> row) {
    _requireActiveAccount(row);
    final isAsset = row['account_class'] == 'ASSET';
    final isCreditCard = row['account_class'] == 'LIABILITY' &&
        row['account_type'] == enumDbName(AccountType.creditCard);
    if (!isAsset && !isCreditCard) {
      throw StateError('Refund hanya boleh masuk ke asset atau credit-card liability.');
    }
  }

  void _requireRecurringExpenseAccount(Map<String, Object?> row) {
    _requireActiveAccount(row);
    final isAsset = row['account_class'] == 'ASSET';
    final isCreditCard = row['account_class'] == 'LIABILITY' &&
        row['account_type'] == enumDbName(AccountType.creditCard);
    if (!isAsset && !isCreditCard) {
      throw StateError('Recurring expense hanya boleh memakai asset atau credit-card liability.');
    }
  }

  void _requireCategoryType(Map<String, Object?> row, CategoryType type) {
    if (row['archived_at'] != null) throw StateError('Kategori sudah diarsipkan.');
    if (row['type'] != enumDbName(type)) {
      throw StateError('Tipe kategori tidak sesuai dengan transaksi.');
    }
  }

  void _requireSupportedCurrency(String currency) {
    if (currency != 'IDR') {
      throw StateError('Versi local-only saat ini hanya mendukung IDR sampai engine multi-currency tersedia.');
    }
  }

  bool _isFutureLocalDate(DateTime value) {
    final candidate = value.toLocal();
    final now = _clock().toLocal();
    final candidateDate = DateTime(candidate.year, candidate.month, candidate.day);
    final today = DateTime(now.year, now.month, now.day);
    return candidateDate.isAfter(today);
  }

  void _requirePostableDate(DateTime value) {
    if (_isFutureLocalDate(value)) {
      throw StateError('Transaksi masa depan tidak boleh langsung POSTED. Gunakan bill/recurring sampai fitur scheduled transaction tersedia.');
    }
  }

  String _ftsQuery(String raw) {
    final tokens = raw
        .trim()
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .map((token) => token.replaceAll('"', '""'))
        .toList(growable: false);
    if (tokens.isEmpty) return '""';
    return tokens.map((token) => '"$token"*').join(' AND ');
  }

  void _requireAccountTypeMatchesClass(AccountClass accountClass, AccountType accountType) {
    const assetTypes = {AccountType.cash, AccountType.bank, AccountType.ewallet, AccountType.investment, AccountType.otherAsset};
    const liabilityTypes = {AccountType.creditCard, AccountType.loan, AccountType.otherLiability};
    final valid = accountClass == AccountClass.asset ? assetTypes.contains(accountType) : liabilityTypes.contains(accountType);
    if (!valid) throw ArgumentError('Tipe account tidak sesuai dengan kelas asset/liability.');
  }


  String _insertTransaction(
    Database db, {
    required TransactionType type,
    required TransactionStatus status,
    required int amountMinor,
    required String currency,
    required DateTime occurredAt,
    String? note,
    String? originalTransactionId,
    String? groupId,
    bool groupPrimary = true,
    String? idOverride,
  }) {
    _requirePositive(amountMinor, 'Nominal transaksi');
    if (status == TransactionStatus.posted) _requirePostableDate(occurredAt);
    final id = idOverride ?? _id();
    final now = _now();
    db.execute(
      '''INSERT INTO transactions(
        id, transaction_group_id, group_primary, type, status, primary_amount_minor, primary_currency,
        occurred_at_utc, local_date, note, original_transaction_id, created_at, updated_at, version
      ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,1)''',
      [
        id,
        groupId,
        groupPrimary ? 1 : 0,
        enumDbName(type),
        enumDbName(status),
        amountMinor,
        currency,
        _iso(occurredAt),
        _localDate(occurredAt),
        note,
        originalTransactionId,
        now,
        now,
      ],
    );
    return id;
  }

  void _insertLeg(Database db, String transactionId, String accountId, int deltaMinor, String currency) {
    _requireMoneyMagnitude(deltaMinor, 'Delta ledger');
    db.execute(
      'INSERT INTO transaction_legs(id, transaction_id, account_id, delta_minor, currency) VALUES (?,?,?,?,?)',
      [_id(), transactionId, accountId, deltaMinor, currency],
    );
  }

  void _insertSplit(Database db, String transactionId, String categoryId, int amountMinor, String currency) {
    _requirePositive(amountMinor, 'Nominal split');
    db.execute(
      'INSERT INTO transaction_splits(id, transaction_id, category_id, amount_minor, currency) VALUES (?,?,?,?,?)',
      [_id(), transactionId, categoryId, amountMinor, currency],
    );
  }

  int _accountBalanceInDb(Database db, String accountId) {
    final row = db.select(
      '''SELECT COALESCE(SUM(l.delta_minor),0) AS balance
         FROM transaction_legs l
         JOIN transactions t ON t.id = l.transaction_id
         WHERE l.account_id = ?
           AND t.status = 'POSTED'
           AND t.deleted_at IS NULL
           AND t.local_date <= ?''',
      [accountId, _localDate(_clock())],
    ).first;
    return row['balance'] as int;
  }

  int _accountBalance(String accountId) => _accountBalanceInDb(_db, accountId);

  @override
  Future<List<Account>> listAccounts({bool includeArchived = false}) async {
    final rows = _db.select(
      'SELECT * FROM accounts ${includeArchived ? '' : 'WHERE archived_at IS NULL'} ORDER BY archived_at IS NOT NULL, name COLLATE NOCASE',
    );
    return rows.map((r) => Account(
      id: r['id'] as String,
      name: r['name'] as String,
      accountClass: enumFromDb(r['account_class'] as String, AccountClass.values),
      accountType: enumFromDb(r['account_type'] as String, AccountType.values),
      currency: r['currency'] as String,
      balanceMinor: _accountBalance(r['id'] as String),
      includeInAvailable: (r['include_available'] as int) == 1,
      includeInNetWorth: (r['include_net_worth'] as int) == 1,
      archivedAt: r['archived_at'] == null ? null : DateTime.parse(r['archived_at'] as String),
    )).toList();
  }

  @override
  Future<List<Category>> listCategories({CategoryType? type, bool includeArchived = false}) async {
    final where = <String>[];
    final args = <Object?>[];
    if (!includeArchived) where.add('archived_at IS NULL');
    if (type != null) {
      where.add('type = ?');
      args.add(enumDbName(type));
    }
    final rows = _db.select(
      'SELECT * FROM categories ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'} ORDER BY name COLLATE NOCASE',
      args,
    );
    return rows.map((r) => Category(
      id: r['id'] as String,
      name: r['name'] as String,
      type: enumFromDb(r['type'] as String, CategoryType.values),
      parentId: r['parent_id'] as String?,
      archivedAt: r['archived_at'] == null ? null : DateTime.parse(r['archived_at'] as String),
    )).toList();
  }

  @override
  Future<String> createAccount({
    required String name,
    required AccountClass accountClass,
    required AccountType accountType,
    String currency = 'IDR',
    int openingBalanceMinor = 0,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('Nama account wajib diisi.');
    _requireSupportedCurrency(currency);
    _requireAccountTypeMatchesClass(accountClass, accountType);
    _requireNonNegativeMoney(openingBalanceMinor, 'Opening balance');
    final duplicate = _db.select('SELECT id FROM accounts WHERE archived_at IS NULL AND lower(name)=lower(?) LIMIT 1', [trimmed]);
    if (duplicate.isNotEmpty) throw StateError('Nama account aktif sudah digunakan.');
    final id = _id();
    _database.transaction((db) {
      final now = _now();
      db.execute(
        '''INSERT INTO accounts(id,name,account_class,account_type,currency,include_available,include_net_worth,created_at,updated_at,version)
           VALUES (?,?,?,?,?,?,?,?,?,1)''',
        [
          id,
          trimmed,
          enumDbName(accountClass),
          enumDbName(accountType),
          currency,
          accountClass == AccountClass.asset && accountType != AccountType.investment ? 1 : 0,
          1,
          now,
          now,
        ],
      );
      if (openingBalanceMinor > 0) {
        final txId = _insertTransaction(
          db,
          type: TransactionType.openingBalance,
          status: TransactionStatus.posted,
          amountMinor: openingBalanceMinor,
          currency: currency,
          occurredAt: _clock(),
          note: 'Opening balance',
        );
        _insertLeg(db, txId, id, openingBalanceMinor, currency);
      }
    });
    return id;
  }

  @override
  Future<String> createCategory({required String name, required CategoryType type}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('Nama kategori wajib diisi.');
    final duplicate = _db.select('SELECT id FROM categories WHERE archived_at IS NULL AND type=? AND lower(name)=lower(?) LIMIT 1', [enumDbName(type), trimmed]);
    if (duplicate.isNotEmpty) throw StateError('Nama kategori aktif sudah digunakan untuk tipe ini.');
    final id = _id();
    _database.transaction((db) {
      final now = _now();
      db.execute(
        'INSERT INTO categories(id,type,name,created_at,updated_at,version) VALUES (?,?,?,?,?,1)',
        [id, enumDbName(type), trimmed, now, now],
      );
    });
    return id;
  }

  @override
  Future<String> createExpense({
    required int amountMinor,
    required String accountId,
    required String categoryId,
    required DateTime occurredAt,
    String? note,
    TransactionStatus status = TransactionStatus.posted,
  }) async {
    _requirePositive(amountMinor, 'Nominal expense');
    if (status != TransactionStatus.posted && status != TransactionStatus.draft) {
      throw StateError('createExpense hanya menerima POSTED atau DRAFT.');
    }
    final account = _accountRow(accountId);
    final category = _categoryRow(categoryId);
    _requireActiveAccount(account);
    _requireCategoryType(category, CategoryType.expense);
    if (account['account_class'] == 'LIABILITY' && account['account_type'] != enumDbName(AccountType.creditCard)) {
      throw StateError('Expense langsung ke liability non-credit-card belum didukung.');
    }
    final currency = account['currency'] as String;
    late String txId;
    _database.transaction((db) {
      txId = _insertTransaction(db,
        type: TransactionType.expense,
        status: status,
        amountMinor: amountMinor,
        currency: currency,
        occurredAt: occurredAt,
        note: note,
      );
      final delta = account['account_class'] == 'ASSET' ? -amountMinor : amountMinor;
      _insertLeg(db, txId, accountId, delta, currency); // intended leg; only POSTED affects balance/report
      _insertSplit(db, txId, categoryId, amountMinor, currency);
    });
    return txId;
  }

  @override
  Future<String> createIncome({
    required int amountMinor,
    required String accountId,
    required String categoryId,
    required DateTime occurredAt,
    String? note,
    TransactionStatus status = TransactionStatus.posted,
  }) async {
    _requirePositive(amountMinor, 'Nominal income');
    if (status != TransactionStatus.posted && status != TransactionStatus.draft) {
      throw StateError('createIncome hanya menerima POSTED atau DRAFT.');
    }
    final account = _accountRow(accountId);
    final category = _categoryRow(categoryId);
    _requireActiveAccount(account);
    _requireCategoryType(category, CategoryType.income);
    if (account['account_class'] != 'ASSET') throw StateError('Income normal harus masuk ke asset account.');
    final currency = account['currency'] as String;
    late String txId;
    _database.transaction((db) {
      txId = _insertTransaction(db,
        type: TransactionType.income,
        status: status,
        amountMinor: amountMinor,
        currency: currency,
        occurredAt: occurredAt,
        note: note,
      );
      _insertLeg(db, txId, accountId, amountMinor, currency); // intended leg; only POSTED affects balance/report
      _insertSplit(db, txId, categoryId, amountMinor, currency);
    });
    return txId;
  }

  @override
  Future<String> createTransfer({
    required int amountMinor,
    required String sourceAccountId,
    required String destinationAccountId,
    required DateTime occurredAt,
    int feeMinor = 0,
    String? note,
  }) async {
    _requirePositive(amountMinor, 'Nominal transfer');
    _requireNonNegativeMoney(feeMinor, 'Fee transfer');
    if (sourceAccountId == destinationAccountId) throw ArgumentError('Source dan destination account tidak boleh sama.');
    final source = _accountRow(sourceAccountId);
    final destination = _accountRow(destinationAccountId);
    _requireActiveAccount(source);
    _requireActiveAccount(destination);
    if (source['account_class'] != 'ASSET' || destination['account_class'] != 'ASSET') {
      throw StateError('Generic transfer hanya untuk asset ke asset.');
    }
    _requireSameCurrency(source, destination);
    final currency = source['currency'] as String;
    late String primaryId;
    _database.transaction((db) {
      String? groupId;
      if (feeMinor > 0) {
        groupId = _id();
        final now = _now();
        db.execute('INSERT INTO transaction_groups(id,group_type,created_at,updated_at,version) VALUES (?,?,?,?,1)', [groupId, 'TRANSFER_WITH_FEE', now, now]);
      }
      primaryId = _insertTransaction(db,
        type: TransactionType.transfer,
        status: TransactionStatus.posted,
        amountMinor: amountMinor,
        currency: currency,
        occurredAt: occurredAt,
        note: note,
        groupId: groupId,
      );
      _insertLeg(db, primaryId, sourceAccountId, -amountMinor, currency);
      _insertLeg(db, primaryId, destinationAccountId, amountMinor, currency);

      if (feeMinor > 0) {
        final feeCategoryRows = db.select("SELECT id FROM categories WHERE type='EXPENSE' AND archived_at IS NULL AND name='Biaya Transfer' LIMIT 1");
        if (feeCategoryRows.isEmpty) throw StateError('Kategori Biaya Transfer tidak tersedia.');
        final feeTx = _insertTransaction(db,
          type: TransactionType.expense,
          status: TransactionStatus.posted,
          amountMinor: feeMinor,
          currency: currency,
          occurredAt: occurredAt,
          note: note == null ? 'Biaya transfer' : 'Biaya transfer — $note',
          groupId: groupId,
          groupPrimary: false,
        );
        _insertLeg(db, feeTx, sourceAccountId, -feeMinor, currency);
        _insertSplit(db, feeTx, feeCategoryRows.first['id'] as String, feeMinor, currency);
      }
    });
    return primaryId;
  }

  @override
  Future<String> createRefund({
    required String originalTransactionId,
    required int amountMinor,
    required String destinationAccountId,
    required DateTime occurredAt,
    String? note,
  }) async {
    _requirePositive(amountMinor, 'Nominal refund');
    final originalRows = _db.select('SELECT * FROM transactions WHERE id=? AND deleted_at IS NULL', [originalTransactionId]);
    if (originalRows.isEmpty) throw StateError('Transaksi original tidak ditemukan.');
    final original = originalRows.first;
    if (original['type'] != 'EXPENSE' || original['status'] != 'POSTED') throw StateError('Refund hanya dapat dibuat dari posted expense.');
    final refunded = _db.select(
      "SELECT COALESCE(SUM(primary_amount_minor),0) AS total FROM transactions WHERE original_transaction_id=? AND type='REFUND' AND status='POSTED' AND deleted_at IS NULL",
      [originalTransactionId],
    ).first['total'] as int;
    final originalAmount = original['primary_amount_minor'] as int;
    if (refunded + amountMinor > originalAmount) throw StateError('Total refund tidak boleh melebihi transaksi original.');
    final originalDate = DateTime.parse(original['local_date'] as String);
    final refundDate = DateTime(occurredAt.year, occurredAt.month, occurredAt.day);
    if (refundDate.isBefore(originalDate)) throw StateError('Tanggal refund tidak boleh mendahului transaksi original.');
    final destination = _accountRow(destinationAccountId);
    _requireRefundDestination(destination);
    if (destination['currency'] != original['primary_currency']) throw StateError('Currency refund harus sama dengan transaksi original.');
    final splitRows = _db.select('SELECT category_id FROM transaction_splits WHERE transaction_id=? LIMIT 1', [originalTransactionId]);
    if (splitRows.isEmpty) throw StateError('Kategori original tidak ditemukan.');
    late String refundId;
    _database.transaction((db) {
      final latestOriginalRows = db.select(
        'SELECT * FROM transactions WHERE id=? AND deleted_at IS NULL',
        [originalTransactionId],
      );
      if (latestOriginalRows.isEmpty ||
          latestOriginalRows.first['type'] != 'EXPENSE' ||
          latestOriginalRows.first['status'] != 'POSTED') {
        throw StateError('Transaksi original tidak lagi valid untuk refund.');
      }
      final latestOriginal = latestOriginalRows.first;
      final latestRefunded = db.select(
        "SELECT COALESCE(SUM(primary_amount_minor),0) AS total FROM transactions WHERE original_transaction_id=? AND type='REFUND' AND status='POSTED' AND deleted_at IS NULL",
        [originalTransactionId],
      ).first['total'] as int;
      if (latestRefunded + amountMinor > (latestOriginal['primary_amount_minor'] as int)) {
        throw StateError('Total refund tidak boleh melebihi transaksi original.');
      }
      if (destination['currency'] != latestOriginal['primary_currency']) {
        throw StateError('Currency refund harus sama dengan transaksi original.');
      }
      final latestSplitRows = db.select(
        'SELECT category_id FROM transaction_splits WHERE transaction_id=? LIMIT 1',
        [originalTransactionId],
      );
      if (latestSplitRows.isEmpty) throw StateError('Kategori original tidak ditemukan.');
      final latestCategoryId = latestSplitRows.first['category_id'] as String;
      final latestCurrency = latestOriginal['primary_currency'] as String;
      refundId = _insertTransaction(db,
        type: TransactionType.refund,
        status: TransactionStatus.posted,
        amountMinor: amountMinor,
        currency: latestCurrency,
        occurredAt: occurredAt,
        note: note,
        originalTransactionId: originalTransactionId,
      );
      final delta = destination['account_class'] == 'ASSET' ? amountMinor : -amountMinor;
      _insertLeg(db, refundId, destinationAccountId, delta, latestCurrency);
      _insertSplit(db, refundId, latestCategoryId, amountMinor, latestCurrency);
      _reconcileBillForPayment(db, originalTransactionId, now: occurredAt);
    });
    return refundId;
  }

  @override
  Future<String> createCreditCardPayment({
    required int amountMinor,
    required String sourceAssetAccountId,
    required String creditCardAccountId,
    required DateTime occurredAt,
    String? note,
  }) async {
    _requirePositive(amountMinor, 'Nominal pembayaran kartu kredit');
    final source = _accountRow(sourceAssetAccountId);
    final card = _accountRow(creditCardAccountId);
    _requireActiveAccount(source);
    _requireActiveAccount(card);
    if (source['account_class'] != 'ASSET') throw StateError('Sumber pembayaran harus asset.');
    if (card['account_type'] != enumDbName(AccountType.creditCard) || card['account_class'] != 'LIABILITY') {
      throw StateError('Destination harus credit-card liability.');
    }
    _requireSameCurrency(source, card);
    final currency = source['currency'] as String;
    late String txId;
    _database.transaction((db) {
      txId = _insertTransaction(db,
        type: TransactionType.creditCardPayment,
        status: TransactionStatus.posted,
        amountMinor: amountMinor,
        currency: currency,
        occurredAt: occurredAt,
        note: note,
      );
      _insertLeg(db, txId, sourceAssetAccountId, -amountMinor, currency);
      _insertLeg(db, txId, creditCardAccountId, -amountMinor, currency);
    });
    return txId;
  }

  @override
  Future<String> createLoanDisbursement({
    required int amountMinor,
    required String assetAccountId,
    required String loanAccountId,
    required DateTime occurredAt,
    String? note,
  }) async {
    _requirePositive(amountMinor, 'Nominal pinjaman');
    final asset = _accountRow(assetAccountId);
    final loan = _accountRow(loanAccountId);
    _requireActiveAccount(asset);
    _requireActiveAccount(loan);
    if (asset['account_class'] != 'ASSET' || loan['account_class'] != 'LIABILITY' || loan['account_type'] != enumDbName(AccountType.loan)) {
      throw StateError('Account pinjaman tidak valid.');
    }
    _requireSameCurrency(asset, loan);
    final currency = asset['currency'] as String;
    late String txId;
    _database.transaction((db) {
      txId = _insertTransaction(db,
        type: TransactionType.loanDisbursement,
        status: TransactionStatus.posted,
        amountMinor: amountMinor,
        currency: currency,
        occurredAt: occurredAt,
        note: note,
      );
      _insertLeg(db, txId, assetAccountId, amountMinor, currency);
      _insertLeg(db, txId, loanAccountId, amountMinor, currency);
    });
    return txId;
  }

  @override
  Future<String> createLoanPayment({
    required int principalMinor,
    required int interestMinor,
    required int feeMinor,
    required String sourceAssetAccountId,
    required String loanAccountId,
    required String interestCategoryId,
    required String feeCategoryId,
    required DateTime occurredAt,
    String? note,
  }) async {
    _requirePositive(principalMinor, 'Pokok pinjaman');
    _requireNonNegativeMoney(interestMinor, 'Bunga pinjaman');
    _requireNonNegativeMoney(feeMinor, 'Fee pinjaman');
    final asset = _accountRow(sourceAssetAccountId);
    final loan = _accountRow(loanAccountId);
    _requireActiveAccount(asset);
    _requireActiveAccount(loan);
    if (asset['account_class'] != 'ASSET' || loan['account_class'] != 'LIABILITY' || loan['account_type'] != enumDbName(AccountType.loan)) {
      throw StateError('Account loan payment tidak valid.');
    }
    _requireSameCurrency(asset, loan);
    final outstanding = _accountBalance(loanAccountId);
    if (outstanding < 0) throw StateError('Pinjaman memiliki credit balance yang harus direkonsiliasi sebelum pembayaran baru.');
    if (principalMinor > outstanding) throw StateError('Pokok pembayaran melebihi outstanding pinjaman.');
    if (interestMinor > 0) _requireCategoryType(_categoryRow(interestCategoryId), CategoryType.expense);
    if (feeMinor > 0) _requireCategoryType(_categoryRow(feeCategoryId), CategoryType.expense);
    final currency = asset['currency'] as String;
    late String primaryId;
    _database.transaction((db) {
      final latestOutstanding = _accountBalanceInDb(db, loanAccountId);
      if (latestOutstanding < 0) {
        throw StateError('Pinjaman memiliki credit balance yang harus direkonsiliasi sebelum pembayaran baru.');
      }
      if (principalMinor > latestOutstanding) {
        throw StateError('Pokok pembayaran melebihi outstanding pinjaman.');
      }
      final groupId = _id();
      final now = _now();
      db.execute('INSERT INTO transaction_groups(id,group_type,created_at,updated_at,version) VALUES (?,?,?,?,1)', [groupId, 'LOAN_PAYMENT', now, now]);
      primaryId = _insertTransaction(db,
        type: TransactionType.loanPayment,
        status: TransactionStatus.posted,
        amountMinor: principalMinor,
        currency: currency,
        occurredAt: occurredAt,
        note: note,
        groupId: groupId,
      );
      _insertLeg(db, primaryId, sourceAssetAccountId, -principalMinor, currency);
      _insertLeg(db, primaryId, loanAccountId, -principalMinor, currency);

      void childExpense(int amount, String categoryId, String childNote) {
        if (amount <= 0) return;
        final childId = _insertTransaction(db,
          type: TransactionType.expense,
          status: TransactionStatus.posted,
          amountMinor: amount,
          currency: currency,
          occurredAt: occurredAt,
          note: childNote,
          groupId: groupId,
          groupPrimary: false,
        );
        _insertLeg(db, childId, sourceAssetAccountId, -amount, currency);
        _insertSplit(db, childId, categoryId, amount, currency);
      }

      childExpense(interestMinor, interestCategoryId, note == null ? 'Bunga pinjaman' : 'Bunga pinjaman — $note');
      childExpense(feeMinor, feeCategoryId, note == null ? 'Biaya pinjaman' : 'Biaya pinjaman — $note');
    });
    return primaryId;
  }

  @override
  Future<String> reconcileAccount({
    required String accountId,
    required int observedBalanceMinor,
    required DateTime occurredAt,
    required String reason,
  }) async {
    if (reason.trim().isEmpty) throw ArgumentError('Alasan adjustment wajib diisi.');
    _requireMoneyMagnitude(observedBalanceMinor, 'Saldo observasi');
    final account = _accountRow(accountId);
    _requireActiveAccount(account);
    final current = _accountBalance(accountId);
    final delta = observedBalanceMinor - current;
    if (delta == 0) return '';
    final currency = account['currency'] as String;
    late String txId;
    _database.transaction((db) {
      txId = _insertTransaction(db,
        type: TransactionType.adjustment,
        status: TransactionStatus.posted,
        amountMinor: delta.abs(),
        currency: currency,
        occurredAt: occurredAt,
        note: reason.trim(),
      );
      _insertLeg(db, txId, accountId, delta, currency);
    });
    return txId;
  }

  @override
  Future<void> updateSimpleTransaction({
    required String transactionId,
    required int amountMinor,
    required String accountId,
    required String categoryId,
    required DateTime occurredAt,
    String? note,
  }) async {
    _requirePositive(amountMinor, 'Nominal transaksi');
    final rows = _db.select('SELECT * FROM transactions WHERE id=? AND deleted_at IS NULL', [transactionId]);
    if (rows.isEmpty) throw StateError('Transaksi tidak ditemukan.');
    final tx = rows.first;
    if (tx['status'] == 'POSTED') _requirePostableDate(occurredAt);
    if (tx['transaction_group_id'] != null) throw StateError('Composite transaction harus diedit melalui group editor.');
    if (tx['type'] != 'EXPENSE' && tx['type'] != 'INCOME') throw StateError('Hanya simple expense/income yang dapat diedit dengan fungsi ini.');
    final refundTotal = _db.select(
      "SELECT COALESCE(SUM(primary_amount_minor),0) AS total FROM transactions WHERE original_transaction_id=? AND type='REFUND' AND status='POSTED' AND deleted_at IS NULL",
      [transactionId],
    ).first['total'] as int;
    if (amountMinor < refundTotal) throw StateError('Nominal baru tidak boleh lebih kecil dari refund aktif.');
    final account = _accountRow(accountId);
    final isExpense = tx['type'] == 'EXPENSE';
    final category = _categoryRow(categoryId);
    _requireActiveAccount(account);
    _requireCategoryType(category, isExpense ? CategoryType.expense : CategoryType.income);
    if (isExpense && account['account_class'] == 'LIABILITY' && account['account_type'] != enumDbName(AccountType.creditCard)) {
      throw StateError('Expense langsung ke liability non-credit-card belum didukung.');
    }
    if (!isExpense && account['account_class'] != 'ASSET') throw StateError('Income harus masuk ke asset.');
    final currency = account['currency'] as String;
    _database.transaction((db) {
      final latestRows = db.select(
        'SELECT type,status,transaction_group_id FROM transactions WHERE id=? AND deleted_at IS NULL',
        [transactionId],
      );
      if (latestRows.isEmpty || latestRows.first['transaction_group_id'] != null ||
          (latestRows.first['type'] != 'EXPENSE' && latestRows.first['type'] != 'INCOME')) {
        throw StateError('Transaksi tidak lagi valid untuk diedit sebagai simple transaction.');
      }
      final latestRefundTotal = db.select(
        "SELECT COALESCE(SUM(primary_amount_minor),0) AS total FROM transactions WHERE original_transaction_id=? AND type='REFUND' AND status='POSTED' AND deleted_at IS NULL",
        [transactionId],
      ).first['total'] as int;
      if (amountMinor < latestRefundTotal) {
        throw StateError('Nominal baru tidak boleh lebih kecil dari refund aktif.');
      }
      db.execute('DELETE FROM transaction_legs WHERE transaction_id=?', [transactionId]);
      db.execute('DELETE FROM transaction_splits WHERE transaction_id=?', [transactionId]);
      db.execute(
        '''UPDATE transactions SET primary_amount_minor=?,primary_currency=?,occurred_at_utc=?,local_date=?,note=?,updated_at=?,version=version+1 WHERE id=?''',
        [amountMinor, currency, _iso(occurredAt), _localDate(occurredAt), note, _now(), transactionId],
      );
      int delta;
      if (isExpense) {
        delta = account['account_class'] == 'ASSET' ? -amountMinor : amountMinor;
      } else {
        delta = amountMinor;
      }
      _insertLeg(db, transactionId, accountId, delta, currency); // intended leg for DRAFT; balance uses POSTED only
      _insertSplit(db, transactionId, categoryId, amountMinor, currency);
    });
  }

  @override
  Future<void> postDraftTransaction(String transactionId) async {
    final rows = _db.select('SELECT * FROM transactions WHERE id=? AND deleted_at IS NULL', [transactionId]);
    if (rows.isEmpty) throw StateError('Draft tidak ditemukan.');
    final tx = rows.first;
    if (tx['status'] != 'DRAFT') throw StateError('Hanya transaksi DRAFT yang dapat dicatat sekarang.');
    _requirePostableDate(DateTime.parse(tx['local_date'] as String));
    if (tx['type'] != 'EXPENSE' && tx['type'] != 'INCOME') throw StateError('Tipe draft belum didukung untuk posting.');
    final legs = _db.select('SELECT l.*,a.archived_at FROM transaction_legs l JOIN accounts a ON a.id=l.account_id WHERE l.transaction_id=?', [transactionId]);
    final splits = _db.select('SELECT s.*,c.archived_at FROM transaction_splits s JOIN categories c ON c.id=s.category_id WHERE s.transaction_id=?', [transactionId]);
    if (legs.length != 1 || splits.isEmpty) throw StateError('Draft tidak lengkap dan harus diedit terlebih dahulu.');
    if (legs.first['archived_at'] != null || splits.any((x) => x['archived_at'] != null)) throw StateError('Account/kategori draft sudah diarsipkan. Edit draft terlebih dahulu.');
    _database.transaction((db) {
      db.execute("UPDATE transactions SET status='POSTED',updated_at=?,version=version+1 WHERE id=?", [_now(), transactionId]);
    });
  }

  @override
  Future<void> deleteTransaction(String transactionId) async {
    final rows = _db.select('SELECT * FROM transactions WHERE id=? AND deleted_at IS NULL', [transactionId]);
    if (rows.isEmpty) return;
    final tx = rows.first;
    final groupId = tx['transaction_group_id'] as String?;
    final originalTransactionId = tx['original_transaction_id'] as String?;

    _database.transaction((db) {
      final targets = groupId == null
          ? db.select('SELECT id FROM transactions WHERE id=? AND deleted_at IS NULL', [transactionId])
          : db.select('SELECT id FROM transactions WHERE transaction_group_id=? AND deleted_at IS NULL', [groupId]);
      final targetIds = targets.map((row) => row['id'] as String).toList();
      if (targetIds.isEmpty) return;

      for (final id in targetIds) {
        final activeRefunds = db.select(
          "SELECT COUNT(*) AS c FROM transactions WHERE original_transaction_id=? "
          "AND type='REFUND' AND status='POSTED' AND deleted_at IS NULL",
          [id],
        ).first['c'] as int;
        if (activeRefunds > 0) {
          throw StateError('Transaksi mempunyai refund aktif. VOID/hapus refund terlebih dahulu.');
        }
      }

      final now = _now();
      for (final id in targetIds) {
        // VOID refunds no longer have financial effect; remove them with a hard-deleted original.
        db.execute("DELETE FROM transactions WHERE original_transaction_id=? AND type='REFUND' AND status='VOIDED'", [id]);
        // Preserve recurring history while detaching a transaction that the user explicitly deletes.
        db.execute('UPDATE recurring_occurrences SET transaction_id=NULL WHERE transaction_id=?', [id]);
        db.execute(
          "UPDATE bills SET status=CASE "
          "WHEN due_date < ? THEN 'OVERDUE' WHEN due_date = ? THEN 'DUE' ELSE 'UPCOMING' END, "
          "paid_transaction_id=NULL,updated_at=? WHERE paid_transaction_id=?",
          [_localDate(_clock()), _localDate(_clock()), now, id],
        );
        db.execute('DELETE FROM transactions WHERE id=?', [id]);
      }
      if (groupId != null) {
        db.execute('DELETE FROM transaction_groups WHERE id=? AND NOT EXISTS (SELECT 1 FROM transactions WHERE transaction_group_id=?)', [groupId, groupId]);
      }
      if (originalTransactionId != null) {
        _reconcileBillForPayment(db, originalTransactionId);
      }
    });
  }

  @override
  Future<void> voidTransaction(String transactionId, {required String reason}) async {
    final trimmedReason = reason.trim();
    if (trimmedReason.length < 3) throw ArgumentError('Alasan pembatalan minimal 3 karakter.');
    final rows = _db.select('SELECT * FROM transactions WHERE id=? AND deleted_at IS NULL', [transactionId]);
    if (rows.isEmpty) throw StateError('Transaksi tidak ditemukan.');
    final tx = rows.first;
    if (tx['status'] == 'VOIDED') return;
    if (tx['status'] != 'POSTED') throw StateError('Hanya transaksi POSTED yang dapat dibatalkan/VOID.');

    final groupId = tx['transaction_group_id'] as String?;
    final now = _now();
    _database.transaction((db) {
      final targets = groupId == null
          ? db.select('SELECT id,note FROM transactions WHERE id=? AND deleted_at IS NULL', [transactionId])
          : db.select('SELECT id,note FROM transactions WHERE transaction_group_id=? AND deleted_at IS NULL', [groupId]);

      // Composite VOID is all-or-nothing. Every member must be safe to void;
      // otherwise a child expense could be voided while its posted refund stayed active.
      for (final row in targets) {
        final activeRefunds = db.select(
          "SELECT COUNT(*) AS c FROM transactions WHERE original_transaction_id=? "
          "AND type='REFUND' AND status='POSTED' AND deleted_at IS NULL",
          [row['id']],
        ).first['c'] as int;
        if (activeRefunds > 0) {
          throw StateError('Group transaksi mempunyai refund aktif. Batalkan/resolve refund terlebih dahulu.');
        }
      }

      for (final row in targets) {
        final oldNote = (row['note'] as String?)?.trim();
        final note = [if (oldNote != null && oldNote.isNotEmpty) oldNote, 'VOID: $trimmedReason'].join(' • ');
        db.execute("UPDATE bills SET status=CASE WHEN due_date < ? THEN 'OVERDUE' WHEN due_date = ? THEN 'DUE' ELSE 'UPCOMING' END,paid_transaction_id=NULL,updated_at=? WHERE paid_transaction_id=?", [_localDate(_clock()), _localDate(_clock()), now, row['id']]);
        db.execute("UPDATE transactions SET status='VOIDED',note=?,updated_at=?,version=version+1 WHERE id=?", [note, now, row['id']]);
      }
      final originalId = tx['original_transaction_id'] as String?;
      if (originalId != null) _reconcileBillForPayment(db, originalId);
    });
  }

  @override
  Future<List<TransactionView>> listTransactions({
    String? query,
    TransactionFilter? filter,
    int limit = 100,
    int offset = 0,
  }) async {
    if (limit <= 0) return const [];
    if (offset < 0) throw ArgumentError('Offset tidak boleh negatif.');
    final q = query?.trim();
    final where = <String>[
      't.deleted_at IS NULL',
      't.group_primary=1',
    ];
    final args = <Object?>[];

    if (q != null && q.isNotEmpty) {
      where.add('''t.id IN (
        SELECT transaction_id FROM transaction_search
        WHERE transaction_search MATCH ?
      )''');
      args.add(_ftsQuery(q));
    }

    if (filter?.type != null) {
      where.add('t.type = ?');
      args.add(enumDbName(filter!.type!));
    }
    if (filter?.status != null) {
      where.add('t.status = ?');
      args.add(enumDbName(filter!.status!));
    }
    if (filter?.accountId != null) {
      where.add('EXISTS (SELECT 1 FROM transaction_legs fa WHERE fa.transaction_id=t.id AND fa.account_id=?)');
      args.add(filter!.accountId);
    }
    if (filter?.categoryId != null) {
      where.add('EXISTS (SELECT 1 FROM transaction_splits fs WHERE fs.transaction_id=t.id AND fs.category_id=?)');
      args.add(filter!.categoryId);
    }
    if (filter?.startDate != null) {
      where.add('t.local_date >= ?');
      args.add(_localDate(filter!.startDate!));
    }
    if (filter?.endDate != null) {
      where.add('t.local_date <= ?');
      args.add(_localDate(filter!.endDate!));
    }
    if (filter?.minAmountMinor != null) {
      where.add('t.primary_amount_minor >= ?');
      args.add(filter!.minAmountMinor);
    }
    if (filter?.maxAmountMinor != null) {
      where.add('t.primary_amount_minor <= ?');
      args.add(filter!.maxAmountMinor);
    }

    args.add(limit);
    args.add(offset);
    final rows = _db.select(
      '''SELECT t.*,
         (SELECT a1.name FROM transaction_legs l1 JOIN accounts a1 ON a1.id=l1.account_id
            WHERE l1.transaction_id=t.id
            ORDER BY CASE WHEN l1.delta_minor < 0 THEN 0 ELSE 1 END, l1.rowid
            LIMIT 1) AS account_name,
         (SELECT c1.name FROM transaction_splits s1 JOIN categories c1 ON c1.id=s1.category_id
            WHERE s1.transaction_id=t.id LIMIT 1) AS category_name,
         (SELECT a2.name FROM transaction_legs l2 JOIN accounts a2 ON a2.id=l2.account_id
            WHERE l2.transaction_id=t.id AND l2.delta_minor>0
            ORDER BY l2.rowid LIMIT 1) AS destination_account_name,
         COALESCE((SELECT SUM(ct.primary_amount_minor) FROM transactions ct
            WHERE ct.transaction_group_id=t.transaction_group_id
              AND ct.group_primary=0
              AND ct.type='EXPENSE'
              AND ct.status='POSTED'
              AND ct.deleted_at IS NULL),0) AS child_expense
       FROM transactions t
       WHERE ${where.join(' AND ')}
       ORDER BY t.occurred_at_utc DESC, t.created_at DESC
       LIMIT ? OFFSET ?''',
      args,
    );
    return rows.map((r) => TransactionView(
      id: r['id'] as String,
      type: enumFromDb(r['type'] as String, TransactionType.values),
      status: enumFromDb(r['status'] as String, TransactionStatus.values),
      amountMinor: r['primary_amount_minor'] as int,
      currency: r['primary_currency'] as String,
      occurredAt: DateTime.parse(r['occurred_at_utc'] as String).toLocal(),
      accountName: (r['account_name'] as String?) ?? '—',
      destinationAccountName: r['destination_account_name'] as String?,
      categoryName: r['category_name'] as String?,
      note: r['note'] as String?,
      originalTransactionId: r['original_transaction_id'] as String?,
      groupId: r['transaction_group_id'] as String?,
      childExpenseMinor: r['child_expense'] as int,
    )).toList();
  }

  @override
  Future<TransactionDetail> getTransactionDetail(String transactionId) async {
    final txRows = _db.select('''SELECT t.*,
      (SELECT a1.name FROM transaction_legs l1 JOIN accounts a1 ON a1.id=l1.account_id
       WHERE l1.transaction_id=t.id ORDER BY CASE WHEN l1.delta_minor < 0 THEN 0 ELSE 1 END,l1.rowid LIMIT 1) AS account_name,
      (SELECT c1.name FROM transaction_splits s1 JOIN categories c1 ON c1.id=s1.category_id
       WHERE s1.transaction_id=t.id LIMIT 1) AS category_name,
      (SELECT a2.name FROM transaction_legs l2 JOIN accounts a2 ON a2.id=l2.account_id
       WHERE l2.transaction_id=t.id AND l2.delta_minor>0 ORDER BY l2.rowid LIMIT 1) AS destination_account_name,
      COALESCE((SELECT SUM(ct.primary_amount_minor) FROM transactions ct
       WHERE ct.transaction_group_id=t.transaction_group_id AND ct.group_primary=0 AND ct.type='EXPENSE'
         AND ct.status='POSTED' AND ct.deleted_at IS NULL),0) AS child_expense
      FROM transactions t WHERE t.id=? AND t.deleted_at IS NULL LIMIT 1''', [transactionId]);
    if (txRows.isEmpty) throw StateError('Transaksi tidak ditemukan.');
    final rr = txRows.first;
    final view = TransactionView(
      id: transactionId,
      type: enumFromDb(rr['type'] as String, TransactionType.values),
      status: enumFromDb(rr['status'] as String, TransactionStatus.values),
      amountMinor: rr['primary_amount_minor'] as int,
      currency: rr['primary_currency'] as String,
      occurredAt: DateTime.parse(rr['occurred_at_utc'] as String).toLocal(),
      accountName: (rr['account_name'] as String?) ?? '—',
      destinationAccountName: rr['destination_account_name'] as String?,
      categoryName: rr['category_name'] as String?,
      note: rr['note'] as String?,
      originalTransactionId: rr['original_transaction_id'] as String?,
      groupId: rr['transaction_group_id'] as String?,
      childExpenseMinor: rr['child_expense'] as int,
    );

    final legRows = _db.select('SELECT l.account_id,l.delta_minor,a.account_class,a.account_type FROM transaction_legs l JOIN accounts a ON a.id=l.account_id WHERE l.transaction_id=? ORDER BY l.rowid', [transactionId]);
    String? accountId;
    String? destinationAccountId;
    if (legRows.isNotEmpty) {
      switch (view.type) {
        case TransactionType.transfer:
          final source = legRows.where((x) => (x['delta_minor'] as int) < 0).toList();
          final destination = legRows.where((x) => (x['delta_minor'] as int) > 0).toList();
          accountId = source.isEmpty ? legRows.first['account_id'] as String : source.first['account_id'] as String;
          destinationAccountId = destination.isEmpty ? null : destination.first['account_id'] as String;
          break;
        case TransactionType.creditCardPayment:
          final assets = legRows.where((x) => x['account_class'] == 'ASSET').toList();
          final liabilities = legRows.where((x) => x['account_class'] == 'LIABILITY').toList();
          accountId = assets.isEmpty ? null : assets.first['account_id'] as String;
          destinationAccountId = liabilities.isEmpty ? null : liabilities.first['account_id'] as String;
          break;
        default:
          accountId = legRows.first['account_id'] as String;
      }
    }
    final categoryRows = _db.select('SELECT category_id FROM transaction_splits WHERE transaction_id=? LIMIT 1', [transactionId]);
    final refunded = _db.select(
      "SELECT COALESCE(SUM(primary_amount_minor),0) AS total FROM transactions WHERE original_transaction_id=? AND type='REFUND' AND status='POSTED' AND deleted_at IS NULL",
      [transactionId],
    ).first['total'] as int;
    return TransactionDetail(
      view: view,
      accountId: accountId,
      destinationAccountId: destinationAccountId,
      categoryId: categoryRows.isEmpty ? null : categoryRows.first['category_id'] as String,
      refundedMinor: refunded,
    );
  }

  @override
  Future<DashboardData> dashboard({DateTime? now}) async {
    final current = now ?? _clock();
    final start = DateTime(current.year, current.month, 1);
    final startIso = _localDate(start);
    final today = _localDate(current);

    final accounts = await listAccounts();
    var available = 0;
    var netWorth = 0;
    var currency = 'IDR';
    for (final account in accounts) {
      currency = account.currency;
      if (account.accountClass == AccountClass.asset) {
        if (account.includeInAvailable) available += account.balanceMinor;
        if (account.includeInNetWorth) netWorth += account.balanceMinor;
      } else if (account.includeInNetWorth) {
        netWorth -= account.balanceMinor;
      }
    }

    int scalar(String sql, List<Object?> args) => _db.select(sql, args).first['v'] as int;
    final expenseSql = '''SELECT COALESCE(SUM(CASE WHEN t.type='EXPENSE' THEN s.amount_minor WHEN t.type='REFUND' THEN -s.amount_minor ELSE 0 END),0) AS v
      FROM transactions t JOIN transaction_splits s ON s.transaction_id=t.id
      WHERE t.status='POSTED' AND t.deleted_at IS NULL AND t.local_date>=? AND t.local_date<? AND t.type IN ('EXPENSE','REFUND')''';
    final spending = scalar(
      expenseSql.replaceFirst('t.local_date<?', 't.local_date<=?'),
      [startIso, today],
    );
    final spendingToday = scalar(
      '''SELECT COALESCE(SUM(CASE WHEN t.type='EXPENSE' THEN s.amount_minor WHEN t.type='REFUND' THEN -s.amount_minor ELSE 0 END),0) AS v
         FROM transactions t JOIN transaction_splits s ON s.transaction_id=t.id
         WHERE t.status='POSTED' AND t.deleted_at IS NULL AND t.local_date=? AND t.type IN ('EXPENSE','REFUND')''',
      [today],
    );
    final income = scalar(
      '''SELECT COALESCE(SUM(s.amount_minor),0) AS v FROM transactions t JOIN transaction_splits s ON s.transaction_id=t.id
         WHERE t.status='POSTED' AND t.deleted_at IS NULL AND t.local_date>=? AND t.local_date<=? AND t.type='INCOME' ''',
      [startIso, today],
    );
    final catRows = _db.select(
      '''SELECT c.name, SUM(CASE WHEN t.type='EXPENSE' THEN s.amount_minor WHEN t.type='REFUND' THEN -s.amount_minor ELSE 0 END) AS total
         FROM transactions t JOIN transaction_splits s ON s.transaction_id=t.id JOIN categories c ON c.id=s.category_id
         WHERE t.status='POSTED' AND t.deleted_at IS NULL AND t.local_date>=? AND t.local_date<=? AND t.type IN ('EXPENSE','REFUND')
         GROUP BY c.id HAVING total > 0 ORDER BY total DESC LIMIT 1''',
      [startIso, today],
    );

    return DashboardData(
      availableBalanceMinor: available,
      netWorthMinor: netWorth,
      spendingPeriodMinor: spending,
      incomePeriodMinor: income,
      spendingTodayMinor: spendingToday,
      currency: currency,
      largestCategory: catRows.isEmpty ? null : catRows.first['name'] as String,
      largestCategoryAmountMinor: catRows.isEmpty ? 0 : catRows.first['total'] as int,
    );
  }

  @override
  Future<String> createBudget({required String name, required int limitMinor, String? categoryId, required DateTime start, required DateTime end}) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) throw ArgumentError('Nama budget wajib diisi.');
    _requirePositive(limitMinor, 'Budget');
    if (end.isBefore(start)) throw ArgumentError('Tanggal akhir budget tidak valid.');
    if (categoryId != null) _requireCategoryType(_categoryRow(categoryId), CategoryType.expense);
    final id = _id();
    final now = _now();
    _database.transaction((db) {
      db.execute('INSERT INTO budgets(id,name,limit_minor,currency,category_id,period_start,period_end,created_at,updated_at) VALUES (?,?,?,?,?,?,?,?,?)', [id, trimmedName, limitMinor, 'IDR', categoryId, _localDate(start), _localDate(end), now, now]);
    });
    return id;
  }

  @override
  Future<void> archiveBudget(String budgetId) async {
    final rows = _db.select('SELECT * FROM budgets WHERE id=? AND archived_at IS NULL', [budgetId]);
    if (rows.isEmpty) return;
    _database.transaction((db) {
      final now = _now();
      db.execute('UPDATE budgets SET archived_at=?,updated_at=? WHERE id=?', [now, now, budgetId]);
    });
  }

  @override
  Future<List<BudgetModel>> listBudgets({DateTime? now}) async {
    final current = now ?? _clock();
    final date = _localDate(current);
    final rows = _db.select('SELECT * FROM budgets WHERE archived_at IS NULL AND period_start<=? AND period_end>=? ORDER BY name', [date, date]);
    final result = <BudgetModel>[];
    for (final r in rows) {
      final categoryId = r['category_id'] as String?;
      final effectiveEnd = (r['period_end'] as String).compareTo(date) > 0 ? date : r['period_end'] as String;
      final args = <Object?>[r['period_start'], effectiveEnd];
      var categoryClause = '';
      if (categoryId != null) {
        categoryClause = 'AND s.category_id=?';
        args.add(categoryId);
      }
      final actual = _db.select(
        '''SELECT COALESCE(SUM(CASE WHEN t.type='EXPENSE' THEN s.amount_minor WHEN t.type='REFUND' THEN -s.amount_minor ELSE 0 END),0) AS v
           FROM transactions t JOIN transaction_splits s ON s.transaction_id=t.id
           WHERE t.status='POSTED' AND t.deleted_at IS NULL AND t.local_date>=? AND t.local_date<=? AND t.type IN ('EXPENSE','REFUND') $categoryClause''',
        args,
      ).first['v'] as int;
      result.add(BudgetModel(
        id: r['id'] as String,
        name: r['name'] as String,
        limitMinor: r['limit_minor'] as int,
        actualMinor: actual,
        start: DateTime.parse(r['period_start'] as String),
        end: DateTime.parse(r['period_end'] as String),
        categoryId: categoryId,
      ));
    }
    return result;
  }

  String _derivedUnpaidBillStatus(String dueDate, {DateTime? now}) {
    final today = _localDate(now ?? _clock());
    if (dueDate.compareTo(today) < 0) return 'OVERDUE';
    if (dueDate == today) return 'DUE';
    return 'UPCOMING';
  }

  bool _paymentFullyRefunded(dynamic db, String paymentTransactionId) {
    final paymentRows = db.select(
      "SELECT primary_amount_minor,status,deleted_at FROM transactions WHERE id=? LIMIT 1",
      [paymentTransactionId],
    );
    if (paymentRows.isEmpty) return true;
    final payment = paymentRows.first;
    if (payment['status'] != 'POSTED' || payment['deleted_at'] != null) return true;
    final refunded = db.select(
      "SELECT COALESCE(SUM(primary_amount_minor),0) AS total FROM transactions "
      "WHERE original_transaction_id=? AND type='REFUND' AND status='POSTED' AND deleted_at IS NULL",
      [paymentTransactionId],
    ).first['total'] as int;
    return refunded >= (payment['primary_amount_minor'] as int);
  }

  void _reconcileBillForPayment(dynamic db, String paymentTransactionId, {DateTime? now}) {
    final bills = db.select('SELECT id,due_date,status FROM bills WHERE paid_transaction_id=?', [paymentTransactionId]);
    if (bills.isEmpty) return;
    final fullyRefunded = _paymentFullyRefunded(db, paymentTransactionId);
    final stamp = _now();
    for (final bill in bills) {
      if (bill['status'] == 'SKIPPED') continue;
      final nextStatus = fullyRefunded
          ? _derivedUnpaidBillStatus(bill['due_date'] as String, now: now)
          : 'PAID';
      db.execute('UPDATE bills SET status=?,updated_at=? WHERE id=?', [nextStatus, stamp, bill['id']]);
    }
  }

  @override
  Future<String> createBill({required String name, required int expectedAmountMinor, required DateTime dueDate, String currency = 'IDR'}) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) throw ArgumentError('Nama tagihan wajib diisi.');
    _requirePositive(expectedAmountMinor, 'Nominal bill');
    _requireSupportedCurrency(currency);
    final id = _id();
    final now = _now();
    final dueDateKey = _localDate(dueDate);
    final initialStatus = _derivedUnpaidBillStatus(dueDateKey);
    _database.transaction((db) {
      db.execute('INSERT INTO bills(id,name,expected_amount_minor,currency,due_date,status,created_at,updated_at) VALUES (?,?,?,?,?,?,?,?)', [id, trimmedName, expectedAmountMinor, currency, dueDateKey, initialStatus, now, now]);
    });
    return id;
  }

  @override
  Future<void> markBillStatus(String billId, BillStatus status) async {
    if (status != BillStatus.skipped) {
      throw StateError('Status tagihan selain SKIPPED harus berasal dari tanggal jatuh tempo atau payBill().');
    }
    _database.transaction((db) {
      final rows = db.select('SELECT status,paid_transaction_id FROM bills WHERE id=?', [billId]);
      if (rows.isEmpty) throw StateError('Tagihan tidak ditemukan.');
      final current = rows.first;
      final paymentId = current['paid_transaction_id'] as String?;
      if (current['status'] == 'PAID' ||
          (paymentId != null && !_paymentFullyRefunded(db, paymentId))) {
        throw StateError('Tagihan dengan pembayaran aktif tidak boleh dilewati.');
      }
      db.execute('UPDATE bills SET status=?,updated_at=? WHERE id=?', [enumDbName(status), _now(), billId]);
    });
  }

  @override
  Future<String> payBill({required String billId, required int amountMinor, required String accountId, required String categoryId, required DateTime occurredAt}) async {
    _requirePositive(amountMinor, 'Nominal pembayaran');
    final billRows = _db.select('SELECT * FROM bills WHERE id=?', [billId]);
    if (billRows.isEmpty) throw StateError('Tagihan tidak ditemukan.');
    final bill = billRows.first;
    final account = _accountRow(accountId);
    final category = _categoryRow(categoryId);
    _requireActiveAccount(account);
    _requireCategoryType(category, CategoryType.expense);
    if (account['account_class'] == 'LIABILITY' && account['account_type'] != enumDbName(AccountType.creditCard)) {
      throw StateError('Pembayaran tagihan hanya boleh dari asset atau credit card.');
    }
    if (account['currency'] != bill['currency']) throw StateError('Currency pembayaran harus sama dengan tagihan.');
    final currency = bill['currency'] as String;
    late String txId;
    _database.transaction((db) {
      final latestBill = db.select('SELECT status,paid_transaction_id FROM bills WHERE id=?', [billId]);
      if (latestBill.isEmpty) throw StateError('Tagihan tidak ditemukan.');
      final previousPaymentId = latestBill.first['paid_transaction_id'] as String?;
      if (latestBill.first['status'] == 'PAID') {
        throw StateError('Tagihan sudah dibayar.');
      }
      if (previousPaymentId != null && !_paymentFullyRefunded(db, previousPaymentId)) {
        throw StateError('Tagihan masih mempunyai pembayaran aktif.');
      }
      txId = _insertTransaction(db,
        type: TransactionType.expense,
        status: TransactionStatus.posted,
        amountMinor: amountMinor,
        currency: currency,
        occurredAt: occurredAt,
        note: 'Pembayaran tagihan: ${bill['name']}',
      );
      final delta = account['account_class'] == 'ASSET' ? -amountMinor : amountMinor;
      _insertLeg(db, txId, accountId, delta, currency);
      _insertSplit(db, txId, categoryId, amountMinor, currency);
      db.execute('UPDATE bills SET status=?,paid_transaction_id=?,updated_at=? WHERE id=?', ['PAID', txId, _now(), billId]);
    });
    return txId;
  }

  @override
  Future<List<BillModel>> listBills({DateTime? now}) async {
    final current = now ?? _clock();
    final today = _localDate(current);
    final linkedPayments = _db.select("SELECT paid_transaction_id FROM bills WHERE paid_transaction_id IS NOT NULL AND status<>'SKIPPED'");
    for (final row in linkedPayments) {
      _reconcileBillForPayment(_db, row['paid_transaction_id'] as String, now: current);
    }
    // Reconcile derived unpaid status in both directions so a corrected device clock heals planning state.
    _db.execute("UPDATE bills SET status='UPCOMING',updated_at=? WHERE status IN ('DUE','OVERDUE') AND due_date > ?", [_now(), today]);
    _db.execute("UPDATE bills SET status='DUE',updated_at=? WHERE status IN ('UPCOMING','OVERDUE') AND due_date = ?", [_now(), today]);
    _db.execute("UPDATE bills SET status='OVERDUE',updated_at=? WHERE status IN ('UPCOMING','DUE') AND due_date < ?", [_now(), today]);
    final rows = _db.select("SELECT * FROM bills WHERE status NOT IN ('PAID','SKIPPED') ORDER BY due_date LIMIT 50");
    return rows.map((r) => BillModel(
      id: r['id'] as String,
      name: r['name'] as String,
      expectedAmountMinor: r['expected_amount_minor'] as int,
      currency: r['currency'] as String,
      dueDate: DateTime.parse(r['due_date'] as String),
      status: enumFromDb(r['status'] as String, BillStatus.values),
    )).toList();
  }

  @override
  Future<String> createRecurringExpenseDraft({required String name, required int amountMinor, required String accountId, required String categoryId, required int dayOfMonth, String currency = 'IDR'}) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) throw ArgumentError('Nama recurring wajib diisi.');
    _requirePositive(amountMinor, 'Nominal recurring');
    _requireSupportedCurrency(currency);
    if (dayOfMonth < 1 || dayOfMonth > 31) throw ArgumentError('Tanggal recurring harus 1–31.');
    final account = _accountRow(accountId);
    final category = _categoryRow(categoryId);
    _requireRecurringExpenseAccount(account);
    _requireCategoryType(category, CategoryType.expense);
    if (account['currency'] != currency) throw StateError('Currency recurring tidak sama dengan account.');
    final now = _clock();
    final nextRun = _nextMonthlyOccurrence(now, dayOfMonth, includeCurrentDay: true);
    final id = _id();
    final stamp = _now();
    _database.transaction((db) {
      db.execute('''INSERT INTO recurring_rules(id,name,mode,amount_minor,currency,account_id,category_id,day_of_month,next_run,active,version,created_at,updated_at)
        VALUES (?,?,?,?,?,?,?,?,?,1,1,?,?)''', [id, trimmedName, enumDbName(RecurringMode.autoCreateDraft), amountMinor, currency, accountId, categoryId, dayOfMonth, _localDate(nextRun), stamp, stamp]);
    });
    return id;
  }

  DateTime _nextMonthlyOccurrence(DateTime from, int day, {bool includeCurrentDay = false}) {
    DateTime occurrenceFor(int year, int month) {
      final last = DateTime(year, month + 1, 0).day;
      return DateTime(year, month, day > last ? last : day, 9);
    }
    var candidate = occurrenceFor(from.year, from.month);
    final dayStart = DateTime(from.year, from.month, from.day);
    if (candidate.isBefore(dayStart) || (!includeCurrentDay && candidate.year == from.year && candidate.month == from.month && candidate.day == from.day)) {
      candidate = occurrenceFor(from.year, from.month + 1);
    }
    return candidate;
  }

  @override
  Future<void> setRecurringActive(String recurringRuleId, bool active) async {
    final rows = _db.select('SELECT * FROM recurring_rules WHERE id=?', [recurringRuleId]);
    if (rows.isEmpty) throw StateError('Recurring rule tidak ditemukan.');
    if (active) {
      final account = _accountRow(rows.first['account_id'] as String);
      final category = _categoryRow(rows.first['category_id'] as String);
      _requireRecurringExpenseAccount(account);
      _requireCategoryType(category, CategoryType.expense);
    }
    _database.transaction((db) {
      db.execute('UPDATE recurring_rules SET active=?,updated_at=?,version=version+1 WHERE id=?', [active ? 1 : 0, _now(), recurringRuleId]);
    });
  }

  @override
  Future<List<RecurringRuleModel>> listRecurringRules() async {
    final rows = _db.select('SELECT * FROM recurring_rules ORDER BY active DESC,next_run');
    return rows.map((r) => RecurringRuleModel(
      id: r['id'] as String,
      name: r['name'] as String,
      mode: enumFromDb(r['mode'] as String, RecurringMode.values),
      amountMinor: r['amount_minor'] as int,
      currency: r['currency'] as String,
      nextRun: DateTime.parse(r['next_run'] as String),
      active: (r['active'] as int) == 1,
    )).toList();
  }

  @override
  Future<int> generateDueRecurring({DateTime? now}) async {
    final current = now ?? _clock();
    // Heal a recurring cursor that was pushed years ahead by a bad device clock.
    // Recurring rules in the current product do not support an intentional far-future start date,
    // so a cursor >2 months ahead is considered clock-drift state, not user intent.
    final futureRules = _db.select('SELECT id,day_of_month,next_run FROM recurring_rules WHERE active=1 AND next_run>?', [_localDate(current)]);
    for (final rule in futureRules) {
      final next = DateTime.parse(rule['next_run'] as String);
      final monthsAhead = (next.year - current.year) * 12 + (next.month - current.month);
      if (monthsAhead > 2) {
        final healed = _nextMonthlyOccurrence(DateTime(current.year, current.month, 1), rule['day_of_month'] as int, includeCurrentDay: true);
        _db.execute('UPDATE recurring_rules SET next_run=?,updated_at=? WHERE id=?', [_localDate(healed), _now(), rule['id']]);
      }
    }

    final rows = _db.select('SELECT * FROM recurring_rules WHERE active=1 AND next_run<=? ORDER BY next_run', [_localDate(current)]);
    var generated = 0;
    for (final r in rows) {
      final recurringAccount = _accountRow(r['account_id'] as String);
      final recurringCategory = _categoryRow(r['category_id'] as String);
      _requireRecurringExpenseAccount(recurringAccount);
      _requireCategoryType(recurringCategory, CategoryType.expense);
      if (recurringAccount['currency'] != r['currency']) {
        throw StateError('Recurring rule mempunyai currency yang tidak konsisten dengan account.');
      }
      var scheduled = DateTime.parse(r['next_run'] as String);
      final monthGap = (current.year - scheduled.year) * 12 + (current.month - scheduled.month);
      // A massive device-clock jump must not create years of synthetic drafts.
      // Recurring drafts are planning aids, not proof that historical spending occurred.
      if (monthGap > 24) {
        scheduled = _nextMonthlyOccurrence(
          DateTime(current.year, current.month, 1),
          r['day_of_month'] as int,
          includeCurrentDay: true,
        );
      }
      var safety = 0;
      while (!scheduled.isAfter(current) && safety < 24) {
        safety++;
        final occurrenceKey = '${r['id']}:${_localDate(scheduled)}';
        final existing = _db.select('SELECT id FROM recurring_occurrences WHERE rule_id=? AND occurrence_key=?', [r['id'], occurrenceKey]);
        if (existing.isEmpty) {
          final mode = enumFromDb(r['mode'] as String, RecurringMode.values);
          _database.transaction((db) {
            String? txId;
            if (mode != RecurringMode.reminderOnly) {
              txId = _insertTransaction(db,
                type: TransactionType.expense,
                // Recurring materialization is always a draft in the local-only safety model.
                // Balance changes only after the user explicitly posts the draft.
                status: TransactionStatus.draft,
                amountMinor: r['amount_minor'] as int,
                currency: r['currency'] as String,
                occurredAt: scheduled,
                note: 'Recurring: ${r['name']}',
              );
              final delta = recurringAccount['account_class'] == 'ASSET' ? -(r['amount_minor'] as int) : (r['amount_minor'] as int);
              _insertLeg(db, txId, r['account_id'] as String, delta, r['currency'] as String); // intended leg for DRAFT too
              _insertSplit(db, txId, r['category_id'] as String, r['amount_minor'] as int, r['currency'] as String);
            }
            db.execute('INSERT INTO recurring_occurrences(id,rule_id,occurrence_key,transaction_id,scheduled_for,created_at) VALUES (?,?,?,?,?,?)', [_id(), r['id'], occurrenceKey, txId, _iso(scheduled), _now()]);
          });
          generated++;
        }
        scheduled = _nextMonthlyOccurrence(DateTime(scheduled.year, scheduled.month, scheduled.day + 1), r['day_of_month'] as int, includeCurrentDay: true);
      }
      _db.execute('UPDATE recurring_rules SET next_run=?,updated_at=? WHERE id=?', [_localDate(scheduled), _now(), r['id']]);
    }
    return generated;
  }

  @override
  Future<void> archiveAccount(String accountId) async {
    final account = _accountRow(accountId);
    if (account['archived_at'] != null) return;
    final deps = _db.select('''SELECT
      (SELECT COUNT(*) FROM recurring_rules WHERE account_id=? AND active=1) AS recurring_count,
      (SELECT COUNT(*) FROM transaction_legs l JOIN transactions t ON t.id=l.transaction_id
       WHERE l.account_id=? AND t.status IN ('DRAFT','SCHEDULED') AND t.deleted_at IS NULL) AS draft_count,
      (SELECT COUNT(*) FROM transaction_legs l JOIN transactions t ON t.id=l.transaction_id
       WHERE l.account_id=? AND t.status='POSTED' AND t.deleted_at IS NULL AND t.local_date>?) AS future_posted_count''',
      [accountId, accountId, accountId, _localDate(_clock())]).first;
    if ((deps['recurring_count'] as int) > 0 || (deps['draft_count'] as int) > 0 || (deps['future_posted_count'] as int) > 0) {
      throw StateError('Account masih dipakai recurring/draft/transaksi masa depan. Selesaikan atau reassign terlebih dahulu.');
    }
    final balance = _accountBalance(accountId);
    if (balance != 0) {
      throw StateError('Account masih memiliki saldo. Pindahkan/rekonsiliasi saldo hingga 0 sebelum diarsipkan.');
    }
    _database.transaction((db) {
      final now = _now();
      db.execute('UPDATE accounts SET archived_at=?,updated_at=?,version=version+1 WHERE id=?', [now, now, accountId]);
    });
  }

  @override
  Future<void> archiveCategory(String categoryId) async {
    final category = _categoryRow(categoryId);
    if (category['archived_at'] != null) return;
    final deps = _db.select('''SELECT
      (SELECT COUNT(*) FROM recurring_rules WHERE category_id=? AND active=1) AS recurring_count,
      (SELECT COUNT(*) FROM budgets WHERE category_id=? AND archived_at IS NULL) AS budget_count,
      (SELECT COUNT(*) FROM transaction_splits s JOIN transactions t ON t.id=s.transaction_id
       WHERE s.category_id=? AND t.status IN ('DRAFT','SCHEDULED') AND t.deleted_at IS NULL) AS draft_count,
      (SELECT COUNT(*) FROM transaction_splits s JOIN transactions t ON t.id=s.transaction_id
       WHERE s.category_id=? AND t.status='POSTED' AND t.deleted_at IS NULL AND t.local_date>?) AS future_posted_count''',
      [categoryId, categoryId, categoryId, categoryId, _localDate(_clock())]).first;
    if ((deps['recurring_count'] as int) > 0 || (deps['budget_count'] as int) > 0 || (deps['draft_count'] as int) > 0 || (deps['future_posted_count'] as int) > 0) {
      throw StateError('Kategori masih dipakai budget/recurring/draft/transaksi masa depan. Reassign terlebih dahulu.');
    }
    _database.transaction((db) {
      final now = _now();
      db.execute('UPDATE categories SET archived_at=?,updated_at=?,version=version+1 WHERE id=?', [now, now, categoryId]);
    });
  }

  @override
  Future<Set<String>> existingImportFingerprints(Iterable<String> fingerprints) async {
    final unique = fingerprints.where((e) => e.isNotEmpty).toSet().toList(growable: false);
    if (unique.isEmpty) return <String>{};

    // Stay safely below SQLite bind-variable limits on older Android builds.
    final found = <String>{};
    const chunkSize = 400;
    for (var start = 0; start < unique.length; start += chunkSize) {
      final end = (start + chunkSize < unique.length) ? start + chunkSize : unique.length;
      final chunk = unique.sublist(start, end);
      final placeholders = List.filled(chunk.length, '?').join(',');
      final rows = _db.select(
        'SELECT fingerprint FROM import_fingerprints WHERE fingerprint IN ($placeholders)',
        chunk,
      );
      for (final row in rows) {
        found.add(row['fingerprint'] as String);
      }
    }
    return found;
  }

  @override
  Future<ImportCommitResult> importSimpleTransactionsAtomically(List<ImportTransactionDraft> rows) async {
    if (rows.isEmpty) {
      return const ImportCommitResult(imported: 0, skippedDuplicates: 0);
    }
    if (rows.length > 5000) {
      throw ArgumentError('Maksimal 5.000 transaksi per import.');
    }

    final seenFingerprints = <String>{};
    final seenSourceIds = <String>{};
    for (final row in rows) {
      if (!seenFingerprints.add(row.fingerprint)) {
        throw StateError('File import mengandung fingerprint duplikat internal.');
      }
      if (row.sourceTransactionId != null &&
          !seenSourceIds.add(row.sourceTransactionId!)) {
        throw StateError('File import mengandung Transaction ID duplikat.');
      }
      _requirePositive(row.amountMinor, 'Nominal import');
      if (row.type != TransactionType.expense &&
          row.type != TransactionType.income) {
        throw StateError('Import hanya menerima expense/income sederhana.');
      }
    }

    final accountsById = _rowsByIds('accounts', rows.map((r) => r.accountId));
    final categoriesById = _rowsByIds('categories', rows.map((r) => r.categoryId));
    for (final row in rows) {
      final account = accountsById[row.accountId];
      final category = categoriesById[row.categoryId];
      if (account == null) throw StateError('Account import tidak ditemukan.');
      if (category == null) throw StateError('Kategori import tidak ditemukan.');
      _requireActiveAccount(account);
      _requireSupportedCurrency(account['currency'] as String);

      if (row.type == TransactionType.expense) {
        _requireCategoryType(category, CategoryType.expense);
        if (account['account_class'] == 'LIABILITY' &&
            account['account_type'] != enumDbName(AccountType.creditCard)) {
          throw StateError('Expense ke liability non-credit-card tidak didukung.');
        }
      } else {
        _requireCategoryType(category, CategoryType.income);
        if (account['account_class'] != 'ASSET') {
          throw StateError('Income harus masuk asset account.');
        }
      }
    }

    final knownFingerprints = await existingImportFingerprints(seenFingerprints);
    final existingSourceRows = <String, Map<String, Object?>>{};
    final sourceIds = seenSourceIds.toList(growable: false);
    const sourceChunkSize = 300;
    for (var sourceStart = 0; sourceStart < sourceIds.length; sourceStart += sourceChunkSize) {
      final sourceEnd = (sourceStart + sourceChunkSize < sourceIds.length)
          ? sourceStart + sourceChunkSize
          : sourceIds.length;
      final chunk = sourceIds.sublist(sourceStart, sourceEnd);
      final placeholders = List.filled(chunk.length, '?').join(',');
      final existing = _db.select(
        '''SELECT t.id,t.type,t.status,t.primary_amount_minor,t.primary_currency,
                  t.occurred_at_utc,t.note,
                  (SELECT l.account_id FROM transaction_legs l
                   WHERE l.transaction_id=t.id ORDER BY l.rowid LIMIT 1) AS account_id,
                  (SELECT s.category_id FROM transaction_splits s
                   WHERE s.transaction_id=t.id ORDER BY s.rowid LIMIT 1) AS category_id
           FROM transactions t
           WHERE t.id IN ($placeholders)''',
        chunk,
      );
      for (final existingRow in existing) {
        existingSourceRows[existingRow['id'] as String] = Map<String, Object?>.from(existingRow);
      }
    }

    var imported = 0;
    var skipped = 0;

    _database.transaction((db) {
      for (final row in rows) {
        final sourceId = row.sourceTransactionId;
        if (sourceId != null) {
          final existing = existingSourceRows[sourceId];
          if (existing != null) {
            final same =
                existing['type'] == enumDbName(row.type) &&
                existing['status'] == enumDbName(TransactionStatus.posted) &&
                existing['primary_amount_minor'] == row.amountMinor &&
                existing['primary_currency'] == 'IDR' &&
                existing['account_id'] == row.accountId &&
                existing['category_id'] == row.categoryId &&
                (existing['note'] as String? ?? '') == (row.note ?? '') &&
                DateTime.parse(existing['occurred_at_utc'] as String)
                    .toUtc()
                    .isAtSameMomentAs(row.occurredAt.toUtc());
            if (!same) {
              throw StateError(
                'Transaction ID $sourceId sudah ada tetapi datanya berbeda.',
              );
            }
            skipped++;
            continue;
          }
        }

        if (knownFingerprints.contains(row.fingerprint)) {
          skipped++;
          continue;
        }

        final account = accountsById[row.accountId]!;
        final currency = account['currency'] as String;
        final txId = _insertTransaction(
          db,
          type: row.type,
          status: TransactionStatus.posted,
          amountMinor: row.amountMinor,
          currency: currency,
          occurredAt: row.occurredAt,
          note: row.note,
          idOverride: sourceId,
        );
        final delta = row.type == TransactionType.income
            ? row.amountMinor
            : (account['account_class'] == 'ASSET'
                ? -row.amountMinor
                : row.amountMinor);
        _insertLeg(db, txId, row.accountId, delta, currency);
        _insertSplit(db, txId, row.categoryId, row.amountMinor, currency);
        db.execute(
          'INSERT INTO import_fingerprints(fingerprint,transaction_id,created_at) VALUES (?,?,?)',
          [row.fingerprint, txId, _now()],
        );
        imported++;
      }
    });

    return ImportCommitResult(
      imported: imported,
      skippedDuplicates: skipped,
    );
  }

  Map<String, Map<String, Object?>> _rowsByIds(
    String table,
    Iterable<String> ids,
  ) {
    if (table != 'accounts' && table != 'categories') {
      throw ArgumentError('Unsupported lookup table.');
    }
    final unique = ids.toSet().toList(growable: false);
    final result = <String, Map<String, Object?>>{};
    const chunkSize = 400;
    for (var lookupStart = 0; lookupStart < unique.length; lookupStart += chunkSize) {
      final lookupEnd = (lookupStart + chunkSize < unique.length)
          ? lookupStart + chunkSize
          : unique.length;
      final chunk = unique.sublist(lookupStart, lookupEnd);
      final placeholders = List.filled(chunk.length, '?').join(',');
      final selected = _db.select('SELECT * FROM $table WHERE id IN ($placeholders)', chunk);
      for (final selectedRow in selected) {
        result[selectedRow['id'] as String] = Map<String, Object?>.from(selectedRow);
      }
    }
    return result;
  }

  @override
  Future<void> wipeLocalFinanceData() async {
    _database.transaction((db) {
      const tables = [
        'recurring_occurrences', 'recurring_rules', 'bills', 'budgets',
        'import_fingerprints', 'transaction_splits', 'transaction_legs', 'transactions',
        'transaction_groups', 'categories', 'accounts'
      ];
      for (final table in tables) {
        db.execute('DELETE FROM $table');
      }
    });
    _database.secureMaintenanceAfterWipe();
    await _seedDefaultsIfNeeded();
  }
}
