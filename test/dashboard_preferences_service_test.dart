import 'package:arus_finance/core/services/dashboard_preferences_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('dashboard defaults place one primary summary first', () async {
    final service = DashboardPreferencesService();
    final config = await service.load();

    expect(config.first.id, 'primary_summary');
    expect(config.first.label, 'Ringkasan utama');
    expect(
      config.map((entry) => entry.id),
      isNot(contains('available')),
    );
    expect(
      config.map((entry) => entry.id),
      isNot(contains('spending_month')),
    );
    expect(
      config.map((entry) => entry.id),
      isNot(contains('income_month')),
    );
  });

  test('legacy v2 primary metrics migrate into one primary summary', () async {
    SharedPreferences.setMockInitialValues({
      'dashboard_widget_order_v2': <String>[
        'income_month',
        'recent_transactions',
        'available',
        'spending_month',
        'net_worth',
      ],
      'dashboard_widget_hidden_v2': <String>[
        'available',
        'income_month',
      ],
    });

    final service = DashboardPreferencesService();
    final config = await service.load();

    expect(
      config.where((entry) => entry.id == 'primary_summary'),
      hasLength(1),
    );
    expect(config.first.id, 'primary_summary');
    expect(
      config.firstWhere((entry) => entry.id == 'primary_summary').enabled,
      isTrue,
    );
    expect(config[1].id, 'recent_transactions');

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getStringList('dashboard_widget_order_v3'),
      contains('primary_summary'),
    );
  });

  test('legacy summary stays hidden only when all three old metrics were hidden',
      () async {
    SharedPreferences.setMockInitialValues({
      'dashboard_widget_order_v2': <String>[
        'available',
        'spending_month',
        'income_month',
      ],
      'dashboard_widget_hidden_v2': <String>[
        'available',
        'spending_month',
        'income_month',
      ],
    });

    final config = await DashboardPreferencesService().load();
    expect(
      config.firstWhere((entry) => entry.id == 'primary_summary').enabled,
      isFalse,
    );
  });
}
