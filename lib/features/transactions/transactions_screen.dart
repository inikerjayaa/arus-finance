import 'package:flutter/material.dart';

import '../../domain/enums.dart';
import '../../domain/models.dart';
import '../../shared/app_scope.dart';
import '../../shared/finance_widgets.dart';
import '../../shared/idr_input_formatter.dart';
import '../../shared/money.dart';
import '../quick_add/quick_add_sheet.dart';
import 'transaction_detail_screen.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _search = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = AppScope.of(context);
    if (_search.text != controller.transactionQuery) {
      _search.text = controller.transactionQuery;
      _search.selection = TextSelection.collapsed(offset: _search.text.length);
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final theme = Theme.of(context);
    final active = controller.transactionFilter.isActive || controller.transactionQuery.isNotEmpty;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Semantics(header: true, child: Text('Transaksi', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)))),
            Badge(
              isLabelVisible: controller.transactionFilter.isActive,
              child: IconButton(
                tooltip: 'Filter transaksi',
                onPressed: () => _showFilters(context),
                icon: const Icon(Icons.tune_rounded),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Cari nominal, kategori, akun, catatan',
              suffixIcon: _search.text.isEmpty ? null : IconButton(
                tooltip: 'Hapus pencarian',
                icon: const Icon(Icons.close),
                onPressed: () async {
                  _search.clear();
                  await controller.refreshTransactions(query: '');
                  if (mounted) setState(() {});
                },
              ),
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (value) => controller.refreshTransactions(query: value),
          ),
          if (active) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 6, children: [
              if (controller.transactionQuery.isNotEmpty)
                Chip(label: Text('Cari: ${controller.transactionQuery}')),
              ..._filterChips(controller.transactionFilter),
              ActionChip(
                avatar: const Icon(Icons.restart_alt, size: 18),
                label: const Text('Reset'),
                onPressed: () async {
                  _search.clear();
                  await controller.clearTransactionFilters();
                  if (mounted) setState(() {});
                },
              ),
            ]),
          ],
        ]),
      ),
      Expanded(
        child: RefreshIndicator(
          onRefresh: controller.refreshTransactions,
          child: controller.transactions.isEmpty
              ? ListView(children: [
                  const SizedBox(height: 120),
                  Icon(active ? Icons.filter_alt_off_outlined : Icons.receipt_long_outlined, size: 44, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(height: 12),
                  Center(child: Text(active ? 'Tidak ada transaksi yang cocok.' : 'Belum ada transaksi.')),
                  if (active)
                    Center(child: TextButton(onPressed: () async {
                      _search.clear();
                      await controller.clearTransactionFilters();
                      if (mounted) setState(() {});
                    }, child: const Text('Hapus filter')))
                  else
                    Center(
                      child: FilledButton.icon(
                        onPressed: () => QuickAddSheet.show(context, controller),
                        icon: const Icon(Icons.add),
                        label: const Text('Catat transaksi pertama'),
                      ),
                    ),
                ])
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 120),
                  itemCount: controller.transactions.length + (controller.hasMoreTransactions ? 1 : 0),
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    if (index == controller.transactions.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: OutlinedButton.icon(
                          onPressed: controller.loadingMoreTransactions
                              ? null
                              : controller.loadMoreTransactions,
                          icon: controller.loadingMoreTransactions
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.expand_more),
                          label: Text(controller.loadingMoreTransactions
                              ? 'Memuat…'
                              : 'Muat transaksi lebih lama'),
                        )),
                      );
                    }
                    final tx = controller.transactions[index];
                    return TransactionTile(
                      transaction: tx,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => AppScope(controller: controller, child: TransactionDetailScreen(transactionId: tx.id)),
                      )),
                    );
                  },
                ),
        ),
      ),
    ]);
  }

  List<Widget> _filterChips(TransactionFilter f) {
    final result = <Widget>[];
    if (f.type != null) result.add(Chip(label: Text(_typeLabel(f.type!))));
    if (f.status != null) result.add(Chip(label: Text('Status: ${f.status!.name}')));
    if (f.accountId != null) result.add(const Chip(label: Text('Akun')));
    if (f.categoryId != null) result.add(const Chip(label: Text('Kategori')));
    if (f.startDate != null || f.endDate != null) result.add(Chip(label: Text(_dateRangeLabel(f))));
    if (f.minAmountMinor != null || f.maxAmountMinor != null) result.add(Chip(label: Text(_amountRangeLabel(f))));
    return result;
  }

  String _dateRangeLabel(TransactionFilter f) {
    String fmt(DateTime? d) => d == null ? '…' : '${d.day}/${d.month}/${d.year}';
    return '${fmt(f.startDate)} – ${fmt(f.endDate)}';
  }

  String _amountRangeLabel(TransactionFilter f) {
    final min = f.minAmountMinor == null ? '…' : Money.format(f.minAmountMinor!);
    final max = f.maxAmountMinor == null ? '…' : Money.format(f.maxAmountMinor!);
    return '$min – $max';
  }

  String _typeLabel(TransactionType type) => switch (type) {
    TransactionType.expense => 'Pengeluaran',
    TransactionType.income => 'Pemasukan',
    TransactionType.transfer => 'Transfer',
    TransactionType.refund => 'Refund',
    TransactionType.adjustment => 'Penyesuaian',
    TransactionType.openingBalance => 'Saldo awal',
    TransactionType.creditCardPayment => 'Bayar kartu kredit',
    TransactionType.loanDisbursement => 'Pencairan pinjaman',
    TransactionType.loanPayment => 'Bayar pinjaman',
  };

  Future<void> _showFilters(BuildContext context) async {
    final controller = AppScope.of(context);
    var filter = controller.transactionFilter;
    final minAmount = TextEditingController(
      text: filter.minAmountMinor == null ? '' : Money.input(filter.minAmountMinor!),
    );
    final maxAmount = TextEditingController(
      text: filter.maxAmountMinor == null ? '' : Money.input(filter.maxAmountMinor!),
    );

    final result = await showModalBottomSheet<TransactionFilter>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(builder: (context, setState) {
        final categories = filter.type == TransactionType.income ? controller.incomeCategories : controller.expenseCategories;
        return Padding(
          padding: EdgeInsets.fromLTRB(18, 0, 18, MediaQuery.viewInsetsOf(context).bottom + 18),
          child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text('Filter transaksi', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800))),
              TextButton(onPressed: () {
                minAmount.clear();
                maxAmount.clear();
                setState(() => filter = const TransactionFilter());
              }, child: const Text('Reset')),
            ]),
            const SizedBox(height: 12),
            DropdownButtonFormField<TransactionType?>(
              initialValue: filter.type,
              decoration: const InputDecoration(labelText: 'Tipe transaksi'),
              items: [
                const DropdownMenuItem<TransactionType?>(value: null, child: Text('Semua tipe')),
                ...TransactionType.values.map((v) => DropdownMenuItem<TransactionType?>(value: v, child: Text(_typeLabel(v)))),
              ],
              onChanged: (v) => setState(() => filter = TransactionFilter(
                type: v,
                status: filter.status,
                accountId: filter.accountId,
                categoryId: null,
                startDate: filter.startDate,
                endDate: filter.endDate,
                minAmountMinor: filter.minAmountMinor,
                maxAmountMinor: filter.maxAmountMinor,
              )),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<TransactionStatus?>(
              initialValue: filter.status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: [
                const DropdownMenuItem<TransactionStatus?>(value: null, child: Text('Semua status')),
                ...TransactionStatus.values.map((v) => DropdownMenuItem<TransactionStatus?>(value: v, child: Text(v.name))),
              ],
              onChanged: (v) => setState(() => filter = filter.copyWith(status: v, clearStatus: v == null)),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: filter.accountId,
              decoration: const InputDecoration(labelText: 'Akun'),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('Semua akun')),
                ...controller.accounts.map((a) => DropdownMenuItem<String?>(value: a.id, child: Text(a.name))),
              ],
              onChanged: (v) => setState(() => filter = filter.copyWith(accountId: v, clearAccount: v == null)),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: categories.any((c) => c.id == filter.categoryId) ? filter.categoryId : null,
              decoration: const InputDecoration(labelText: 'Kategori'),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('Semua kategori')),
                ...categories.map((c) => DropdownMenuItem<String?>(value: c.id, child: Text(c.name))),
              ],
              onChanged: (v) => setState(() => filter = filter.copyWith(categoryId: v, clearCategory: v == null)),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(filter.startDate == null ? 'Dari tanggal' : '${filter.startDate!.day}/${filter.startDate!.month}/${filter.startDate!.year}'),
                onPressed: () async {
                  final p = await showDatePicker(context: context, firstDate: DateTime(2000), lastDate: DateTime(2100), initialDate: filter.startDate ?? DateTime.now());
                  if (p != null) setState(() => filter = filter.copyWith(startDate: p));
                },
              )),
              const SizedBox(width: 10),
              Expanded(child: OutlinedButton.icon(
                icon: const Icon(Icons.event_outlined),
                label: Text(filter.endDate == null ? 'Sampai tanggal' : '${filter.endDate!.day}/${filter.endDate!.month}/${filter.endDate!.year}'),
                onPressed: () async {
                  final p = await showDatePicker(context: context, firstDate: DateTime(2000), lastDate: DateTime(2100), initialDate: filter.endDate ?? DateTime.now());
                  if (p != null) setState(() => filter = filter.copyWith(endDate: p));
                },
              )),
            ]),
            if (filter.startDate != null || filter.endDate != null)
              Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: () => setState(() => filter = filter.copyWith(clearStartDate: true, clearEndDate: true)), child: const Text('Hapus rentang tanggal'))),
            const SizedBox(height: 4),
            Row(children: [
              Expanded(child: TextField(controller: minAmount, keyboardType: TextInputType.number, inputFormatters: const [IdrInputFormatter()], decoration: const InputDecoration(labelText: 'Nominal minimum', prefixText: 'Rp '))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: maxAmount, keyboardType: TextInputType.number, inputFormatters: const [IdrInputFormatter()], decoration: const InputDecoration(labelText: 'Nominal maksimum', prefixText: 'Rp '))),
            ]),
            const SizedBox(height: 20),
            FilledButton.icon(
              icon: const Icon(Icons.check),
              label: const Text('Terapkan filter'),
              onPressed: () {
                final min = Money.parseIdr(minAmount.text);
                final max = Money.parseIdr(maxAmount.text);
                if (min != null && max != null && min > max) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nominal minimum tidak boleh lebih besar dari maksimum.')));
                  return;
                }
                Navigator.pop(sheetContext, TransactionFilter(
                  type: filter.type,
                  status: filter.status,
                  accountId: filter.accountId,
                  categoryId: filter.categoryId,
                  startDate: filter.startDate,
                  endDate: filter.endDate,
                  minAmountMinor: min,
                  maxAmountMinor: max,
                ));
              },
            ),
          ])),
        );
      }),
    );
    minAmount.dispose();
    maxAmount.dispose();
    if (result != null) await controller.refreshTransactions(filter: result);
  }
}
