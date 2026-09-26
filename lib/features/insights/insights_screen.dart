import 'package:flutter/material.dart';

import '../../core/services/local_ai_preferences_controller_access.dart';
import '../../core/services/local_ai_preferences_service.dart';
import '../../core/services/local_insight_controller_access.dart';
import '../../core/services/local_insight_service.dart';
import '../../shared/app_scope.dart';
import '../../shared/finance_widgets.dart';
import '../../shared/money.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  Future<LocalInsight?>? _localInsight;
  Object? _controllerIdentity;
  LocalAiPreferencesService? _preferences;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = AppScope.of(context);
    if (!identical(_controllerIdentity, controller)) {
      _controllerIdentity = controller;
      _preferences?.removeListener(_preferenceChanged);
      _preferences = controller.localAiPreferencesService;
      _preferences?.addListener(_preferenceChanged);
      _refreshLocalInsight();
    }
  }

  @override
  void dispose() {
    _preferences?.removeListener(_preferenceChanged);
    super.dispose();
  }

  void _preferenceChanged() {
    if (!mounted) return;
    setState(_refreshLocalInsight);
  }

  void _refreshLocalInsight() {
    final controller = AppScope.of(context);
    if (_preferences?.enabled == true) {
      // Lazy by design: no local-ledger analysis runs during app startup.
      // Analysis starts only after the user opens Insights and leaves AI on.
      _localInsight = controller.localInsightService?.build();
    } else {
      _localInsight = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final d = c.dashboardData;
    final theme = Theme.of(context);
    if (d == null) {
      return const Center(
        child: Semantics(
          label: 'Memuat insight',
          liveRegion: true,
          child: CircularProgressIndicator(),
        ),
      );
    }
    final cashFlow = d.incomePeriodMinor - d.spendingPeriodMinor;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 120),
      children: [
        Semantics(
          header: true,
          child: Text(
            'Insight',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Dihitung di perangkatmu dari transaksi yang sudah tercatat. SAKU tidak mengubah transaksi dari sini.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 14),
        Card(
          child: SwitchListTile(
            key: const Key('local_ai_enabled_switch'),
            secondary: const Icon(Icons.auto_awesome_rounded),
            title: const Text('AI lokal SAKU'),
            subtitle: const Text(
              '100% di perangkat. Bisa dimatikan kapan saja dan tidak punya akses mengubah ledger.',
            ),
            value: _preferences?.enabled ?? false,
            onChanged: _preferences == null
                ? null
                : (value) async {
                    await _preferences!.setEnabled(value);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          value
                              ? 'AI lokal SAKU diaktifkan.'
                              : 'AI lokal SAKU dimatikan.',
                        ),
                      ),
                    );
                  },
          ),
        ),
        const SizedBox(height: 12),
        MetricCard(
          label: 'Cash flow bulan ini',
          value: Money.format(cashFlow),
          caption: 'Pemasukan − pengeluaran',
          icon: Icons.waterfall_chart_rounded,
        ),
        const SizedBox(height: 12),
        _LocalInsightCard(
          future: _localInsight,
          enabled: _preferences?.enabled ?? false,
        ),
        const SizedBox(height: 12),
        MetricCard(
          label: 'Net worth',
          value: Money.format(d.netWorthMinor),
          caption: 'Asset − liability. Transfer internal tidak mengubah nilai ini.',
          icon: Icons.balance_rounded,
        ),
      ],
    );
  }
}

class _LocalInsightCard extends StatelessWidget {
  const _LocalInsightCard({required this.future, required this.enabled});

  final Future<LocalInsight?>? future;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: !enabled
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome_outlined,
                          color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'AI lokal dimatikan',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tidak ada analisis lokal yang dijalankan. Data transaksi tetap tersimpan seperti biasa.',
                  ),
                ],
              )
            : FutureBuilder<LocalInsight?>(
                future: future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Semantics(
                      label: 'Menganalisis pola lokal',
                      liveRegion: true,
                      child: LinearProgressIndicator(),
                    );
                  }
                  final insight = snapshot.data;
                  final title =
                      insight?.title ?? 'Belum ada pola yang cukup kuat';
                  final message = insight?.message ??
                      'SAKU akan menampilkan insight setelah ada cukup bukti dari transaksi lokalmu. Tidak ada data yang dikirim ke server.';
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.auto_awesome_rounded,
                              color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Insight lokal',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        title,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(message),
                      const SizedBox(height: 10),
                      Text(
                        'Offline • hanya-baca • tanpa otoritas mengubah ledger',
                        style: theme.textTheme.labelSmall,
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}
