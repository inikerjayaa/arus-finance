import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app_controller.dart';
import '../../domain/models.dart';
import '../../shared/app_scope.dart';
import '../../shared/finance_widgets.dart';
import '../../shared/money.dart';
import '../transactions/transaction_detail_screen.dart';
import 'daily_activity.dart';

class DailyActivityScreen extends StatefulWidget {
  const DailyActivityScreen({super.key, this.initialDate});

  final DateTime? initialDate;

  @override
  State<DailyActivityScreen> createState() => _DailyActivityScreenState();
}

class _DailyActivityScreenState extends State<DailyActivityScreen> {
  late DateTime _selectedDate;
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
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = AppScope.of(context);
    if (!identical(_controller, controller)) {
      _controller = controller;
      _loadMonth(_selectedDate);
    }
  }

  Future<void> _loadMonth(DateTime date) async {
    final controller = _controller;
    if (controller == null) return;
    final generation = ++_loadGeneration;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    final start = DateTime(date.year, date.month, 1);
    final end = DateTime(date.year, date.month + 1, 0);
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
    final summary = DailyActivityBuilder.build(_selectedDate, _monthTransactions);
    return Scaffold(
      appBar: AppBar(title: const Text('Aktivitas harian')),
      body: RefreshIndicator(
        onRefresh: () => _loadMonth(_selectedDate),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 120),
          children: [
            Semantics(
              header: true,
              child: Text(
                'Kalender SAKU',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Pilih tanggal untuk melihat uang yang keluar, masuk, dan aktivitas keuangan hari itu.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            Card(
              clipBehavior: Clip.antiAlias,
              child: CalendarDatePicker(
                initialDate: _selectedDate,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
                onDateChanged: (date) {
                  final monthChanged = date.year != _selectedDate.year ||
                      date.month != _selectedDate.month;
                  setState(() => _selectedDate = date);
                  if (monthChanged) _loadMonth(date);
                },
              ),
            ),
            if (_loading) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(minHeight: 2),
            ],
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
                        onPressed: () => _loadMonth(_selectedDate),
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
            _SummaryStrip(summary: summary),
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
                  '${summary.activities.length} item',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (!_loading && summary.activities.isEmpty)
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
            else if (summary.activities.isNotEmpty)
              Card(
                child: Column(
                  children: [
                    for (var i = 0; i < summary.activities.length; i++) ...[
                      TransactionTile(
                        transaction: summary.activities[i],
                        onTap: () => _openTransaction(summary.activities[i].id),
                      ),
                      if (i != summary.activities.length - 1)
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
    if (mounted) await _loadMonth(_selectedDate);
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.summary});

  final DailyActivitySummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final net = summary.netMinor;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _SummaryChip(
          label: 'Keluar',
          value: Money.format(summary.spendingMinor),
          icon: Icons.arrow_upward_rounded,
          color: theme.colorScheme.error,
        ),
        _SummaryChip(
          label: 'Masuk',
          value: Money.format(summary.incomingMinor),
          icon: Icons.arrow_downward_rounded,
          color: theme.colorScheme.primary,
        ),
        _SummaryChip(
          label: 'Net',
          value: '${net > 0 ? '+' : ''}${Money.format(net)}',
          icon: Icons.balance_rounded,
          color: net < 0
              ? theme.colorScheme.error
              : net > 0
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
        ),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelSmall),
              Text(
                value,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
