import 'package:flutter/material.dart';

import '../../core/services/dashboard_preferences_service.dart';

class CustomizeDashboardScreen extends StatefulWidget {
  const CustomizeDashboardScreen({
    super.key,
    required this.service,
    required this.initial,
  });
  final DashboardPreferencesService service;
  final List<DashboardWidgetConfig> initial;

  @override
  State<CustomizeDashboardScreen> createState() =>
      _CustomizeDashboardScreenState();
}

class _CustomizeDashboardScreenState extends State<CustomizeDashboardScreen> {
  late List<DashboardWidgetConfig> _items;

  @override
  void initState() {
    super.initState();
    _items = [...widget.initial];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Atur dashboard'),
        actions: [TextButton(onPressed: _reset, child: const Text('Reset'))],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
            child: Text(
              'Tampilkan hanya informasi yang penting untukmu. Tahan ikon drag untuk mengubah urutan.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 110),
              itemCount: _items.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex -= 1;
                  final item = _items.removeAt(oldIndex);
                  _items.insert(newIndex, item);
                });
              },
              itemBuilder: (context, index) {
                final item = _items[index];
                return Card(
                  key: ValueKey(item.id),
                  child: SwitchListTile(
                    value: item.enabled,
                    onChanged: (v) => setState(
                      () => _items[index] = item.copyWith(enabled: v),
                    ),
                    title: Text(item.label),
                    secondary: ReorderableDragStartListener(
                      index: index,
                      child: const Icon(Icons.drag_indicator_rounded),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _save,
        icon: const Icon(Icons.check),
        label: const Text('Simpan'),
      ),
    );
  }

  Future<void> _save() async {
    await widget.service.save(_items);
    if (mounted) Navigator.pop(context, _items);
  }

  Future<void> _reset() async {
    await widget.service.reset();
    final fresh = await widget.service.load();
    if (mounted) setState(() => _items = fresh);
  }
}
