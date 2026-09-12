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
        raise SystemExit(f'FAIL: {rel}: expected exactly 1 match, got {count}: {old[:120]!r}')
    write(rel, text.replace(old, new, 1))


def replace_count(rel: str, old: str, new: str, expected: int) -> None:
    text = read(rel)
    count = text.count(old)
    if count != expected:
        raise SystemExit(f'FAIL: {rel}: expected {expected} matches, got {count}: {old[:120]!r}')
    write(rel, text.replace(old, new))


def replace_slice(rel: str, start: str, end: str, replacement: str) -> None:
    text = read(rel)
    a = text.find(start)
    if a < 0:
        raise SystemExit(f'FAIL: {rel}: start marker not found: {start[:120]!r}')
    b = text.find(end, a)
    if b < 0:
        raise SystemExit(f'FAIL: {rel}: end marker not found: {end[:120]!r}')
    if text.find(start, a + 1) >= 0:
        raise SystemExit(f'FAIL: {rel}: start marker ambiguous: {start[:120]!r}')
    write(rel, text[:a] + replacement + text[b:])


# ---------------------------------------------------------------------------
# A. IDR input grouping while typing.
# ---------------------------------------------------------------------------
write(
    'lib/shared/idr_input_formatter.dart',
    r'''import 'package:flutter/services.dart';

/// Formats integer IDR input with Indonesian thousand separators while typing.
/// Persistence remains canonical through Money.parseIdr/repository validation.
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

    final selectionEnd = newValue.selection.extentOffset
        .clamp(0, newValue.text.length);
    final digitsToRight = RegExp(r'\d')
        .allMatches(newValue.text.substring(selectionEnd))
        .length;
    var caret = formatted.length;
    if (digitsToRight > 0) {
      var seen = 0;
      for (var i = formatted.length - 1; i >= 0; i--) {
        if (RegExp(r'\d').hasMatch(formatted[i])) seen++;
        if (seen == digitsToRight) {
          caret = i;
          break;
        }
      }
    }

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

# Quick Add: formatter + selector race fix.
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

replace_slice(
    'lib/features/quick_add/quick_add_sheet.dart',
    "            DropdownButtonFormField<String>(\n              initialValue: _accountId,",
    "            if (_mode == 2) ...[\n",
    r'''            _selectionField(
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
                        title: _mode == 2
                            ? 'Pilih account asal'
                            : 'Pilih account',
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
''',
)

replace_slice(
    'lib/features/quick_add/quick_add_sheet.dart',
    "              DropdownButtonFormField<String>(\n                initialValue: _destinationId,",
    "              const SizedBox(height: 12),\n              TextFormField(\n",
    r'''              _selectionField(
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
                        final picked = await _pickChoice(
                          context,
                          title: 'Pilih account tujuan',
                          selected: _destinationId,
                          choices: eligibleAccounts
                              .where((a) => a.id != _accountId)
                              .map((a) => _PickerChoice(a.id, a.name))
                              .toList(growable: false),
                        );
                        if (!mounted || picked == null) return;
                        setState(() {
                          _dirty = true;
                          _destinationId = picked;
                          _destinationError = null;
                        });
                      },
              ),
''',
)

replace_slice(
    'lib/features/quick_add/quick_add_sheet.dart',
    "              DropdownButtonFormField<String>(\n                initialValue: _categoryId,",
    "            ],\n            const SizedBox(height: 12),\n            OutlinedButton.icon(\n",
    r'''              _selectionField(
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
''',
)

quick_helpers = r'''
  Widget _selectionField({
    required BuildContext context,
    required String label,
    required String? value,
    required String? errorText,
    required VoidCallback? onTap,
  }) {
    return InkWell(
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
    );
  }

  Future<String?> _pickChoice(
    BuildContext context, {
    required String title,
    required List<_PickerChoice> choices,
    String? selected,
  }) async {
    // Android can position a Dropdown overlay using the pre-keyboard layout.
    // Dismiss the IME and wait for viewInsets to settle before opening a
    // selector that is independent from the old field anchor.
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
          Text(
            title,
            style: Theme.of(sheetContext)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
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

# Apply formatter to the rest of user-facing money entry surfaces.
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
    "TextField(controller: observed, keyboardType: const TextInputType.numberWithOptions(signed: true), inputFormatters: const [IdrInputFormatter(allowNegative: true)], decoration: const InputDecoration(labelText: 'Saldo yang terlihat', prefixText: 'Rp ')),",
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
replace_count(
    'lib/features/planning/planning_screen.dart',
    "TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Nominal', prefixText: 'Rp ')),",
    "TextField(controller: amount, keyboardType: TextInputType.number, inputFormatters: const [IdrInputFormatter()], decoration: const InputDecoration(labelText: 'Nominal', prefixText: 'Rp ')),",
    2,
)
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
# B. Category management: seeded defaults remain, user can add/rename/archive.
#    Automatic transfer-fee category stays system-protected until a stable
#    schema-level system key exists.
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
    if (row['type'] == enumDbName(CategoryType.expense) &&
        row['name'] == 'Biaya Transfer') {
      throw StateError(
        'Biaya Transfer adalah kategori sistem dan belum dapat diganti nama.',
      );
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
    'lib/data/local_finance_repository.dart',
    "    final category = _categoryRow(categoryId);\n    if (category['archived_at'] != null) return;\n",
    "    final category = _categoryRow(categoryId);\n"
    "    if (category['archived_at'] != null) return;\n"
    "    if (category['type'] == enumDbName(CategoryType.expense) &&\n"
    "        category['name'] == 'Biaya Transfer') {\n"
    "      throw StateError('Biaya Transfer adalah kategori sistem dan tidak dapat diarsipkan.');\n"
    "    }\n",
)

replace_once(
    'lib/features/settings/categories_screen.dart',
    "        final category = list[index];\n        return ListTile(\n",
    "        final category = list[index];\n"
    "        final isSystem = type == CategoryType.expense && category.name == 'Biaya Transfer';\n"
    "        return ListTile(\n",
)
replace_once(
    'lib/features/settings/categories_screen.dart',
    "          title: Text(category.name),\n          trailing: PopupMenuButton<String>(\n",
    "          title: Text(category.name),\n"
    "          subtitle: isSystem\n"
    "              ? const Text('Kategori sistem • dipakai otomatis untuk biaya transfer')\n"
    "              : null,\n"
    "          trailing: isSystem\n"
    "              ? const Icon(Icons.lock_outline_rounded)\n"
    "              : PopupMenuButton<String>(\n",
)
replace_once(
    'lib/features/settings/categories_screen.dart',
    "            onSelected: (v) async {\n              if (v == 'archive') {\n",
    "            onSelected: (v) async {\n"
    "              if (v == 'edit') {\n"
    "                await _rename(context, category.id, category.name);\n"
    "              }\n"
    "              if (v == 'archive') {\n",
)
replace_once(
    'lib/features/settings/categories_screen.dart',
    "            itemBuilder: (_) => const [PopupMenuItem(value: 'archive', child: Text('Arsipkan'))],\n          ),\n",
    "            itemBuilder: (_) => const [\n"
    "              PopupMenuItem(value: 'edit', child: Text('Edit nama')),\n"
    "              PopupMenuItem(value: 'archive', child: Text('Arsipkan')),\n"
    "            ],\n"
    "          ),\n",
)

rename_ui = r'''

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
              await c.run(
                () => c.repository.renameCategory(categoryId, input.text),
              );
              if (ctx.mounted && c.errorMessage == null) {
                Navigator.pop(ctx, true);
              }
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
marker = "  @override\n  Widget build(BuildContext context) {\n    final c = AppScope.of(context);\n"
text = read('lib/features/settings/categories_screen.dart')
# The marker belongs to _CategoryList only; the top-level screen build does not
# start with AppScope lookup.
if text.count(marker) != 1:
    raise SystemExit(f'FAIL: categories rename insertion marker count={text.count(marker)}')
write(
    'lib/features/settings/categories_screen.dart',
    text.replace(marker, rename_ui + "\n" + marker, 1),
)

# ---------------------------------------------------------------------------
# C. Home category composition: native dependency-free donut.
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
    "    required this.largestCategoryAmountMinor,\n"
    "    this.expenseCategoryBreakdown = const [],\n"
    "    this.incomeCategoryBreakdown = const [],\n"
    "  });",
)
replace_once(
    'lib/domain/models.dart',
    "  final int largestCategoryAmountMinor;\n}\n\nclass BudgetModel",
    "  final int largestCategoryAmountMinor;\n"
    "  final List<CategoryBreakdownItem> expenseCategoryBreakdown;\n"
    "  final List<CategoryBreakdownItem> incomeCategoryBreakdown;\n"
    "}\n\nclass BudgetModel",
)

old_cat_query = r"""    final catRows = _db.select(
      '''SELECT c.name, SUM(CASE WHEN t.type='EXPENSE' THEN s.amount_minor WHEN t.type='REFUND' THEN -s.amount_minor ELSE 0 END) AS total
         FROM transactions t JOIN transaction_splits s ON s.transaction_id=t.id JOIN categories c ON c.id=s.category_id
         WHERE t.status='POSTED' AND t.deleted_at IS NULL AND t.local_date>=? AND t.local_date<=? AND t.type IN ('EXPENSE','REFUND')
         GROUP BY c.id HAVING total > 0 ORDER BY total DESC LIMIT 1''',
      [startIso, today],
    );
"""
new_cat_query = r"""    final expenseCategoryRows = _db.select(
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
"""
replace_once('lib/data/local_finance_repository.dart', old_cat_query, new_cat_query)
replace_once(
    'lib/data/local_finance_repository.dart',
    "      largestCategory: catRows.isEmpty ? null : catRows.first['name'] as String,\n"
    "      largestCategoryAmountMinor: catRows.isEmpty ? 0 : catRows.first['total'] as int,\n",
    "      largestCategory: expenseCategoryRows.isEmpty\n"
    "          ? null\n"
    "          : expenseCategoryRows.first['name'] as String,\n"
    "      largestCategoryAmountMinor: expenseCategoryRows.isEmpty\n"
    "          ? 0\n"
    "          : expenseCategoryRows.first['total'] as int,\n"
    "      expenseCategoryBreakdown: expenseCategoryRows\n"
    "          .map((r) => CategoryBreakdownItem(\n"
    "                name: r['name'] as String,\n"
    "                amountMinor: r['total'] as int,\n"
    "              ))\n"
    "          .toList(growable: false),\n"
    "      incomeCategoryBreakdown: incomeCategoryRows\n"
    "          .map((r) => CategoryBreakdownItem(\n"
    "                name: r['name'] as String,\n"
    "                amountMinor: r['total'] as int,\n"
    "              ))\n"
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
    final remaining = source
        .skip(5)
        .fold<int>(0, (sum, item) => sum + item.amountMinor);
    top.add(
      CategoryBreakdownItem(name: 'Kategori lain', amountMinor: remaining),
    );
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
  bool shouldRepaint(covariant _DonutPainter oldDelegate) => true;
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
    "    'income_month',\n    'net_worth',\n",
    "    'income_month',\n    'category_breakdown',\n    'net_worth',\n",
)
replace_once(
    'lib/core/services/dashboard_preferences_service.dart',
    "    'income_month': 'Pemasukan bulan ini',\n    'net_worth': 'Net worth',\n",
    "    'income_month': 'Pemasukan bulan ini',\n"
    "    'category_breakdown': 'Komposisi kategori',\n"
    "    'net_worth': 'Net worth',\n",
)
replace_once(
    'lib/core/services/dashboard_preferences_service.dart',
    "    final missing = defaultOrder.where((id) => !validStored.contains(id));\n    final order = [...validStored, ...missing];\n",
    "    final order = _mergeOrder(validStored);\n",
)
replace_once(
    'lib/core/services/dashboard_preferences_service.dart',
    "  Future<void> save(List<DashboardWidgetConfig> config) async {\n",
    r'''  static List<String> _mergeOrder(List<String> stored) {
    if (stored.isEmpty) return [...defaultOrder];
    final order = [...stored];
    for (var index = 0; index < defaultOrder.length; index++) {
      final id = defaultOrder[index];
      if (order.contains(id)) continue;
      final following = defaultOrder
          .skip(index + 1)
          .where(order.contains)
          .firstOrNull;
      if (following == null) {
        order.add(id);
      } else {
        order.insert(order.indexOf(following), id);
      }
    }
    return order;
  }

  Future<void> save(List<DashboardWidgetConfig> config) async {
''',
)
replace_once(
    'lib/core/services/dashboard_preferences_service.dart',
    "}\n",
    "}\n\nextension _FirstOrNull<T> on Iterable<T> {\n  T? get firstOrNull => isEmpty ? null : first;\n}\n",
)

# ---------------------------------------------------------------------------
# D. Tests and audit.
# ---------------------------------------------------------------------------
write(
    'test/idr_input_formatter_test.dart',
    r'''import 'package:arus_finance/shared/idr_input_formatter.dart';
import 'package:arus_finance/shared/money.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

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
    'test/category_management_test.dart',
    r'''import 'package:arus_finance/core/db/app_database.dart';
import 'package:arus_finance/data/local_finance_repository.dart';
import 'package:arus_finance/domain/enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late LocalFinanceRepository repo;

  setUp(() async {
    db = AppDatabase.inMemory();
    repo = LocalFinanceRepository(db, clock: () => DateTime(2026, 9, 12, 12));
    await repo.initialize();
  });

  tearDown(() => db.close());

  test('default expense and income categories are editable/addable', () async {
    final expenses = await repo.listCategories(type: CategoryType.expense);
    final incomes = await repo.listCategories(type: CategoryType.income);
    expect(expenses.any((c) => c.name == 'Makanan'), isTrue);
    expect(incomes.any((c) => c.name == 'Gaji'), isTrue);

    final food = expenses.firstWhere((c) => c.name == 'Makanan');
    await repo.renameCategory(food.id, 'Makan & Minum');
    expect(
      (await repo.listCategories(type: CategoryType.expense))
          .any((c) => c.name == 'Makan & Minum'),
      isTrue,
    );

    await repo.createCategory(name: 'Freelance', type: CategoryType.income);
    expect(
      (await repo.listCategories(type: CategoryType.income))
          .any((c) => c.name == 'Freelance'),
      isTrue,
    );
  });

  test('automatic transfer fee category cannot be renamed or archived', () async {
    final fee = (await repo.listCategories(type: CategoryType.expense))
        .firstWhere((c) => c.name == 'Biaya Transfer');
    await expectLater(
      repo.renameCategory(fee.id, 'Admin Bank'),
      throwsA(isA<StateError>()),
    );
    await expectLater(
      repo.archiveCategory(fee.id),
      throwsA(isA<StateError>()),
    );
  });
}
''',
)

write(
    'test/category_donut_card_test.dart',
    r'''import 'package:arus_finance/domain/models.dart';
import 'package:arus_finance/shared/category_donut_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('donut switches expense and income percentages', (tester) async {
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
    'Quick Add uses keyboard-independent picker': "title: 'Pilih account'" in quick and '_selectionField(' in quick,
    'Category rename repository contract': 'Future<void> renameCategory' in repo,
    'Transfer fee system category remains protected': 'kategori sistem' in repo and "category['name'] == 'Biaya Transfer'" in repo,
    'Category rename UI': "value: 'edit'" in cats and 'Edit nama' in cats,
    'Expense category breakdown': 'expenseCategoryBreakdown' in models and 'expenseCategoryRows' in repo,
    'Income category breakdown': 'incomeCategoryBreakdown' in models and 'incomeCategoryRows' in repo,
    'Home category donut': "case 'category_breakdown'" in home and 'CategoryDonutCard' in home,
    'Donut expense/income toggle': "Text('Pengeluaran')" in donut and "Text('Pemasukan')" in donut,
    'Donut uses native CustomPainter': 'extends CustomPainter' in donut,
}
failed = [name for name, ok in checks.items() if not ok]
for name, ok in checks.items():
    print(('PASS' if ok else 'FAIL') + ': ' + name)
if failed:
    raise SystemExit(f'FAIL: V29 UX audit {len(checks)-len(failed)}/{len(checks)}')
print(f'PASS: V29 UX audit {len(checks)}/{len(checks)}')
''',
)

run_all = ROOT / 'tool/run_all_audits.sh'
text = run_all.read_text()
needle = 'python3 tool/deep_mine_biometric_cancel_audit.py\n'
if needle not in text:
    raise SystemExit('FAIL: V29 audit insertion point missing')
if 'deep_mine_v29_ux_audit.py' not in text:
    run_all.write_text(text.replace(needle, needle + 'python3 tool/deep_mine_v29_ux_audit.py\n', 1))

write(
    'docs/V29_UX_DEVICE_FEEDBACK.md',
    '''# V29 UX / Android Device Feedback\n\nCarried forward from vivo 1915 / Android 12 device UAT:\n\n- Integer IDR entry groups thousands with `.` while typing (`1.000`, `100.000`, `1.000.000`).\n- Quick Add dismisses the keyboard before account/category selection and uses a bottom-sheet selector, preventing the old dropdown overlay from remaining at the keyboard position.\n- Expense and income starter categories remain seeded locally. Users can add, rename, and archive normal categories. `Biaya Transfer` remains visibly system-protected because transfer fees currently depend on it automatically.\n- Home includes a native dependency-free donut chart for current-month expense/income composition with percentages and amounts.\n- Android screenshot blocking remains intentional; the device UAT confirmed FLAG_SECURE behavior.\n''',
)

print('PASS: guarded V29 UX patch applied')
