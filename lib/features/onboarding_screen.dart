import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _saving = false;

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
                      Align(
                        alignment: Alignment.centerLeft,
                        child: CircleAvatar(
                          radius: 34,
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: Icon(
                            Icons.account_balance_wallet_rounded,
                            size: 34,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Semantics(
                        header: true,
                        child: Text(
                          'Selamat datang di Arus',
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Catat uang dengan cepat dan pahami keuangan tanpa dibuat rumit.',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 28),
                      const _OnboardingPoint(
                        icon: Icons.flash_on_rounded,
                        title: 'Cepat untuk dipakai sehari-hari',
                        description:
                            'Catat pemasukan dan pengeluaran tanpa alur yang panjang.',
                      ),
                      const SizedBox(height: 12),
                      const _OnboardingPoint(
                        icon: Icons.phone_android_rounded,
                        title: 'Data tetap di perangkatmu',
                        description:
                            'Tidak perlu login atau server agar Arus bisa digunakan.',
                      ),
                      const SizedBox(height: 12),
                      const _OnboardingPoint(
                        icon: Icons.auto_awesome_rounded,
                        title: 'Insight yang membantu, bukan mengganggu',
                        description:
                            'Arus dapat membaca pola keuangan secara lokal dan memberi ringkasan seperlunya.',
                      ),
                      const SizedBox(height: 30),
                      FilledButton(
                        onPressed: _saving ? null : _continueLocal,
                        child: Text(_saving ? 'Menyiapkan…' : 'Mulai'),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Data keuangan utama tetap berada dalam kendalimu.',
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
      // Old goal metadata had no product effect. Remove it when a returning
      // install reaches this onboarding after a reset/repair.
      await prefs.remove('onboarding_goal_v1');
      if (mounted) widget.onDone();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _OnboardingPoint extends StatelessWidget {
  const _OnboardingPoint({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: theme.colorScheme.onPrimaryContainer),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
