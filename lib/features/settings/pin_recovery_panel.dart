import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/services/security_service.dart';

class PinRecoveryPanel extends StatefulWidget {
  const PinRecoveryPanel({
    super.key,
    required this.security,
    required this.onRecovered,
    required this.onCancel,
  });

  final SecurityService security;
  final VoidCallback onRecovered;
  final VoidCallback onCancel;

  @override
  State<PinRecoveryPanel> createState() => _PinRecoveryPanelState();
}

class _PinRecoveryPanelState extends State<PinRecoveryPanel> {
  final _recovery = TextEditingController();
  final _pin = TextEditingController();
  final _confirm = TextEditingController();

  bool _loading = true;
  bool _busy = false;
  bool _hasRecovery = false;
  bool _biometricRecovery = false;
  bool _savedReplacement = false;
  String? _replacementCode;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  @override
  void dispose() {
    _recovery.dispose();
    _pin.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    final hasRecovery = await widget.security.hasRecoveryCode();
    final biometricEnabled = await widget.security.biometricEnabled();
    final biometricAvailable =
        biometricEnabled && await widget.security.canUseBiometrics();
    if (!mounted) return;
    setState(() {
      _hasRecovery = hasRecovery;
      _biometricRecovery = biometricAvailable;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _replacementCode != null
                      ? _buildReplacement(theme)
                      : _buildResetForm(theme),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResetForm(ThemeData theme) {
    final canRecover = _hasRecovery || _biometricRecovery;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          Icons.lock_reset_rounded,
          size: 54,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          'Pulihkan PIN',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          canRecover
              ? 'Buat PIN baru menggunakan kode pemulihan atau biometrik yang sebelumnya sudah kamu aktifkan di Arus.'
              : 'Perangkat ini belum memiliki kode pemulihan atau biometrik Arus yang aktif.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (!canRecover) ...[
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              'Arus tidak memiliki server atau akun online untuk melewati PIN. Jika PIN masih kamu ingat, kembali lalu buka Arus dan buat kode pemulihan dari Pengaturan.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
        if (canRecover) ...[
          const SizedBox(height: 22),
          TextField(
            key: const Key('recovery_new_pin_input'),
            controller: _pin,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            inputFormatters: const [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(8),
            ],
            decoration: const InputDecoration(labelText: 'PIN baru'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('recovery_confirm_pin_input'),
            controller: _confirm,
            obscureText: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            inputFormatters: const [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(8),
            ],
            decoration: const InputDecoration(labelText: 'Ulangi PIN baru'),
          ),
        ],
        if (_hasRecovery) ...[
          const SizedBox(height: 18),
          TextField(
            key: const Key('recovery_code_input'),
            controller: _recovery,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Kode pemulihan',
              hintText: 'XXXX-XXXX-XXXX-XXXX',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ? null : _resetWithCode,
            icon: const Icon(Icons.key_rounded),
            label: Text(_busy ? 'Memeriksa…' : 'Reset dengan kode'),
          ),
        ],
        if (_biometricRecovery) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy ? null : _resetWithBiometric,
            icon: const Icon(Icons.fingerprint_rounded),
            label: const Text('Reset dengan biometrik'),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        TextButton(
          onPressed: _busy ? null : widget.onCancel,
          child: const Text('Kembali ke PIN'),
        ),
      ],
    );
  }

  Widget _buildReplacement(ThemeData theme) {
    final code = _replacementCode!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          Icons.verified_user_rounded,
          size: 54,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          'PIN berhasil diganti',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Kode pemulihan lama sudah tidak berlaku. Simpan kode baru ini karena Arus tidak menyimpan plaintext-nya.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              SelectableText(
                code,
                key: const Key('replacement_recovery_code'),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: code));
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Kode baru disalin.')),
                  );
                },
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Salin kode baru'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        CheckboxListTile(
          key: const Key('replacement_recovery_saved'),
          contentPadding: EdgeInsets.zero,
          value: _savedReplacement,
          onChanged: (value) =>
              setState(() => _savedReplacement = value ?? false),
          title: const Text('Saya sudah menyimpan kode baru ini'),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _savedReplacement ? widget.onRecovered : null,
          child: const Text('Buka Arus'),
        ),
      ],
    );
  }

  String? _validateNewPin() {
    final pin = _pin.text;
    if (!RegExp(r'^\d{4,8}$').hasMatch(pin)) {
      return 'PIN baru harus terdiri dari 4–8 digit.';
    }
    if (pin != _confirm.text) {
      return 'Ulangi PIN baru dengan angka yang sama.';
    }
    return null;
  }

  Future<void> _resetWithCode() async {
    final validation = _validateNewPin();
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final replacement = await widget.security.resetPinWithRecoveryCode(
        recoveryCode: _recovery.text,
        newPin: _pin.text,
      );
      if (!mounted) return;
      if (replacement == null) {
        final lockedUntil = await widget.security.recoveryLockedUntil();
        if (!mounted) return;
        if (lockedUntil != null) {
          final seconds =
              lockedUntil.difference(DateTime.now().toUtc()).inSeconds + 1;
          setState(() {
            _error =
                'Terlalu banyak percobaan kode. Coba lagi sekitar $seconds detik.';
          });
        } else {
          setState(() => _error = 'Kode pemulihan tidak cocok.');
        }
        return;
      }
      setState(() {
        _replacementCode = replacement;
        _savedReplacement = false;
        _pin.clear();
        _confirm.clear();
        _recovery.clear();
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'PIN belum berhasil dipulihkan. Coba lagi.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetWithBiometric() async {
    final validation = _validateNewPin();
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final replacement = await widget.security.resetPinWithBiometric(
        newPin: _pin.text,
      );
      if (!mounted) return;
      if (replacement == null) {
        setState(() {
          _error = widget.security.lastBiometricError ??
              'Biometrik tidak berhasil memulihkan PIN.';
        });
        return;
      }
      setState(() {
        _replacementCode = replacement;
        _savedReplacement = false;
        _pin.clear();
        _confirm.clear();
        _recovery.clear();
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'PIN belum berhasil dipulihkan. Coba lagi.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
