import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/finance_repository.dart';

class CsvExportService {
  CsvExportService(this.repository);

  final FinanceRepository repository;
  static final Csv _codec = Csv(lineDelimiter: '\n');

  Future<File> exportTransactions() async {
    final dir = await getTemporaryDirectory();
    final file = File(
      p.join(
        dir.path,
        'arus_transactions_${DateTime.now().millisecondsSinceEpoch}.csv',
      ),
    );
    final sink = file.openWrite(encoding: utf8);

    sink.write(_codec.encode([
      [
        'Date',
        'Type',
        'Account',
        'Destination Account',
        'Category',
        'Amount Minor',
        'Currency',
        'Note',
        'Transaction ID',
      ],
    ]));

    const pageSize = 500;
    var offset = 0;
    while (true) {
      final txs = await repository.listTransactions(
        limit: pageSize,
        offset: offset,
      );
      if (txs.isEmpty) break;

      final rows = txs
          .map((t) => [
                t.occurredAt.toUtc().toIso8601String(),
                t.type.name,
                t.accountName,
                t.destinationAccountName ?? '',
                t.categoryName ?? '',
                t.amountMinor,
                t.currency,
                t.note ?? '',
                t.id,
              ])
          .toList(growable: false);
      sink.write(_codec.encode(rows));

      offset += txs.length;
      if (txs.length < pageSize) break;
    }

    await sink.flush();
    await sink.close();
    return file;
  }
}
