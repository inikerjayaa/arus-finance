import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/enums.dart';
import '../../shared/money.dart';

class CategoryDonutSlice {
  const CategoryDonutSlice({
    required this.label,
    required this.amountMinor,
    required this.color,
    this.icon,
  });

  final String label;
  final int amountMinor;
  final Color color;
  final IconData? icon;
}

class CategoryDonutCard extends StatelessWidget {
  const CategoryDonutCard({
    super.key,
    required this.selectedType,
    required this.onTypeChanged,
    required this.netTotalMinor,
    required this.positiveTotalMinor,
    required this.refundOffsetMinor,
    required this.currency,
    required this.slices,
    this.maxNamedSlices = 5,
  });

  final CategoryType selectedType;
  final ValueChanged<CategoryType> onTypeChanged;
  final int netTotalMinor;
  final int positiveTotalMinor;
  final int refundOffsetMinor;
  final String currency;
  final List<CategoryDonutSlice> slices;
  final int maxNamedSlices;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visible = _collapseSlices(
      slices.where((slice) => slice.amountMinor > 0).toList(growable: false),
      maxNamedSlices: maxNamedSlices,
      otherColor: theme.colorScheme.outlineVariant,
    );
    final denominator = visible.fold<int>(
      0,
      (total, slice) => total + slice.amountMinor,
    );
    final title = selectedType == CategoryType.expense
        ? 'Komposisi Pengeluaran'
        : 'Komposisi Pemasukan';

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SegmentedButton<CategoryType>(
                  segments: const [
                    ButtonSegment(
                      value: CategoryType.expense,
                      label: Text('Keluar'),
                    ),
                    ButtonSegment(
                      value: CategoryType.income,
                      label: Text('Masuk'),
                    ),
                  ],
                  selected: {selectedType},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) {
                    if (selection.isNotEmpty) onTypeChanged(selection.first);
                  },
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Bulan ini',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            if (visible.isEmpty)
              _EmptyComposition(type: selectedType)
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 390;
                  final chart = _DonutVisual(
                    slices: visible,
                    totalMinor: netTotalMinor,
                    currency: currency,
                  );
                  final legend = _DonutLegend(
                    slices: visible,
                    denominator: denominator,
                    currency: currency,
                  );
                  if (compact) {
                    return Column(
                      children: [
                        chart,
                        const SizedBox(height: 18),
                        legend,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(width: 180, child: chart),
                      const SizedBox(width: 18),
                      Expanded(child: legend),
                    ],
                  );
                },
              ),
            if (refundOffsetMinor > 0) ...[
              const SizedBox(height: 14),
              Semantics(
                label:
                    'Refund bulan ini mengurangi pengeluaran sebesar ${Money.format(refundOffsetMinor, currency: currency)}',
                child: ExcludeSemantics(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.replay_rounded,
                          size: 20,
                          color: theme.colorScheme.onTertiaryContainer,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            'Refund bulan ini mengurangi total ${Money.format(refundOffsetMinor, currency: currency)}. Persentase chart dihitung dari kategori dengan nilai positif agar refund tidak digambar sebagai pengeluaran palsu.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onTertiaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            if (positiveTotalMinor > 0 &&
                positiveTotalMinor != denominator) ...[
              const SizedBox(height: 8),
              Text(
                'Komposisi ditampilkan dari kategori bernilai positif.',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static List<CategoryDonutSlice> _collapseSlices(
    List<CategoryDonutSlice> input, {
    required int maxNamedSlices,
    required Color otherColor,
  }) {
    final sorted = [...input]
      ..sort((a, b) => b.amountMinor.compareTo(a.amountMinor));
    if (sorted.length <= maxNamedSlices) return sorted;
    final named = sorted.take(maxNamedSlices).toList(growable: true);
    final otherAmount = sorted
        .skip(maxNamedSlices)
        .fold<int>(0, (total, slice) => total + slice.amountMinor);
    if (otherAmount > 0) {
      named.add(
        CategoryDonutSlice(
          label: 'Kategori lain',
          amountMinor: otherAmount,
          color: otherColor,
          icon: Icons.more_horiz_rounded,
        ),
      );
    }
    return named;
  }
}

class _DonutVisual extends StatelessWidget {
  const _DonutVisual({
    required this.slices,
    required this.totalMinor,
    required this.currency,
  });

  final List<CategoryDonutSlice> slices;
  final int totalMinor;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final semantics = slices
        .map((slice) => '${slice.label} ${Money.format(slice.amountMinor, currency: currency)}')
        .join(', ');
    return Semantics(
      image: true,
      label:
          'Diagram komposisi kategori. Total ${Money.format(totalMinor, currency: currency)}. $semantics',
      child: ExcludeSemantics(
        child: AspectRatio(
          aspectRatio: 1,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(painter: _DonutPainter(slices)),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(34),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          Money.format(totalMinor, currency: currency),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        Text(
                          'Total',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DonutLegend extends StatelessWidget {
  const _DonutLegend({
    required this.slices,
    required this.denominator,
    required this.currency,
  });

  final List<CategoryDonutSlice> slices;
  final int denominator;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        for (final slice in slices)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Semantics(
              label:
                  '${slice.label}, ${_percent(slice.amountMinor, denominator)} persen, ${Money.format(slice.amountMinor, currency: currency)}',
              child: ExcludeSemantics(
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: slice.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (slice.icon != null) ...[
                      Icon(slice.icon, size: 17, color: slice.color),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        slice.label,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_percent(slice.amountMinor, denominator)}%',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  static int _percent(int amount, int total) {
    if (total <= 0 || amount <= 0) return 0;
    return ((amount * 100) / total).round();
  }
}

class _EmptyComposition extends StatelessWidget {
  const _EmptyComposition({required this.type});

  final CategoryType type;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(
            Icons.donut_large_rounded,
            size: 38,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 10),
          Text(
            type == CategoryType.expense
                ? 'Belum ada pengeluaran bulan ini.'
                : 'Belum ada pemasukan bulan ini.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.slices);

  final List<CategoryDonutSlice> slices;

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold<int>(
      0,
      (sum, slice) => sum + math.max(0, slice.amountMinor),
    );
    if (total <= 0) return;

    final side = math.min(size.width, size.height);
    final stroke = side * .18;
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: (side - stroke) / 2,
    );
    var start = -math.pi / 2;
    for (final slice in slices) {
      if (slice.amountMinor <= 0) continue;
      final sweep = (slice.amountMinor / total) * math.pi * 2;
      final paint = Paint()
        ..color = slice.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    if (oldDelegate.slices.length != slices.length) return true;
    for (var i = 0; i < slices.length; i++) {
      final old = oldDelegate.slices[i];
      final current = slices[i];
      if (old.amountMinor != current.amountMinor || old.color != current.color) {
        return true;
      }
    }
    return false;
  }
}
