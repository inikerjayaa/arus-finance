import 'package:flutter/material.dart';
import '../../domain/enums.dart';
import '../../shared/app_scope.dart';
import '../../shared/idr_input_formatter.dart';
import '../../shared/money.dart';

class PlanningScreen extends StatelessWidget {
  const PlanningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 120),
      children: [
        Semantics(header: true, child: Text('Rencana', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800))),
        const SizedBox(height: 18),
        _Header(title: 'Budget', action: 'Tambah', onTap: () => _addBudget(context)),
        const SizedBox(height: 8),
        if (c.budgets.isEmpty)
          const _Empty(text: 'Belum ada budget aktif.')
        else
          ...c.budgets.map((b) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(b.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
              Text('${(b.progress * 100).clamp(0, 999).toStringAsFixed(0)}%'),
              PopupMenuButton<String>(tooltip: 'Aksi budget ${b.name}', onSelected: (v) { if (v == 'archive') _archiveBudget(context, b.id, b.name); }, itemBuilder: (_) => const [PopupMenuItem(value: 'archive', child: Text('Arsipkan budget'))]),
            ]),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: b.progress.clamp(0.0, 1.0).toDouble()),
            const SizedBox(height: 10),
            Text('${Money.format(b.actualMinor)} dari ${Money.format(b.limitMinor)} • sisa ${Money.format(b.remainingMinor)}'),
            const SizedBox(height: 4),
            Text('Aman/hari ${Money.format(b.safePerDayMinor(DateTime.now()))}', style: theme.textTheme.bodySmall),
          ])))),
        const SizedBox(height: 24),
        _Header(title: 'Tagihan', action: 'Tambah', onTap: () => _addBill(context)),
        const SizedBox(height: 8),
        if (c.bills.isEmpty)
          const _Empty(text: 'Belum ada tagihan mendatang.')
        else
          ...c.bills.map((b) => Card(child: ListTile(
            title: Text(b.name),
            subtitle: Text('${b.dueDate.day}/${b.dueDate.month}/${b.dueDate.year} • ${b.status.name}\n${Money.format(b.expectedAmountMinor, currency: b.currency)}'),
            trailing: PopupMenuButton<String>(
              tooltip: 'Aksi tagihan ${b.name}',
              onSelected: (v) {
                if (v == 'paid') _payBill(context, b.id, b.name, b.expectedAmountMinor);
                if (v == 'skip') _skipBill(context, b.id, b.name);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'paid', child: Text('Tandai dibayar')),
                PopupMenuItem(value: 'skip', child: Text('Lewati')),
              ],
            ),
          ))),
        const SizedBox(height: 24),
        _Header(title: 'Transaksi rutin', action: 'Tambah', onTap: () => _addRecurring(context)),
        const SizedBox(height: 8),
        if (c.recurring.isEmpty)
          const _Empty(text: 'Belum ada transaksi rutin.')
        else
          ...c.recurring.map((r) => Card(child: SwitchListTile(
            title: Text(r.name),
            subtitle: Text('${r.mode.name} • berikutnya ${r.nextRun.day}/${r.nextRun.month}/${r.nextRun.year} • ${Money.format(r.amountMinor, currency: r.currency)}'),
            value: r.active,
            onChanged: (value) => c.run(() => c.repository.setRecurringActive(r.id, value)),
          ))),
      ],
    );
  }

  Future<void> _archiveBudget(BuildContext context, String budgetId, String name) async {
    final c = AppScope.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Arsipkan budget $name?'),
        content: const Text('Budget tidak akan tampil sebagai budget aktif. Histori transaksi tidak dihapus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Arsipkan')),
        ],
      ),
    );
    if (ok == true) await c.run(() => c.repository.archiveBudget(budgetId));
  }

  Future<void> _skipBill(BuildContext context, String billId, String name) async {
    final c = AppScope.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Lewati tagihan $name?'),
        content: const Text('Tagihan akan ditandai SKIPPED dan tidak dicatat sebagai pembayaran.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Lewati tagihan')),
        ],
      ),
    );
    if (ok == true) {
      await c.run(() => c.repository.markBillStatus(billId, BillStatus.skipped));
    }
  }

  Future<void> _addBudget(BuildContext context) async {
    final c = AppScope.of(context);
    final name = TextEditingController();
    final amount = TextEditingController();
    await showModalBottomSheet<void>(context: context, isScrollControlled: true, showDragHandle: true, builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(18, 4, 18, MediaQuery.viewInsetsOf(ctx).bottom + 18),
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Budget bulanan', style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 14),
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Nama')), const SizedBox(height: 12),
        TextField(controller: amount, keyboardType: TextInputType.number, inputFormatters: const [IdrInputFormatter()], decoration: const InputDecoration(labelText: 'Limit', prefixText: 'Rp ')), const SizedBox(height: 18),
        FilledButton(onPressed: () async {
          final now = DateTime.now();
          final result = await c.run(() => c.repository.createBudget(name: name.text, limitMinor: Money.parseIdr(amount.text) ?? 0, start: DateTime(now.year, now.month, 1), end: DateTime(now.year, now.month + 1, 0)));
          if (ctx.mounted && result != null) Navigator.pop(ctx);
        }, child: const Text('Simpan')),
      ])),
    ));
    name.dispose(); amount.dispose();
  }

  Future<void> _payBill(BuildContext context, String billId, String billName, int expectedMinor) async {
    final c = AppScope.of(context);
    final paymentAccounts = c.accounts.where((a) =>
      a.accountClass == AccountClass.asset || a.accountType == AccountType.creditCard
    ).toList();
    if (paymentAccounts.isEmpty || c.expenseCategories.isEmpty) return;
    final amount = TextEditingController(text: Money.input(expectedMinor));
    var accountId = paymentAccounts.first.id;
    var categoryId = c.expenseCategories.firstWhere((x) => x.name == 'Tagihan', orElse: () => c.expenseCategories.first).id;
    await showModalBottomSheet<void>(context: context, isScrollControlled: true, showDragHandle: true, builder: (ctx) => StatefulBuilder(builder: (context, setState) => Padding(
      padding: EdgeInsets.fromLTRB(18, 4, 18, MediaQuery.viewInsetsOf(ctx).bottom + 18),
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Bayar $billName', style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 14),
        TextField(controller: amount, keyboardType: TextInputType.number, inputFormatters: const [IdrInputFormatter()], decoration: const InputDecoration(labelText: 'Nominal aktual', prefixText: 'Rp ')), const SizedBox(height: 12),
        DropdownButtonFormField<String>(initialValue: accountId, decoration: const InputDecoration(labelText: 'Bayar dari'), items: paymentAccounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))).toList(), onChanged: (v) => setState(() => accountId = v ?? accountId)), const SizedBox(height: 12),
        DropdownButtonFormField<String>(initialValue: categoryId, decoration: const InputDecoration(labelText: 'Kategori'), items: c.expenseCategories.map((x) => DropdownMenuItem(value: x.id, child: Text(x.name))).toList(), onChanged: (v) => setState(() => categoryId = v ?? categoryId)), const SizedBox(height: 18),
        FilledButton(onPressed: () async {
          final parsed = Money.parseIdr(amount.text);
          if (parsed == null || parsed <= 0) return;
          final result = await c.run(() => c.repository.payBill(billId: billId, amountMinor: parsed, accountId: accountId, categoryId: categoryId, occurredAt: DateTime.now()));
          if (ctx.mounted && result != null) Navigator.pop(ctx);
        }, child: const Text('Catat pembayaran')),
      ])),
    )));
    amount.dispose();
  }

  Future<void> _addBill(BuildContext context) async {
    final c = AppScope.of(context);
    final name = TextEditingController();
    final amount = TextEditingController();
    var due = DateTime.now().add(const Duration(days: 7));
    await showModalBottomSheet<void>(context: context, isScrollControlled: true, showDragHandle: true, builder: (ctx) => StatefulBuilder(builder: (context, setState) => Padding(
      padding: EdgeInsets.fromLTRB(18, 4, 18, MediaQuery.viewInsetsOf(ctx).bottom + 18),
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Tambah tagihan', style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 14),
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Nama tagihan')), const SizedBox(height: 12),
        TextField(controller: amount, keyboardType: TextInputType.number, inputFormatters: const [IdrInputFormatter()], decoration: const InputDecoration(labelText: 'Nominal', prefixText: 'Rp ')), const SizedBox(height: 12),
        OutlinedButton.icon(onPressed: () async { final p = await showDatePicker(context: ctx, firstDate: DateTime.now(), lastDate: DateTime(2100), initialDate: due); if (p != null) setState(() => due = p); }, icon: const Icon(Icons.calendar_today), label: Text('Jatuh tempo ${due.day}/${due.month}/${due.year}')),
        const SizedBox(height: 18),
        FilledButton(onPressed: () async { final result = await c.run(() => c.repository.createBill(name: name.text, expectedAmountMinor: Money.parseIdr(amount.text) ?? 0, dueDate: due)); if (ctx.mounted && result != null) Navigator.pop(ctx); }, child: const Text('Simpan')),
      ])),
    )));
    name.dispose(); amount.dispose();
  }

  Future<void> _addRecurring(BuildContext context) async {
    final c = AppScope.of(context);
    final recurringAccounts = c.accounts.where((a) =>
      a.accountClass == AccountClass.asset || a.accountType == AccountType.creditCard
    ).toList();
    if (recurringAccounts.isEmpty || c.expenseCategories.isEmpty) return;
    final name = TextEditingController();
    final amount = TextEditingController();
    final day = TextEditingController(text: '${DateTime.now().day}');
    var accountId = recurringAccounts.first.id;
    var categoryId = c.expenseCategories.first.id;
    await showModalBottomSheet<void>(context: context, isScrollControlled: true, showDragHandle: true, builder: (ctx) => StatefulBuilder(builder: (context, setState) => Padding(
      padding: EdgeInsets.fromLTRB(18, 4, 18, MediaQuery.viewInsetsOf(ctx).bottom + 18),
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Transaksi rutin', style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 14),
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Nama')), const SizedBox(height: 12),
        TextField(controller: amount, keyboardType: TextInputType.number, inputFormatters: const [IdrInputFormatter()], decoration: const InputDecoration(labelText: 'Nominal', prefixText: 'Rp ')), const SizedBox(height: 12),
        DropdownButtonFormField(initialValue: accountId, decoration: const InputDecoration(labelText: 'Akun'), items: recurringAccounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))).toList(), onChanged: (v) => setState(() => accountId = v ?? accountId)), const SizedBox(height: 12),
        DropdownButtonFormField(initialValue: categoryId, decoration: const InputDecoration(labelText: 'Kategori'), items: c.expenseCategories.map((x) => DropdownMenuItem(value: x.id, child: Text(x.name))).toList(), onChanged: (v) => setState(() => categoryId = v ?? categoryId)), const SizedBox(height: 12),
        TextField(controller: day, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Tanggal tiap bulan (1–31)')), const SizedBox(height: 18),
        FilledButton(onPressed: () async { final result = await c.run(() => c.repository.createRecurringExpenseDraft(name: name.text, amountMinor: Money.parseIdr(amount.text) ?? 0, accountId: accountId, categoryId: categoryId, dayOfMonth: int.tryParse(day.text) ?? 1)); if (ctx.mounted && result != null) Navigator.pop(ctx); }, child: const Text('Simpan sebagai draft otomatis')),
      ])),
    )));
    name.dispose(); amount.dispose(); day.dispose();
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.action, required this.onTap});
  final String title; final String action; final VoidCallback onTap;
  @override Widget build(BuildContext context) => Row(children: [Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700))), TextButton.icon(onPressed: onTap, icon: const Icon(Icons.add, size: 18), label: Text(action))]);
}
class _Empty extends StatelessWidget { const _Empty({required this.text}); final String text; @override Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(18), child: Text(text))); }
