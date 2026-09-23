import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/services/dashboard_preferences_service.dart';
import '../../core/services/user_profile_controller_access.dart';
import '../../core/services/user_profile_service.dart';
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
        padding: const EdgeInsets.fromLTRB(
          SakuBrand.pageInset,
          12,
          SakuBrand.pageInset,
          120,
        ),
        children: [
          Row(
            children: [
              Expanded(
                child: _HomeGreeting(profile: controller.userProfileService),
              ),
              IconButton(
                onPressed: _customize,
                icon: const Icon(Icons.dashboard_customize_outlined),
                tooltip: 'Atur dashboard',
              ),
              IconButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AppScope(
                      controller: controller,
                      child: DailyActivityScreen(initialDate: DateTime.now()),
                    ),
                  ),
                ),
                icon: const Icon(Icons.calendar_month_rounded),
                tooltip: 'Kalender aktivitas',
              ),
            ],
          ),
          const SizedBox(height: 18),
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
            value: Money.format(data.spendingTodayMinor, currency: data.currency),
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
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  TextButton(
                    onPressed: () => controller.setNavigation(1),
                    child: const Text('Lihat semua'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (recent.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Belum ada transaksi. Tekan + untuk mencatat pengeluaran pertama.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    child: Column(
                      children: recent
                          .map<Widget>(
                            (tx) => TransactionTile(
                              transaction: tx,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => AppScope(
                                    controller: controller,
                                    child: TransactionDetailScreen(transactionId: tx.id),
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
        if (widgets.isNotEmpty) widgets.add(const SizedBox(height: 16));
        widgets.add(content);
      }
    }
    return widgets;
  }

  Future<void> _customize() async {
    final result = await Navigator.of(context).push<List<DashboardWidgetConfig>>(
      MaterialPageRoute(
        builder: (_) => CustomizeDashboardScreen(service: _prefs, initial: _config!),
      ),
    );
    if (result != null && mounted) setState(() => _config = result);
  }
}

class _HomeGreeting extends StatelessWidget {
  const _HomeGreeting({required this.profile});

  final UserProfileService? profile;

  @override
  Widget build(BuildContext context) {
    final source = profile;
    if (source == null) return _text(context, null);
    return AnimatedBuilder(
      animation: source,
      builder: (context, _) => _text(context, source.name),
    );
  }

  Widget _text(BuildContext context, String? name) {
    final theme = Theme.of(context);
    return Semantics(
      header: true,
      child: Text(
        homeGreetingFor(DateTime.now(), name: name),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
          letterSpacing: -.1,
        ),
      ),
    );
  }
}

class _PrimaryFinanceHighlightCard extends StatelessWidget {
  const _PrimaryFinanceHighlightCard({
    required this.totalBalanceMinor,
    required this.incomeMinor,
    required this.spendingMinor,
    required this.currency,
  });

  final int totalBalanceMinor;
  final int incomeMinor;
  final int spendingMinor;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final background = dark ? const Color(0xFF073833) : SakuBrand.cyprus;
    final foreground = SakuBrand.onNoturno;
    final muted = SakuBrand.mutedOnNoturno;
    final incomeColor = dark ? const Color(0xFF8EDDB8) : const Color(0xFFB6E8CE);
    final spendingColor = dark ? const Color(0xFFFFA08A) : const Color(0xFFFFB39F);

    final totalLabel = Money.format(totalBalanceMinor, currency: currency);
    final incomeLabel = Money.format(incomeMinor, currency: currency);
    final spendingLabel = Money.format(spendingMinor, currency: currency);

    return Semantics(
      container: true,
      label: 'Total saldo $totalLabel, pemasukan bulan ini $incomeLabel, pengeluaran bulan ini $spendingLabel',
      child: ExcludeSemantics(
        child: Container(
          decoration: BoxDecoration(
            color: background,
            borderRadius: const BorderRadius.all(SakuBrand.cardRadius),
            border: Border.all(color: Colors.white.withValues(alpha: dark ? .08 : .10)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_balance_wallet_outlined, size: 18, color: SakuBrand.vulcanico),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Total saldo',
                        style: theme.textTheme.titleSmall?.copyWith(color: muted, fontWeight: FontWeight.w600),
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
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.55,
                  ),
                ),
                const SizedBox(height: 20),
                Container(height: 1, color: Colors.white.withValues(alpha: .12)),
                const SizedBox(height: 14),
                Text(
                  'Bulan ini',
                  style: theme.textTheme.labelMedium?.copyWith(color: muted, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final income = _HighlightMetric(
                      label: 'Pemasukan',
                      value: incomeLabel,
                      icon: Icons.south_west_rounded,
                      color: incomeColor,
                      foreground: foreground,
                      muted: muted,
                    );
                    final spending = _HighlightMetric(
                      label: 'Pengeluaran',
                      value: spendingLabel,
                      icon: Icons.north_east_rounded,
                      color: spendingColor,
                      foreground: foreground,
                      muted: muted,
                    );
                    if (constraints.maxWidth < 330) {
                      return Column(children: [income, const SizedBox(height: 12), spending]);
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [Expanded(child: income), const SizedBox(width: 18), Expanded(child: spending)],
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
    required this.muted,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color foreground;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelMedium?.copyWith(color: muted, fontWeight: FontWeight.w500)),
              const SizedBox(height: 3),
              Text(
                value,
                softWrap: true,
                style: theme.textTheme.titleSmall?.copyWith(color: foreground, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
