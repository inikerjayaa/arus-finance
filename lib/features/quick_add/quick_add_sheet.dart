import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../domain/enums.dart';
import '../../domain/models.dart';
import '../../shared/app_scope.dart';
import '../../shared/category_choice_tile.dart';
import '../../shared/idr_input_formatter.dart';
import '../../shared/money.dart';

class QuickAddSheet extends StatefulWidget {
  const QuickAddSheet({super.key});

  static Future<void> show(BuildContext context, AppController controller) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      showDragHandle: false,
      builder: (_) => AppScope(
        controller: controller,
        child: const QuickAddSheet(),
      ),
    );
  }

  @override
  State<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<QuickAddSheet> {
  int _mode = 0;
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String? _accountId;
  String? _categoryId;
  String? _destinationId;
  int _feeMinor = 0;
  DateTime _date = DateTime.now();
  String? _amountError;
  String? _accountError;
  String? _categoryError;
  String? _destinationError;
  String? _feeError;
  String? _submitError;
  bool _dirty = false;
  bool _submitting = false;
  bool _allowPop = false;
  bool _closePromptOpen = false;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  List<Account> _eligibleAccounts(List<Account> all) {
    if (_mode == 1 || _mode == 2) {
      return all.where((a) => a.accountClass == AccountClass.asset).toList();
    }
    return all
        .where(
          (a) =>
              a.accountClass == AccountClass.asset ||
              a.accountType == AccountType.creditCard,
        )
        .toList();
  }

  void _normalizeSelections(AppController controller) {
    final categories =
        _mode == 1 ? controller.incomeCategories : controller.expenseCategories;
    final eligible = _eligibleAccounts(controller.accounts);
    if (!eligible.any((a) => a.id == _accountId)) {
      _accountId = eligible.firstOrNull?.id;
    }
    if (_mode == 2) {
      if (!_eligibleAccounts(controller.accounts).any((a) => a.id == _destinationId) ||
          _destinationId == _accountId) {
        _destinationId = eligible.where((a) => a.id != _accountId).firstOrNull?.id;
      }
    } else {
      _destinationId = null;
      if (!categories.any((c) => c.id == _categoryId)) {
        _categoryId = categories.firstOrNull?.id;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    _normalizeSelections(controller);
    final categories =
        _mode == 1 ? controller.incomeCategories : controller.expenseCategories;
    final eligibleAccounts = _eligibleAccounts(controller.accounts);

    return PopScope<void>(
      canPop: _allowPop || (!_dirty && !_submitting),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestClose(context);
      },
      child: Padding(
        padding: EdgeInsets.only(
          left: 18,
          right: 18,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 18,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        'Catat transaksi',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Tutup pencatatan transaksi',
                    onPressed: _submitting ? null : () => _requestClose(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('Keluar'), icon: Icon(Icons.arrow_upward_rounded)),
                  ButtonSegment(value: 1, label: Text('Masuk'), icon: Icon(Icons.arrow_downward_rounded)),
                  ButtonSegment(value: 2, label: Text('Transfer'), icon: Icon(Icons.swap_horiz_rounded)),
                ],
                selected: {_mode},
                onSelectionChanged: (value) => setState(() {
                  _mode = value.first;
                  _dirty = true;
                  _accountId = null;
                  _categoryId = null;
                  _destinationId = null;
                  _amountError = null;
                  _accountError = null;
                  _categoryError = null;
                  _destinationError = null;
                  _feeError = null;
                  _submitError = null;
                }),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _amount,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: const [IdrInputFormatter()],
                textInputAction: TextInputAction.next,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
                decoration: InputDecoration(
                  prefixText: 'Rp ',
                  hintText: '0',
                  labelText: 'Nominal',
                  errorText: _amountError,
                ),
                onChanged: (_) {
                  setState(() {
                    _dirty = true;
                    _amountError = null;
                    _submitError = null;
                  });
                },
              ),
              const SizedBox(height: 12),
              _selectionField(
                context: context,
                label: _mode == 2 ? 'Dari account' : 'Account',
                value: eligibleAccounts.where((a) => a.id == _accountId).firstOrNull?.name,
                errorText: _accountError,
                onTap: eligibleAccounts.isEmpty
                    ? null
                    : () async {
                        final picked = await _pickChoice(
                          context,
                          title: _mode == 2 ? 'Pilih account asal' : 'Pilih account',
                          selected: _accountId,
                          choices: eligibleAccounts.map((a) => _PickerChoice(a.id, a.name)).toList(growable: false),
                        );
                        if (!mounted || picked == null) return;
                        setState(() {
                          _dirty = true;
                          _accountId = picked;
                          _accountError = null;
                          if (_mode == 2 && _destinationId == picked) {
                            _destinationId = eligibleAccounts.where((a) => a.id != picked).firstOrNull?.id;
                          }
                        });
                      },
              ),
              if (_mode == 2) ...[
                const SizedBox(height: 12),
                _selectionField(
                  context: context,
                  label: 'Ke account',
                  value: eligibleAccounts.where((a) => a.id == _destinationId).firstOrNull?.name,
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
                const SizedBox(height: 12),
                TextFormField(
                  keyboardType: TextInputType.number,
                  inputFormatters: const [IdrInputFormatter()],
                  decoration: InputDecoration(
                    labelText: 'Biaya transfer (opsional)',
                    prefixText: 'Rp ',
                    errorText: _feeError,
                  ),
                  onChanged: (value) {
                    final trimmed = value.trim();
                    final parsed = trimmed.isEmpty ? 0 : Money.parseIdr(trimmed);
                    setState(() {
                      _dirty = true;
                      _feeMinor = parsed ?? 0;
                      _feeError = parsed == null ? 'Masukkan biaya yang valid.' : null;
                    });
                  },
                ),
              ] else ...[
                const SizedBox(height: 12),
                _selectionField(
                  context: context,
                  label: 'Kategori',
                  value: categories.where((c) => c.id == _categoryId).firstOrNull?.name,
                  errorText: _categoryError,
                  onTap: categories.isEmpty
                      ? null
                      : () async {
                          final picked = await showCategoryChoicePicker(
                            context,
                            title: _mode == 1
                                ? 'Pilih kategori pemasukan'
                                : 'Pilih kategori pengeluaran',
                            selectedId: _categoryId,
                            categories: categories,
                          );
                          if (!mounted || picked == null) return;
                          setState(() {
                            _dirty = true;
                            _categoryId = picked;
                            _categoryError = null;
                          });
                        },
                ),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                    initialDate: _date,
                  );
                  if (picked != null && mounted) {
                    final now = DateTime.now();
                    setState(() {
                      _dirty = true;
                      _date = DateTime(picked.year, picked.month, picked.day, now.hour, now.minute);
                    });
                  }
                },
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text('${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _note,
                maxLines: 2,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(labelText: 'Catatan (opsional)'),
                onChanged: (_) => setState(() => _dirty = true),
              ),
              if (_submitError != null) ...[
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: Text(_submitError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: controller.busy || _submitting || eligibleAccounts.isEmpty ? null : () => _save(context),
                icon: const Icon(Icons.check_rounded),
                label: Text(controller.busy || _submitting ? 'Menyimpan…' : 'Simpan'),
              ),
              if (eligibleAccounts.isEmpty) ...[
                const SizedBox(height: 8),
                const Text(
                  'Belum ada account yang dapat dipakai untuk tipe transaksi ini.',
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }

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
              Expanded(child: Text(value ?? 'Pilih $label', overflow: TextOverflow.ellipsis)),
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
              style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 8),
          ...choices.map(
            (choice) => ListTile(
              leading: Icon(choice.id == selected ? Icons.radio_button_checked : Icons.radio_button_unchecked),
              title: Text(choice.label),
              onTap: () => Navigator.pop(sheetContext, choice.id),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _requestClose(BuildContext context) async {
    if (_submitting || _closePromptOpen) return;
    if (!_dirty) {
      _allowPop = true;
      setState(() {});
      await Future<void>.delayed(Duration.zero);
      if (context.mounted) Navigator.of(context).pop();
      return;
    }
    _closePromptOpen = true;
    bool? discard;
    try {
      discard = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Buang perubahan?'),
          content: const Text('Transaksi ini belum disimpan. Jika ditutup sekarang, isian yang sudah dibuat akan hilang.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Lanjut mengisi')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Buang isian')),
          ],
        ),
      );
    } finally {
      _closePromptOpen = false;
    }
    if (discard != true || !context.mounted) return;
    _allowPop = true;
    setState(() {});
    await Future<void>.delayed(Duration.zero);
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _save(BuildContext context) async {
    if (_submitting) return;
    final controller = AppScope.of(context);
    final amount = Money.parseIdr(_amount.text);
    final amountError = amount == null || amount <= 0 ? 'Masukkan nominal lebih besar dari 0.' : null;
    final accountError = _accountId == null ? 'Pilih account.' : null;
    final categoryError = _mode != 2 && _categoryId == null ? 'Pilih kategori.' : null;
    final destinationError = _mode == 2 && _destinationId == null ? 'Pilih account tujuan.' : null;
    if (amountError != null || accountError != null || categoryError != null || destinationError != null || _feeError != null) {
      setState(() {
        _amountError = amountError;
        _accountError = accountError;
        _categoryError = categoryError;
        _destinationError = destinationError;
        _submitError = 'Periksa kembali field yang ditandai.';
      });
      return;
    }
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    Object? result;
    if (_mode == 0) {
      result = await controller.run(
        () => controller.repository.createExpense(
          amountMinor: amount!,
          accountId: _accountId!,
          categoryId: _categoryId!,
          occurredAt: _date,
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        ),
      );
    } else if (_mode == 1) {
      result = await controller.run(
        () => controller.repository.createIncome(
          amountMinor: amount!,
          accountId: _accountId!,
          categoryId: _categoryId!,
          occurredAt: _date,
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        ),
      );
    } else {
      result = await controller.run(
        () => controller.repository.createTransfer(
          amountMinor: amount!,
          sourceAccountId: _accountId!,
          destinationAccountId: _destinationId!,
          occurredAt: _date,
          feeMinor: _feeMinor,
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        ),
      );
    }
    if (!context.mounted) return;
    if (result != null) {
      _dirty = false;
      _allowPop = true;
      _submitting = false;
      setState(() {});
      await Future<void>.delayed(Duration.zero);
      if (context.mounted) Navigator.of(context).pop();
      return;
    }
    setState(() {
      _submitting = false;
      _submitError = controller.errorMessage ?? 'Transaksi belum berhasil disimpan.';
    });
  }
}

class _PickerChoice {
  const _PickerChoice(this.id, this.label);
  final String id;
  final String label;
}

extension FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
