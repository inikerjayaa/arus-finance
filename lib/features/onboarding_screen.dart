import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/services/user_profile_service.dart';
import '../shared/saku_brand.dart';
import '../shared/saku_splash.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.onDone,
    this.profile,
  });

  final VoidCallback onDone;
  final UserProfileService? profile;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final UserProfileService _profile =
      widget.profile ?? UserProfileService();
  final _name = TextEditingController();

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wordmarkColor = theme.brightness == Brightness.dark
        ? SakuBrand.sand
        : SakuBrand.noturno;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - 56)
                    .clamp(0.0, double.infinity)
                    .toDouble(),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: SakuBrandLockup(
                          markSize: 128,
                          wordmarkSize: 38,
                          wordmarkColor: wordmarkColor,
                        ),
                      ),
                      const SizedBox(height: 42),
                      TextField(
                        key: const Key('onboarding_name_input'),
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
                        onSubmitted: (_) => _createSaku(),
                      ),
                      const SizedBox(height: 18),
                      FilledButton(
                        key: const Key('onboarding_create_button'),
                        onPressed: _saving ? null : _createSaku,
                        child: Text(_saving ? 'Menyiapkan SAKU…' : 'Buat SAKU'),
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

  Future<void> _createSaku() async {
    if (_saving) return;

    final cleanName = _name.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (cleanName.isEmpty) {
      setState(() => _error = 'Nama tidak boleh kosong.');
      return;
    }
    if (cleanName.length > 40) {
      setState(() => _error = 'Nama maksimal 40 karakter.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _profile.saveName(cleanName);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_done_v1', true);
      if (mounted) widget.onDone();
    } on ArgumentError catch (error) {
      if (mounted) setState(() => _error = error.message?.toString());
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'SAKU belum berhasil disiapkan. Coba lagi.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
