import 'package:flutter/material.dart';
import '../../domain/enums.dart';
import '../../shared/app_scope.dart';
import '../../shared/money.dart';
import 'financial_actions_screen.dart';

class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts'),
        actions: [
          IconButton(
            tooltip: 'Aksi kartu kredit dan pinjaman',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => AppScope(
                controller: controller,
                child: const FinancialActionsScreen(),
              ),
            )),
            icon: const Icon(Icons.swap_horiz_rounded),
          ),
        ],
      ),
      body: controller.accounts.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.account_balance_wallet_outlined, size: 48),
                    const SizedBox(height: 12),
                    const Text('Belum ada account.'),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => _showCreate(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Tambah account'),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 120),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Kelola sumber uang dan kewajibanmu.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.tonalIcon(
                      onPressed: () => _showCreate(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Tambah'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ...controller.accounts.map(
                  (a) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 8,
                        ),
                        leading: CircleAvatar(child: Icon(_icon(a.accountType))),
                        title: Text(a.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${a.accountType.name} • ${a.currency}'),
                            const SizedBox(height: 4),
                            Text(
                              Money.format(a.balanceMinor, currency: a.currency),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          tooltip: 'Aksi account ${a.name}',
                          onSelected: (value) {
                            if (value == 'reconcile') {
                              _reconcile(context, a.id, a.name, a.balanceMinor);
                            }
                            if (value == 'archive') {
                              _archive(context, a.id, a.name);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'reconcile',
                              child: Text('Rekonsiliasi saldo'),
                            ),
                            PopupMenuItem(
                              value: 'archive',
                              child: Text('Arsipkan'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  IconData _icon(AccountType type) {
    switch (type) {
      case AccountType.cash: return Icons.payments_outlined;
      case AccountType.bank: return Icons.account_balance_outlined;
      case AccountType.ewallet: return Icons.account_balance_wallet_outlined;
      case AccountType.creditCard: return Icons.credit_card;
      case AccountType.loan: return Icons.request_quote_outlined;
      case AccountType.investment: return Icons.show_chart_rounded;
      default: return Icons.wallet_outlined;
    }
  }

  Future<void> _reconcile(BuildContext context, String accountId, String accountName, int calculatedMinor) async {
    final controller = AppScope.of(context);
    final observed = TextEditingController(text: calculatedMinor.toString());
    final reason = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text('Rekonsiliasi $accountName'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Saldo terhitung: ${Money.format(calculatedMinor)}'),
        const SizedBox(height: 12),
        TextField(controller: observed, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Saldo yang terlihat', prefixText: 'Rp ')),
        const SizedBox(height: 12),
        TextField(controller: reason, decoration: const InputDecoration(labelText: 'Alasan penyesuaian')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
        FilledButton(onPressed: () async {
          final amount = Money.parseIdr(observed.text);
          if (amount == null || reason.text.trim().isEmpty) return;
          await controller.run(() => controller.repository.reconcileAccount(accountId: accountId, observedBalanceMinor: amount, occurredAt: DateTime.now(), reason: reason.text.trim()));
          if (ctx.mounted && controller.errorMessage == null) Navigator.pop(ctx, true);
        }, child: const Text('Sesuaikan')),
      ],
    ));
    observed.dispose(); reason.dispose();
    if (ok == true && context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rekonsiliasi selesai.')));
  }

  Future<void> _archive(BuildContext context, String accountId, String accountName) async {
    final controller = AppScope.of(context);
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text('Arsipkan $accountName?'),
      content: const Text('Histori transaksi tidak dihapus. Account tidak akan muncul untuk transaksi baru.'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Arsipkan'))],
    ));
    if (ok == true) await controller.run(() => controller.repository.archiveAccount(accountId));
  }

  Future<void> _showCreate(BuildContext context) async {
    final controller = AppScope.of(context);
    final name = TextEditingController();
    final opening = TextEditingController();
    var type = AccountType.bank;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(builder: (context, setState) {
        final accountClass = {AccountType.creditCard, AccountType.loan, AccountType.otherLiability}.contains(type) ? AccountClass.liability : AccountClass.asset;
        return Padding(
          padding: EdgeInsets.fromLTRB(18, 4, 18, MediaQuery.viewInsetsOf(context).bottom + 18),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Tambah account', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'Nama account')),
            const SizedBox(height: 12),
            DropdownButtonFormField<AccountType>(
              value: type,
              decoration: const InputDecoration(labelText: 'Tipe'),
              items: AccountType.values.map((v) => DropdownMenuItem(value: v, child: Text(v.name))).toList(),
              onChanged: (v) => setState(() => type = v ?? type),
            ),
            const SizedBox(height: 12),
            TextField(controller: opening, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: accountClass == AccountClass.liability ? 'Utang awal' : 'Saldo awal', prefixText: 'Rp ')),
            const SizedBox(height: 18),
            FilledButton(onPressed: () async {
              final result = await controller.run(() => controller.repository.createAccount(
                name: name.text,
                accountClass: accountClass,
                accountType: type,
                openingBalanceMinor: Money.parseIdr(opening.text) ?? 0,
              ));
              if (sheetContext.mounted && result != null) Navigator.of(sheetContext).pop();
            }, child: const Text('Simpan account')),
          ]),
        );
      }),
    );
    name.dispose();
    opening.dispose();
  }
}
