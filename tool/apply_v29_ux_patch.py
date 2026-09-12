from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(rel: str) -> str:
    return (ROOT / rel).read_text()


def write(rel: str, text: str) -> None:
    path = ROOT / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)


def replace_once(rel: str, old: str, new: str) -> None:
    text = read(rel)
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'FAIL: {rel}: expected exactly one match, found {count}: {old[:90]!r}')
    write(rel, text.replace(old, new, 1))


def replace_slice(rel: str, start: str, end: str, replacement: str) -> None:
    text = read(rel)
    a = text.find(start)
    if a < 0:
        raise SystemExit(f'FAIL: {rel}: start marker not found: {start[:90]!r}')
    b = text.find(end, a)
    if b < 0:
        raise SystemExit(f'FAIL: {rel}: end marker not found: {end[:90]!r}')
    if text.find(start, a + 1) >= 0:
        raise SystemExit(f'FAIL: {rel}: start marker is ambiguous')
    write(rel, text[:a] + replacement + text[b:])


# ---------------------------------------------------------------------------
# 1. IDR input formatter — visual grouping only; Money.parseIdr stays canonical.
# ---------------------------------------------------------------------------
write(
    'lib/shared/idr_input_formatter.dart',
    r'''import 'package:flutter/services.dart';

/// Formats integer IDR input with Indonesian thousand separators while the
/// user types. The formatter never changes the numeric value; persistence
/// still goes through Money.parseIdr and the repository money envelope.
class IdrInputFormatter extends TextInputFormatter {
  const IdrInputFormatter({this.allowNegative = false});

  final bool allowNegative;

  static String formatDigits(String raw, {bool allowNegative = false}) {
    final negative = allowNegative && raw.trimLeft().startsWith('-');
    var digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return negative ? '-' : '';
    digits = digits.replaceFirst(RegExp(r'^0+(?=\d)'), '');

    final out = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      final remaining = digits.length - i;
      out.write(digits[i]);
      if (remaining > 1 && (remaining - 1) % 3 == 0) out.write('.');
    }
    return '${negative ? '-' : ''}$out';
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    final formatted = formatDigits(
      newValue.text,
      allowNegative: allowNegative,
    );
    if (formatted == '-' && !allowNegative) {
      return const TextEditingValue();
    }

    // Preserve the logical caret by counting digits to the right of it. This
    // keeps mid-number edits predictable instead of always jumping to the end.
    final extent = newValue.selection.extentOffset
        .clamp(0, newValue.text.length);
    final digitsToRight = RegExp(r'\d')
        .allMatches(newValue.text.substring(extent))
        .length;
    var caret = formatted.length;
    var seen = 0;
    for (var i = formatted.length - 1; i >= 0 && seen < digitsToRight; i--) {
      if (RegExp(r'\d').hasMatch(formatted[i])) seen++;
      caret = i;
    }
    if (digitsToRight == 0) caret = formatted.length;

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: caret),
    );
  }
}
''',
)

replace_once(
    'lib/shared/money.dart',
    "  static final NumberFormat _idr = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);\n",
    "  static final NumberFormat _idr = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);\n"
    "  static final NumberFormat _idrInput = NumberFormat.decimalPattern('id_ID');\n"
    "  static String input(int minor) => _idrInput.format(minor);\n",
)

# ---------------------------------------------------------------------------
# 2. Quick Add keyboard -> selector race + formatted amount input.
# ---------------------------------------------------------------------------
replace_once(
    'lib/features/quick_add/quick_add_sheet.dart',
    "import '../../shared/app_scope.dart';\nimport '../../shared/money.dart';\n",
    "import '../../shared/app_scope.dart';\nimport '../../shared/idr_input_formatter.dart';\nimport '../../shared/money.dart';\n",
)
replace_once(
    'lib/features/quick_add/quick_add_sheet.dart',
    "              keyboardType: TextInputType.number,\n              textInputAction: TextInputAction.next,\n",
    "              keyboardType: TextInputType.number,\n              inputFormatters: const [IdrInputFormatter()],\n              textInputAction: TextInputAction.next,\n",
)
replace_once(
    'lib/features/quick_add/quick_add_sheet.dart',
    "              TextFormField(\n                keyboardType: TextInputType.number,\n",
    "              TextFormField(\n                keyboardType: TextInputType.number,\n                inputFormatters: const [IdrInputFormatter()],\n",
)

account_start = "            DropdownButtonFormField<String>(\n              initialValue: _accountId,"
account_end = "            if (_mode == 2) ...[\n"
account_replacement = r'''            _selectionField(
              context: context,
              label: _mode == 2 ? 'Dari account' : 'Account',
              value: eligibleAccounts
                  .where((a) => a.id == _accountId)
                  .firstOrNull
                  ?.name,
              errorText: _accountError,
              onTap: eligibleAccounts.isEmpty
                  ? null
                  : () async {
                      final picked = await _pickChoice(
                        context,
                        title: _mode == 2 ? 'Pilih account asal' : 'Pilih account',
                        selected: _accountId,
                        choices: eligibleAccounts
                            .map((a) => _PickerChoice(a.id, a.name))
                            .toList(growable: false),
                      );
                      if (!mounted || picked == null) return;
                      setState(() {
                        _dirty = true;
                        _accountId = picked;
                        _accountError = null;
                        if (_mode == 2 && _destinationId == picked) {
                          _destinationId = eligibleAccounts
                              .where((a) => a.id != picked)
                              .firstOrNull
                              ?.id;
                        }
                      });
                    },
            ),
'''
replace_slice('lib/features/quick_add/quick_add_sheet.dart', account_start, account_end, account_replacement)

destination_start = "              DropdownButtonFormField<String>(\n                initialValue: _destinationId,"
destination_end = "              const SizedBox(height: 12),\n              TextFormField(\n"
destination_replacement = r'''              _selectionField(
                context: context,
                label: 'Ke account',
                value: eligibleAccounts
                    .where((a) => a.id == _destinationId)
                    .firstOrNull
                    ?.name,
                errorText: _destinationError,
                onTap: eligibleAccounts.where((a) => a.id != _accountId).isEmpty
                    ? null
                    : () async {
                        final choices = eligibleAccounts
                            .where((a) => a.id != _accountId)
                            .map((a) => _PickerChoice(a.id, a.name))
                            .toList(growable: false);
                        final picked = await _pickChoice(
                          context,
                          title: 'Pilih account tujuan',
                          selected: _destinationId,
                          choices: choices,
                        );
                        if (!mounted || picked == null) return;
                        setState(() {
                          _dirty = true;
                          _destinationId = picked;
                          _destinationError = null;
                        });
                      },
              ),
'''
replace_slice('lib/features/quick_add/quick_add_sheet.dart', destination_start, destination_end, destination_replacement)

category_start = "              DropdownButtonFormField<String>(\n                initialValue: _categoryId,"
category_end = "            ],\n            const SizedBox(height: 12),\n            OutlinedButton.icon("
category_replacement = r'''              _selectionField(
                context: context,
                label: 'Kategori',
                value: categories
                    .where((c) => c.id == _categoryId)
                    .firstOrNull
                    ?.name,
                errorText: _categoryError,
                onTap: categories.isEmpty
                    ? null
                    : () async {
                        final picked = await _pickChoice(
                          context,
                          title: _mode == 1
                              ? 'Pilih kategori pemasukan'
                              : 'Pilih kategori pengeluaran',
                          selected: _categoryId,
                          choices: categories
                              .map((c) => _PickerChoice(c.id, c.name))
                              .toList(growable: false),
                        );
                        if (!mounted || picked == null) return;
                        setState(() {
                          _dirty = true;
                          _categoryId = picked;
                          _categoryError = null;
                        });
                      },
              ),
'''
replace_slice('lib/features/quick_add/quick_add_sheet.dart', category_start, category_end, category_replacement)

quick_helpers = r'''
  Widget _selectionField({
    required BuildContext context,
    required String label,
    required String? value,
    required String? errorText,
    required VoidCallback? onTap,
  }) {
    return Semantics(
      button: true,
      label: '$label, ${value ?? 'belum dipilih'}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          decoration: InputDecoration(labelText: label, errorText: errorText),
          isEmpty: value == null,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value ?? 'Pilih $label',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.arrow_drop_down_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _pickChoice(
    BuildContext context, {
    required String title,
    required List<_PickerChoice> choices,
    String? selected,
  }) async {
    // Dropdown overlays can be anchored to the pre-keyboard layout. Dismiss
    // the IME first and wait until viewInsets reaches zero before opening the
    // selector so the menu cannot remain stuck at the old keyboard position.
    FocusManager.instance.primaryFocus?.unfocus();
    for (var i = 0; i < 16; i++) {
      if (!mounted || !context.mounted) return null;
      if (MediaQuery.viewInsetsOf(context).bottom <= 0) break;
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
    if (!context.mounted) return null;

    return showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: Theme.of(sheetContext)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 8),
          ...choices.map(
            (choice) => ListTile(
              leading: Icon(
                choice.id == selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
              ),
              title: Text(choice.label),
              onTap: () => Navigator.pop(sheetContext, choice.id),
            ),
          ),
        ],
      ),
    );
  }

'''
replace_once(
    'lib/features/quick_add/quick_add_sheet.dart',
    "  Future<void> _requestClose(BuildContext context) async {\n",
    quick_helpers + "  Future<void> _requestClose(BuildContext context) async {\n",
)
replace_once(
    'lib/features/quick_add/quick_add_sheet.dart',
    "extension FirstOrNull<T> on Iterable<T> {\n",
    "class _PickerChoice {\n  const _PickerChoice(this.id, this.label);\n  final String id;\n  final String label;\n}\n\nextension FirstOrNull<T> on Iterable<T> {\n",
)

# ---------------------------------------------------------------------------
# 3. Apply IDR formatter to the other monetary entry surfaces.
# ---------------------------------------------------------------------------
for rel in [
    'lib/features/accounts/accounts_screen.dart',
    'lib/features/accounts/financial_actions_screen.dart',
    'lib/features/planning/planning_screen.dart',
    'lib/features/transactions/transactions_screen.dart',
    'lib/features/transactions/transaction_detail_screen.dart',
]:
    replace_once(
        rel,
        "import '../../shared/app_scope.dart';\n",
        "import '../../shared/app_scope.dart';\nimport '../../shared/idr_input_formatter.dart';\n",
    )

replace_once(
    'lib/features/accounts/accounts_screen.dart',
    'final observed = TextEditingController(text: calculatedMinor.toString());',
    'final observed = TextEditingController(text: Money.input(calculatedMinor));',
)
replace_once(
    'lib/features/accounts/accounts_screen.dart',
    "TextField(controller: observed, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Saldo yang terlihat', prefixText: 'Rp ')),",
    "TextField(controller: observed, keyboardType: TextInputType.number, inputFormatters: const [IdrInputFormatter(allowNegative: true)], decoration: const InputDecoration(labelText: 'Saldo yang terlihat', prefixText: 'Rp ')),",
)
replace_once(
    'lib/features/accounts/accounts_screen.dart',
    "TextField(controller: opening, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: accountClass == AccountClass.liability ? 'Utang awal' : 'Saldo awal', prefixText: 'Rp ')),",
    "TextField(controller: opening, keyboardType: TextInputType.number, inputFormatters: const [IdrInputFormatter()], decoration: InputDecoration(labelText: accountClass == AccountClass.liability ? 'Utang awal' : 'Saldo awal', prefixText: 'Rp ')),",
)

replace_once(
    'lib/features/accounts/financial_actions_screen.dart',
    "    keyboardType: TextInputType.number,\n    decoration: InputDecoration(labelText: label, prefixText: 'Rp '),",
    "    keyboardType: TextInputType.number,\n    inputFormatters: const [IdrInputFormatter()],\n    decoration: InputDecoration(labelText: label, prefixText: 'Rp '),",
)

replace_once(
    'lib/features/planning/planning_screen.dart',
    "TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Limit', prefixText: 'Rp ')),",
    "TextField(controller: amount, keyboardType: TextInputType.number, inputFormatters: const [IdrInputFormatter()], decoration: const InputDecoration(labelText: 'Limit', prefixText: 'Rp ')),",
)
replace_once(
    'lib/features/planning/planning_screen.dart',
    'final amount = TextEditingController(text: expectedMinor.toString());',
    'final amount = TextEditingController(text: Money.input(expectedMinor));',
)
replace_once(
    'lib/features/planning/planning_screen.dart',
    "TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Nominal aktual', prefixText: 'Rp ')),",
    "TextField(controller: amount, keyboardType: TextInputType.number, inputFormatters: const [IdrInputFormatter()], decoration: const InputDecoration(labelText: 'Nominal aktual', prefixText: 'Rp ')),",
)
replace_once(
    'lib/features/planning/planning_screen.dart',
    "TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Nominal', prefixText: 'Rp ')),",
    "TextField(controller: amount, keyboardType: TextInputType.number, inputFormatters: const [IdrInputFormatter()], decoration: const InputDecoration(labelText: 'Nominal', prefixText: 'Rp ')),",
)
# A second nominal field exists for recurring expense.
text = read('lib/features/planning/planning_screen.dart')
needle = "TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Nominal', prefixText: 'Rp ')),"
if needle in text:
    write('lib/features/planning/planning_screen.dart', text.replace(
        needle,
        "TextField(controller: amount, keyboardType: TextInputType.number, inputFormatters: const [IdrInputFormatter()], decoration: const InputDecoration(labelText: 'Nominal', prefixText: 'Rp ')),",
        1,
    ))

replace_once(
    'lib/features/transactions/transactions_screen.dart',
    "final minAmount = TextEditingController(text: filter.minAmountMinor?.toString() ?? '');\n    final maxAmount = TextEditingController(text: filter.maxAmountMinor?.toString() ?? '');",
    "final minAmount = TextEditingController(text: filter.minAmountMinor == null ? '' : Money.input(filter.minAmountMinor!));\n    final maxAmount = TextEditingController(text: filter.maxAmountMinor == null ? '' : Money.input(filter.maxAmountMinor!));",
)
replace_once(
    'lib/features/transactions/transactions_screen.dart',
    "Expanded(child: TextField(controller: minAmount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Nominal minimum', prefixText: 'Rp '))),",
    "Expanded(child: TextField(controller: minAmount, keyboardType: TextInputType.number, inputFormatters: const [IdrInputFormatter()], decoration: const InputDecoration(labelText: 'Nominal minimum', prefixText: 'Rp '))),",
)
replace_once(
    'lib/features/transactions/transactions_screen.dart',
    "Expanded(child: TextField(controller: maxAmount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Nominal maksimum', prefixText: 'Rp '))),",
    "Expanded(child: TextField(controller: maxAmount, keyboardType: TextInputType.number, inputFormatters: const [IdrInputFormatter()], decoration: const InputDecoration(labelText: 'Nominal maksimum', prefixText: 'Rp '))),",
)

replace_once(
    'lib/features/transactions/transaction_detail_screen.dart',
    'final amount = TextEditingController(text: d.view.amountMinor.toString());',
    'final amount = TextEditingController(text: Money.input(d.view.amountMinor));',
)
replace_once(
    'lib/features/transactions/transaction_detail_screen.dart',
    "TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Nominal', prefixText: 'Rp ')),",
    "TextField(controller: amount, keyboardType: TextInputType.number, inputFormatters: const [IdrInputFormatter()], decoration: const InputDecoration(labelText: 'Nominal', prefixText: 'Rp ')),",
)
replace_once(
    'lib/features/transactions/transaction_detail_screen.dart',
    'final amount = TextEditingController(text: remaining.toString());',
    'final amount = TextEditingController(text: Money.input(remaining));',
)
replace_once(
    'lib/features/transactions/transaction_detail_screen.dart',
    "TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Nominal refund', prefixText: 'Rp ')),",
    "TextField(controller: amount, keyboardType: TextInputType.number, inputFormatters: const [IdrInputFormatter()], decoration: const InputDecoration(labelText: 'Nominal refund', prefixText: 'Rp ')),",
)

# ---------------------------------------------------------------------------
# 4. Default categories remain seeded; add safe rename support.
# ---------------------------------------------------------------------------
replace_once(
    'lib/domain/finance_repository.dart',
    "  Future<String> createCategory({required String name, required CategoryType type});\n",
    "  Future<String> createCategory({required String name, required CategoryType type});\n  Future<void> renameCategory(String categoryId, String name);\n",
)

rename_method = r'''
  @override
  Future<void> renameCategory(String categoryId, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('Nama kategori wajib diisi.');
    final row = _categoryRow(categoryId);
    if (row['archived_at'] != null) throw StateError('Kategori sudah diarsipkan.');
    // Transfer fee is currently an automatic repository category. Keep this
    // one stable until it has a schema-level system key instead of name lookup.
    if (row['type'] == enumDbName(CategoryType.expense) &&
        row['name'] == 'Biaya Transfer') {
      throw StateError('Biaya Transfer adalah kategori sistem dan belum dapat diganti nama.');
    }
    final duplicate = _db.select(
      'SELECT id FROM categories WHERE id<>? AND archived_at IS NULL AND type=? AND lower(name)=lower(?) LIMIT 1',
      [categoryId, row['type'], trimmed],
    );
    if (duplicate.isNotEmpty) {
      throw StateError('Nama kategori aktif sudah digunakan untuk tipe ini.');
    }
    _database.transaction((db) {
      db.execute(
        'UPDATE categories SET name=?, updated_at=?, version=version+1 WHERE id=?',
        [trimmed, _now(), categoryId],
      );
    });
  }

'''
replace_once(
    'lib/data/local_finance_repository.dart',
    "  @override\n  Future<String> createExpense({\n",
    rename_method + "  @override\n  Future<String> createExpense({\n",
)

replace_once(
    'lib/features/settings/categories_screen.dart',
    "            onSelected: (v) async {\n              if (v == 'archive') {",
    "            onSelected: (v) async {\n              if (v == 'edit') {\n                await _rename(context, category.id, category.name);\n              }\n              if (v == 'archive') {",
)
replace_once(
    'lib/features/settings/categories_screen.dart',
    "            itemBuilder: (_) => const [PopupMenuItem(value: 'archive', child: Text('Arsipkan'))],\n",
    "            itemBuilder: (_) => [\n              if (!(type == CategoryType.expense && category.name == 'Biaya Transfer'))\n                const PopupMenuItem(value: 'edit', child: Text('Edit nama')),\n              const PopupMenuItem(value: 'archive', child: Text('Arsipkan')),\n            ],\n",
)
category_rename_helper = r'''

  Future<void> _rename(
    BuildContext context,
    String categoryId,
    String currentName,
  ) async {
    final c = AppScope.of(context);
    final input = TextEditingController(text: currentName);
    final renamed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit nama kategori'),
        content: TextField(
          controller: input,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nama kategori'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () async {
              final result = await c.run(
                () => c.repository.renameCategory(categoryId, input.text),
              );
              if (ctx.mounted && result != null) Navigator.pop(ctx, true);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    input.dispose();
    if (renamed == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama kategori diperbarui.')),
      );
    }
  }
'''
replace_once(
    'lib/features/settings/categories_screen.dart',
    "  @override\n  Widget build(BuildContext context) {\n    final c = AppScope.of(context);",
    category_rename_helper + "\n  @override\n  Widget build(BuildContext context) {\n    final c = AppScope.of(context);",
)

# ---------------------------------------------------------------------------
# 5. Dashboard expense/income category composition and native donut chart.
# ---------------------------------------------------------------------------
replace_once(
    'lib/domain/models.dart',
    "class DashboardData {\n",
    "class CategoryBreakdownItem {\n"
    "  const CategoryBreakdownItem({required this.name, required this.amountMinor});\n"
    "  final String name;\n"
    "  final int amountMinor;\n"
    "}\n\n"
    "class DashboardData {\n",
)
replace_once(
    'lib/domain/models.dart',
    "    required this.largestCategoryAmountMinor,\n  });",
    "    required this.largestCategoryAmountMinor,\n    this.expenseCategoryBreakdown = const [],\n    this.incomeCategoryBreakdown = const [],\n  });",
)
replace_once(
    'lib/domain/models.dart',
    "  final int largestCategoryAmountMinor;\n}",
    "  final int largestCategoryAmountMinor;\n  final List<CategoryBreakdownItem> expenseCategoryBreakdown;\n  final List<CategoryBreakdownItem> incomeCategoryBreakdown;\n}",
)

old_cat_query = r'''    final catRows = _db.select(
      '''SELECT c.name, SUM(CASE WHEN t.type='EXPENSE' THEN s.amount_minor WHEN t.type='REFUND' THEN -s.amount_minor ELSE 0 END) AS total
         FROM transactions t JOIN transaction_splits s ON s.transaction_id=t.id JOIN categories c ON c.id=s.category_id
         WHERE t.status='POSTED' AND t.deleted_at IS NULL AND t.local_date>=? AND t.local_date<=? AND t.type IN ('EXPENSE','REFUND')
         GROUP BY c.id HAVING total > 0 ORDER BY total DESC LIMIT 1''',
      [startIso, today],
    );
'''
new_cat_query = r'''    final expenseCategoryRows = _db.select(
      '''SELECT c.name, SUM(CASE WHEN t.type='EXPENSE' THEN s.amount_minor WHEN t.type='REFUND' THEN -s.amount_minor ELSE 0 END) AS total
         FROM transactions t JOIN transaction_splits s ON s.transaction_id=t.id JOIN categories c ON c.id=s.category_id
         WHERE t.status='POSTED' AND t.deleted_at IS NULL AND t.local_date>=? AND t.local_date<=? AND t.type IN ('EXPENSE','REFUND')
         GROUP BY c.id HAVING total > 0 ORDER BY total DESC''',
      [startIso, today],
    );
    final incomeCategoryRows = _db.select(
      '''SELECT c.name, SUM(s.amount_minor) AS total
         FROM transactions t JOIN transaction_splits s ON s.transaction_id=t.id JOIN categories c ON c.id=s.category_id
         WHERE t.status='POSTED' AND t.deleted_at IS NULL AND t.local_date>=? AND t.local_date<=? AND t.type='INCOME'
         GROUP BY c.id HAVING total > 0 ORDER BY total DESC''',
      [startIso, today],
    );
'''
replace_once('lib/data/local_finance_repository.dart', old_cat_query, new_cat_query)
replace_once(
    'lib/data/local_finance_repository.dart',
    "      largestCategory: catRows.isEmpty ? null : catRows.first['name'] as String,\n      largestCategoryAmountMinor: catRows.isEmpty ? 0 : catRows.first['total'] as int,\n",
    "      largestCategory: expenseCategoryRows.isEmpty ? null : expenseCategoryRows.first['name'] as String,\n"
    "      largestCategoryAmountMinor: expenseCategoryRows.isEmpty ? 0 : expenseCategoryRows.first['total'] as int,\n"
    "      expenseCategoryBreakdown: expenseCategoryRows\n"
    "          .map((r) => CategoryBreakdownItem(name: r['name'] as String, amountMinor: r['total'] as int))\n"
    "          .toList(growable: false),\n"
    "      incomeCategoryBreakdown: incomeCategoryRows\n"
    "          .map((r) => CategoryBreakdownItem(name: r['name'] as String, amountMinor: r['total'] as int))\n"
    "          .toList(growable: false),\n",
)

write(
    'lib/shared/category_donut_card.dart',
    r'''import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/models.dart';
import 'money.dart';

class CategoryDonutCard extends StatefulWidget {
  const CategoryDonutCard({
    super.key,
    required this.expenseItems,
    required this.incomeItems,
    required this.currency,
  });

  final List<CategoryBreakdownItem> expenseItems;
  final List<CategoryBreakdownItem> incomeItems;
  final String currency;

  @override
  State<CategoryDonutCard> createState() => _CategoryDonutCardState();
}

class _CategoryDonutCardState extends State<CategoryDonutCard> {
  bool _income = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final source = _income ? widget.incomeItems : widget.expenseItems;
    final items = _compact(source);
    final total = source.fold<int>(0, (sum, item) => sum + item.amountMinor);
    final colors = _palette(theme.colorScheme, items.length);
    final kind = _income ? 'Pemasukan' : 'Pengeluaran';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Komposisi kategori',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Persentase bulan berjalan',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Pengeluaran')),
                ButtonSegment(value: true, label: Text('Pemasukan')),
              ],
              selected: {_income},
              onSelectionChanged: (value) => setState(() => _income = value.first),
            ),
            const SizedBox(height: 18),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Text(
                  'Belum ada ${kind.toLowerCase()} bulan ini.',
                  textAlign: TextAlign.center,
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final chart = _chart(
                    context,
                    kind: kind,
                    items: items,
                    colors: colors,
                    total: total,
                  );
                  final legend = _legend(
                    context,
                    items: items,
                    colors: colors,
                    total: total,
                  );
                  if (constraints.maxWidth < 430) {
                    return Column(
                      children: [
                        chart,
                        const SizedBox(height: 18),
                        legend,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      chart,
                      const SizedBox(width: 22),
                      Expanded(child: legend),
                    ],
                  );
                },
              ),
            if (items.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                'Total $kind: ${Money.format(total, currency: widget.currency)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chart(
    BuildContext context, {
    required String kind,
    required List<CategoryBreakdownItem> items,
    required List<Color> colors,
    required int total,
  }) {
    final semantics = items.map((item) {
      final pct = total == 0 ? 0 : item.amountMinor * 100 / total;
      return '${item.name} ${pct.toStringAsFixed(pct >= 10 ? 0 : 1)} persen';
    }).join(', ');
    return Semantics(
      label: 'Diagram donat $kind bulan ini: $semantics',
      child: SizedBox.square(
        dimension: 164,
        child: CustomPaint(
          painter: _DonutPainter(items: items, colors: colors),
          child: const Center(
            child: Text(
              '100%',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ),
    );
  }

  Widget _legend(
    BuildContext context, {
    required List<CategoryBreakdownItem> items,
    required List<Color> colors,
    required int total,
  }) {
    final theme = Theme.of(context);
    return Column(
      children: List.generate(items.length, (index) {
        final item = items[index];
        final pct = total == 0 ? 0 : item.amountMinor * 100 / total;
        final pctText = '${pct.toStringAsFixed(pct >= 10 ? 0 : 1)}%';
        return Padding(
          padding: EdgeInsets.only(bottom: index == items.length - 1 ? 0 : 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 5),
                decoration: BoxDecoration(
                  color: colors[index],
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: theme.textTheme.bodyMedium),
                    Text(
                      Money.format(item.amountMinor, currency: widget.currency),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                pctText,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  List<CategoryBreakdownItem> _compact(List<CategoryBreakdownItem> source) {
    if (source.length <= 6) return source;
    final top = source.take(5).toList(growable: true);
    final remaining = source.skip(5).fold<int>(0, (sum, item) => sum + item.amountMinor);
    top.add(CategoryBreakdownItem(name: 'Kategori lain', amountMinor: remaining));
    return top;
  }

  List<Color> _palette(ColorScheme scheme, int count) {
    final base = <Color>[
      scheme.primary,
      scheme.tertiary,
      scheme.secondary,
      scheme.error,
      scheme.primaryContainer,
      scheme.tertiaryContainer,
      scheme.secondaryContainer,
    ];
    return List.generate(count, (index) => base[index % base.length]);
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({required this.items, required this.colors});

  final List<CategoryBreakdownItem> items;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final total = items.fold<int>(0, (sum, item) => sum + item.amountMinor);
    if (total <= 0) return;
    const stroke = 25.0;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.shortestSide / 2 - stroke / 2,
    );
    var start = -math.pi / 2;
    for (var i = 0; i < items.length; i++) {
      final sweep = items[i].amountMinor / total * math.pi * 2;
      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.items != items || oldDelegate.colors != colors;
}
''',
)

replace_once(
    'lib/features/home/home_screen.dart',
    "import '../../shared/app_scope.dart';\n",
    "import '../../shared/app_scope.dart';\nimport '../../shared/category_donut_card.dart';\n",
)
replace_once(
    'lib/features/home/home_screen.dart',
    "        case 'largest_category':\n",
    "        case 'category_breakdown':\n"
    "          content = CategoryDonutCard(\n"
    "            expenseItems: data.expenseCategoryBreakdown,\n"
    "            incomeItems: data.incomeCategoryBreakdown,\n"
    "            currency: data.currency,\n"
    "          );\n"
    "          break;\n"
    "        case 'largest_category':\n",
)
replace_once(
    'lib/core/services/dashboard_preferences_service.dart',
    "    'income_month',\n    'net_worth',",
    "    'income_month',\n    'category_breakdown',\n    'net_worth',",
)
replace_once(
    'lib/core/services/dashboard_preferences_service.dart',
    "    'income_month': 'Pemasukan bulan ini',\n    'net_worth': 'Net worth',",
    "    'income_month': 'Pemasukan bulan ini',\n    'category_breakdown': 'Komposisi kategori',\n    'net_worth': 'Net worth',",
)

# ---------------------------------------------------------------------------
# 6. Regression tests for formatter + donut presentation.
# ---------------------------------------------------------------------------
write(
    'test/idr_input_formatter_test.dart',
    r'''import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arus_finance/shared/idr_input_formatter.dart';
import 'package:arus_finance/shared/money.dart';

void main() {
  const formatter = IdrInputFormatter();

  TextEditingValue apply(String text) => formatter.formatEditUpdate(
        const TextEditingValue(),
        TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        ),
      );

  test('groups IDR thousands while preserving numeric value', () {
    expect(apply('1000').text, '1.000');
    expect(apply('100000').text, '100.000');
    expect(apply('1000000').text, '1.000.000');
    expect(Money.parseIdr(apply('1250000').text), 1250000);
  });

  test('pasted separators are normalized', () {
    expect(apply('Rp 1.234.567').text, '1.234.567');
    expect(apply('001000').text, '1.000');
  });
}
''',
)
write(
    'test/category_donut_card_test.dart',
    r'''import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arus_finance/domain/models.dart';
import 'package:arus_finance/shared/category_donut_card.dart';

void main() {
  testWidgets('donut switches between expense and income category percentages', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CategoryDonutCard(
              currency: 'IDR',
              expenseItems: [
                CategoryBreakdownItem(name: 'Makanan', amountMinor: 60000),
                CategoryBreakdownItem(name: 'Transport', amountMinor: 40000),
              ],
              incomeItems: [
                CategoryBreakdownItem(name: 'Gaji', amountMinor: 1000000),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Makanan'), findsOneWidget);
    expect(find.text('60%'), findsOneWidget);
    expect(find.text('Transport'), findsOneWidget);

    await tester.tap(find.text('Pemasukan'));
    await tester.pumpAndSettle();

    expect(find.text('Gaji'), findsOneWidget);
    expect(find.text('100%'), findsWidgets);
    expect(find.text('Makanan'), findsNothing);
  });
}
''',
)

# ---------------------------------------------------------------------------
# 7. V29 source audit + UAT note.
# ---------------------------------------------------------------------------
write(
    'tool/deep_mine_v29_ux_audit.py',
    r'''from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
read = lambda p: (ROOT / p).read_text()

quick = read('lib/features/quick_add/quick_add_sheet.dart')
repo = read('lib/data/local_finance_repository.dart')
models = read('lib/domain/models.dart')
home = read('lib/features/home/home_screen.dart')
cats = read('lib/features/settings/categories_screen.dart')
formatter = read('lib/shared/idr_input_formatter.dart')
donut = read('lib/shared/category_donut_card.dart')

checks = {
    'IDR formatter inserts dot grouping': "out.write('.')" in formatter,
    'Quick Add amount uses formatter': 'inputFormatters: const [IdrInputFormatter()]' in quick,
    'Quick Add waits for keyboard dismissal': 'MediaQuery.viewInsetsOf(context).bottom <= 0' in quick,
    'Quick Add account selector no longer anchored dropdown': "title: 'Pilih account'" in quick and '_selectionField(' in quick,
    'Category rename repository contract retained': 'Future<void> renameCategory' in repo,
    'Transfer fee system category remains protected': 'kategori sistem' in repo and "row['name'] == 'Biaya Transfer'" in repo,
    'Category rename UI retained': "value: 'edit'" in cats and 'Edit nama' in cats,
    'Dashboard exposes expense breakdown': 'expenseCategoryBreakdown' in models and 'expenseCategoryRows' in repo,
    'Dashboard exposes income breakdown': 'incomeCategoryBreakdown' in models and 'incomeCategoryRows' in repo,
    'Home category donut retained': "case 'category_breakdown'" in home and 'CategoryDonutCard' in home,
    'Donut has expense/income toggle': "Text('Pengeluaran')" in donut and "Text('Pemasukan')" in donut,
    'Donut remains dependency-free CustomPainter': 'extends CustomPainter' in donut,
}

failed = [name for name, ok in checks.items() if not ok]
for name, ok in checks.items():
    print(('PASS' if ok else 'FAIL') + ': ' + name)
if failed:
    raise SystemExit(f'FAIL: V29 UX audit failed: {len(failed)}')
print(f'PASS: V29 UX audit {len(checks)}/{len(checks)}')
''',
)

replace_once(
    'tool/run_all_audits.sh',
    "python3 tool/deep_mine_v27_git_bootstrap_audit.py\n",
    "python3 tool/deep_mine_v27_git_bootstrap_audit.py\npython3 tool/deep_mine_v29_ux_audit.py\n",
)

write(
    'docs/V29_UX_DEVICE_FEEDBACK.md',
    '''# V29 UX / Android Device Feedback\n\nDevice UAT feedback from vivo 1915 / Android 12 is carried forward as product requirements:\n\n- IDR monetary entry visually groups thousands with `.` while typing.\n- Quick Add must dismiss the keyboard fully before account/category selection opens; the selector must never remain anchored to the pre-keyboard layout.\n- Default expense/income categories remain local starter data. Users may add, rename, and archive categories; the current automatic transfer-fee category stays protected until a stable schema-level system key exists.\n- Home includes a dependency-free donut chart for current-month expense/income composition by category and exposes percentages plus amounts.\n- Android `FLAG_SECURE` screenshot blocking remains intentional and passed the first device UAT batch.\n''',
)

print('PASS: guarded V29 UX patch applied')
