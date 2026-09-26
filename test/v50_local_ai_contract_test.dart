import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('V50 local AI source contracts', () {
    test('AI remains user controlled and lazy on reachable Insights UI', () {
      final screen = File('lib/features/insights/insights_screen.dart').readAsStringSync();
      final prefs = File('lib/core/services/local_ai_preferences_service.dart').readAsStringSync();

      expect(screen, contains("Key('local_ai_enabled_switch')"));
      expect(screen, contains('AI lokal SAKU'));
      expect(screen, contains('_preferences?.enabled == true'));
      expect(screen, contains('controller.localInsightService?.build()'));
      expect(prefs, contains('SharedPreferences'));
      expect(prefs, contains('saku_local_ai_enabled'));
    });

    test('AI has no ledger mutation or network dependency', () {
      final insight = File('lib/core/services/local_insight_service.dart').readAsStringSync();
      final enhanced = File('lib/core/services/enhanced_local_insight_service.dart').readAsStringSync();
      final joined = '$insight\n$enhanced';

      expect(joined, isNot(contains('http://')));
      expect(joined, isNot(contains('https://')));
      expect(joined, isNot(contains('insert(')));
      expect(joined, isNot(contains('update(')));
      expect(joined, isNot(contains('delete(')));
      expect(joined, contains('readSnapshot'));
    });

    test('recurring expense detection is evidence bounded', () {
      final enhanced = File('lib/core/services/enhanced_local_insight_service.dart').readAsStringSync();

      expect(enhanced, contains('occurrences>=3'));
      expect(enhanced, contains('spanDays < 14'));
      expect(enhanced, contains('averageGap < 5 || averageGap > 45'));
      expect(enhanced, contains('recurring_expense_pattern'));
    });
  });
}
