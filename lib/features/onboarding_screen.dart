import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/services/security_service.dart';
import '../core/services/user_profile_service.dart';
import '../shared/saku_brand.dart';

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

  bool _saving = false;
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
                                  SakuBrand.appName,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  _recoveryCode == null
                                      ? 'Siapkan sekali, lalu langsung pakai.'
                                      : 'Satu langkah terakhir untuk keamananmu.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      if (_recoveryCode == null)
                        _buildSetupForm(theme)
                      else
                        _buildRecoveryView(theme),
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

  Widget _buildSetupForm(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            'Mulai pakai SAKU',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Isi nama dan buat PIN. Semuanya disimpan lokal di perangkatmu.',
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
          textInputAction: TextInputAction.next,
          maxLength: 40,
          decoration: const InputDecoration(
            labelText: 'Nama',
            hintText: 'Contoh: Ema',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('onboarding_pin_input'),
          controller: _pin,
          obscureText: true,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(8),
          ],
          decoration: const InputDecoration(
            labelText: 'PIN',
            helperText: '4–8 digit',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('onboarding_pin_confirm_input'),
          controller: _pinConfirm,
          obscureText: true,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(8),
          ],
          decoration: const InputDecoration(labelText: 'Konfirmasi PIN'),
          onSubmitted: (_) => _saveSetup(),
        ),
        const SizedBox(height: 18),
        FilledButton(
          key: const Key('onboarding_save_setup'),
          onPressed: _saving ? null : _saveSetup,
          child: Text(_saving ? 'Menyimpan…' : 'Simpan'),
        ),
      ],
    );
  }

  Widget _buildRecoveryView(ThemeData theme) {
    final code = _recoveryCode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            'Kode pemulihan PIN',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Simpan kode ini untuk memulihkan akses jika kamu lupa PIN. SAKU hanya menyimpan verifikasinya, jadi kode asli tidak dapat ditampilkan lagi setelah halaman ini ditutup.',
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
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                key: const Key('onboarding_copy_recovery'),
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
        const SizedBox(height: 18),
        FilledButton(
          key: const Key('onboarding_enter_dashboard'),
          onPressed: _saving ? null : _finish,
          child: Text(_saving ? 'Menyiapkan SAKU…' : 'Masuk ke Dashboard'),
        ),
      ],
    );
  }

  String? _validateName() {
    final clean = _name.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (clean.isEmpty) return 'Nama tidak boleh kosong.';
    if (clean.length > 40) return 'Nama maksimal 40 karakter.';
    return null;
  }

  Future<void> _saveSetup() async {
    if (_saving) return;

    final nameError = _validateName();
    if (nameError != null) {
      setState(() => _error = nameError);
      return;
    }

    final pin = _pin.text;
    if (!RegExp(r'^\d{4,8}$').hasMatch(pin)) {
      setState(() => _error = 'PIN harus terdiri dari 4–8 digit.');
      return;
    }
    if (pin != _pinConfirm.text) {
      setState(() => _error = 'Konfirmasi PIN harus sama.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _profile.saveName(_name.text);
      await widget.security.setPin(pin);
      final recovery = await widget.security.createRecoveryCode();
      if (!mounted) return;
      _pin.clear();
      _pinConfirm.clear();
      setState(() => _recoveryCode = recovery);
    } on ArgumentError catch (error) {
      if (mounted) setState(() => _error = error.message?.toString());
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'SAKU belum berhasil disiapkan. Coba lagi.';
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _finish() async {
    if (_saving || _recoveryCode == null) return;
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
        setState(() => _error = 'SAKU belum selesai disiapkan. Coba lagi.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
