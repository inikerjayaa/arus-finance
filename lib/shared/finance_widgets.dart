import 'package:flutter/material.dart';

import '../domain/enums.dart';
import '../domain/models.dart';
import 'money.dart';
import 'saku_brand.dart';

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
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: .08),
                    borderRadius:
                        const BorderRadius.all(SakuBrand.controlRadius),
                  ),
                  child: Icon(
                    icon,
                    size: 19,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      softWrap: true,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.2,
                      ),
                    ),
                    if (caption != null) ...[
                      const SizedBox(height: 4),
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
            ],
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
    final prefix = isExpense
        ? '−'
        : isIncome
            ? '+'
            : '';
    final amount =
        '$prefix${Money.format(transaction.amountMinor, currency: transaction.currency)}';
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
    final amountColor = isExpense
        ? theme.colorScheme.error
        : isIncome
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurface;

    return Semantics(
      button: onTap != null,
      onTap: onTap,
      label: '$title, $amount, $subtitle',
      child: ExcludeSemantics(
        child: ListTile(
          onTap: onTap,
          minVerticalPadding: 10,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          leading: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: .56),
              borderRadius: const BorderRadius.all(SakuBrand.controlRadius),
            ),
            child: Icon(
              icon,
              size: 19,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          title: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 132),
            child: Text(
              amount,
              textAlign: TextAlign.end,
              softWrap: true,
              style: theme.textTheme.titleSmall?.copyWith(
                color: amountColor,
                fontWeight: FontWeight.w700,
                letterSpacing: -.1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
