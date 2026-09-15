import 'package:shared_preferences/shared_preferences.dart';

class DashboardWidgetConfig {
  const DashboardWidgetConfig({
    required this.id,
    required this.label,
    required this.enabled,
  });

  final String id;
  final String label;
  final bool enabled;

  DashboardWidgetConfig copyWith({bool? enabled}) => DashboardWidgetConfig(
        id: id,
        label: label,
        enabled: enabled ?? this.enabled,
      );
}

class DashboardPreferencesService {
  static const _orderKey = 'dashboard_widget_order_v3';
  static const _hiddenKey = 'dashboard_widget_hidden_v3';
  static const _legacyOrderKey = 'dashboard_widget_order_v2';
  static const _legacyHiddenKey = 'dashboard_widget_hidden_v2';

  static const defaultOrder = <String>[
    'primary_summary',
    'category_breakdown',
    'spending_today',
    'net_worth',
    'largest_category',
    'recent_transactions',
  ];

  static const labels = <String, String>{
    'primary_summary': 'Ringkasan utama',
    'category_breakdown': 'Komposisi kategori',
    'spending_today': 'Pengeluaran hari ini',
    'net_worth': 'Net worth',
    'largest_category': 'Kategori terbesar',
    'recent_transactions': 'Transaksi terbaru',
  };

  static const _legacyPrimaryIds = <String>{
    'available',
    'spending_month',
    'income_month',
  };

  Future<List<DashboardWidgetConfig>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final hasV3 = prefs.containsKey(_orderKey) || prefs.containsKey(_hiddenKey);
    if (!hasV3 &&
        (prefs.containsKey(_legacyOrderKey) ||
            prefs.containsKey(_legacyHiddenKey))) {
      final migrated = _migrateLegacy(prefs);
      await save(migrated);
      return migrated;
    }

    final storedOrder = prefs.getStringList(_orderKey) ?? const <String>[];
    final hidden = (prefs.getStringList(_hiddenKey) ?? const <String>[]).toSet();
    return _normalize(storedOrder, hidden);
  }

  List<DashboardWidgetConfig> _migrateLegacy(SharedPreferences prefs) {
    final legacyOrder =
        prefs.getStringList(_legacyOrderKey) ?? const <String>[];
    final legacyHidden =
        (prefs.getStringList(_legacyHiddenKey) ?? const <String>[]).toSet();
    final order = <String>[];
    var primaryInserted = false;

    for (final id in legacyOrder) {
      if (_legacyPrimaryIds.contains(id)) {
        if (!primaryInserted) {
          order.add('primary_summary');
          primaryInserted = true;
        }
        continue;
      }
      if (labels.containsKey(id) && !order.contains(id)) order.add(id);
    }
    if (!primaryInserted) order.insert(0, 'primary_summary');

    final hidden = <String>{
      ...legacyHidden.where(labels.containsKey),
      if (_legacyPrimaryIds.every(legacyHidden.contains)) 'primary_summary',
    };
    return _normalize(order, hidden);
  }

  List<DashboardWidgetConfig> _normalize(
    List<String> storedOrder,
    Set<String> hidden,
  ) {
    final validStored = storedOrder.where(labels.containsKey).toList();
    final order = [...validStored];

    // For a truly fresh dashboard there is no user order to preserve, so use
    // the canonical default sequence exactly. Existing V3 users keep their
    // custom order; only the new composition widget is inserted next to the
    // primary summary when it has never been stored before.
    if (order.isEmpty) {
      order.addAll(defaultOrder);
    } else if (!order.contains('category_breakdown')) {
      final primaryIndex = order.indexOf('primary_summary');
      if (primaryIndex >= 0) {
        order.insert(primaryIndex + 1, 'category_breakdown');
      }
    }

    for (final id in defaultOrder) {
      if (!order.contains(id)) order.add(id);
    }

    return order
        .map(
          (id) => DashboardWidgetConfig(
            id: id,
            label: labels[id]!,
            enabled: !hidden.contains(id),
          ),
        )
        .toList();
  }

  Future<void> save(List<DashboardWidgetConfig> config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _orderKey,
      config.map((entry) => entry.id).toList(),
    );
    await prefs.setStringList(
      _hiddenKey,
      config.where((entry) => !entry.enabled).map((entry) => entry.id).toList(),
    );
  }

  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_orderKey);
    await prefs.remove(_hiddenKey);
    await prefs.remove(_legacyOrderKey);
    await prefs.remove(_legacyHiddenKey);
  }
}
