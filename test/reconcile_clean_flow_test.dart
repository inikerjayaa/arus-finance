import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('account reconciliation stays concise and auto-logs the adjustment', () {
    final source = File('lib/features/accounts/accounts_screen.dart')
        .readAsStringSync();

    expect(source, contains("'Sesuaikan saldo'"));
    expect(source, contains("'Saldo Saat Ini'"));
    expect(source, contains("labelText: 'Saldo Baru'"));
    expect(source, isNot(contains("labelText: 'Alasan penyesuaian'")));
    expect(source, contains('Penyesuaian saldo $accountName:'));
    expect(source, contains('amount != calculatedMinor'));
  });
}
