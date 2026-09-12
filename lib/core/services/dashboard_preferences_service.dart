import 'package:shared_preferences/shared_preferences.dart';

class DashboardWidgetConfig {
  const DashboardWidgetConfig({required this.id, required this.label, required this.enabled});
  final String id;
  final String label;
  final bool enabled;

  DashboardWidgetConfig copyWith({bool? enabled}) => DashboardWidgetConfig(id: id, label: label, enabled: enabled ?? this.enabled);
}

class DashboardPreferencesService {
  static const _orderKey = 'dashboard_widget_order_v2';
  static const _hiddenKey = 'dashboard_widget_hidden_v2';

  static const defaultOrder = <String>[
    'available',
    'spending_month',
    'spending_today',
    'income_month',
    'net_worth',
    'largest_category',
    'recent_transactions',
  ];

  static const labels = <String, String>{
    'available': 'Saldo tersedia',
    'spending_month': 'Pengeluaran bulan ini',
    'spending_today': 'Pengeluaran hari ini',
    'income_month': 'Pemasukan bulan ini',
    'net_worth': 'Net worth',
    'largest_category': 'Kategori terbesar',
    'recent_transactions': 'Transaksi terbaru',
  };

  Future<List<DashboardWidgetConfig>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final storedOrder = prefs.getStringList(_orderKey) ?? const <String>[];
    final hidden = (prefs.getStringList(_hiddenKey) ?? const <String>[]).toSet();
    final validStored = storedOrder.where(labels.containsKey).toList();
    final missing = defaultOrder.where((id) => !validStored.contains(id));
    final order = [...validStored, ...missing];
    return order.map((id) => DashboardWidgetConfig(id: id, label: labels[id]!, enabled: !hidden.contains(id))).toList();
  }

  Future<void> save(List<DashboardWidgetConfig> config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_orderKey, config.map((e) => e.id).toList());
    await prefs.setStringList(_hiddenKey, config.where((e) => !e.enabled).map((e) => e.id).toList());
  }

  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_orderKey);
    await prefs.remove(_hiddenKey);
  }
}
