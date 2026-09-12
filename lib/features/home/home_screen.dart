import 'package:flutter/material.dart';

import '../../core/services/dashboard_preferences_service.dart';
import '../../shared/app_scope.dart';
import '../../shared/finance_widgets.dart';
import '../../shared/money.dart';
import '../transactions/transaction_detail_screen.dart';
import 'customize_dashboard_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _prefs = DashboardPreferencesService();
  List<DashboardWidgetConfig>? _config;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final value = await _prefs.load();
    if (mounted) setState(() => _config = value);
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final data = controller.dashboardData;
    final theme = Theme.of(context);
    if (data == null || _config == null) {
      return Center(
        child: Semantics(
          label: 'Memuat dashboard',
          liveRegion: true,
          child: CircularProgressIndicator(),
        ),
      );
    }
    final recent = controller.recentTransactions;
    final enabled = _config!.where((e) => e.enabled).toList();

    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 120),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        'Ringkasan',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Keuanganmu hari ini',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _customize,
                icon: const Icon(Icons.dashboard_customize_outlined),
                tooltip: 'Atur dashboard',
              ),
              IconButton(
                onPressed: controller.refresh,
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Perbarui',
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (enabled.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  children: [
                    const Icon(Icons.dashboard_customize_outlined, size: 36),
                    const SizedBox(height: 10),
                    const Text('Semua widget dashboard sedang disembunyikan.'),
                    TextButton(
                      onPressed: _customize,
                      child: const Text('Atur dashboard'),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._buildWidgets(enabled, controller, data, recent, theme),
        ],
      ),
    );
  }

  List<Widget> _buildWidgets(
    List<DashboardWidgetConfig> config,
    dynamic controller,
    dynamic data,
    List<dynamic> recent,
    ThemeData theme,
  ) {
    final widgets = <Widget>[];
    for (final item in config) {
      Widget? content;
      switch (item.id) {
        case 'available':
          content = MetricCard(
            label: 'Saldo tersedia',
            value: Money.format(
              data.availableBalanceMinor,
              currency: data.currency,
            ),
            caption: 'Asset yang ditandai tersedia untuk dibelanjakan',
            icon: Icons.account_balance_wallet_outlined,
          );
          break;
        case 'spending_month':
          content = MetricCard(
            label: 'Pengeluaran bulan ini',
            value: Money.format(
              data.spendingPeriodMinor,
              currency: data.currency,
            ),
            icon: Icons.trending_down_rounded,
          );
          break;
        case 'spending_today':
          content = MetricCard(
            label: 'Hari ini',
            value: Money.format(
              data.spendingTodayMinor,
              currency: data.currency,
            ),
            icon: Icons.today_outlined,
          );
          break;
        case 'income_month':
          content = MetricCard(
            label: 'Pemasukan bulan ini',
            value: Money.format(
              data.incomePeriodMinor,
              currency: data.currency,
            ),
            icon: Icons.trending_up_rounded,
          );
          break;
        case 'net_worth':
          content = MetricCard(
            label: 'Net worth',
            value: Money.format(data.netWorthMinor, currency: data.currency),
            icon: Icons.insights_outlined,
          );
          break;
        case 'largest_category':
          content = data.largestCategory == null
              ? const MetricCard(
                  label: 'Kategori terbesar',
                  value: 'Belum ada pengeluaran',
                  icon: Icons.donut_large_rounded,
                )
              : MetricCard(
                  label: 'Kategori terbesar',
                  value: data.largestCategory,
                  caption: Money.format(
                    data.largestCategoryAmountMinor,
                    currency: data.currency,
                  ),
                  icon: Icons.donut_large_rounded,
                );
          break;
        case 'recent_transactions':
          content = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Transaksi terbaru',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => controller.setNavigation(1),
                    child: const Text('Lihat semua'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (recent.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Text(
                      'Belum ada transaksi. Tekan tombol + untuk mencatat pengeluaran pertama.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                )
              else
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    child: Column(
                      children: recent
                          .map<Widget>(
                            (tx) => TransactionTile(
                              transaction: tx,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => AppScope(
                                    controller: controller,
                                    child: TransactionDetailScreen(
                                      transactionId: tx.id,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
            ],
          );
          break;
      }
      if (content != null) {
        if (widgets.isNotEmpty) widgets.add(const SizedBox(height: 12));
        widgets.add(content);
      }
    }
    return widgets;
  }

  Future<void> _customize() async {
    final result = await Navigator.of(context)
        .push<List<DashboardWidgetConfig>>(
          MaterialPageRoute(
            builder: (_) =>
                CustomizeDashboardScreen(service: _prefs, initial: _config!),
          ),
        );
    if (result != null && mounted) setState(() => _config = result);
  }
}
