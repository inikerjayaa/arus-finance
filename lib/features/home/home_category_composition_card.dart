import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/services/category_composition_controller_access.dart';
import '../../core/services/category_composition_service.dart';
import '../../core/services/visual_identity_controller_access.dart';
import '../../core/services/visual_identity_store.dart';
import '../../domain/enums.dart';
import '../../shared/icon_catalog.dart';
import '../../shared/visual_palette.dart';
import 'category_donut_card.dart';

class HomeCategoryCompositionCard extends StatefulWidget {
  const HomeCategoryCompositionCard({
    super.key,
    required this.controller,
    required this.currency,
    required this.refreshMarker,
  });

  final AppController controller;
  final String currency;

  /// A new marker means the controller has completed a new financial snapshot.
  /// Home passes DashboardData, whose identity changes on every full refresh.
  final Object refreshMarker;

  @override
  State<HomeCategoryCompositionCard> createState() =>
      _HomeCategoryCompositionCardState();
}

class _HomeCategoryCompositionCardState
    extends State<HomeCategoryCompositionCard> {
  CategoryType _selectedType = CategoryType.expense;
  late Future<_CompositionViewData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant HomeCategoryCompositionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller) ||
        !identical(oldWidget.refreshMarker, widget.refreshMarker)) {
      _future = _load();
    }
  }

  Future<_CompositionViewData> _load() async {
    final service = widget.controller.categoryCompositionService;
    if (service == null) {
      throw StateError('Layanan komposisi kategori belum tersedia.');
    }

    final composition = await service.month(_selectedType);
    final visuals = widget.controller.visualIdentityStore;
    final entries = <_CompositionVisualEntry>[];
    for (final entry in composition.chartEntries) {
      VisualIdentity identity;
      if (visuals == null) {
        identity = const VisualIdentity(
          iconKey: 'other.category',
          colorKey: 'slate',
        );
      } else {
        identity = await visuals.category(entry.categoryId) ??
            visuals.suggestCategory(entry.name, composition.type);
      }
      entries.add(
        _CompositionVisualEntry(
          label: entry.name,
          amountMinor: entry.amountMinor,
          identity: identity,
        ),
      );
    }

    return _CompositionViewData(
      composition: composition,
      entries: List.unmodifiable(entries),
    );
  }

  void _changeType(CategoryType type) {
    if (type == _selectedType) return;
    setState(() {
      _selectedType = type;
      _future = _load();
    });
  }

  void _retry() {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_CompositionViewData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Center(
                child: Semantics(
                  label: 'Memuat komposisi kategori',
                  liveRegion: true,
                  child: const CircularProgressIndicator(),
                ),
              ),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Komposisi kategori belum dapat dimuat.',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Data transaksi tetap aman. Coba muat ulang chart.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _retry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Muat ulang'),
                  ),
                ],
              ),
            ),
          );
        }

        final value = snapshot.data!;
        final brightness = Theme.of(context).brightness;
        final slices = value.entries
            .map(
              (entry) => CategoryDonutSlice(
                label: entry.label,
                amountMinor: entry.amountMinor,
                color: VisualPalette.fallbackFor(entry.identity.colorKey)
                    .resolve(brightness),
                icon: IconCatalog.fallbackFor(entry.identity.iconKey)
                    .fallbackIcon,
              ),
            )
            .toList(growable: false);

        return CategoryDonutCard(
          selectedType: _selectedType,
          onTypeChanged: _changeType,
          netTotalMinor: value.composition.netTotalMinor,
          positiveTotalMinor: value.composition.positiveTotalMinor,
          refundOffsetMinor: value.composition.negativeOffsetMinor,
          currency: widget.currency,
          slices: slices,
        );
      },
    );
  }
}

class _CompositionViewData {
  const _CompositionViewData({
    required this.composition,
    required this.entries,
  });

  final CategoryComposition composition;
  final List<_CompositionVisualEntry> entries;
}

class _CompositionVisualEntry {
  const _CompositionVisualEntry({
    required this.label,
    required this.amountMinor,
    required this.identity,
  });

  final String label;
  final int amountMinor;
  final VisualIdentity identity;
}
