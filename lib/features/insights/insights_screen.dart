import 'package:flutter/material.dart';
import '../../shared/app_scope.dart';
import '../../shared/finance_widgets.dart';
import '../../shared/money.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final d = c.dashboardData;
    final theme = Theme.of(context);
    if (d == null) {
      return Center(
        child: Semantics(
          label: 'Memuat insight',
          liveRegion: true,
          child: CircularProgressIndicator(),
        ),
      );
    }
    final cashFlow = d.incomePeriodMinor - d.spendingPeriodMinor;
    final insight = d.spendingPeriodMinor == 0
        ? 'Belum cukup data pengeluaran bulan ini untuk membuat insight.'
        : d.largestCategory == null
          ? 'Pengeluaran sudah tercatat, tetapi belum ada kategori dominan.'
          : '${d.largestCategory} adalah kategori pengeluaran terbesar bulan ini sebesar ${Money.format(d.largestCategoryAmountMinor)}.';
    return ListView(padding: const EdgeInsets.fromLTRB(18, 14, 18, 120), children: [
      Semantics(header: true, child: Text('Insight', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800))),
      const SizedBox(height: 18),
      MetricCard(label: 'Cash flow bulan ini', value: Money.format(cashFlow), caption: 'Pemasukan − pengeluaran', icon: Icons.waterfall_chart_rounded),
      const SizedBox(height: 12),
      Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(Icons.lightbulb_outline, color: theme.colorScheme.primary), const SizedBox(width: 8), Text('Yang perlu diperhatikan', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))]),
        const SizedBox(height: 10), Text(insight),
      ]))),
      const SizedBox(height: 12),
      MetricCard(label: 'Net worth', value: Money.format(d.netWorthMinor), caption: 'Asset − liability. Transfer internal tidak mengubah nilai ini.', icon: Icons.balance_rounded),
    ]);
  }
}
