import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app_controller.dart';
import '../../domain/enums.dart';
import '../../domain/models.dart';
import '../../shared/app_scope.dart';
import '../../shared/money.dart';
import '../transactions/transaction_detail_screen.dart';
import 'daily_activity.dart';

class DailyActivityScreen extends StatefulWidget {
  const DailyActivityScreen({super.key, DateTime? initialDate})
      : initialDate = initialDate;

  final DateTime? initialDate;

  @override
  State<DailyActivityScreen> createState() => _DailyActivityScreenState();
}

class _DailyActivityScreenState extends State<DailyActivityScreen> {
  late DateTime _selectedDate;
  late DateTime _visibleMonth;
  AppController? _controller;
  List<TransactionView> _monthTransactions = const [];
  bool _loading = true;
  String? _error;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialDate ?? DateTime.now();
    _selectedDate = DateTime(initial.year, initial.month, initial.day);
    _visibleMonth = DateTime(initial.year, initial.month);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = AppScope.of(context);
    if (!identical(_controller, controller)) {
      _controller = controller;
      _loadMonth();
    }
  }

  Future<void> _loadMonth() async {
    final controller = _controller;
    if (controller == null) return;
    final generation = ++_loadGeneration;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    final start = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final end = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0);
    try {
      final rows = await controller.repository.listTransactions(
        filter: TransactionFilter(startDate: start, endDate: end),
        limit: 5000,
      );
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _monthTransactions = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _loading = false;
        _error = e.toString()
            .replaceFirst('Bad state: ', '')
            .replaceFirst('Invalid argument(s): ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedSummary =
        DailyActivityBuilder.build(_selectedDate, _monthTransactions);

    return Scaffold(
      appBar: AppBar(title: const Text('Aktivitas harian')),
      body: RefreshIndicator(
        onRefresh: _loadMonth,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 120),
          children: [
            Semantics(
              header: true,
              child: Text(
                'Kalender Arus',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap tanggal untuk melihat apa yang keluar, masuk, dan bergerak pada hari itu.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            _MonthCalendar(
              month: _visibleMonth,
              selectedDate: _selectedDate,
              transactions: _monthTransactions,
              loading: _loading,
              onPrevious: () => _changeMonth(-1),
              onNext: () => _changeMonth(1),
              onDateSelected: (date) {
                setState(() => _selectedDate = date);
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Aktivitas belum dapat dimuat: $_error',
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _loadMonth,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Coba lagi'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            Text(
              DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(_selectedDate),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            _SummaryStrip(summary: selectedSummary),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Aktivitas',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${selectedSummary.activities.length} item',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (selectedSummary.activities.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    children: [
                      const Icon(Icons.event_available_rounded, size: 34),
                      const SizedBox(height: 8),
                      Text(
                        'Tidak ada aktivitas pada tanggal ini.',
                        style: theme.textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              Card(
                child: Column(
                  children: [
                    for (var i = 0;
                        i < selectedSummary.activities.length;
                        i++) ...[
                      _ActivityTile(
                        transaction: selectedSummary.activities[i],
                        onTap: () => _openTransaction(
                          selectedSummary.activities[i].id,
                        ),
                      ),
                      if (i != selectedSummary.activities.length - 1)
                        const Divider(height: 1),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _changeMonth(int delta) {
    final next = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + delta,
    );
    setState(() {
      _visibleMonth = next;
      _selectedDate = DateTime(next.year, next.month, 1);
      _monthTransactions = const [];
    });
    _loadMonth();
  }

  Future<void> _openTransaction(String transactionId) async {
    final controller = _controller;
    if (controller == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AppScope(
          controller: controller,
          child: TransactionDetailScreen(transactionId: transactionId),
        ),
      ),
    );
    if (mounted) await _loadMonth();
  }
}

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.month,
    required this.selectedDate,
    required this.transactions,
    required this.loading,
    required this.onPrevious,
    required this.onNext,
    required this.onDateSelected,
  });

  final DateTime month;
  final DateTime selectedDate;
  final List<TransactionView> transactions;
  final bool loading;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<DateTime> onDateSelected;

  static const _weekdayLabels = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = first.weekday - DateTime.monday;
    final cells = ((leading + daysInMonth + 6) ~/ 7) * 7;

    final summaries = <int, DailyActivitySummary>{};
    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(month.year, month.month, day);
      summaries[day] = DailyActivityBuilder.build(date, transactions);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 14),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: loading ? null : onPrevious,
                  icon: const Icon(Icons.chevron_left_rounded),
                  tooltip: 'Bulan sebelumnya',
                ),
                Expanded(
                  child: Text(
                    DateFormat('MMMM yyyy', 'id_ID').format(month),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: loading ? null : onNext,
                  icon: const Icon(Icons.chevron_right_rounded),
                  tooltip: 'Bulan berikutnya',
                ),
              ],
            ),
            const SizedBox(height: 4),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.05,
              children: [
                for (final label in _weekdayLabels)
                  Center(
                    child: Text(
                      label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                for (var index = 0; index < cells; index++)
                  _buildDateCell(
                    context,
                    index: index,
                    leading: leading,
                    daysInMonth: daysInMonth,
                    summaries: summaries,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                _LegendDot(
                  color: theme.colorScheme.error,
                  label: 'Keluar',
                ),
                _LegendDot(
                  color: theme.colorScheme.primary,
                  label: 'Masuk',
                ),
                _LegendDot(
                  color: theme.colorScheme.outline,
                  label: 'Aktivitas netral',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateCell(
    BuildContext context, {
    required int index,
    required int leading,
    required int daysInMonth,
    required Map<int, DailyActivitySummary> summaries,
  }) {
    final day = index - leading + 1;
    if (day < 1 || day > daysInMonth) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final date = DateTime(month.year, month.month, day);
    final selected = _sameDay(date, selectedDate);
    final today = _sameDay(date, DateTime.now());
    final summary = summaries[day]!;
    final hasNeutral = summary.neutralActivityCount > 0;

    return Semantics(
      button: true,
      selected: selected,
      label: _semanticDateLabel(date, summary),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => onDateSelected(date),
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: selected ? theme.colorScheme.primaryContainer : null,
            border: today && !selected
                ? Border.all(color: theme.colorScheme.primary)
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$day',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: selected || today ? FontWeight.w800 : null,
                  color: selected
                      ? theme.colorScheme.onPrimaryContainer
                      : null,
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 5,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (summary.spendingMinor > 0)
                      _TinyDot(color: theme.colorScheme.error),
                    if (summary.incomingMinor > 0)
                      _TinyDot(color: theme.colorScheme.primary),
                    if (hasNeutral)
                      _TinyDot(color: theme.colorScheme.outline),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _semanticDateLabel(
    DateTime date,
    DailyActivitySummary summary,
  ) {
    final parts = <String>[
      DateFormat('d MMMM yyyy', 'id_ID').format(date),
    ];
    if (summary.spendingMinor > 0) {
      parts.add('keluar ${Money.format(summary.spendingMinor)}');
    }
    if (summary.incomingMinor > 0) {
      parts.add('masuk ${Money.format(summary.incomingMinor)}');
    }
    if (summary.neutralActivityCount > 0) {
      parts.add('${summary.neutralActivityCount} aktivitas netral');
    }
    if (parts.length == 1) parts.add('tidak ada aktivitas');
    return parts.join(', ');
  }
}

class _TinyDot extends StatelessWidget {
  const _TinyDot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 5,
        height: 5,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TinyDot(color: color),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      );
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.summary});
  final DailyActivitySummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final net = summary.netMinor;
    final netColor = net < 0
        ? theme.colorScheme.error
        : net > 0
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 430;
        final cards = [
          _MiniSummary(
            label: 'Keluar',
            value: Money.format(summary.spendingMinor),
            icon: Icons.arrow_upward_rounded,
            color: theme.colorScheme.error,
          ),
          _MiniSummary(
            label: 'Masuk',
            value: Money.format(summary.incomingMinor),
            icon: Icons.arrow_downward_rounded,
            color: theme.colorScheme.primary,
          ),
          _MiniSummary(
            label: 'Net',
            value: '${net > 0 ? '+' : ''}${Money.format(net)}',
            icon: Icons.balance_rounded,
            color: netColor,
          ),
        ];
        if (compact) {
          return Column(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                cards[i],
                if (i != cards.length - 1) const SizedBox(height: 8),
              ],
            ],
          );
        }
        return Row(
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              Expanded(child: cards[i]),
              if (i != cards.length - 1) const SizedBox(width: 8),
            ],
          ],
        );
      },
    );
  }
}

class _MiniSummary extends StatelessWidget {
  const _MiniSummary({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
        label: '$label $value',
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        value,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: color,
                            ),
                        softWrap: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.transaction, required this.onTap});
  final TransactionView transaction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final presentation = _presentation(transaction, theme);
    final title = transaction.categoryName ??
        transaction.note ??
        _typeLabel(transaction.type);
    final subtitleParts = <String>[
      DateFormat('HH:mm').format(transaction.occurredAt.toLocal()),
      transaction.accountName,
      if (transaction.destinationAccountName != null)
        '→ ${transaction.destinationAccountName}',
      if (transaction.note != null && transaction.note != title)
        transaction.note!,
    ];

    return ListTile(
      onTap: onTap,
      minVerticalPadding: 10,
      leading: CircleAvatar(
        backgroundColor: presentation.color.withValues(alpha: .12),
        child: Icon(presentation.icon, color: presentation.color),
      ),
      title: Text(title),
      subtitle: Text(subtitleParts.join(' • ')),
      trailing: Text(
        '${presentation.prefix}${Money.format(transaction.amountMinor, currency: transaction.currency)}',
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w800,
          color: presentation.color,
        ),
      ),
    );
  }

  static ({IconData icon, Color color, String prefix}) _presentation(
    TransactionView tx,
    ThemeData theme,
  ) {
    switch (tx.type) {
      case TransactionType.expense:
        return (
          icon: Icons.arrow_upward_rounded,
          color: theme.colorScheme.error,
          prefix: '-',
        );
      case TransactionType.income:
      case TransactionType.refund:
        return (
          icon: Icons.arrow_downward_rounded,
          color: theme.colorScheme.primary,
          prefix: '+',
        );
      case TransactionType.transfer:
        return (
          icon: Icons.swap_horiz_rounded,
          color: theme.colorScheme.secondary,
          prefix: '',
        );
      case TransactionType.creditCardPayment:
        return (
          icon: Icons.credit_card_rounded,
          color: theme.colorScheme.secondary,
          prefix: '',
        );
      case TransactionType.loanDisbursement:
      case TransactionType.loanPayment:
        return (
          icon: Icons.request_quote_rounded,
          color: theme.colorScheme.secondary,
          prefix: '',
        );
      case TransactionType.adjustment:
        return (
          icon: Icons.tune_rounded,
          color: theme.colorScheme.secondary,
          prefix: '',
        );
      case TransactionType.openingBalance:
        return (
          icon: Icons.flag_rounded,
          color: theme.colorScheme.secondary,
          prefix: '',
        );
    }
  }

  static String _typeLabel(TransactionType type) {
    return switch (type) {
      TransactionType.expense => 'Pengeluaran',
      TransactionType.income => 'Pemasukan',
      TransactionType.transfer => 'Transfer',
      TransactionType.refund => 'Refund',
      TransactionType.adjustment => 'Penyesuaian',
      TransactionType.openingBalance => 'Saldo awal',
      TransactionType.creditCardPayment => 'Pembayaran kartu kredit',
      TransactionType.loanDisbursement => 'Pencairan pinjaman',
      TransactionType.loanPayment => 'Pembayaran pinjaman',
    };
  }
}
