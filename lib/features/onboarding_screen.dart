import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/services/security_service.dart';
import '../core/services/user_profile_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.onDone,
    required this.security,
    required this.profile,
  });

  final VoidCallback onDone;
  final SecurityService security;
  final UserProfileService profile;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final TextEditingController _name;
  final _pin = TextEditingController();
  final _confirmPin = TextEditingController();
  int _step = 0;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.profile.name ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _pin.dispose();
    _confirmPin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _step == 0
                    ? _buildNameStep(theme)
                    : _buildPinStep(theme),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNameStep(ThemeData theme) {
    return Column(
      key: const ValueKey('name-step'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          Icons.account_balance_wallet_rounded,
          size: 46,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 26),
        Text(
          'Siapa nama kamu?',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          'Supaya Arus bisa menyapa kamu.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 28),
        TextField(
          controller: _name,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          maxLength: 40,
          decoration: InputDecoration(
            labelText: 'Nama',
            errorText: _error,
            counterText: '',
          ),
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          onSubmitted: (_) => _continueName(),
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: _continueName,
          child: const Text('Lanjut'),
        ),
      ],
    );
  }

  Widget _buildPinStep(ThemeData theme) {
    return Column(
      key: const ValueKey('pin-step'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            tooltip: 'Kembali',
            onPressed: _saving
                ? null
                : () => setState(() {
                    _step = 0;
                    _error = null;
                  }),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        const SizedBox(height: 8),
        Icon(
          Icons.lock_outline_rounded,
          size: 46,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 22),
        Text(
          'Buat PIN Arus',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          '4–8 digit untuk melindungi data di perangkat ini.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 28),
        TextField(
          controller: _pin,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          maxLength: 8,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: 'PIN',
            errorText: _error,
            counterText: '',
          ),
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _confirmPin,
          obscureText: true,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          maxLength: 8,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Ulangi PIN',
            counterText: '',
          ),
          onSubmitted: (_) => _finish(),
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: _saving ? null : _finish,
          child: Text(_saving ? 'Menyiapkan…' : 'Mulai Arus'),
        ),
      ],
    );
  }

  void _continueName() {
    final clean = _name.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (clean.isEmpty) {
      setState(() => _error = 'Masukkan nama terlebih dahulu.');
      return;
    }
    if (clean.length > 40) {
      setState(() => _error = 'Nama maksimal 40 karakter.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _step = 1;
      _error = null;
    });
  }

  Future<void> _finish() async {
    if (_saving) return;
    if (!RegExp(r'^\d{4,8}$').hasMatch(_pin.text)) {
      setState(() => _error = 'PIN harus 4–8 digit.');
      return;
    }
    if (_pin.text != _confirmPin.text) {
      setState(() => _error = 'PIN tidak sama.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.security.setPin(_pin.text);
      await widget.profile.saveName(_name.text);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_done_v1', true);
      await prefs.remove('onboarding_goal_v1');
      if (mounted) widget.onDone();
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString().replaceFirst('Invalid argument(s): ', ''));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
