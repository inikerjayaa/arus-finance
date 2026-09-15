import 'package:flutter/material.dart';

import '../core/services/visual_identity_store.dart';
import 'icon_catalog.dart';
import 'visual_palette.dart';

class IconPickerSheet {
  const IconPickerSheet._();

  static Future<VisualIdentity?> show(
    BuildContext context, {
    required VisualIdentity initial,
    String suggestionText = '',
  }) {
    return showModalBottomSheet<VisualIdentity>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _IconPickerBody(
        initial: initial,
        suggestionText: suggestionText,
      ),
    );
  }
}

class _IconPickerBody extends StatefulWidget {
  const _IconPickerBody({
    required this.initial,
    required this.suggestionText,
  });

  final VisualIdentity initial;
  final String suggestionText;

  @override
  State<_IconPickerBody> createState() => _IconPickerBodyState();
}

class _IconPickerBodyState extends State<_IconPickerBody> {
  final _search = TextEditingController();
  IconCatalogGroup? _group;
  late String _iconKey;
  late String _colorKey;

  @override
  void initState() {
    super.initState();
    _iconKey = widget.initial.iconKey;
    _colorKey = widget.initial.colorKey;
    _search.text = widget.suggestionText.trim();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final entries = IconCatalog.search(
      _search.text,
      group: _group,
      limit: 120,
    );
    final selected = IconCatalog.fallbackFor(_iconKey);
    final selectedColor = VisualPalette.fallbackFor(_colorKey).resolve(brightness);

    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: .9,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            0,
            18,
            MediaQuery.viewInsetsOf(context).bottom + 18,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Pilih ikon & warna',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _search,
                autofocus: false,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  labelText: 'Cari ikon',
                  hintText: 'BCA, makanan, Netflix, sepatu…',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 42,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    ChoiceChip(
                      label: const Text('Semua'),
                      selected: _group == null,
                      onSelected: (_) => setState(() => _group = null),
                    ),
                    const SizedBox(width: 8),
                    for (final group in IconCatalogGroup.values) ...[
                      ChoiceChip(
                        label: Text(_groupLabel(group)),
                        selected: _group == group,
                        onSelected: (_) => setState(() => _group = group),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: entries.isEmpty
                    ? Center(
                        child: Text(
                          'Ikon tidak ditemukan.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : GridView.builder(
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 112,
                          mainAxisExtent: 100,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: entries.length,
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          final isSelected = entry.key == _iconKey;
                          return Semantics(
                            button: true,
                            selected: isSelected,
                            label: 'Ikon ${entry.label}',
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => setState(() => _iconKey = entry.key),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 140),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  color: isSelected
                                      ? theme.colorScheme.primaryContainer
                                      : theme.colorScheme.surfaceContainerLow,
                                  border: Border.all(
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.outlineVariant,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      entry.fallbackIcon,
                                      size: 30,
                                      color: isSelected
                                          ? theme.colorScheme.onPrimaryContainer
                                          : theme.colorScheme.onSurface,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      entry.label,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.labelSmall,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 10),
              Text(
                'Warna',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final preset in VisualPalette.presets)
                    Tooltip(
                      message: preset.label,
                      child: ChoiceChip(
                        selected: preset.key == _colorKey,
                        label: const SizedBox(width: 18, height: 18),
                        avatar: CircleAvatar(
                          backgroundColor: preset.resolve(brightness),
                        ),
                        onSelected: (_) => setState(() => _colorKey = preset.key),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: selectedColor.withValues(alpha: .16),
                        foregroundColor: selectedColor,
                        child: Icon(selected.fallbackIcon),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selected.label,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              VisualPalette.fallbackFor(_colorKey).label,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(
                          VisualIdentity(
                            iconKey: _iconKey,
                            colorKey: _colorKey,
                          ),
                        ),
                        child: const Text('Pakai'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _groupLabel(IconCatalogGroup group) {
    return switch (group) {
      IconCatalogGroup.finance => 'Keuangan',
      IconCatalogGroup.bank => 'Bank',
      IconCatalogGroup.wallet => 'E-wallet',
      IconCatalogGroup.subscription => 'Subscription',
      IconCatalogGroup.food => 'Makanan',
      IconCatalogGroup.shopping => 'Belanja',
      IconCatalogGroup.transport => 'Transport',
      IconCatalogGroup.home => 'Rumah',
      IconCatalogGroup.health => 'Kesehatan',
      IconCatalogGroup.lifestyle => 'Lifestyle',
      IconCatalogGroup.other => 'Lainnya',
    };
  }
}
