import 'package:flutter/material.dart';

import '../../core/services/screen_protection_service.dart';

class PrivacySettingsScreen extends StatelessWidget {
  const PrivacySettingsScreen({super.key, this.service});

  final ScreenProtectionService? service;

  @override
  Widget build(BuildContext context) {
    final protection = service ?? ScreenProtectionService.instance;
    final theme = Theme.of(context);
    final runtimeEnabled = protection.supported && protection.enabled;
    return Scaffold(
      appBar: AppBar(title: const Text('Privasi layar')),
      body: AnimatedBuilder(
        animation: protection,
        builder: (context, _) {
          final runtimeEnabled = protection.supported && protection.enabled;
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 120),
            children: [
              Semantics(
                header: true,
                child: Text(
                  'Perlindungan layar',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Arus tetap menyembunyikan isi aplikasi saat masuk app switcher. Di Android, Anda juga dapat mengatur apakah screenshot dan perekaman layar diblokir saat aplikasi aktif.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              Card(
                child: SwitchListTile(
                  value: runtimeEnabled,
                  onChanged: !protection.loaded || !protection.supported
                      ? null
                      : (value) => _changeProtection(context, protection, value),
                  secondary: Icon(
                    runtimeEnabled
                        ? Icons.screen_lock_portrait_rounded
                        : Icons.screenshot_monitor_rounded,
                  ),
                  title: const Text('Lindungi screenshot & rekaman layar'),
                  subtitle: Text(_statusText(protection)),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                protection.supported
                    ? 'Default: aktif. Pengaturan ini hanya tersimpan di perangkat ini dan tidak mengubah data keuangan.'
                    : 'Kontrol screenshot runtime belum tersedia di platform/perangkat ini. Arus tidak akan mengklaim perlindungan yang tidak dapat diverifikasi.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _statusText(ScreenProtectionService service) {
    if (!service.loaded) return 'Memeriksa dukungan perangkat…';
    if (!service.supported) {
      return 'Toggle runtime tidak tersedia; app-switcher shield tetap aktif.';
    }
    return service.enabled
        ? 'Aktif — Android memblokir tangkapan layar saat Arus aktif.'
        : 'Nonaktif — screenshot dapat menangkap isi Arus saat aplikasi aktif.';
  }

  Future<void> _changeProtection(
    BuildContext context,
    ScreenProtectionService service,
    bool value,
  ) async {
    if (!value) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Izinkan screenshot?'),
          content: const Text(
            'Saat perlindungan ini dimatikan, screenshot atau perekaman layar dapat menangkap data keuangan ketika Arus sedang aktif. Perlindungan app switcher tetap aktif.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Matikan perlindungan'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
    }

    try {
      await service.setEnabled(value);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Perlindungan layar belum berubah: $error')),
      );
    }
  }
}
