import 'package:flutter/services.dart';

/// Formats integer IDR input with Indonesian thousand separators while the
/// user types. This only changes presentation; canonical parsing and money
/// bounds remain enforced by the money parser and repository layer.
class IdrInputFormatter extends TextInputFormatter {
  const IdrInputFormatter({this.allowNegative = false});

  final bool allowNegative;

  static String formatDigits(String raw, {bool allowNegative = false}) {
    final negative = allowNegative && raw.trimLeft().startsWith('-');
    var digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return negative ? '-' : '';
    digits = digits.replaceFirst(RegExp(r'^0+(?=\d)'), '');

    final out = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      final remaining = digits.length - i;
      out.write(digits[i]);
      if (remaining > 1 && (remaining - 1) % 3 == 0) out.write('.');
    }
    return '${negative ? '-' : ''}$out';
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    final formatted = formatDigits(
      newValue.text,
      allowNegative: allowNegative,
    );
    if (formatted == '-' && !allowNegative) {
      return const TextEditingValue();
    }

    // Keep the caret at the same logical digit position for mid-number edits.
    final rawExtent = newValue.selection.extentOffset;
    final extent = rawExtent < 0
        ? 0
        : rawExtent > newValue.text.length
            ? newValue.text.length
            : rawExtent;
    final digitsToRight = RegExp(r'\d')
        .allMatches(newValue.text.substring(extent))
        .length;
    var caret = formatted.length;
    var seen = 0;
    for (var i = formatted.length - 1; i >= 0 && seen < digitsToRight; i--) {
      if (RegExp(r'\d').hasMatch(formatted[i])) seen++;
      caret = i;
    }
    if (digitsToRight == 0) caret = formatted.length;

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: caret),
    );
  }
}
