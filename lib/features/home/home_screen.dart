import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/services/dashboard_preferences_service.dart';
import '../../domain/enums.dart';
import '../../domain/models.dart';
import '../../shared/app_scope.dart';
import '../../shared/finance_widgets.dart';
import '../../shared/money.dart';
import '../transactions/transaction_detail_screen.dart';
import 'customize_dashboard_screen.dart';
import 'home_category_composition_card.dart';

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
          child: const CircularProgressIndicator(),
        ),
      );
    }
    final recent = controller.recentTransactions;
    final enabled = _config!.where((entry) => entry.enabled).toList();

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
    AppController controller,
    DashboardData data,
    List<TransactionView> recent,
    ThemeData theme,
  ) {
    final widgets = <Widget>[];
    final totalAssetBalanceMinor = controller.accounts
        .where((account) => account.accountClass == AccountClass.asset)
        .fold<int>(0, (total, account) => total + account.balanceMinor);

    for (final item in config) {
      Widget? content;
      switch (item.id) {
        case 'primary_summary':
          content = _PrimaryFinanceHighlightCard(
            totalBalanceMinor: totalAssetBalanceMinor,
            availableBalanceMinor: data.availableBalanceMinor,
            incomeMinor: data.incomePeriodMinor,
            spendingMinor: data.spendingPeriodMinor,
            currency: data.currency,
          );
          break;
        case 'category_breakdown':
          content = HomeCategoryCompositionCard(
            controller: controller,
            currency: data.currency,
            refreshMarker: data,
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
                  value: data.largestCategory!,
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
        builder: (_) => CustomizeDashboardScreen(
          service: _prefs,
          initial: _config!,
        ),
      ),
    );
    if (result != null && mounted) setState(() => _config = result);
  }
}

class _PrimaryFinanceHighlightCard extends StatelessWidget {
  const _PrimaryFinanceHighlightCard({
    required this.totalBalanceMinor,
    required this.availableBalanceMinor,
    required this.incomeMinor,
    required this.spendingMinor,
    required this.currency,
  });

  final int totalBalanceMinor;
  final int availableBalanceMinor;
  final int incomeMinor;
  final int spendingMinor;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final backgroundStart =
        dark ? const Color(0xFF211A36) : const Color(0xFFF4EEFF);
    final backgroundEnd =
        dark ? const Color(0xFF2E2348) : const Color(0xFFE9E0FF);
    final border = dark ? const Color(0xFFA890FF) : const Color(0xFF7D5CE7);
    final foreground =
        dark ? const Color(0xFFF8F4FF) : const Color(0xFF2D1C55);
    final muted = dark ? const Color(0xFFCFC3EE) : const Color(0xFF66558C);
    final incomeColor =
        dark ? const Color(0xFF70E5AD) : const Color(0xFF167A52);
    final spendingColor =
        dark ? const Color(0xFFFF8996) : const Color(0xFFB93F51);

    final totalLabel = Money.format(totalBalanceMinor, currency: currency);
    final availableLabel =
        Money.format(availableBalanceMinor, currency: currency);
    final incomeLabel = Money.format(incomeMinor, currency: currency);
    final spendingLabel = Money.format(spendingMinor, currency: currency);

    return Semantics(
      container: true,
      label:
          'Total saldo $totalLabel, saldo tersedia $availableLabel, pemasukan bulan ini $incomeLabel, pengeluaran bulan ini $spendingLabel',
      child: ExcludeSemantics(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [backgroundStart, backgroundEnd],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: border, width: 1.4),
            boxShadow: [
              BoxShadow(
                blurRadius: 18,
                offset: const Offset(0, 8),
                color: border.withValues(alpha: dark ? .12 : .16),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet_rounded,
                      size: 19,
                      color: border,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Total Saldo',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  totalLabel,
                  softWrap: true,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.6,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Tersedia untuk dibelanjakan $availableLabel',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  height: 1,
                  color: border.withValues(alpha: .22),
                ),
                const SizedBox(height: 14),
                Text(
                  'Bulan ini',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final income = _HighlightMetric(
                      label: 'Pemasukan',
                      value: incomeLabel,
                      icon: Icons.arrow_downward_rounded,
                      color: incomeColor,
                      foreground: foreground,
                      surface: dark
                          ? Colors.white.withValues(alpha: .07)
                          : Colors.white.withValues(alpha: .62),
                    );
                    final spending = _HighlightMetric(
                      label: 'Pengeluaran',
                      value: spendingLabel,
                      icon: Icons.arrow_upward_rounded,
                      color: spendingColor,
                      foreground: foreground,
                      surface: dark
                          ? Colors.white.withValues(alpha: .07)
                          : Colors.white.withValues(alpha: .62),
                    );
                    if (constraints.maxWidth < 330) {
                      return Column(
                        children: [
                          income,
                          const SizedBox(height: 8),
                          spending,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: income),
                        const SizedBox(width: 10),
                        Expanded(child: spending),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HighlightMetric extends StatelessWidget {
  const _HighlightMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.foreground,
    required this.surface,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color foreground;
  final Color surface;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  softWrap: true,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
