import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/services/custom_icon_repository.dart';
import '../core/services/visual_identity_store.dart';
import 'brand_icon_catalog.dart';
import 'icon_catalog.dart';
import 'saku_icon_registry.dart';
import 'saku_visual_icon.dart';
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

enum _PickerMode { common, brand }

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
  SakuIconGroup? _brandGroup;
  _PickerMode _mode = _PickerMode.common;
  late String _iconKey;
  late String _colorKey;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _iconKey = widget.initial.iconKey;
    _colorKey = widget.initial.colorKey;
    _search.text = widget.suggestionText.trim();
    if (SakuIconRegistry.isBrandKey(_iconKey)) _mode = _PickerMode.brand;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _pickCustomIcon() async {
    if (_importing) return;
    setState(() => _importing = true);
    try {
      final picked = await FilePicker.pickFile(type: FileType.image);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final stored = await CustomIconRepository().save(bytes);
      if (!mounted) return;
      setState(() => _iconKey = stored.key);
    } on FormatException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal memakai ikon custom.')),
      );
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final commonEntries = _mode == _PickerMode.common
        ? IconCatalog.search(_search.text, group: _group, limit: 120)
        : const <IconCatalogEntry>[];
    final brandEntries = _mode == _PickerMode.brand
        ? SakuIconRegistry.search(
            _search.text,
            group: _brandGroup,
            limit: 160,
          )
        : const <SakuIconChoice>[];
    final selectedColor =
        VisualPalette.fallbackFor(_colorKey).resolve(brightness);
    final selectedLabel = SakuVisualIconResolver.labelFor(_iconKey);

    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: .92,
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
              SegmentedButton<_PickerMode>(
                segments: const [
                  ButtonSegment(
                    value: _PickerMode.common,
                    icon: Icon(Icons.category_rounded),
                    label: Text('Umum'),
                  ),
                  ButtonSegment(
                    value: _PickerMode.brand,
                    icon: Icon(Icons.apps_rounded),
                    label: Text('Brand'),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (value) => setState(() {
                  _mode = value.first;
                  _group = null;
                  _brandGroup = null;
                }),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _search,
                autofocus: false,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  labelText: 'Cari ikon',
                  hintText: 'BCA, DANA, ChatGPT, makanan…',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _importing ? null : _pickCustomIcon,
                icon: _importing
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_photo_alternate_rounded),
                label: Text(
                  _importing ? 'Memproses…' : 'Pakai gambar sendiri',
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 42,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _mode == _PickerMode.common
                      ? _commonGroupChips()
                      : _brandGroupChips(),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _mode == _PickerMode.common
                    ? _buildCommonGrid(commonEntries, theme)
                    : _buildBrandGrid(brandEntries, theme),
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
                        onSelected: (_) =>
                            setState(() => _colorKey = preset.key),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor:
                            selectedColor.withValues(alpha: .16),
                        foregroundColor: selectedColor,
                        child: SakuVisualIcon(
                          iconKey: _iconKey,
                          size: 24,
                          color: selectedColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selectedLabel,
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

  List<Widget> _commonGroupChips() => [
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
      ];

  List<Widget> _brandGroupChips() => [
        ChoiceChip(
          label: const Text('Semua'),
          selected: _brandGroup == null,
          onSelected: (_) => setState(() => _brandGroup = null),
        ),
        const SizedBox(width: 8),
        for (final group in SakuIconGroup.values) ...[
          ChoiceChip(
            label: Text(_brandGroupLabel(group)),
            selected: _brandGroup == group,
            onSelected: (_) => setState(() => _brandGroup = group),
          ),
          const SizedBox(width: 8),
        ],
      ];

  Widget _buildCommonGrid(
    List<IconCatalogEntry> entries,
    ThemeData theme,
  ) {
    if (entries.isEmpty) return _emptyState(theme);
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 112,
        mainAxisExtent: 100,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return _choiceTile(
          theme: theme,
          keyValue: entry.key,
          label: entry.label,
        );
      },
    );
  }

  Widget _buildBrandGrid(
    List<SakuIconChoice> entries,
    ThemeData theme,
  ) {
    if (entries.isEmpty) return _emptyState(theme);
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 112,
        mainAxisExtent: 100,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return _choiceTile(
          theme: theme,
          keyValue: entry.key,
          label: entry.label,
        );
      },
    );
  }

  Widget _choiceTile({
    required ThemeData theme,
    required String keyValue,
    required String label,
  }) {
    final isSelected = keyValue == _iconKey;
    return Semantics(
      button: true,
      selected: isSelected,
      label: 'Ikon $label',
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() => _iconKey = keyValue),
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
              SakuVisualIcon(
                iconKey: keyValue,
                size: 30,
                color: isSelected
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurface,
              ),
              const SizedBox(height: 6),
              Text(
                label,
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
  }

  Widget _emptyState(ThemeData theme) => Center(
        child: Text(
          'Ikon tidak ditemukan.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );

  String _groupLabel(IconCatalogGroup group) => switch (group) {
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

  String _brandGroupLabel(SakuIconGroup group) => switch (group) {
        SakuIconGroup.bank => 'Bank',
        SakuIconGroup.wallet => 'E-wallet',
        SakuIconGroup.transport => 'Transport',
        SakuIconGroup.marketplace => 'Belanja',
        SakuIconGroup.subscription => 'Subscription',
        SakuIconGroup.ai => 'AI',
        SakuIconGroup.telco => 'Telco',
        SakuIconGroup.utility => 'Tagihan',
        SakuIconGroup.generic => 'Generic',
      };
}
