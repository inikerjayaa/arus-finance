import 'package:arus_finance/core/services/dashboard_preferences_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('dashboard defaults place primary summary then category composition', () async {
    final service = DashboardPreferencesService();
    final config = await service.load();

    expect(config.first.id, 'primary_summary');
    expect(config.first.label, 'Ringkasan utama');
    expect(config[1].id, 'category_breakdown');
    expect(config[1].label, 'Komposisi kategori');
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
    expect(config[1].id, 'category_breakdown');
    expect(
      config.firstWhere((entry) => entry.id == 'primary_summary').enabled,
      isTrue,
    );
    expect(config[2].id, 'recent_transactions');

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getStringList('dashboard_widget_order_v3'),
      contains('primary_summary'),
    );
    expect(
      prefs.getStringList('dashboard_widget_order_v3'),
      contains('category_breakdown'),
    );
  });

  test('existing v3 users receive category composition after primary', () async {
    SharedPreferences.setMockInitialValues({
      'dashboard_widget_order_v3': <String>[
        'recent_transactions',
        'primary_summary',
        'net_worth',
      ],
      'dashboard_widget_hidden_v3': <String>['net_worth'],
    });

    final config = await DashboardPreferencesService().load();
    expect(
      config.take(4).map((entry) => entry.id).toList(),
      <String>[
        'recent_transactions',
        'primary_summary',
        'category_breakdown',
        'net_worth',
      ],
    );
    expect(
      config.firstWhere((entry) => entry.id == 'net_worth').enabled,
      isFalse,
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

  test('v3 preferences preserve custom order and hidden widgets', () async {
    final service = DashboardPreferencesService();
    final initial = await service.load();
    final primary = initial.firstWhere((entry) => entry.id == 'primary_summary');
    final recent = initial.firstWhere((entry) => entry.id == 'recent_transactions');
    final rest = initial.where(
      (entry) => entry.id != 'primary_summary' && entry.id != 'recent_transactions',
    );

    await service.save([
      recent,
      primary.copyWith(enabled: false),
      ...rest,
    ]);

    final reloaded = await service.load();
    expect(reloaded.first.id, 'recent_transactions');
    expect(reloaded[1].id, 'primary_summary');
    expect(reloaded[1].enabled, isFalse);
  });
}
