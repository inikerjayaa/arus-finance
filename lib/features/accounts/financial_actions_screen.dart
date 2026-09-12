import 'package:flutter/material.dart';

import '../../domain/enums.dart';
import '../../domain/models.dart';
import '../../shared/app_scope.dart';
import '../../shared/money.dart';

class FinancialActionsScreen extends StatelessWidget {
  const FinancialActionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final assets = c.accounts.where((a) => a.accountClass == AccountClass.asset).toList();
    final cards = c.accounts.where((a) => a.accountType == AccountType.creditCard).toList();
    final loans = c.accounts.where((a) => a.accountType == AccountType.loan).toList();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Aksi finansial')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 120),
        children: [
        Semantics(
          header: true,
          child: Text('Aksi finansial', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 4),
        Text('Settlement liability dipisahkan dari transfer biasa agar laporan tidak double-count.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 18),
        _ActionCard(
          icon: Icons.credit_card,
          title: 'Bayar kartu kredit',
          description: 'Asset berkurang dan utang kartu kredit berkurang. Tidak menjadi pengeluaran kedua kali.',
          enabled: assets.isNotEmpty && cards.isNotEmpty,
          disabledReason: cards.isEmpty ? 'Buat account Credit Card terlebih dahulu.' : 'Buat asset account terlebih dahulu.',
          onTap: () => _creditCardPayment(context, assets, cards),
        ),
        _ActionCard(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Pencairan pinjaman',
          description: 'Asset bertambah dan liability bertambah dengan nilai yang sama. Tidak dianggap pemasukan.',
          enabled: assets.isNotEmpty && loans.isNotEmpty,
          disabledReason: loans.isEmpty ? 'Buat account Loan terlebih dahulu.' : 'Buat asset account terlebih dahulu.',
          onTap: () => _loanDisbursement(context, assets, loans),
        ),
        _ActionCard(
          icon: Icons.request_quote_outlined,
          title: 'Bayar pinjaman',
          description: 'Pokok mengurangi liability; bunga dan fee masuk pengeluaran secara terpisah.',
          enabled: assets.isNotEmpty && loans.isNotEmpty && c.expenseCategories.isNotEmpty,
          disabledReason: loans.isEmpty ? 'Buat account Loan terlebih dahulu.' : 'Data account/kategori belum siap.',
          onTap: () => _loanPayment(context, assets, loans, c.expenseCategories),
        ),
        ],
      ),
    );
  }

  Future<void> _creditCardPayment(BuildContext context, List<Account> assets, List<Account> cards) async {
    final c = AppScope.of(context);
    final amount = TextEditingController();
    final note = TextEditingController();
    var sourceId = assets.first.id;
    var cardId = cards.first.id;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(builder: (context, setState) => Padding(
        padding: EdgeInsets.fromLTRB(18, 0, 18, MediaQuery.viewInsetsOf(context).bottom + 18),
        child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Bayar kartu kredit', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          _moneyField(amount, 'Nominal pembayaran'),
          const SizedBox(height: 12),
          _accountDropdown('Bayar dari', assets, sourceId, (v) => setState(() => sourceId = v)),
          const SizedBox(height: 12),
          _accountDropdown('Kartu kredit', cards, cardId, (v) => setState(() => cardId = v)),
          const SizedBox(height: 12),
          TextField(controller: note, decoration: const InputDecoration(labelText: 'Catatan (opsional)')),
          const SizedBox(height: 18),
          FilledButton(onPressed: () async {
            final parsed = Money.parseIdr(amount.text);
            if (parsed == null || parsed <= 0) return;
            final card = cards.firstWhere((a) => a.id == cardId);
            if (parsed > card.balanceMinor && card.balanceMinor >= 0) {
              final proceed = await _confirmOverpay(context, card.balanceMinor, parsed);
              if (!proceed) return;
            }
            final result = await c.run(() => c.repository.createCreditCardPayment(
              amountMinor: parsed,
              sourceAssetAccountId: sourceId,
              creditCardAccountId: cardId,
              occurredAt: DateTime.now(),
              note: note.text.trim().isEmpty ? null : note.text.trim(),
            ));
            if (sheetContext.mounted && result != null) Navigator.pop(sheetContext);
          }, child: const Text('Catat pembayaran')),
        ])),
      )),
    );
    amount.dispose();
    note.dispose();
  }

  Future<void> _loanDisbursement(BuildContext context, List<Account> assets, List<Account> loans) async {
    final c = AppScope.of(context);
    final amount = TextEditingController();
    final note = TextEditingController();
    var assetId = assets.first.id;
    var loanId = loans.first.id;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(builder: (context, setState) => Padding(
        padding: EdgeInsets.fromLTRB(18, 0, 18, MediaQuery.viewInsetsOf(context).bottom + 18),
        child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Pencairan pinjaman', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          _moneyField(amount, 'Dana diterima'),
          const SizedBox(height: 12),
          _accountDropdown('Dana masuk ke', assets, assetId, (v) => setState(() => assetId = v)),
          const SizedBox(height: 12),
          _accountDropdown('Liability pinjaman', loans, loanId, (v) => setState(() => loanId = v)),
          const SizedBox(height: 12),
          TextField(controller: note, decoration: const InputDecoration(labelText: 'Catatan (opsional)')),
          const SizedBox(height: 18),
          FilledButton(onPressed: () async {
            final parsed = Money.parseIdr(amount.text);
            if (parsed == null || parsed <= 0) return;
            final result = await c.run(() => c.repository.createLoanDisbursement(
              amountMinor: parsed,
              assetAccountId: assetId,
              loanAccountId: loanId,
              occurredAt: DateTime.now(),
              note: note.text.trim().isEmpty ? null : note.text.trim(),
            ));
            if (sheetContext.mounted && result != null) Navigator.pop(sheetContext);
          }, child: const Text('Catat pencairan')),
        ])),
      )),
    );
    amount.dispose();
    note.dispose();
  }

  Future<void> _loanPayment(BuildContext context, List<Account> assets, List<Account> loans, List<Category> categories) async {
    final c = AppScope.of(context);
    final principal = TextEditingController();
    final interest = TextEditingController();
    final fee = TextEditingController();
    final note = TextEditingController();
    var assetId = assets.first.id;
    var loanId = loans.first.id;
    var interestCategoryId = categories.firstWhere((x) => x.name == 'Bunga Pinjaman', orElse: () => categories.first).id;
    var feeCategoryId = categories.firstWhere((x) => x.name == 'Biaya Pinjaman', orElse: () => categories.first).id;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(builder: (context, setState) => Padding(
        padding: EdgeInsets.fromLTRB(18, 0, 18, MediaQuery.viewInsetsOf(context).bottom + 18),
        child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Bayar pinjaman', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          _moneyField(principal, 'Pokok'),
          const SizedBox(height: 10),
          _moneyField(interest, 'Bunga (boleh 0)'),
          const SizedBox(height: 10),
          _moneyField(fee, 'Fee (boleh 0)'),
          const SizedBox(height: 12),
          _accountDropdown('Bayar dari', assets, assetId, (v) => setState(() => assetId = v)),
          const SizedBox(height: 12),
          _accountDropdown('Pinjaman', loans, loanId, (v) => setState(() => loanId = v)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: interestCategoryId,
            decoration: const InputDecoration(labelText: 'Kategori bunga'),
            items: categories.map((x) => DropdownMenuItem(value: x.id, child: Text(x.name))).toList(),
            onChanged: (v) => setState(() => interestCategoryId = v ?? interestCategoryId),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: feeCategoryId,
            decoration: const InputDecoration(labelText: 'Kategori fee'),
            items: categories.map((x) => DropdownMenuItem(value: x.id, child: Text(x.name))).toList(),
            onChanged: (v) => setState(() => feeCategoryId = v ?? feeCategoryId),
          ),
          const SizedBox(height: 12),
          TextField(controller: note, decoration: const InputDecoration(labelText: 'Catatan (opsional)')),
          const SizedBox(height: 18),
          FilledButton(onPressed: () async {
            final p = Money.parseIdr(principal.text) ?? 0;
            final i = Money.parseIdr(interest.text) ?? 0;
            final f = Money.parseIdr(fee.text) ?? 0;
            if (p <= 0 || i < 0 || f < 0) return;
            final loan = loans.firstWhere((a) => a.id == loanId);
            if (p > loan.balanceMinor && loan.balanceMinor >= 0) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pokok pembayaran melebihi outstanding pinjaman.')));
              return;
            }
            final result = await c.run(() => c.repository.createLoanPayment(
              principalMinor: p,
              interestMinor: i,
              feeMinor: f,
              sourceAssetAccountId: assetId,
              loanAccountId: loanId,
              interestCategoryId: interestCategoryId,
              feeCategoryId: feeCategoryId,
              occurredAt: DateTime.now(),
              note: note.text.trim().isEmpty ? null : note.text.trim(),
            ));
            if (sheetContext.mounted && result != null) Navigator.pop(sheetContext);
          }, child: const Text('Catat pembayaran')),
        ])),
      )),
    );
    principal.dispose();
    interest.dispose();
    fee.dispose();
    note.dispose();
  }

  Widget _moneyField(TextEditingController controller, String label) => TextField(
    controller: controller,
    keyboardType: TextInputType.number,
    decoration: InputDecoration(labelText: label, prefixText: 'Rp '),
  );

  Widget _accountDropdown(String label, List<Account> values, String value, ValueChanged<String> onChanged) => DropdownButtonFormField<String>(
    initialValue: value,
    decoration: InputDecoration(labelText: label),
    items: values.map((a) => DropdownMenuItem(value: a.id, child: Text('${a.name} • ${Money.format(a.balanceMinor, currency: a.currency)}'))).toList(),
    onChanged: (v) { if (v != null) onChanged(v); },
  );

  Future<bool> _confirmOverpay(BuildContext context, int outstanding, int payment) async {
    return await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Pembayaran melebihi outstanding'),
      content: Text('Outstanding ${Money.format(outstanding)}. Pembayaran ${Money.format(payment)} akan membuat saldo kredit pada kartu.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Lanjutkan')),
      ],
    )) ?? false;
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.icon, required this.title, required this.description, required this.enabled, required this.disabledReason, required this.onTap});
  final IconData icon;
  final String title;
  final String description;
  final bool enabled;
  final String disabledReason;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(child: ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
    leading: CircleAvatar(child: Icon(icon)),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    subtitle: Text(enabled ? description : disabledReason),
    trailing: enabled ? const Icon(Icons.chevron_right) : const Icon(Icons.lock_outline),
    onTap: enabled ? onTap : null,
  ));
}
