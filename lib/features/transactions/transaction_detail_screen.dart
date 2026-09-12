import 'package:flutter/material.dart';

import '../../domain/enums.dart';
import '../../domain/models.dart';
import '../../shared/app_scope.dart';
import '../../shared/money.dart';

class TransactionDetailScreen extends StatefulWidget {
  const TransactionDetailScreen({super.key, required this.transactionId});
  final String transactionId;

  @override
  State<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  TransactionDetail? _detail;
  String? _error;
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading && _detail == null) _load();
  }

  Future<void> _load() async {
    try {
      final detail = await AppScope.of(context).repository.getTransactionDetail(widget.transactionId);
      if (!mounted) return;
      setState(() { _detail = detail; _loading = false; _error = null; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: Semantics(
            label: 'Memuat detail transaksi',
            liveRegion: true,
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }
    if (_error != null || _detail == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detail transaksi')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error ?? 'Transaksi tidak ditemukan.',
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _loading = true;
                      _error = null;
                    });
                    _load();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Coba lagi'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final d = _detail!;
    final tx = d.view;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Detail transaksi'), actions: [
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') _edit();
            if (value == 'post') _postDraft();
            if (value == 'refund') _refund();
            if (value == 'void') _voidTransaction();
            if (value == 'delete') _delete();
          },
          itemBuilder: (_) => [
            if (d.canEditSimple) const PopupMenuItem(value: 'edit', child: Text('Edit')),
            if (tx.status == TransactionStatus.draft) const PopupMenuItem(value: 'post', child: Text('Catat sekarang')),
            if (d.canRefund) const PopupMenuItem(value: 'refund', child: Text('Buat refund')),
            if (tx.status == TransactionStatus.posted) const PopupMenuItem(value: 'void', child: Text('Batalkan (VOID)')),
            const PopupMenuItem(value: 'delete', child: Text('Hapus')),
          ],
        )
      ]),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 12, 18, 40), children: [
        Card(child: Padding(padding: const EdgeInsets.all(22), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_title(tx.type), style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Text(Money.format(tx.amountMinor, currency: tx.currency), style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800)),
          if (tx.childExpenseMinor > 0) ...[const SizedBox(height: 8), Text('Biaya terkait: ${Money.format(tx.childExpenseMinor, currency: tx.currency)}')],
        ]))),
        const SizedBox(height: 14),
        Card(child: Column(children: [
          _row('Tanggal', '${tx.occurredAt.day}/${tx.occurredAt.month}/${tx.occurredAt.year}'),
          const Divider(height: 1),
          _row('Account', tx.accountName),
          if (tx.destinationAccountName != null) ...[const Divider(height: 1), _row('Tujuan', tx.destinationAccountName!)],
          if (tx.categoryName != null) ...[const Divider(height: 1), _row('Kategori', tx.categoryName!)],
          const Divider(height: 1),
          _row('Status', tx.status.name),
          if (d.refundedMinor > 0) ...[const Divider(height: 1), _row('Sudah direfund', Money.format(d.refundedMinor, currency: tx.currency))],
          if (tx.note?.isNotEmpty == true) ...[const Divider(height: 1), _row('Catatan', tx.note!)],
        ])),
      ]),
    );
  }

  Widget _row(String label, String value) => ListTile(
        title: Text(label),
        subtitle: Text(value),
      );

  String _title(TransactionType type) => switch (type) {
    TransactionType.expense => 'Pengeluaran',
    TransactionType.income => 'Pemasukan',
    TransactionType.transfer => 'Transfer',
    TransactionType.refund => 'Refund',
    TransactionType.adjustment => 'Penyesuaian saldo',
    TransactionType.openingBalance => 'Saldo awal',
    TransactionType.creditCardPayment => 'Pembayaran kartu kredit',
    TransactionType.loanDisbursement => 'Pencairan pinjaman',
    TransactionType.loanPayment => 'Pembayaran pinjaman',
  };

  Future<void> _edit() async {
    final d = _detail!;
    final c = AppScope.of(context);
    final amount = TextEditingController(text: d.view.amountMinor.toString());
    final note = TextEditingController(text: d.view.note ?? '');
    var accountId = d.accountId;
    var categoryId = d.categoryId;
    var date = d.view.occurredAt;
    final categories = d.view.type == TransactionType.expense ? c.expenseCategories : c.incomeCategories;
    final accounts = d.view.type == TransactionType.income
        ? c.accounts.where((a) => a.accountClass == AccountClass.asset).toList()
        : c.accounts
            .where((a) =>
                a.accountClass == AccountClass.asset ||
                a.accountType == AccountType.creditCard)
            .toList();
    final saved = await showModalBottomSheet<bool>(context: context, isScrollControlled: true, showDragHandle: true, builder: (ctx) => StatefulBuilder(builder: (context, setState) => Padding(
      padding: EdgeInsets.fromLTRB(18, 4, 18, MediaQuery.viewInsetsOf(ctx).bottom + 18),
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Edit transaksi', style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 14),
        TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Nominal', prefixText: 'Rp ')), const SizedBox(height: 12),
        DropdownButtonFormField<String>(value: accountId, decoration: const InputDecoration(labelText: 'Account'), items: accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))).toList(), onChanged: (v) => setState(() => accountId = v)), const SizedBox(height: 12),
        DropdownButtonFormField<String>(value: categoryId, decoration: const InputDecoration(labelText: 'Kategori'), items: categories.map((x) => DropdownMenuItem(value: x.id, child: Text(x.name))).toList(), onChanged: (v) => setState(() => categoryId = v)), const SizedBox(height: 12),
        OutlinedButton.icon(onPressed: () async {
          final lastDate = d.view.status == TransactionStatus.posted ? DateTime.now() : DateTime(2100);
          final initialDate = date.isAfter(lastDate) ? lastDate : date;
          final p = await showDatePicker(context: ctx, firstDate: DateTime(2000), lastDate: lastDate, initialDate: initialDate);
          if (p != null) setState(() => date = DateTime(p.year,p.month,p.day,date.hour,date.minute));
        }, icon: const Icon(Icons.calendar_today), label: Text('${date.day}/${date.month}/${date.year}')), const SizedBox(height: 12),
        TextField(controller: note, maxLines: 2, decoration: const InputDecoration(labelText: 'Catatan')), const SizedBox(height: 18),
        FilledButton(onPressed: () async {
          final parsed = Money.parseIdr(amount.text);
          if (parsed == null || parsed <= 0 || accountId == null || categoryId == null) return;
          final result = await c.run(() => c.repository.updateSimpleTransaction(transactionId: widget.transactionId, amountMinor: parsed, accountId: accountId!, categoryId: categoryId!, occurredAt: date, note: note.text.trim().isEmpty ? null : note.text.trim()));
          if (ctx.mounted && c.errorMessage == null) Navigator.pop(ctx, true);
        }, child: const Text('Simpan perubahan')),
      ])),
    )));
    amount.dispose(); note.dispose();
    if (saved == true && mounted) await _load();
  }

  Future<void> _refund() async {
    final d = _detail!;
    final c = AppScope.of(context);
    final remaining = d.view.amountMinor - d.refundedMinor;
    final amount = TextEditingController(text: remaining.toString());
    var destinationId = d.accountId;
    final assetsAndCards = c.accounts.where((a) => a.accountClass == AccountClass.asset || a.accountType == AccountType.creditCard).toList();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (context, setState) => AlertDialog(
      title: const Text('Buat refund'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Maksimal ${Money.format(remaining, currency: d.view.currency)}'), const SizedBox(height: 12),
        TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Nominal refund', prefixText: 'Rp ')), const SizedBox(height: 12),
        DropdownButtonFormField<String>(value: destinationId, decoration: const InputDecoration(labelText: 'Refund masuk ke'), items: assetsAndCards.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))).toList(), onChanged: (v) => setState(() => destinationId = v)),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')), FilledButton(onPressed: () async {
        final parsed = Money.parseIdr(amount.text);
        if (parsed == null || parsed <= 0 || destinationId == null) return;
        final result = await c.run(() => c.repository.createRefund(originalTransactionId: widget.transactionId, amountMinor: parsed, destinationAccountId: destinationId!, occurredAt: DateTime.now()));
        if (ctx.mounted && result != null) Navigator.pop(ctx, true);
      }, child: const Text('Refund'))],
    )));
    amount.dispose();
    if (ok == true && mounted) await _load();
  }


  Future<void> _postDraft() async {
    final c = AppScope.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Catat draft sekarang?'),
        content: const Text(
          'Draft akan menjadi transaksi POSTED dan langsung memengaruhi saldo serta laporan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Catat sekarang'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await c.run(() => c.repository.postDraftTransaction(widget.transactionId));
    if (mounted && c.errorMessage == null) await _load();
  }

  Future<void> _voidTransaction() async {
    final c = AppScope.of(context);
    final input = TextEditingController();
    final reason = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Batalkan transaksi (VOID)?'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('VOID mengeluarkan efek transaksi dari saldo/laporan tetapi tetap menyimpan jejak transaksi.'),
        const SizedBox(height: 12),
        TextField(controller: input, autofocus: true, maxLines: 2, decoration: const InputDecoration(labelText: 'Alasan pembatalan')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
        FilledButton(onPressed: () => Navigator.pop(ctx, input.text), child: const Text('VOID')),
      ],
    ));
    input.dispose();
    if (reason == null) return;
    if (reason.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alasan VOID wajib diisi.')),
        );
      }
      return;
    }
    await c.run(() => c.repository.voidTransaction(widget.transactionId, reason: reason.trim()));
    if (mounted && c.errorMessage == null) await _load();
  }

  Future<void> _delete() async {
    final c = AppScope.of(context);
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Hapus transaksi permanen?'),
      content: const Text('Transaksi akan dihapus dari database lokal dan efeknya dikeluarkan dari saldo/laporan. Tindakan ini tidak dapat dibatalkan tanpa backup. Gunakan VOID bila jejak pembatalan perlu tetap terlihat.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(ctx).colorScheme.error,
            foregroundColor: Theme.of(ctx).colorScheme.onError,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Hapus permanen'),
        ),
      ],
    ));
    if (ok != true) return;
    await c.run(() => c.repository.deleteTransaction(widget.transactionId));
    if (!mounted) return;
    if (c.errorMessage == null) Navigator.pop(context);
  }
}
