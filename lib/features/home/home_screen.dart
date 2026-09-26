import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/services/dashboard_preferences_service.dart';
import '../../domain/enums.dart';
import '../../domain/models.dart';
import '../../shared/app_scope.dart';
import '../../shared/finance_widgets.dart';
import '../../shared/money.dart';
import '../../shared/saku_brand.dart';
import '../activity/daily_activity_screen.dart';
import '../transactions/transaction_detail_screen.dart';
import 'customize_dashboard_screen.dart';
import 'home_category_composition_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _prefs = DashboardPreferencesService();
  List<DashboardWidgetConfig>? _config;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async { final value = await _prefs.load(); if (mounted) setState(() => _config = value); }

  @override Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final data = controller.dashboardData;
    final theme = Theme.of(context);
    if (data == null || _config == null) return const Center(child: CircularProgressIndicator());
    final recent = controller.recentTransactions;
    final enabled = _config!.where((entry) => entry.enabled).toList();
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(SakuBrand.pageInset, 14, SakuBrand.pageInset, 120),
        children: [
          _DashboardHeader(onCalendar: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AppScope(controller: controller, child: DailyActivityScreen(initialDate: DateTime.now())))), onCustomize: _customize),
          const SizedBox(height: 18),
          if (enabled.isEmpty)
            Card(child: Padding(padding: const EdgeInsets.all(22), child: Column(children: [const Icon(Icons.dashboard_customize_outlined, size: 36), const SizedBox(height: 10), const Text('Semua widget dashboard sedang disembunyikan.'), TextButton(onPressed: _customize, child: const Text('Atur dashboard'))])))
          else
            ..._buildWidgets(enabled, controller, data, recent, theme),
        ],
      ),
    );
  }

  List<Widget> _buildWidgets(List<DashboardWidgetConfig> config, AppController controller, DashboardData data, List<TransactionView> recent, ThemeData theme) {
    final widgets = <Widget>[];
    final total = controller.accounts.where((a) => a.accountClass == AccountClass.asset).fold<int>(0, (sum, a) => sum + a.balanceMinor);
    for (final item in config) {
      Widget? content;
      switch (item.id) {
        case 'primary_summary':
          content = _BalanceHero(totalBalanceMinor: total, incomeMinor: data.incomePeriodMinor, spendingMinor: data.spendingPeriodMinor, currency: data.currency);
          break;
        case 'category_breakdown': content = HomeCategoryCompositionCard(controller: controller, currency: data.currency, refreshMarker: data); break;
        case 'spending_today': content = MetricCard(label: 'Hari ini', value: Money.format(data.spendingTodayMinor, currency: data.currency), icon: Icons.today_outlined); break;
        case 'net_worth': content = MetricCard(label: 'Net worth', value: Money.format(data.netWorthMinor, currency: data.currency), icon: Icons.insights_outlined); break;
        case 'largest_category': content = data.largestCategory == null ? const MetricCard(label: 'Kategori terbesar', value: 'Belum ada pengeluaran', icon: Icons.donut_large_rounded) : MetricCard(label: 'Kategori terbesar', value: data.largestCategory!, caption: Money.format(data.largestCategoryAmountMinor, currency: data.currency), icon: Icons.donut_large_rounded); break;
        case 'recent_transactions':
          content = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [Expanded(child: Text('Transaksi Terbaru', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700))), TextButton(onPressed: () => controller.setNavigation(1), child: const Text('Lihat semua'))]),
            const SizedBox(height: 6),
            if (recent.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 18), child: Text('Belum ada transaksi. Tekan + untuk mencatat transaksi pertama.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)))
            else Card(clipBehavior: Clip.antiAlias, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), child: Column(children: recent.map((tx) => TransactionTile(transaction: tx, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AppScope(controller: controller, child: TransactionDetailScreen(transactionId: tx.id)))))).toList()))),
          ]);
          break;
      }
      if (content != null) { if (widgets.isNotEmpty) widgets.add(const SizedBox(height: 16)); widgets.add(content); }
    }
    return widgets;
  }

  Future<void> _customize() async { final result = await Navigator.of(context).push<List<DashboardWidgetConfig>>(MaterialPageRoute(builder: (_) => CustomizeDashboardScreen(service: _prefs, initial: _config!))); if (result != null && mounted) setState(() => _config = result); }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.onCalendar, required this.onCustomize});
  final VoidCallback onCalendar; final VoidCallback onCustomize;
  @override Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(children: [
      Expanded(child: Semantics(header: true, child: Text('S A K U', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 4, color: theme.colorScheme.onSurface)))),
      IconButton(onPressed: onCalendar, icon: const Icon(Icons.calendar_month_rounded), tooltip: 'Kalender aktivitas'),
      IconButton(onPressed: onCustomize, icon: const Icon(Icons.tune_rounded), tooltip: 'Atur dashboard'),
    ]);
  }
}

class _BalanceHero extends StatelessWidget {
  const _BalanceHero({required this.totalBalanceMinor, required this.incomeMinor, required this.spendingMinor, required this.currency});
  final int totalBalanceMinor; final int incomeMinor; final int spendingMinor; final String currency;
  @override Widget build(BuildContext context) {
    final theme = Theme.of(context); final dark = theme.brightness == Brightness.dark;
    final hero = dark ? const Color(0xFF082F2B) : SakuBrand.cyprus;
    final total = Money.format(totalBalanceMinor, currency: currency); final income = Money.format(incomeMinor, currency: currency); final spending = Money.format(spendingMinor, currency: currency);
    return Semantics(container: true, label: 'Total saldo $total. Pemasukan $income. Pengeluaran $spending.', child: ExcludeSemantics(child: Column(children: [
      Container(width: double.infinity, padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: hero, borderRadius: const BorderRadius.all(SakuBrand.cardRadius), border: Border.all(color: const Color(0xFF16A085).withValues(alpha: .55))), child: Stack(children: [
        Positioned(right: -34, bottom: -58, child: Transform.rotate(angle: -.45, child: Container(width: 190, height: 72, decoration: BoxDecoration(color: const Color(0xFF1AB394).withValues(alpha: .22), borderRadius: BorderRadius.circular(60))))),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Total Saldo', style: theme.textTheme.titleSmall?.copyWith(color: Colors.white70, fontWeight: FontWeight.w600)), const SizedBox(height: 10), Text(total, style: theme.textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700, letterSpacing: -.6)), const SizedBox(height: 8), Text('Semua akun aset', style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60))]),
      ])),
      const SizedBox(height: 14),
      Row(children: [Expanded(child: _FlowCard(label: 'Pemasukan', value: income, icon: Icons.south_west_rounded, positive: true)), const SizedBox(width: 12), Expanded(child: _FlowCard(label: 'Pengeluaran', value: spending, icon: Icons.north_east_rounded, positive: false))]),
    ])));
  }
}

class _FlowCard extends StatelessWidget {
  const _FlowCard({required this.label, required this.value, required this.icon, required this.positive});
  final String label; final String value; final IconData icon; final bool positive;
  @override Widget build(BuildContext context) { final theme = Theme.of(context); final accent = positive ? const Color(0xFF13A77B) : const Color(0xFFFF5A2A); return Card(child: Padding(padding: const EdgeInsets.all(15), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 36, height: 36, decoration: BoxDecoration(color: accent.withValues(alpha: .12), borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 18, color: accent)), const SizedBox(height: 10), Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)), const SizedBox(height: 3), Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700))]))); }
}
