import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/enums.dart';
import '../../domain/models.dart';

class ActivityCalendar extends StatelessWidget {
  const ActivityCalendar({
    super.key,
    required this.selectedDate,
    required this.transactions,
    required this.onDateChanged,
    required this.onMonthChanged,
  });

  final DateTime selectedDate;
  final List<TransactionView> transactions;
  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<DateTime> onMonthChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final month = DateTime(selectedDate.year, selectedDate.month);
    final firstWeekday = month.weekday;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final activityDays = <int>{};
    for (final tx in transactions) {
      if (tx.deleted || tx.status != TransactionStatus.posted) continue;
      if (tx.type == TransactionType.openingBalance) continue;
      final local = tx.occurredAt.toLocal();
      if (local.year == month.year && local.month == month.month) {
        activityDays.add(local.day);
      }
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Bulan sebelumnya',
                  onPressed: () => onMonthChanged(
                    DateTime(month.year, month.month - 1, 1),
                  ),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                    DateFormat('MMMM yyyy', 'id_ID').format(month),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Bulan berikutnya',
                  onPressed: () => onMonthChanged(
                    DateTime(month.year, month.month + 1, 1),
                  ),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                for (final label in const ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'])
                  Expanded(
                    child: Center(
                      child: Text(
                        label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1,
              ),
              itemCount: 42,
              itemBuilder: (context, index) {
                final day = index - (firstWeekday - 1) + 1;
                if (day < 1 || day > daysInMonth) {
                  return const SizedBox.shrink();
                }
                final date = DateTime(month.year, month.month, day);
                final selected = day == selectedDate.day;
                final hasActivity = activityDays.contains(day);
                final dateKey = '${date.year}-${date.month}-${date.day}';
                return Semantics(
                  key: ValueKey('activity-calendar-day-$dateKey'),
                  button: true,
                  selected: selected,
                  label: '${DateFormat('d MMMM yyyy', 'id_ID').format(date)}${hasActivity ? ', ada transaksi' : ''}',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => onDateChanged(date),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            alignment: Alignment.center,
                            decoration: selected
                                ? BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    shape: BoxShape.circle,
                                  )
                                : null,
                            child: Text(
                              '$day',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: selected
                                    ? theme.colorScheme.onPrimary
                                    : theme.colorScheme.onSurface,
                                fontWeight: selected ? FontWeight.w700 : null,
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 5,
                            child: hasActivity
                                ? Center(
                                    child: Container(
                                      key: ValueKey('activity-calendar-marker-$dateKey'),
                                      width: 4,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? theme.colorScheme.primary
                                            : theme.colorScheme.tertiary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
