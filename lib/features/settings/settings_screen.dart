import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/services/backup_service.dart';
import '../../core/services/csv_export_service.dart';
import '../../core/services/csv_import_service.dart';
import '../../core/services/local_notification_service.dart';
import '../../core/services/security_service.dart';
import '../../core/services/user_profile_controller_access.dart';
import '../../shared/app_scope.dart';
import 'appearance_settings_screen.dart';
import 'categories_screen.dart';
import 'privacy_settings_screen.dart';
import 'recovery_code_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.security,
    required this.backup,
    required this.csv,
    required this.csvImport,
    required this.notifications,
  });

  final SecurityService security;
  final BackupService backup;
  final CsvExportService csv;
  final CsvImportService csvImport;
  final LocalNotificationService notifications;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool? _hasPin;
  bool? _bio;
  bool? _canBio;
  bool? _reminders;
  bool? _notificationDetails;
  DateTime? _localRecoveryAt;

  @override
  void initState() {
    super.initState();
    _reloadSecurity();
    _reloadNotifications();
    _reloadRecovery();
  }

  Future<void> _reloadSecurity() async {
    final values = await Future.wait([
      widget.security.hasPin(),
      widget.security.biometricEnabled(),
      widget.security.canUseBiometrics(),
    ]);
    if (!mounted) return;
    setState(() {
      _hasPin = values[0];
      _bio = values[1];
      _canBio = values[2];
    });
  }

  Future<void> _reloadNotifications() async {
    final values = await Future.wait([
      widget.notifications.enabled(),
      widget.notifications.showDetails(),
    ]);
    if (!mounted) return;
    setState(() {
      _reminders = values[0];
      _notificationDetails = values[1];
    });
  }

  Future<void> _reloadRecovery() async {
    DateTime? value;
    try {
      value = await widget.backup.latestLocalRecoveryAt();
    } catch (_) {
      value = null;
    }
    if (!mounted) return;
    setState(() => _localRecoveryAt = value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = AppScope.of(context);
    final profile = controller.userProfileService;

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 120),
        children: [
          _sectionTitle(theme, 'Profil & tampilan'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outline_rounded),
                  title: const Text('Nama'),
                  subtitle: Text(profile?.name ?? 'Belum diatur'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: profile == null ? null : () => _editName(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text('Tema'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AppearanceSettingsScreen(),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.category_outlined),
                  title: const Text('Kategori'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AppScope(
                        controller: controller,
                        child: const CategoriesScreen(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _sectionTitle(theme, 'Keamanan'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.pin_outlined),
                  title: Text(_hasPin == true ? 'Ubah PIN' : 'Buat PIN'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _setPin(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.key_rounded),
                  title: const Text('Kode pemulihan'),
                  subtitle: Text(
                    _hasPin == true
                        ? 'Buat atau ganti kode jika suatu saat lupa PIN'
                        : 'Buat PIN terlebih dahulu',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  enabled: _hasPin == true,
                  onTap: _hasPin == true
                      ? () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => RecoveryCodeSettingsScreen(
                                security: widget.security,
                              ),
                            ),
                          )
                      : null,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.fingerprint),
                  title: const Text('Biometrik'),
                  subtitle: _canBio == false
                      ? const Text('Tidak tersedia di perangkat ini')
                      : null,
                  value: _bio ?? false,
                  onChanged: _hasPin == true && _canBio == true
                      ? (value) async {
                          try {
                            await widget.security.setBiometricEnabled(value);
                            await _reloadSecurity();
                          } catch (error) {
                            if (context.mounted) {
                              _snack(context, error.toString());
                            }
                          }
                        }
                      : null,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.screen_lock_portrait_outlined),
                  title: const Text('Privasi layar'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PrivacySettingsScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _sectionTitle(theme, 'Pengingat'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_active_outlined),
                  title: const Text('Tagihan & transaksi rutin'),
                  value: _reminders ?? false,
                  onChanged: _reminders == null
                      ? null
                      : (value) => _setReminders(context, value),
                ),
                if (_reminders == true) ...[
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.visibility_outlined),
                    title: const Text('Tampilkan detail notifikasi'),
                    value: _notificationDetails ?? false,
                    onChanged: (value) =>
                        _setNotificationDetails(context, value),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          _sectionTitle(theme, 'Data & backup'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.backup_outlined),
                  title: const Text('Backup terenkripsi'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _backup(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.restore_rounded),
                  title: const Text('Restore backup'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _restore(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.ios_share_outlined),
                  title: const Text('Export CSV'),
                  onTap: () => _exportCsv(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.file_download_outlined),
                  title: const Text('Import CSV'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _importCsv(context),
                ),
                const Divider(height: 1),
                ExpansionTile(
                  leading: const Icon(Icons.tune_rounded),
                  title: const Text('Lanjutan'),
                  subtitle: const Text('Pemulihan & pemeriksaan data'),
                  children: [
                    ListTile(
                      leading: const Icon(Icons.history_rounded),
                      title: const Text('Buat titik pemulihan lokal'),
                      subtitle: _localRecoveryAt == null
                          ? null
                          : Text('Terbaru ${_formatRecoveryTime(_localRecoveryAt!)}'),
                      onTap: () => _createRecoveryPoint(context),
                    ),
                    ListTile(
                      leading: const Icon(Icons.settings_backup_restore_rounded),
                      title: const Text('Pulihkan titik lokal terbaru'),
                      enabled: _localRecoveryAt != null,
                      onTap: _localRecoveryAt == null
                          ? null
                          : () => _restoreLocalRecovery(context),
                    ),
                    ListTile(
                      leading: const Icon(Icons.fact_check_outlined),
                      title: const Text('Periksa integritas data'),
                      onTap: () => _verifyIntegrity(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _sectionTitle(theme, 'Hapus data', color: theme.colorScheme.error),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Icon(
                Icons.delete_forever_outlined,
                color: theme.colorScheme.error,
              ),
              title: Text(
                'Hapus seluruh data lokal',
                style: TextStyle(color: theme.colorScheme.error),
              ),
              onTap: () => _wipe(context),
            ),
          ),
          const SizedBox(height: 28),
          _sectionTitle(theme, 'Tentang Arus'),
          const SizedBox(height: 8),
          Card(
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.account_balance_wallet_rounded),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Arus Finance',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        SizedBox(height: 4),
                        Text('Dibuat oleh Akbar bersama Bantuan AI'),
                        SizedBox(height: 3),
                        Text('Local-first • data tetap di perangkatmu'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(ThemeData theme, String value, {Color? color}) => Text(
        value,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w800,
          color: color,
        ),
      );

  Future<void> _editName(BuildContext context) async {
    final profile = AppScope.of(context).userProfileService;
    if (profile == null) return;
    var value = profile.name ?? '';
    String? error;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nama'),
          content: TextFormField(
            initialValue: value,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            maxLength: 40,
            decoration: InputDecoration(
              labelText: 'Nama',
              errorText: error,
              counterText: '',
            ),
            onChanged: (next) {
              value = next;
              if (error != null) setDialogState(() => error = null);
            },
            onFieldSubmitted: (_) {
              final clean = value.trim().replaceAll(RegExp(r'\s+'), ' ');
              if (clean.isNotEmpty && clean.length <= 40) {
                Navigator.pop(ctx, clean);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                final clean = value.trim().replaceAll(RegExp(r'\s+'), ' ');
                if (clean.isEmpty) {
                  setDialogState(() => error = 'Nama tidak boleh kosong.');
                  return;
                }
                if (clean.length > 40) {
                  setDialogState(() => error = 'Nama maksimal 40 karakter.');
                  return;
                }
                Navigator.pop(ctx, clean);
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    try {
      await profile.saveName(result);
      if (mounted) setState(() {});
    } catch (error) {
      if (context.mounted) _snack(context, error.toString());
    }
  }

  Future<void> _setPin(BuildContext context) async {
    if (_hasPin == true) {
      final current = await _askSecret(
        context,
        title: 'Konfirmasi PIN saat ini',
        label: 'PIN saat ini',
        obscure: true,
      );
      if (current == null || !context.mounted) return;
      final ok = await widget.security.verifyPin(current);
      if (!context.mounted) return;
      if (!ok) {
        _snack(context, 'PIN saat ini tidak cocok.');
        return;
      }
    }

    var pin = '';
    var confirm = '';
    String? error;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(_hasPin == true ? 'Ubah PIN' : 'Buat PIN'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                autofocus: true,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 8,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'PIN baru',
                  errorText: error,
                  counterText: '',
                ),
                onChanged: (value) {
                  pin = value;
                  if (error != null) setDialogState(() => error = null);
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 8,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Ulangi PIN',
                  counterText: '',
                ),
                onChanged: (value) => confirm = value,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                if (!RegExp(r'^\d{4,8}$').hasMatch(pin)) {
                  setDialogState(() => error = 'PIN harus 4–8 digit.');
                  return;
                }
                if (pin != confirm) {
                  setDialogState(() => error = 'PIN tidak sama.');
                  return;
                }
                Navigator.pop(ctx, pin);
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    try {
      await widget.security.setPin(result);
      await _reloadSecurity();
    } catch (error) {
      if (context.mounted) _snack(context, error.toString());
    }
  }

  Future<void> _setReminders(BuildContext context, bool value) async {
    try {
      final granted = await widget.notifications.setEnabled(value);
      if (!context.mounted) return;
      if (value && !granted) {
        _snack(context, 'Izin notifikasi tidak diberikan.');
      }
      await _reloadNotifications();
      if (!context.mounted) return;
      final controller = AppScope.of(context);
      await widget.notifications.syncSchedules(
        bills: controller.bills,
        recurring: controller.recurring,
      );
    } catch (error) {
      if (mounted) {
        await _reloadNotifications();
        if (context.mounted) _snack(context, error.toString());
      }
    }
  }

  Future<void> _setNotificationDetails(BuildContext context, bool value) async {
    await widget.notifications.setShowDetails(value);
    await _reloadNotifications();
    if (!context.mounted) return;
    final controller = AppScope.of(context);
    await widget.notifications.syncSchedules(
      bills: controller.bills,
      recurring: controller.recurring,
    );
  }

  Future<void> _importCsv(BuildContext context) async {
    final pick = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['csv'],
    );
    final path = pick?.path;
    if (path == null) return;

    try {
      final preview = await widget.csvImport.preview(File(path));
      if (!context.mounted) return;

      final errors = preview.rows
          .where((row) => !row.valid || row.duplicate)
          .take(5)
          .map((row) =>
              'Baris ${row.line}: ${row.error ?? 'Tidak dapat diimport'}')
          .join('\n');

      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Preview import CSV'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Siap diimport: ${preview.validCount}'),
                Text('Duplikat: ${preview.duplicateCount}'),
                Text('Error: ${preview.errorCount}'),
                if (errors.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(errors),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: preview.validCount > 0
                  ? () => Navigator.pop(ctx, true)
                  : null,
              child: const Text('Import'),
            ),
          ],
        ),
      );
      if (confirm != true || !context.mounted) return;

      final controller = AppScope.of(context);
      final result = await controller.run(() => widget.csvImport.commit(preview));
      if (!context.mounted || result == null) return;
      _snack(
        context,
        'Import selesai: ${result.imported} masuk, ${result.skippedDuplicates} dilewati.',
      );
    } catch (error) {
      if (context.mounted) _snack(context, 'Import gagal: $error');
    }
  }

  Future<void> _exportCsv(BuildContext context) async {
    File? tempFile;
    try {
      tempFile = await widget.csv.exportTransactions();
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(tempFile.path)],
          text: 'Arus Finance — export transaksi',
        ),
      );
    } catch (error) {
      if (context.mounted) _snack(context, 'Export gagal: $error');
    } finally {
      try {
        if (tempFile != null && await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (_) {}
    }
  }

  Future<void> _backup(BuildContext context) async {
    final pass = await _askSecret(
      context,
      title: 'Passphrase backup',
      label: 'Minimal 8 karakter',
      obscure: true,
    );
    if (pass == null || !context.mounted) return;
    final confirm = await _askSecret(
      context,
      title: 'Konfirmasi passphrase',
      label: 'Ketik ulang passphrase',
      obscure: true,
    );
    if (confirm == null || !context.mounted) return;
    if (pass != confirm) {
      _snack(context, 'Passphrase tidak sama. Backup dibatalkan.');
      return;
    }
    File? tempFile;
    try {
      tempFile = await widget.backup.createPortableBackup(pass);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(tempFile.path)],
          text: 'Arus Finance encrypted backup',
        ),
      );
    } catch (error) {
      if (context.mounted) _snack(context, 'Backup gagal: $error');
    } finally {
      try {
        if (tempFile != null && await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (_) {}
    }
  }

  Future<void> _restore(BuildContext context) async {
    final pick = await FilePicker.pickFile(type: FileType.any);
    final path = pick?.path;
    if (path == null || !context.mounted) return;
    final pass = await _askSecret(
      context,
      title: 'Buka backup',
      label: 'Passphrase',
      obscure: true,
    );
    if (pass == null || !context.mounted) return;
    final replace = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore backup?'),
        content: const Text('Data aktif akan diganti dengan isi backup.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (replace != true) return;
    try {
      await widget.backup.restorePortableBackup(File(path), pass);
      if (!context.mounted) return;
      await AppScope.of(context).refresh();
      await _reloadRecovery();
      if (context.mounted) _snack(context, 'Restore berhasil.');
    } catch (error) {
      if (context.mounted) {
        _snack(context, 'Restore gagal. Data lama tidak diubah. $error');
      }
    }
  }

  Future<void> _createRecoveryPoint(BuildContext context) async {
    try {
      await widget.backup.createLocalRecoveryGeneration(force: true);
      await _reloadRecovery();
      if (context.mounted) _snack(context, 'Titik pemulihan berhasil dibuat.');
    } catch (error) {
      if (context.mounted) {
        _snack(context, 'Gagal membuat titik pemulihan: $error');
      }
    }
  }

  Future<void> _restoreLocalRecovery(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pulihkan titik lokal terbaru?'),
        content: const Text('Data aktif akan diganti setelah integrity check lolos.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Pulihkan'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.backup.restoreLatestLocalRecoveryAsRecovery();
      if (!context.mounted) return;
      await AppScope.of(context).refresh();
      await _reloadRecovery();
      if (context.mounted) _snack(context, 'Pemulihan berhasil.');
    } catch (error) {
      if (context.mounted) _snack(context, 'Pemulihan gagal: $error');
    }
  }

  Future<void> _verifyIntegrity(BuildContext context) async {
    try {
      widget.backup.verifyLocalDatabase();
      if (context.mounted) _snack(context, 'Database lokal sehat.');
    } catch (error) {
      if (context.mounted) _snack(context, 'Pemeriksaan gagal: $error');
    }
  }

  Future<void> _wipe(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus seluruh data lokal?'),
        content: const Text('Tindakan ini tidak dapat dibatalkan tanpa backup.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Lanjut'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final phraseConfirmed = await _confirmPermanentWipe(context);
    if (!phraseConfirmed || !context.mounted) return;
    if (_hasPin == true) {
      final pin = await _askSecret(
        context,
        title: 'Konfirmasi penghapusan',
        label: 'Masukkan PIN',
        obscure: true,
      );
      if (pin == null) return;
      if (!await widget.security.verifyPin(pin)) {
        if (context.mounted) _snack(context, 'PIN tidak cocok.');
        return;
      }
    }
    if (!context.mounted) return;
    final controller = AppScope.of(context);
    try {
      await widget.backup.destroyLocalRecoveryMaterial();
    } catch (error) {
      if (context.mounted) {
        _snack(context, 'Penghapusan dibatalkan: $error');
      }
      return;
    }
    await controller.run(() => controller.repository.wipeLocalFinanceData());
    if (controller.errorMessage != null) return;
    await _reloadRecovery();
    if (context.mounted) _snack(context, 'Data lokal berhasil direset.');
  }

  Future<bool> _confirmPermanentWipe(BuildContext context) async {
    var value = '';
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: const Text('Konfirmasi penghapusan'),
              content: TextFormField(
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Ketik HAPUS'),
                onChanged: (next) => setDialogState(() => value = next),
                onFieldSubmitted: (_) {
                  if (value.trim() == 'HAPUS') Navigator.pop(ctx, true);
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(ctx).colorScheme.error,
                    foregroundColor: Theme.of(ctx).colorScheme.onError,
                  ),
                  onPressed: value.trim() == 'HAPUS'
                      ? () => Navigator.pop(ctx, true)
                      : null,
                  child: const Text('Hapus seluruh data'),
                ),
              ],
            ),
          ),
        ) ??
        false;
  }

  String _formatRecoveryTime(DateTime value) {
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  Future<String?> _askSecret(
    BuildContext context, {
    required String title,
    required String label,
    required bool obscure,
  }) async {
    var value = '';
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextFormField(
          autofocus: true,
          obscureText: obscure,
          decoration: InputDecoration(labelText: label),
          onChanged: (next) => value = next,
          onFieldSubmitted: (next) => Navigator.pop(ctx, next),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, value),
            child: const Text('Lanjut'),
          ),
        ],
      ),
    );
  }

  void _snack(BuildContext context, String value) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                .replaceFirst('Bad state: ', '')
                .replaceFirst('Invalid argument(s): ', ''),
          ),
        ),
      );
}
