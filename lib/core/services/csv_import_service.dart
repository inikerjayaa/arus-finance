import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:csv/csv.dart';

import '../../domain/enums.dart';
import '../../domain/finance_repository.dart';
import '../../domain/models.dart';
import '../../domain/money_limits.dart';

class CsvImportPreviewRow {
  const CsvImportPreviewRow({
    required this.line,
    required this.type,
    required this.account,
    required this.category,
    required this.amountMinor,
    required this.valid,
    required this.duplicate,
    required this.note,
    this.error,
    this.draft,
  });

  final int line;
  final String type;
  final String account;
  final String category;
  final int? amountMinor;
  final bool valid;
  final bool duplicate;
  final String note;
  final String? error;
  final ImportTransactionDraft? draft;
}

class CsvImportPreview {
  const CsvImportPreview(this.rows);
  final List<CsvImportPreviewRow> rows;

  int get validCount => rows.where((r) => r.valid && !r.duplicate).length;
  int get duplicateCount => rows.where((r) => r.duplicate).length;
  int get errorCount => rows.where((r) => !r.valid).length;

  List<ImportTransactionDraft> get importable => rows
      .where((r) => r.valid && !r.duplicate && r.draft != null)
      .map((r) => r.draft!)
      .toList(growable: false);
}

class CsvImportService {
  CsvImportService(this.repository);
  final FinanceRepository repository;

  static const maxFileBytes = 10 * 1024 * 1024;
  static const maxRows = 5000;

  Future<CsvImportPreview> preview(File file) async {
    final size = await file.length();
    if (size <= 0) throw StateError('File CSV kosong.');
    if (size > maxFileBytes) throw StateError('File CSV terlalu besar. Maksimal 10 MB.');

    final text = await file.readAsString(encoding: utf8);
    final decoded = csv.decode(text);
    if (decoded.isEmpty) throw StateError('CSV tidak memiliki header.');

    final header = decoded.first.map((e) => e.toString().trim()).toList(growable: false);
    const required = [
      'Date',
      'Type',
      'Account',
      'Destination Account',
      'Category',
      'Amount Minor',
      'Currency',
      'Note',
      'Transaction ID',
    ];
    for (final column in required) {
      if (!header.contains(column)) {
        throw StateError('Format CSV tidak cocok. Kolom "$column" tidak ditemukan.');
      }
    }
    if (decoded.length - 1 > maxRows) {
      throw StateError('Maksimal 5.000 baris per import.');
    }

    int indexOf(String name) => header.indexOf(name);
    final accounts = await repository.listAccounts();
    final expenseCategories = await repository.listCategories(type: CategoryType.expense);
    final incomeCategories = await repository.listCategories(type: CategoryType.income);
    final accountsByName = {for (final a in accounts) a.name.trim().toLowerCase(): a};
    final expenseByName = {for (final c in expenseCategories) c.name.trim().toLowerCase(): c};
    final incomeByName = {for (final c in incomeCategories) c.name.trim().toLowerCase(): c};

    final seen = <String>{};
    final previewRows = <CsvImportPreviewRow>[];

    for (var i = 1; i < decoded.length; i++) {
      final row = decoded[i];
      String value(String column) {
        final index = indexOf(column);
        return index >= 0 && index < row.length ? row[index].toString().trim() : '';
      }

      final dateRaw = value('Date');
      final typeRaw = value('Type').toLowerCase();
      final accountRaw = value('Account');
      final destinationRaw = value('Destination Account');
      final categoryRaw = value('Category');
      final amountRaw = value('Amount Minor');
      final currency = value('Currency').toUpperCase();
      final note = value('Note');
      final transactionId = value('Transaction ID');

      String? error;
      DateTime? date;
      int? amount;
      TransactionType? type;

      if (destinationRaw.isNotEmpty) {
        error = 'Transfer belum didukung oleh import CSV aman.';
      }
      if (error == null) {
        try {
          date = DateTime.parse(dateRaw);
        } catch (_) {
          error = 'Tanggal tidak valid.';
        }
      }

      amount = int.tryParse(amountRaw);
      if (error == null && (amount == null || amount <= 0)) {
        error = 'Amount Minor harus integer > 0.';
      }
      if (error == null && amount! > kMaxMoneyMinor) {
        error = 'Amount Minor melebihi batas keamanan nominal aplikasi.';
      }
      if (error == null && currency != 'IDR') {
        error = 'Versi ini hanya mendukung IDR.';
      }
      if (error == null) {
        if (typeRaw == 'expense') type = TransactionType.expense;
        if (typeRaw == 'income') type = TransactionType.income;
        if (type == null) error = 'Import hanya mendukung expense/income sederhana.';
      }

      final account = accountsByName[accountRaw.toLowerCase()];
      if (error == null && account == null) {
        error = 'Account "$accountRaw" tidak ditemukan.';
      }
      final category = type == TransactionType.income
          ? incomeByName[categoryRaw.toLowerCase()]
          : expenseByName[categoryRaw.toLowerCase()];
      if (error == null && category == null) {
        error = 'Kategori "$categoryRaw" tidak ditemukan.';
      }

      // Transaction ID from Arus export is preferred for idempotency.
      // For other compatible CSVs, fall back to a canonical content hash.
      final identitySource = transactionId.isNotEmpty
          ? 'arus-id:$transactionId'
          : [
              date?.toUtc().toIso8601String() ?? dateRaw,
              typeRaw,
              accountRaw.trim().toLowerCase(),
              categoryRaw.trim().toLowerCase(),
              amountRaw,
              currency,
              note.trim(),
            ].join('|');
      final fingerprint = sha256.convert(utf8.encode(identitySource)).toString();
      final duplicate = !seen.add(fingerprint);

      ImportTransactionDraft? draft;
      if (error == null && !duplicate) {
        draft = ImportTransactionDraft(
          fingerprint: fingerprint,
          type: type!,
          amountMinor: amount!,
          accountId: account!.id,
          categoryId: category!.id,
          occurredAt: date!,
          note: note.isEmpty ? null : note,
          sourceTransactionId: transactionId.isEmpty ? null : transactionId,
        );
      }

      previewRows.add(CsvImportPreviewRow(
        line: i + 1,
        type: typeRaw,
        account: accountRaw,
        category: categoryRaw,
        amountMinor: amount,
        valid: error == null,
        duplicate: duplicate,
        note: note,
        error: error ?? (duplicate ? 'Duplikat di file yang sama.' : null),
        draft: draft,
      ));
    }

    // Check fingerprints in one batched repository lookup. This keeps preview honest
    // without issuing one SQL query per CSV row.
    final known = await repository.existingImportFingerprints(
      previewRows.where((r) => r.draft != null).map((r) => r.draft!.fingerprint),
    );
    if (known.isNotEmpty) {
      for (var i = 0; i < previewRows.length; i++) {
        final row = previewRows[i];
        final draft = row.draft;
        if (draft == null || !known.contains(draft.fingerprint)) continue;
        previewRows[i] = CsvImportPreviewRow(
          line: row.line,
          type: row.type,
          account: row.account,
          category: row.category,
          amountMinor: row.amountMinor,
          valid: true,
          duplicate: true,
          note: row.note,
          error: 'Transaksi ini sudah pernah di-import.',
          draft: null,
        );
      }
    }

    return CsvImportPreview(previewRows);
  }

  Future<ImportCommitResult> commit(CsvImportPreview preview) {
    return repository.importSimpleTransactionsAtomically(preview.importable);
  }
}
