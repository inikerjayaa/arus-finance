import 'package:intl/intl.dart';

import '../domain/money_limits.dart';

class Money {
  static final NumberFormat _idr = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  static final NumberFormat _idrInput = NumberFormat.decimalPattern('id_ID');

  static String input(int minor) => _idrInput.format(minor);

  static String format(int minor, {String currency = 'IDR'}) {
    if (currency == 'IDR') return _idr.format(minor);
    final sign = minor < 0 ? '-' : '';
    final abs = minor.abs();
    return '$sign$currency ${NumberFormat('#,##0').format(abs)}';
  }

  static int? parseIdr(String raw) {
    var value = raw.trim();
    if (value.isEmpty) return null;
    value = value.replaceFirst(RegExp(r'^Rp\s*', caseSensitive: false), '').trim();
    final negative = value.startsWith('-');
    if (negative) value = value.substring(1).trim();
    if (!RegExp(r'^\d{1,3}([.]\d{3})*$|^\d+$').hasMatch(value)) return null;
    final parsed = int.tryParse(value.replaceAll('.', ''));
    if (parsed == null || parsed > kMaxMoneyMinor) return null;
    return negative ? -parsed : parsed;
  }
}
