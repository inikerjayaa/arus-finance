import 'package:flutter/material.dart';

import '../../core/services/category_maintenance_controller_access.dart';
import '../../core/services/visual_identity_controller_access.dart';
import '../../core/services/visual_identity_store.dart';
import '../../domain/enums.dart';
import '../../domain/models.dart';
import '../../shared/app_scope.dart';
import '../../shared/icon_catalog.dart';
import '../../shared/icon_picker_sheet.dart';
import '../../shared/visual_palette.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Kategori'),
          bottom: const TabBar(
            tabs: [Tab(text: 'Pengeluaran'), Tab(text: 'Pemasukan')],
          ),
        ),
        body: TabBarView(
          children: [
            _CategoryList(
              type: CategoryType.expense,
              onAdd: () => _add(context, CategoryType.expense),
            ),
            _CategoryList(
              type: CategoryType.income,
              onAdd: () => _add(context, CategoryType.income),
            ),
          ],
        ),
        floatingActionButton: Builder(
          builder: (tabContext) => FloatingActionButton.extended(
            onPressed: () {
              final index = DefaultTabController.of(tabContext).index;
              _add(
                tabContext,
                index == 0 ? CategoryType.expense : CategoryType.income,
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Kategori'),
          ),
        ),
      ),
    );
  }

  Future<void> _add(BuildContext context, CategoryType type) async {
    final controller = AppScope.of(context);
    final visuals = controller.visualIdentityStore;
    final input = TextEditingController();
    var identity = visuals?.suggestCategory('', type) ??
        VisualIdentity(
          iconKey: type == CategoryType.income
              ? 'finance.salary'
              : 'other.category',
          colorKey: type == CategoryType.income ? 'green' : 'slate',
        );
    var customized = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final entry = IconCatalog.fallbackFor(identity.iconKey);
          final color = VisualPalette.fallbackFor(identity.colorKey)
              .resolve(Theme.of(dialogContext).brightness);
          return AlertDialog(
            title: Text(
              type == CategoryType.expense
                  ? 'Kategori pengeluaran'
                  : 'Kategori pemasukan',
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: input,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Nama kategori'),
                  onChanged: (value) {
                    if (visuals != null && !customized) {
                      setDialogState(
                        () => identity = visuals.suggestCategory(value, type),
                      );
                    }
                  },
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: color.withValues(alpha: .14),
                    foregroundColor: color,
                    child: Icon(entry.fallbackIcon),
                  ),
                  title: const Text('Ikon & warna'),
                  subtitle: Text(
                    '${entry.label} • ${VisualPalette.fallbackFor(identity.colorKey).label}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: visuals == null
                      ? null
                      : () async {
                          final picked = await IconPickerSheet.show(
                            dialogContext,
                            initial: identity,
                            suggestionText: input.text,
                          );
                          if (picked != null && dialogContext.mounted) {
                            setDialogState(() {
                              identity = picked;
                              customized = true;
                            });
                          }
                        },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: () async {
                  final id = await controller.run(
                    () => controller.repository.createCategory(
                      name: input.text,
                      type: type,
                    ),
                    refreshAfter: false,
                  );
                  if (id == null) return;

                  final warnings = <String>[];
                  if (visuals != null) {
                    try {
                      await visuals.setCategory(
                        categoryId: id,
                        iconKey: identity.iconKey,
                        colorKey: identity.colorKey,
                      );
                    } catch (_) {
                      warnings.add(
                        'Kategori tersimpan, tetapi ikon belum berhasil disimpan.',
                      );
                    }
                  }
                  try {
                    await controller.refresh();
                  } catch (_) {
                    warnings.add(
                      'Kategori sudah tersimpan. Muat ulang tampilan bila belum terlihat.',
                    );
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (warnings.isNotEmpty && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(warnings.join(' '))),
                    );
                  }
                },
                child: const Text('Simpan'),
              ),
            ],
          );
        },
      ),
    );
    input.dispose();
  }
}

class _CategoryList extends StatelessWidget {
  const _CategoryList({required this.type, required this.onAdd});

  final CategoryType type;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final list = type == CategoryType.expense
        ? controller.expenseCategories
        : controller.incomeCategories;
    if (list.isEmpty) {
      return Center(
        child: FilledButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: const Text('Tambah kategori'),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 100),
      itemCount: list.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, index) {
        final category = list[index];
        return ListTile(
          leading: _CategoryAvatar(category: category),
          title: Text(category.name),
          trailing: PopupMenuButton<String>(
            tooltip: 'Aksi kategori ${category.name}',
            onSelected: (value) async {
              if (value == 'rename') {
                await _rename(context, category);
              } else if (value == 'visual') {
                await _changeVisual(context, category);
              } else if (value == 'archive') {
                await _archive(context, category);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'rename',
                child: Text('Ubah nama'),
              ),
              PopupMenuItem(
                value: 'visual',
                child: Text('Ubah ikon & warna'),
              ),
              PopupMenuItem(value: 'archive', child: Text('Arsipkan')),
            ],
          ),
        );
      },
    );
  }

  Future<void> _rename(BuildContext context, Category category) async {
    final controller = AppScope.of(context);
    final maintenance = controller.categoryMaintenanceService;
    if (maintenance == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fitur ubah nama kategori belum tersedia.')),
      );
      return;
    }

    final input = TextEditingController(text: category.name);
    final formKey = GlobalKey<FormState>();
    final nextName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ubah nama kategori'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: input,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(labelText: 'Nama kategori'),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Nama kategori wajib diisi.'
                : null,
            onFieldSubmitted: (_) {
              if (formKey.currentState?.validate() == true) {
                Navigator.pop(ctx, input.text);
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() == true) {
                Navigator.pop(ctx, input.text);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    input.dispose();
    if (nextName == null || !context.mounted) return;

    await controller.run(
      () => maintenance.renameCategory(
        categoryId: category.id,
        name: nextName,
      ),
    );
  }

  Future<void> _changeVisual(BuildContext context, Category category) async {
    final controller = AppScope.of(context);
    final visuals = controller.visualIdentityStore;
    if (visuals == null) return;
    final current = await visuals.category(category.id) ??
        visuals.suggestCategory(category.name, category.type);
    if (!context.mounted) return;
    final picked = await IconPickerSheet.show(
      context,
      initial: current,
      suggestionText: category.name,
    );
    if (picked == null) return;
    try {
      await visuals.setCategory(
        categoryId: category.id,
        iconKey: picked.iconKey,
        colorKey: picked.colorKey,
      );
      await controller.refresh();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ikon belum tersimpan: $e')),
        );
      }
    }
  }

  Future<void> _archive(BuildContext context, Category category) async {
    final controller = AppScope.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Arsipkan kategori?'),
        content: const Text(
          'Histori transaksi tetap terhubung. Kategori tidak akan muncul lagi untuk transaksi baru.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Arsipkan'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await controller.run(
        () => controller.repository.archiveCategory(category.id),
      );
    }
  }
}

class _CategoryAvatar extends StatelessWidget {
  const _CategoryAvatar({required this.category});

  final Category category;

  @override
  Widget build(BuildContext context) {
    final visuals = AppScope.of(context).visualIdentityStore;
    if (visuals == null) {
      return CircleAvatar(
        child: Icon(
          category.type == CategoryType.expense
              ? Icons.arrow_upward_rounded
              : Icons.arrow_downward_rounded,
        ),
      );
    }
    return FutureBuilder<VisualIdentity?>(
      future: visuals.category(category.id),
      builder: (context, snapshot) {
        final identity = snapshot.data ??
            visuals.suggestCategory(category.name, category.type);
        final entry = IconCatalog.fallbackFor(identity.iconKey);
        final color = VisualPalette.fallbackFor(identity.colorKey)
            .resolve(Theme.of(context).brightness);
        return CircleAvatar(
          backgroundColor: color.withValues(alpha: .14),
          foregroundColor: color,
          child: Icon(entry.fallbackIcon),
        );
      },
    );
  }
}
