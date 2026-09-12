import 'package:flutter/material.dart';
import '../domain/enums.dart';
import '../domain/models.dart';
import 'money.dart';

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.icon,
  });
  final String label;
  final String value;
  final String? caption;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spoken = [label, value, ?caption].join(', ');
    return Semantics(
      container: true,
      label: spoken,
      child: ExcludeSemantics(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 18, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        label,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  softWrap: true,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (caption != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    caption!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.transaction,
    this.onTap,
  });
  final TransactionView transaction;
  final VoidCallback? onTap;

  String get title {
    switch (transaction.type) {
      case TransactionType.expense:
        return transaction.categoryName ?? 'Pengeluaran';
      case TransactionType.income:
        return transaction.categoryName ?? 'Pemasukan';
      case TransactionType.transfer:
        return 'Transfer';
      case TransactionType.refund:
        return 'Refund ${transaction.categoryName ?? ''}'.trim();
      case TransactionType.adjustment:
        return 'Penyesuaian Saldo';
      case TransactionType.openingBalance:
        return 'Saldo Awal';
      case TransactionType.creditCardPayment:
        return 'Pembayaran Kartu Kredit';
      case TransactionType.loanDisbursement:
        return 'Pencairan Pinjaman';
      case TransactionType.loanPayment:
        return 'Pembayaran Pinjaman';
    }
  }

  IconData get icon {
    switch (transaction.type) {
      case TransactionType.expense:
        return Icons.arrow_upward_rounded;
      case TransactionType.income:
        return Icons.arrow_downward_rounded;
      case TransactionType.transfer:
        return Icons.swap_horiz_rounded;
      case TransactionType.refund:
        return Icons.replay_rounded;
      case TransactionType.adjustment:
        return Icons.tune_rounded;
      case TransactionType.openingBalance:
        return Icons.flag_outlined;
      case TransactionType.creditCardPayment:
        return Icons.credit_card;
      case TransactionType.loanDisbursement:
      case TransactionType.loanPayment:
        return Icons.account_balance_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isExpense = transaction.type == TransactionType.expense;
    final isIncome = transaction.type == TransactionType.income ||
        transaction.type == TransactionType.refund;
    final prefix = isExpense ? '−' : isIncome ? '+' : '';
    final amount = '$prefix${Money.format(transaction.amountMinor, currency: transaction.currency)}';
    final subtitleParts = <String>[transaction.accountName];
    if (transaction.destinationAccountName != null) {
      subtitleParts.add('ke ${transaction.destinationAccountName}');
    }
    if (transaction.note?.trim().isNotEmpty == true) {
      subtitleParts.add(transaction.note!.trim());
    }
    if (transaction.childExpenseMinor > 0) {
      final childLabel = transaction.type == TransactionType.transfer
          ? 'Biaya transfer'
          : transaction.type == TransactionType.loanPayment
              ? 'Bunga/biaya'
              : 'Biaya tambahan';
      subtitleParts.add(
        '$childLabel ${Money.format(transaction.childExpenseMinor, currency: transaction.currency)}',
      );
    }
    final subtitle = subtitleParts.join(' • ');

    return Semantics(
      button: onTap != null,
      onTap: onTap,
      label: '$title, $amount, $subtitle',
      child: ExcludeSemantics(
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          leading: CircleAvatar(
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            child: Icon(icon, color: theme.colorScheme.primary),
          ),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 132),
            child: Text(
              amount,
              textAlign: TextAlign.end,
              softWrap: true,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
