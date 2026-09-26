import 'package:flutter/material.dart';

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = AppScope.of(context);
    if (!identical(_controllerIdentity, controller)) {
      _controllerIdentity = controller;
      // Lazy by design: no local-ledger analysis runs during application startup.
      // It is created only when the user actually opens the Insights route.
      _localInsight = controller.localInsightService?.build();
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
        const SizedBox(height: 18),
        MetricCard(
          label: 'Cash flow bulan ini',
          value: Money.format(cashFlow),
          caption: 'Pemasukan − pengeluaran',
          icon: Icons.waterfall_chart_rounded,
        ),
        const SizedBox(height: 12),
        _LocalInsightCard(future: _localInsight),
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
  const _LocalInsightCard({required this.future});

  final Future<LocalInsight?>? future;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: FutureBuilder<LocalInsight?>(
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
            final title = insight?.title ?? 'Belum ada pola yang cukup kuat';
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
                Text(title,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
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
