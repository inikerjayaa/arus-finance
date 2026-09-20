import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/services/security_service.dart';

class RecoveryCodeSettingsScreen extends StatefulWidget {
  const RecoveryCodeSettingsScreen({
    super.key,
    required this.security,
    this.initialCode,
  });

  final SecurityService security;
  final String? initialCode;

  @override
  State<RecoveryCodeSettingsScreen> createState() =>
      _RecoveryCodeSettingsScreenState();
}

class _RecoveryCodeSettingsScreenState
    extends State<RecoveryCodeSettingsScreen> {
  late bool _loading;
  bool _busy = false;
  late bool _hasRecovery;
  bool _saved = false;
  late String? _code;
  String? _error;

  @override
  void initState() {
    super.initState();
    _code = widget.initialCode;
    _hasRecovery = widget.initialCode != null;
    _loading = widget.initialCode == null;
    if (_loading) _load();
  }

  Future<void> _load() async {
    final hasRecovery = await widget.security.hasRecoveryCode();
    if (!mounted) return;
    setState(() {
      _hasRecovery = hasRecovery;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Kode pemulihan')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 48),
                children: [
                  if (_code == null)
                    _buildOverview(theme)
                  else
                    _buildOneTimeCode(theme),
                ],
              ),
      ),
    );
  }

  Widget _buildOverview(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          _hasRecovery ? Icons.verified_user_rounded : Icons.key_rounded,
          size: 48,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 18),
        Text(
          _hasRecovery
              ? 'Kode pemulihan sudah aktif'
              : 'Siapkan kode pemulihan',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _hasRecovery
              ? 'SAKU tidak dapat menampilkan kode lama lagi. Kamu dapat membuat kode baru kapan saja; kode lama langsung tidak berlaku.'
              : 'Kode ini dapat dipakai untuk membuat PIN baru jika kamu lupa PIN. SAKU hanya menyimpan verifikasinya di perangkat.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.phonelink_lock_rounded, size: 21),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Tidak ada akun atau server SAKU yang menyimpan salinan kode. Simpan kode baru di tempat yang aman.',
                ),
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          Semantics(
            liveRegion: true,
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton.icon(
          key: const Key('recovery_settings_generate'),
          onPressed: _busy ? null : _confirmPinAndGenerate,
          icon: const Icon(Icons.key_rounded),
          label: Text(
            _busy
                ? 'Menyiapkan…'
                : _hasRecovery
                    ? 'Buat kode baru'
                    : 'Buat kode pemulihan',
          ),
        ),
      ],
    );
  }

  Widget _buildOneTimeCode(ThemeData theme) {
    final code = _code!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.key_rounded, size: 48),
        const SizedBox(height: 18),
        Text(
          'Simpan kode pemulihan',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Kode hanya ditampilkan kali ini. Setelah halaman ini ditutup, SAKU tidak dapat menampilkan kode asli lagi.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 22),
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
                key: const Key('recovery_settings_code'),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: code));
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Kode disalin.')),
                  );
                },
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Salin kode'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        CheckboxListTile(
          key: const Key('recovery_settings_saved'),
          contentPadding: EdgeInsets.zero,
          value: _saved,
          onChanged: (value) => setState(() => _saved = value ?? false),
          title: const Text('Saya sudah menyimpan kode ini di tempat aman'),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        const SizedBox(height: 12),
        FilledButton(
          key: const Key('recovery_settings_finish'),
          onPressed: _saved ? _finishOneTimeCode : null,
          child: const Text('Selesai'),
        ),
      ],
    );
  }

  void _finishOneTimeCode() {
    if (widget.initialCode != null) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _hasRecovery = true;
      _code = null;
      _saved = false;
    });
  }

  Future<void> _confirmPinAndGenerate() async {
    final pin = await _askCurrentPin();
    if (pin == null || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ok = await widget.security.verifyPin(pin);
      if (!mounted) return;
      if (!ok) {
        final lockUntil = await widget.security.pinLockedUntil();
        if (!mounted) return;
        if (lockUntil != null) {
          final seconds =
              lockUntil.difference(DateTime.now().toUtc()).inSeconds + 1;
          setState(() {
            _error =
                'Terlalu banyak percobaan PIN. Coba lagi sekitar $seconds detik.';
          });
        } else {
          setState(() => _error = 'PIN tidak cocok.');
        }
        return;
      }

      final code = await widget.security.createRecoveryCode();
      if (!mounted) return;
      setState(() {
        _code = code;
        _saved = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Kode pemulihan belum berhasil dibuat. Coba lagi.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _askCurrentPin() async {
    var value = '';
    String? error;
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Konfirmasi PIN'),
          content: TextField(
            key: const Key('recovery_settings_pin'),
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(8),
            ],
            decoration: InputDecoration(
              labelText: 'PIN SAKU saat ini',
              errorText: error,
            ),
            onChanged: (next) {
              value = next;
              if (error != null) setDialogState(() => error = null);
            },
            onSubmitted: (_) {
              if (RegExp(r'^\d{4,8}$').hasMatch(value)) {
                Navigator.pop(dialogContext, value);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                if (!RegExp(r'^\d{4,8}$').hasMatch(value)) {
                  setDialogState(() => error = 'PIN harus 4–8 digit.');
                  return;
                }
                Navigator.pop(dialogContext, value);
              },
              child: const Text('Lanjut'),
            ),
          ],
        ),
      ),
    );
  }
}
