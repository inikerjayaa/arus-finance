import 'package:flutter/material.dart';

import '../../core/services/visual_identity_controller_access.dart';
import '../../core/services/visual_identity_store.dart';
import '../../domain/enums.dart';
import '../../domain/models.dart';
import '../../shared/app_scope.dart';
import '../../shared/icon_catalog.dart';
import '../../shared/icon_picker_sheet.dart';
import '../../shared/idr_input_formatter.dart';
import '../../shared/money.dart';
import '../../shared/visual_palette.dart';
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
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AppScope(
                  controller: controller,
                  child: const FinancialActionsScreen(),
                ),
              ),
            ),
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
                  (account) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 8,
                        ),
                        leading: _AccountAvatar(account: account),
                        title: Text(account.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${account.accountType.name} • ${account.currency}'),
                            const SizedBox(height: 4),
                            Text(
                              Money.format(
                                account.balanceMinor,
                                currency: account.currency,
                              ),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          tooltip: 'Aksi account ${account.name}',
                          onSelected: (value) async {
                            if (value == 'visual') {
                              await _changeVisual(context, account);
                            } else if (value == 'reconcile') {
                              await _reconcile(
                                context,
                                account.id,
                                account.name,
                                account.balanceMinor,
                              );
                            } else if (value == 'archive') {
                              await _archive(context, account.id, account.name);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'visual',
                              child: Text('Ubah ikon & warna'),
                            ),
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

  Future<void> _changeVisual(BuildContext context, Account account) async {
    final controller = AppScope.of(context);
    final visuals = controller.visualIdentityStore;
    if (visuals == null) return;
    final current = await visuals.account(account.id) ??
        visuals.suggestAccount(account.name, account.accountType);
    if (!context.mounted) return;
    final picked = await IconPickerSheet.show(
      context,
      initial: current,
      suggestionText: account.name,
    );
    if (picked == null) return;
    try {
      await visuals.setAccount(
        accountId: account.id,
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

  Future<void> _reconcile(
    BuildContext context,
    String accountId,
    String accountName,
    int calculatedMinor,
  ) async {
    final controller = AppScope.of(context);
    final observed = TextEditingController(text: Money.input(calculatedMinor));
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Rekonsiliasi $accountName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Saldo terhitung: ${Money.format(calculatedMinor)}'),
            const SizedBox(height: 12),
            TextField(
              controller: observed,
              keyboardType: TextInputType.number,
              inputFormatters: const [
                IdrInputFormatter(allowNegative: true),
              ],
              decoration: const InputDecoration(
                labelText: 'Saldo yang terlihat',
                prefixText: 'Rp ',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reason,
              decoration: const InputDecoration(
                labelText: 'Alasan penyesuaian',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () async {
              final amount = Money.parseIdr(observed.text);
              if (amount == null || reason.text.trim().isEmpty) return;
              await controller.run(
                () => controller.repository.reconcileAccount(
                  accountId: accountId,
                  observedBalanceMinor: amount,
                  occurredAt: DateTime.now(),
                  reason: reason.text.trim(),
                ),
              );
              if (ctx.mounted && controller.errorMessage == null) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Sesuaikan'),
          ),
        ],
      ),
    );
    observed.dispose();
    reason.dispose();
    if (ok == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rekonsiliasi selesai.')),
      );
    }
  }

  Future<void> _archive(
    BuildContext context,
    String accountId,
    String accountName,
  ) async {
    final controller = AppScope.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Arsipkan $accountName?'),
        content: const Text(
          'Histori transaksi tidak dihapus. Account tidak akan muncul untuk transaksi baru.',
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
        () => controller.repository.archiveAccount(accountId),
      );
    }
  }

  Future<void> _showCreate(BuildContext context) async {
    final controller = AppScope.of(context);
    final visuals = controller.visualIdentityStore;
    final name = TextEditingController();
    final opening = TextEditingController();
    var type = AccountType.bank;
    var identity = visuals?.suggestAccount('', type) ??
        const VisualIdentity(iconKey: 'finance.bank', colorKey: 'blue');
    var customized = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setState) {
          final accountClass = {
            AccountType.creditCard,
            AccountType.loan,
            AccountType.otherLiability,
          }.contains(type)
              ? AccountClass.liability
              : AccountClass.asset;
          final entry = IconCatalog.fallbackFor(identity.iconKey);
          final color = VisualPalette.fallbackFor(identity.colorKey)
              .resolve(Theme.of(context).brightness);
          return Padding(
            padding: EdgeInsets.fromLTRB(
              18,
              4,
              18,
              MediaQuery.viewInsetsOf(context).bottom + 18,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Tambah account',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: name,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Nama account'),
                    onChanged: (value) {
                      if (visuals != null && !customized) {
                        setState(
                          () => identity = visuals.suggestAccount(value, type),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<AccountType>(
                    initialValue: type,
                    decoration: const InputDecoration(labelText: 'Tipe'),
                    items: AccountType.values
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        type = value ?? type;
                        if (visuals != null && !customized) {
                          identity = visuals.suggestAccount(name.text, type);
                        }
                      });
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
                              context,
                              initial: identity,
                              suggestionText: name.text,
                            );
                            if (picked != null && context.mounted) {
                              setState(() {
                                identity = picked;
                                customized = true;
                              });
                            }
                          },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: opening,
                    keyboardType: TextInputType.number,
                    inputFormatters: const [IdrInputFormatter()],
                    decoration: InputDecoration(
                      labelText: accountClass == AccountClass.liability
                          ? 'Utang awal'
                          : 'Saldo awal',
                      prefixText: 'Rp ',
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: () async {
                      final id = await controller.run(
                        () => controller.repository.createAccount(
                          name: name.text,
                          accountClass: accountClass,
                          accountType: type,
                          openingBalanceMinor:
                              Money.parseIdr(opening.text) ?? 0,
                        ),
                        refreshAfter: false,
                      );
                      if (id == null) return;
                      String? visualWarning;
                      if (visuals != null) {
                        try {
                          await visuals.setAccount(
                            accountId: id,
                            iconKey: identity.iconKey,
                            colorKey: identity.colorKey,
                          );
                        } catch (_) {
                          visualWarning =
                              'Account tersimpan, tetapi ikon belum berhasil disimpan.';
                        }
                      }
                      try {
                        await controller.refresh();
                      } catch (_) {
                        controller.noticeMessage =
                            'Account sudah tersimpan. Muat ulang tampilan bila belum terlihat.';
                        controller.notifyListeners();
                      }
                      if (sheetContext.mounted) {
                        Navigator.of(sheetContext).pop();
                      }
                      if (visualWarning != null && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(visualWarning)),
                        );
                      }
                    },
                    child: const Text('Simpan account'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    name.dispose();
    opening.dispose();
  }
}

class _AccountAvatar extends StatelessWidget {
  const _AccountAvatar({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context) {
    final visuals = AppScope.of(context).visualIdentityStore;
    if (visuals == null) {
      return CircleAvatar(child: Icon(_fallbackIcon(account.accountType)));
    }
    return FutureBuilder<VisualIdentity?>(
      future: visuals.account(account.id),
      builder: (context, snapshot) {
        final identity = snapshot.data ??
            visuals.suggestAccount(account.name, account.accountType);
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

  IconData _fallbackIcon(AccountType type) {
    switch (type) {
      case AccountType.cash:
        return Icons.payments_outlined;
      case AccountType.bank:
        return Icons.account_balance_outlined;
      case AccountType.ewallet:
        return Icons.account_balance_wallet_outlined;
      case AccountType.creditCard:
        return Icons.credit_card;
      case AccountType.loan:
        return Icons.request_quote_outlined;
      case AccountType.investment:
        return Icons.show_chart_rounded;
      default:
        return Icons.wallet_outlined;
    }
  }
}
