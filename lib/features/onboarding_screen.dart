import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/services/security_service.dart';
import '../core/services/user_profile_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.security,
    required this.onDone,
    this.profile,
  });

  final SecurityService security;
  final VoidCallback onDone;
  final UserProfileService? profile;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final UserProfileService _profile =
      widget.profile ?? UserProfileService();
  final _name = TextEditingController();
  final _pin = TextEditingController();
  final _pinConfirm = TextEditingController();

  int _step = 0;
  bool _saving = false;
  bool _recoverySaved = false;
  String? _recoveryCode;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _pin.dispose();
    _pinConfirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - 48)
                    .clamp(0.0, double.infinity)
                    .toDouble(),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 25,
                            backgroundColor: theme.colorScheme.primaryContainer,
                            child: Icon(
                              Icons.account_balance_wallet_rounded,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Arus Finance',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  'Langkah ${_step + 1} dari 3',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      LinearProgressIndicator(value: (_step + 1) / 3),
                      const SizedBox(height: 30),
                      if (_step == 0) _buildNameStep(theme),
                      if (_step == 1) _buildPinStep(theme),
                      if (_step == 2) _buildRecoveryStep(theme),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
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
                      const SizedBox(height: 16),
                      Text(
                        'Tidak perlu login. Data keuangan utama tetap berada di perangkatmu.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNameStep(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            'Siapa nama kamu?',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Nama ini hanya dipakai untuk membuat Arus terasa lebih personal dan disimpan lokal di perangkat.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 22),
        TextField(
          key: const Key('onboarding_name_input'),
          controller: _name,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          maxLength: 40,
          decoration: const InputDecoration(
            labelText: 'Nama',
            hintText: 'Contoh: Ema',
          ),
          onSubmitted: (_) => _continueName(),
        ),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: _saving ? null : _continueName,
          child: Text(_saving ? 'Menyimpan…' : 'Lanjut'),
        ),
      ],
    );
  }

  Widget _buildPinStep(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            'Buat PIN Arus',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Gunakan 4–8 digit. PIN ini melindungi Arus di perangkatmu dan tidak dikirim ke server.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 22),
        TextField(
          key: const Key('onboarding_pin_input'),
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
          key: const Key('onboarding_pin_confirm_input'),
          controller: _pinConfirm,
          obscureText: true,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          inputFormatters: const [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(8),
          ],
          decoration: const InputDecoration(labelText: 'Ulangi PIN'),
          onSubmitted: (_) => _createPinAndRecovery(),
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: _saving ? null : _createPinAndRecovery,
          child: Text(_saving ? 'Menyiapkan keamanan…' : 'Buat PIN'),
        ),
        TextButton(
          onPressed: _saving
              ? null
              : () => setState(() {
                    _step = 0;
                    _error = null;
                  }),
          child: const Text('Kembali'),
        ),
      ],
    );
  }

  Widget _buildRecoveryStep(ThemeData theme) {
    final code = _recoveryCode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            'Simpan kode pemulihan',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Kode ini dipakai jika kamu lupa PIN. Arus hanya menyimpan verifikasinya, jadi kode asli tidak dapat ditampilkan lagi setelah halaman ini ditutup.',
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
              const Icon(Icons.key_rounded, size: 30),
              const SizedBox(height: 10),
              SelectableText(
                code ?? '—',
                key: const Key('onboarding_recovery_code'),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: code == null
                    ? null
                    : () async {
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
        const SizedBox(height: 16),
        CheckboxListTile(
          key: const Key('onboarding_recovery_saved'),
          contentPadding: EdgeInsets.zero,
          value: _recoverySaved,
          onChanged: _saving
              ? null
              : (value) => setState(() => _recoverySaved = value ?? false),
          title: const Text('Saya sudah menyimpan kode ini di tempat aman'),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: !_recoverySaved || _saving ? null : _finish,
          child: Text(_saving ? 'Menyiapkan Arus…' : 'Masuk ke Arus'),
        ),
      ],
    );
  }

  Future<void> _continueName() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _profile.saveName(_name.text);
      if (!mounted) return;
      setState(() => _step = 1);
    } on ArgumentError catch (error) {
      if (mounted) setState(() => _error = error.message?.toString());
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Nama belum berhasil disimpan. Coba lagi.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _createPinAndRecovery() async {
    if (_saving) return;
    final pin = _pin.text;
    if (!RegExp(r'^\d{4,8}$').hasMatch(pin)) {
      setState(() => _error = 'PIN harus terdiri dari 4–8 digit.');
      return;
    }
    if (pin != _pinConfirm.text) {
      setState(() => _error = 'Ulangi PIN dengan angka yang sama.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.security.setPin(pin);
      final recovery = await widget.security.createRecoveryCode();
      if (!mounted) return;
      setState(() {
        _recoveryCode = recovery;
        _recoverySaved = false;
        _step = 2;
        _pin.clear();
        _pinConfirm.clear();
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Keamanan Arus belum berhasil disiapkan. Coba lagi.';
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _finish() async {
    if (_saving || !_recoverySaved || _recoveryCode == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_done_v1', true);
      await prefs.setBool('onboarding_security_v2', true);
      if (mounted) widget.onDone();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Arus belum selesai disiapkan. Coba lagi.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
