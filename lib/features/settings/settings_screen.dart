import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/services/backup_service.dart';
import '../../core/services/csv_export_service.dart';
import '../../core/services/csv_import_service.dart';
import '../../core/services/local_notification_service.dart';
import '../../core/services/security_service.dart';
import '../../shared/app_scope.dart';
import 'categories_screen.dart';

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
    final values = await Future.wait([widget.security.hasPin(), widget.security.biometricEnabled(), widget.security.canUseBiometrics()]);
    if (!mounted) return;
    setState(() { _hasPin = values[0]; _bio = values[1]; _canBio = values[2]; });
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
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 14, 18, 120), children: [
      Semantics(header: true, child: Text('Keamanan & data', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800))),
      const SizedBox(height: 18),
      Text('Keamanan', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Card(child: Column(children: [
        ListTile(
          leading: const Icon(Icons.pin_outlined),
          title: Text(_hasPin == true ? 'Ubah PIN' : 'Aktifkan PIN'),
          subtitle: const Text('PIN lokal 4–8 digit'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _setPin(context),
        ),
        const Divider(height: 1),
        SwitchListTile(
          secondary: const Icon(Icons.fingerprint),
          title: const Text('Biometrik'),
          subtitle: Text(_canBio == true ? 'Gunakan fingerprint/Face ID setelah PIN aktif' : 'Tidak tersedia di perangkat ini'),
          value: _bio ?? false,
          onChanged: _hasPin == true && _canBio == true ? (value) async {
            try { await widget.security.setBiometricEnabled(value); await _reloadSecurity(); }
            catch (e) { if (context.mounted) _snack(context, e.toString()); }
          } : null,
        ),
        if (_hasPin == true) ...[
          const Divider(height: 1),
          ListTile(leading: const Icon(Icons.lock_open_outlined), title: const Text('Nonaktifkan app lock'), onTap: () => _disablePin(context)),
        ],
      ])),
      const SizedBox(height: 22),
      Text('Personalisasi', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Card(child: ListTile(
        leading: const Icon(Icons.category_outlined),
        title: const Text('Kategori'),
        subtitle: const Text('Tambah atau arsipkan kategori pemasukan/pengeluaran'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          final controller = AppScope.of(context);
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => AppScope(controller: controller, child: const CategoriesScreen())));
        },
      )),
      const SizedBox(height: 22),
      Text('Pengingat lokal', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Card(child: Column(children: [
        SwitchListTile(
          secondary: const Icon(Icons.notifications_active_outlined),
          title: const Text('Pengingat tagihan & recurring'),
          subtitle: const Text('Dijadwalkan di perangkat. Tidak memerlukan server atau akun.'),
          value: _reminders ?? false,
          onChanged: _reminders == null ? null : (value) => _setReminders(context, value),
        ),
        const Divider(height: 1),
        SwitchListTile(
          secondary: const Icon(Icons.visibility_outlined),
          title: const Text('Tampilkan detail di notifikasi'),
          subtitle: const Text('Default dimatikan agar nominal/nama tidak tampil di lock screen.'),
          value: _notificationDetails ?? false,
          onChanged: _reminders == true
              ? (value) => _setNotificationDetails(context, value)
              : null,
        ),
      ])),
      const SizedBox(height: 22),
      Text('Data', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Text('Arus tidak menyimpan salinan cloud. Buat backup terenkripsi secara berkala, terutama sebelum ganti HP atau menghapus aplikasi.', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      const SizedBox(height: 8),
      Card(child: Column(children: [
        ListTile(leading: const Icon(Icons.table_view_outlined), title: const Text('Export CSV'), subtitle: const Text('Ekspor transaksi yang dapat dibuka di Excel/Sheets'), trailing: const Icon(Icons.ios_share_outlined), onTap: () => _exportCsv(context)),
        const Divider(height: 1),
        ListTile(leading: const Icon(Icons.file_download_outlined), title: const Text('Import CSV'), subtitle: const Text('Preview + validasi + import atomik dari format export Arus'), trailing: const Icon(Icons.chevron_right), onTap: () => _importCsv(context)),
        const Divider(height: 1),
        ListTile(leading: const Icon(Icons.backup_outlined), title: const Text('Backup terenkripsi'), subtitle: const Text('Portable backup dengan passphrase'), trailing: const Icon(Icons.chevron_right), onTap: () => _backup(context)),
        const Divider(height: 1),
        ListTile(leading: const Icon(Icons.restore_rounded), title: const Text('Restore backup'), subtitle: const Text('Restore atomic + integrity check'), trailing: const Icon(Icons.chevron_right), onTap: () => _restore(context)),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.history_rounded),
          title: const Text('Buat titik pemulihan lokal'),
          subtitle: Text(_localRecoveryAt == null
              ? 'Belum ada generasi lokal terenkripsi'
              : 'Terbaru: ${_formatRecoveryTime(_localRecoveryAt!)} • otomatis maksimal 3 generasi'),
          trailing: const Icon(Icons.add_circle_outline),
          onTap: () => _createRecoveryPoint(context),
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.settings_backup_restore_rounded),
          title: const Text('Pulihkan titik lokal terbaru'),
          subtitle: const Text('Rollback terenkripsi ke generasi lokal terbaru'),
          trailing: const Icon(Icons.chevron_right),
          enabled: _localRecoveryAt != null,
          onTap: _localRecoveryAt == null ? null : () => _restoreLocalRecovery(context),
        ),
        const Divider(height: 1),
        ListTile(leading: const Icon(Icons.fact_check_outlined), title: const Text('Periksa integritas data'), subtitle: const Text('Pemeriksaan lokal SQLite; tidak mengirim data ke mana pun'), trailing: const Icon(Icons.chevron_right), onTap: () => _verifyIntegrity(context)),
      ])),
      const SizedBox(height: 22),
      Text('Aplikasi', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      const Card(child: Column(children: [
        ListTile(leading: Icon(Icons.shield_outlined), title: Text('Device-owned'), subtitle: Text('Data keuangan utama disimpan di perangkat. Internet dan akun tidak diperlukan.')),
        Divider(height: 1),
        ListTile(leading: Icon(Icons.palette_outlined), title: Text('Tema'), subtitle: Text('Mengikuti Light/Dark Mode perangkat.')),
      ])),
      const SizedBox(height: 22),
      Text('Danger zone', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: theme.colorScheme.error)),
      const SizedBox(height: 8),
      Card(child: ListTile(leading: Icon(Icons.delete_forever_outlined, color: theme.colorScheme.error), title: Text('Hapus seluruh data lokal', style: TextStyle(color: theme.colorScheme.error)), subtitle: const Text('Tidak dapat dibatalkan tanpa backup.'), onTap: () => _wipe(context))),
      ]),
    );
  }

  Future<void> _setPin(BuildContext context) async {
    final controller = TextEditingController();
    final confirm = TextEditingController();
    await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: Text(_hasPin == true ? 'Ubah PIN' : 'Buat PIN'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: controller, obscureText: true, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'PIN baru')), const SizedBox(height: 10),
        TextField(controller: confirm, obscureText: true, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Ulangi PIN')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')), FilledButton(onPressed: () async {
        if (controller.text != confirm.text) { _snack(context, 'PIN tidak sama.'); return; }
        try { await widget.security.setPin(controller.text); if (ctx.mounted) Navigator.pop(ctx); await _reloadSecurity(); }
        catch (e) { if (context.mounted) _snack(context, e.toString()); }
      }, child: const Text('Simpan'))],
    ));
    controller.dispose(); confirm.dispose();
  }

  Future<void> _disablePin(BuildContext context) async {
    final pin = await _askSecret(context, title: 'Konfirmasi PIN', label: 'PIN saat ini', obscure: true);
    if (pin == null) return;
    if (!await widget.security.verifyPin(pin)) { if (context.mounted) _snack(context, 'PIN tidak cocok.'); return; }
    await widget.security.disablePin();
    await _reloadSecurity();
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
    } catch (e) {
      if (mounted) {
        await _reloadNotifications();
        if (context.mounted) _snack(context, e.toString());
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
          .where((r) => !r.valid || r.duplicate)
          .take(5)
          .map((r) => 'Baris ${r.line}: ${r.error ?? 'Tidak dapat diimport'}')
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
                const SizedBox(height: 12),
                const Text(
                  'Account dan kategori harus sudah ada. Transfer tidak diimport otomatis.',
                ),
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
      final result = await controller.run(
        () => widget.csvImport.commit(preview),
      );
      if (!context.mounted || result == null) return;
      _snack(
        context,
        'Import selesai: ${result.imported} masuk, ${result.skippedDuplicates} dilewati.',
      );
    } catch (e) {
      if (context.mounted) _snack(context, 'Import gagal: $e');
    }
  }

  Future<void> _exportCsv(BuildContext context) async {
    File? tempFile;
    try {
      tempFile = await widget.csv.exportTransactions();
      await SharePlus.instance.share(ShareParams(files: [XFile(tempFile.path)], text: 'Arus Finance — export transaksi'));
    } catch (e) {
      if (context.mounted) _snack(context, 'Export gagal: $e');
    } finally {
      // CSV is intentionally plaintext for portability. Do not leave our temporary
      // working copy in the app cache after the platform share flow finishes.
      try {
        if (tempFile != null && await tempFile.exists()) await tempFile.delete();
      } catch (_) {}
    }
  }

  Future<void> _backup(BuildContext context) async {
    final pass = await _askSecret(context, title: 'Passphrase backup', label: 'Minimal 8 karakter', obscure: true);
    if (pass == null || !context.mounted) return;
    final confirm = await _askSecret(context, title: 'Konfirmasi passphrase', label: 'Ketik ulang passphrase', obscure: true);
    if (confirm == null || !context.mounted) return;
    if (pass != confirm) { _snack(context, 'Passphrase tidak sama. Backup dibatalkan.'); return; }
    File? tempFile;
    try {
      tempFile = await widget.backup.createPortableBackup(pass);
      await SharePlus.instance.share(ShareParams(files: [XFile(tempFile.path)], text: 'Arus Finance encrypted backup'));
    } catch (e) {
      if (context.mounted) _snack(context, 'Backup gagal: $e');
    } finally {
      try {
        if (tempFile != null && await tempFile.exists()) await tempFile.delete();
      } catch (_) {}
    }
  }

  Future<void> _restore(BuildContext context) async {
    final pick = await FilePicker.pickFile(type: FileType.any);
    final path = pick?.path;
    if (path == null || !context.mounted) return;
    final pass = await _askSecret(context, title: 'Buka backup', label: 'Passphrase', obscure: true);
    if (pass == null) return;
    if (!context.mounted) return;
    final replace = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Ganti data aktif dengan backup?'),
      content: const Text('Restore akan mengganti seluruh data finansial yang sekarang ada di perangkat. Jika ragu, buat backup data aktif terlebih dahulu.'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Restore'))],
    ));
    if (replace != true) return;
    try {
      await widget.backup.restorePortableBackup(File(path), pass);
      if (!context.mounted) return;
      await AppScope.of(context).refresh();
      await _reloadRecovery();
      if (!context.mounted) return;
      _snack(context, 'Restore berhasil dan ledger lolos integrity check.');
    } catch (e) { if (context.mounted) _snack(context, 'Restore gagal. Data lama tidak diubah. $e'); }
  }

  Future<void> _createRecoveryPoint(BuildContext context) async {
    try {
      await widget.backup.createLocalRecoveryGeneration(force: true);
      await _reloadRecovery();
      if (context.mounted) {
        _snack(context, 'Titik pemulihan lokal terenkripsi berhasil dibuat.');
      }
    } catch (e) {
      if (context.mounted) _snack(context, 'Gagal membuat titik pemulihan: $e');
    }
  }

  Future<void> _restoreLocalRecovery(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pulihkan titik lokal terbaru?'),
        content: const Text(
          'Data aktif saat ini akan dipindahkan ke quarantine. Generasi lokal terbaru hanya menjadi replacement setelah lolos integrity check.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Pulihkan')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.backup.restoreLatestLocalRecoveryAsRecovery();
      if (!context.mounted) return;
      await AppScope.of(context).refresh();
      await _reloadRecovery();
      if (!context.mounted) return;
      _snack(context, 'Titik pemulihan lokal berhasil diterapkan dan tervalidasi.');
    } catch (e) {
      if (context.mounted) _snack(context, 'Pemulihan lokal gagal: $e');
    }
  }

  Future<void> _verifyIntegrity(BuildContext context) async {
    try {
      widget.backup.verifyLocalDatabase();
      if (context.mounted) _snack(context, 'Database lokal sehat. Integrity check: OK.');
    } catch (e) {
      if (context.mounted) _snack(context, 'Integrity check gagal: $e');
    }
  }

  Future<void> _wipe(BuildContext context) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Hapus seluruh data lokal?'),
      content: const Text('Account, transaksi, budget, bill, dan recurring lokal akan dihapus. Buat backup bila data masih dibutuhkan.'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus'))],
    ));
    if (ok != true || !context.mounted) return;
    final phraseConfirmed = await _confirmPermanentWipe(context);
    if (!phraseConfirmed || !context.mounted) return;
    if (_hasPin == true) {
      final pin = await _askSecret(context, title: 'Konfirmasi penghapusan', label: 'Masukkan PIN', obscure: true);
      if (pin == null) return;
      if (!await widget.security.verifyPin(pin)) { if (context.mounted) _snack(context, 'PIN tidak cocok.'); return; }
    }
    if (!context.mounted) return;
    final controller = AppScope.of(context);
    try {
      await widget.backup.destroyLocalRecoveryMaterial();
    } catch (e) {
      if (context.mounted) {
        _snack(context, 'Penghapusan dibatalkan karena material recovery belum dapat dibersihkan: $e');
      }
      return;
    }
    await controller.run(() => controller.repository.wipeLocalFinanceData());
    if (controller.errorMessage != null) return;
    await _reloadRecovery();
    if (context.mounted) _snack(context, 'Data lokal dan material recovery lama sudah direset.');
  }

  Future<bool> _confirmPermanentWipe(BuildContext context) async {
    final input = TextEditingController();
    var matches = false;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Konfirmasi penghapusan permanen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Ketik HAPUS untuk mengonfirmasi bahwa seluruh data lokal dan material recovery akan direset.'),
              const SizedBox(height: 12),
              TextField(
                controller: input,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Ketik HAPUS'),
                onChanged: (value) => setState(() => matches = value.trim() == 'HAPUS'),
                onSubmitted: (_) {
                  if (matches) Navigator.pop(ctx, true);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error,
                foregroundColor: Theme.of(ctx).colorScheme.onError,
              ),
              onPressed: matches ? () => Navigator.pop(ctx, true) : null,
              child: const Text('Hapus seluruh data'),
            ),
          ],
        ),
      ),
    );
    input.dispose();
    return result == true;
  }

  String _formatRecoveryTime(DateTime value) {
    final local = value.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
  }

  Future<String?> _askSecret(BuildContext context, {required String title, required String label, required bool obscure}) async {
    final input = TextEditingController();
    final result = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(controller: input, autofocus: true, obscureText: obscure, decoration: InputDecoration(labelText: label), onSubmitted: (v) => Navigator.pop(ctx, v)),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')), FilledButton(onPressed: () => Navigator.pop(ctx, input.text), child: const Text('Lanjut'))],
    ));
    input.dispose();
    return result;
  }

  void _snack(BuildContext context, String value) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value.replaceFirst('Bad state: ', '').replaceFirst('Invalid argument(s): ', ''))));
}
