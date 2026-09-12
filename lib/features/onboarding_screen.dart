import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});
  final VoidCallback onDone;
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  String _goal = 'Mencatat pengeluaran';
  bool _saving = false;
  final goals = const [
    'Mencatat pengeluaran',
    'Mengatur budget',
    'Menabung',
    'Mengontrol tagihan',
    'Semuanya',
  ];

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
                minHeight: (constraints.maxHeight - 48).clamp(0.0, double.infinity).toDouble(),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CircleAvatar(
                        radius: 34,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Icon(
                          Icons.account_balance_wallet_rounded,
                          size: 34,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Semantics(
                        header: true,
                        child: Text(
                          'Arus',
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Catat uang dengan cepat. Pahami keuangan tanpa dibuat rumit.',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Semantics(
                        header: true,
                        child: Text(
                          'Tujuan utama kamu?',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      RadioGroup<String>(
                        groupValue: _goal,
                        onChanged: (v) {
                          if (!_saving && v != null) {
                            setState(() => _goal = v);
                          }
                        },
                        child: Column(
                          children: goals
                              .map(
                                (g) => RadioListTile<String>(
                                  value: g,
                                  title: Text(g),
                                  contentPadding: EdgeInsets.zero,
                                  enabled: !_saving,
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      FilledButton(
                        onPressed: _saving ? null : _continueLocal,
                        child: Text(_saving ? 'Menyiapkan…' : 'Mulai'),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tidak perlu login. Data keuangan utama tetap tersimpan di perangkatmu.',
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

  Future<void> _continueLocal() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_done_v1', true);
      await prefs.setString('onboarding_goal_v1', _goal);
      if (mounted) widget.onDone();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
