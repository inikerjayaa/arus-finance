import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../domain/enums.dart';
import '../../domain/models.dart';
import '../../shared/app_scope.dart';
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
  int _mode = 0; // 0 expense, 1 income, 2 transfer
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
    if (_mode == 1) {
      return all.where((a) => a.accountClass == AccountClass.asset).toList();
    }
    if (_mode == 2) {
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
                ButtonSegment(
                  value: 0,
                  label: Text('Keluar'),
                  icon: Icon(Icons.arrow_upward_rounded),
                ),
                ButtonSegment(
                  value: 1,
                  label: Text('Masuk'),
                  icon: Icon(Icons.arrow_downward_rounded),
                ),
                ButtonSegment(
                  value: 2,
                  label: Text('Transfer'),
                  icon: Icon(Icons.swap_horiz_rounded),
                ),
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
              textInputAction: TextInputAction.next,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
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
            DropdownButtonFormField<String>(
              initialValue: _accountId,
              decoration: InputDecoration(
                labelText: _mode == 2 ? 'Dari account' : 'Account',
                errorText: _accountError,
              ),
              items: eligibleAccounts
                  .map(
                    (a) => DropdownMenuItem(
                      value: a.id,
                      child: Text(a.name, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() {
                _dirty = true;
                _accountId = value;
                _accountError = null;
                if (_mode == 2 && _destinationId == value) {
                  _destinationId = eligibleAccounts
                      .where((a) => a.id != value)
                      .firstOrNull
                      ?.id;
                }
              }),
            ),
            if (_mode == 2) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _destinationId,
                decoration: InputDecoration(
                  labelText: 'Ke account',
                  errorText: _destinationError,
                ),
                items: eligibleAccounts
                    .where((a) => a.id != _accountId)
                    .map(
                      (a) => DropdownMenuItem(
                        value: a.id,
                        child: Text(a.name, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() {
                  _dirty = true;
                  _destinationId = value;
                  _destinationError = null;
                }),
              ),
              const SizedBox(height: 12),
              TextFormField(
                keyboardType: TextInputType.number,
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
              DropdownButtonFormField<String>(
                initialValue: _categoryId,
                decoration: InputDecoration(
                  labelText: 'Kategori',
                  errorText: _categoryError,
                ),
                items: categories
                    .map(
                      (c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(c.name, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() {
                  _dirty = true;
                  _categoryId = value;
                  _categoryError = null;
                }),
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
                  setState(
                    () {
                      _dirty = true;
                      _date = DateTime(
                      picked.year,
                      picked.month,
                      picked.day,
                      now.hour,
                      now.minute,
                    );
                    },
                  );
                }
              },
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text(
                '${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}',
              ),
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
                child: Text(
                  _submitError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: controller.busy || _submitting || eligibleAccounts.isEmpty
                  ? null
                  : () => _save(context),
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

  Future<void> _requestClose(BuildContext context) async {
    if (_submitting || _closePromptOpen) return;
    if (!_dirty) {
      _allowPop = true;
      setState(() {});
      await Future<void>.delayed(Duration.zero);
      if (mounted) Navigator.of(context).pop();
      return;
    }
    _closePromptOpen = true;
    bool? discard;
    try {
      discard = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Buang perubahan?'),
          content: const Text(
            'Transaksi ini belum disimpan. Jika ditutup sekarang, isian yang sudah dibuat akan hilang.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Lanjut mengisi'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Buang isian'),
            ),
          ],
        ),
      );
    } finally {
      _closePromptOpen = false;
    }
    if (discard != true || !mounted) return;
    _allowPop = true;
    setState(() {});
    await Future<void>.delayed(Duration.zero);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _save(BuildContext context) async {
    if (_submitting) return;
    final controller = AppScope.of(context);
    final amount = Money.parseIdr(_amount.text);
    final amountError = amount == null || amount <= 0
        ? 'Masukkan nominal lebih besar dari 0.'
        : null;
    final accountError = _accountId == null ? 'Pilih account.' : null;
    final categoryError = _mode != 2 && _categoryId == null
        ? 'Pilih kategori.'
        : null;
    final destinationError = _mode == 2 && _destinationId == null
        ? 'Pilih account tujuan.'
        : null;
    if (amountError != null ||
        accountError != null ||
        categoryError != null ||
        destinationError != null ||
        _feeError != null) {
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
    if (!mounted) return;
    if (result != null) {
      _dirty = false;
      _allowPop = true;
      _submitting = false;
      setState(() {});
      await Future<void>.delayed(Duration.zero);
      if (mounted) Navigator.of(context).pop();
      return;
    }
    setState(() {
      _submitting = false;
      _submitError = controller.errorMessage ?? 'Transaksi belum berhasil disimpan.';
    });
  }
}

extension FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
