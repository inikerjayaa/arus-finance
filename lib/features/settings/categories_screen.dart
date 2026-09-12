import 'package:flutter/material.dart';

import '../../domain/enums.dart';
import '../../shared/app_scope.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(title: const Text('Kategori'), bottom: const TabBar(tabs: [Tab(text: 'Pengeluaran'), Tab(text: 'Pemasukan')])),
        body: TabBarView(children: [
          _CategoryList(type: CategoryType.expense, onAdd: () => _add(context, CategoryType.expense)),
          _CategoryList(type: CategoryType.income, onAdd: () => _add(context, CategoryType.income)),
        ]),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            final index = DefaultTabController.of(context).index;
            _add(context, index == 0 ? CategoryType.expense : CategoryType.income);
          },
          icon: const Icon(Icons.add),
          label: const Text('Kategori'),
        ),
      ),
    );
  }

  Future<void> _add(BuildContext context, CategoryType type) async {
    final c = AppScope.of(context);
    final input = TextEditingController();
    await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: Text(type == CategoryType.expense ? 'Kategori pengeluaran' : 'Kategori pemasukan'),
      content: TextField(controller: input, autofocus: true, decoration: const InputDecoration(labelText: 'Nama kategori')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
        FilledButton(onPressed: () async {
          final result = await c.run(() => c.repository.createCategory(name: input.text, type: type));
          if (ctx.mounted && result != null) Navigator.pop(ctx);
        }, child: const Text('Simpan')),
      ],
    ));
    input.dispose();
  }
}

class _CategoryList extends StatelessWidget {
  const _CategoryList({required this.type, required this.onAdd});
  final CategoryType type;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final list = type == CategoryType.expense ? c.expenseCategories : c.incomeCategories;
    if (list.isEmpty) return Center(child: FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('Tambah kategori')));
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 100),
      itemCount: list.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, index) {
        final category = list[index];
        return ListTile(
          leading: CircleAvatar(child: Icon(type == CategoryType.expense ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded)),
          title: Text(category.name),
          trailing: PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'archive') {
                final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                  title: const Text('Arsipkan kategori?'),
                  content: const Text('Histori transaksi tetap terhubung. Kategori tidak akan muncul lagi untuk transaksi baru.'),
                  actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Arsipkan'))],
                ));
                if (ok == true) await c.run(() => c.repository.archiveCategory(category.id));
              }
            },
            itemBuilder: (_) => const [PopupMenuItem(value: 'archive', child: Text('Arsipkan'))],
          ),
        );
      },
    );
  }
}
