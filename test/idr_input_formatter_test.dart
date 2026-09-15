import 'package:arus_finance/shared/idr_input_formatter.dart';
import 'package:arus_finance/shared/money.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IdrInputFormatter', () {
    test('groups Indonesian thousands without changing numeric value', () {
      expect(IdrInputFormatter.formatDigits('1'), '1');
      expect(IdrInputFormatter.formatDigits('1000'), '1.000');
      expect(IdrInputFormatter.formatDigits('1000000'), '1.000.000');
      expect(IdrInputFormatter.formatDigits('001000'), '1.000');
      expect(Money.parseIdr(IdrInputFormatter.formatDigits('1250000')), 1250000);
    });

    test('negative input is opt-in', () {
      expect(IdrInputFormatter.formatDigits('-1250'), '1.250');
      expect(
        IdrInputFormatter.formatDigits('-1250', allowNegative: true),
        '-1.250',
      );
    });

    test('formatEditUpdate keeps caret at end during normal typing', () {
      const formatter = IdrInputFormatter();
      final result = formatter.formatEditUpdate(
        const TextEditingValue(text: '999'),
        const TextEditingValue(
          text: '9999',
          selection: TextSelection.collapsed(offset: 4),
        ),
      );
      expect(result.text, '9.999');
      expect(result.selection.extentOffset, 5);
    });

    test('formatted value still respects canonical money parser', () {
      final formatted = IdrInputFormatter.formatDigits('999999999');
      expect(Money.parseIdr(formatted), 999999999);
    });
  });
}
