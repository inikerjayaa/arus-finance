import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/db/app_database.dart';
import '../../core/services/backup_service.dart';

class RecoveryScreen extends StatefulWidget {
  const RecoveryScreen({super.key, required this.controller, required this.database, required this.errorMessage});
  final AppController controller;
  final AppDatabase database;
  final String errorMessage;
  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen> {
  late final BackupService _backup = BackupService(widget.database);
  DateTime? _latestLocalRecovery;
  bool _checking = true;
  bool _busy = false;
  String? _status;

  @override
  void initState() { super.initState(); _loadRecoveryState(); }

  Future<void> _loadRecoveryState() async {
    try { _latestLocalRecovery = await _backup.latestLocalRecoveryAt(); } catch (_) { _latestLocalRecovery = null; }
    if (mounted) setState(() => _checking = false);
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
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.health_and_safety_outlined, size: 56, color: theme.colorScheme.primary),
                  const SizedBox(height: 18),
                  Semantics(header: true, child: Text('Mode Pemulihan Data', textAlign: TextAlign.center, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700))),
                  const SizedBox(height: 10),
                  Text('SAKU tidak akan menimpa database yang gagal dibuka. Pilih jalur pemulihan yang tersedia di bawah ini.', textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 18),
                  Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Alasan startup dihentikan', style: TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 8), Text(widget.errorMessage)]))),
                  const SizedBox(height: 16),
                  FilledButton.icon(onPressed: _busy ? null : _retry, icon: const Icon(Icons.refresh), label: const Text('Coba buka database lagi')),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _busy || _checking || _latestLocalRecovery == null ? null : _restoreLocal,
                    icon: const Icon(Icons.history_rounded),
                    label: Text(_checking ? 'Memeriksa titik pemulihan lokal…' : _latestLocalRecovery == null ? 'Tidak ada titik pemulihan lokal' : 'Pulihkan titik lokal terbaru • ${_formatTime(_latestLocalRecovery!)}'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(onPressed: _busy ? null : _restorePortable, icon: const Icon(Icons.folder_open_outlined), label: const Text('Pulihkan dari file .arusbackup')),
                  if (_busy) ...[const SizedBox(height: 18), const Semantics(label: 'Pemulihan sedang berjalan', liveRegion: true, child: LinearProgressIndicator())],
                  if (_status != null) ...[const SizedBox(height: 14), Semantics(liveRegion: true, child: Text(_status!, textAlign: TextAlign.center, style: theme.textTheme.bodySmall))],
                  const SizedBox(height: 16),
                  Text('Database lama dipindahkan ke area quarantine sebelum replacement dimulai. Jika recovery terputus sebelum replacement tervalidasi, startup berikutnya mengembalikan database lama.', textAlign: TextAlign.center, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _retry() async {
    await _runRecovery(() async {
      await widget.controller.initialize();
      if (widget.controller.errorMessage != null) throw StateError(widget.controller.errorMessage!);
    }, success: 'Database berhasil dibuka kembali.');
  }

  Future<void> _restoreLocal() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pulihkan titik lokal terbaru?'),
        content: const Text('SAKU akan menyimpan database yang gagal dibuka di quarantine, membangun database baru, lalu memasukkan snapshot terenkripsi terbaru. Replacement hanya dianggap sah setelah seluruh integrity check lulus.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Pulihkan'))],
      ),
    );
    if (confirmed != true) return;
    await _runRecovery(() async {
      await _backup.restoreLatestLocalRecoveryAsRecovery();
      await widget.controller.initialize();
      if (widget.controller.errorMessage != null) throw StateError(widget.controller.errorMessage!);
    }, success: 'Pemulihan lokal berhasil dan integrity check lulus.');
  }

  Future<void> _restorePortable() async {
    final pick = await FilePicker.pickFile(type: FileType.any);
    final path = pick?.path;
    if (path == null || !mounted) return;
    final passphrase = await _askPassphrase();
    if (passphrase == null || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pulihkan portable backup?'),
        content: const Text('File akan didekripsi dan diperiksa terlebih dahulu. Database lama tidak ditimpa langsung; SAKU menggunakan quarantine + validated replacement.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Pulihkan'))],
      ),
    );
    if (confirmed != true) return;
    await _runRecovery(() async {
      await _backup.restorePortableBackupAsRecovery(File(path), passphrase);
      await widget.controller.initialize();
      if (widget.controller.errorMessage != null) throw StateError(widget.controller.errorMessage!);
    }, success: 'Portable backup berhasil dipulihkan dan tervalidasi.');
  }

  Future<void> _runRecovery(Future<void> Function() action, {required String success}) async {
    if (_busy) return;
    setState(() { _busy = true; _status = null; });
    try {
      await action();
      if (!mounted) return;
      setState(() => _status = success);
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Pemulihan belum berhasil. Data lama tidak sengaja dibuang. ${_message(e)}');
      await _loadRecoveryState();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _askPassphrase() async {
    final input = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Passphrase backup'),
        content: TextField(controller: input, autofocus: true, obscureText: true, decoration: const InputDecoration(labelText: 'Passphrase'), onSubmitted: (value) => Navigator.pop(ctx, value)),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')), FilledButton(onPressed: () => Navigator.pop(ctx, input.text), child: const Text('Lanjut'))],
      ),
    );
    input.dispose();
    return result;
  }

  String _formatTime(DateTime value) {
    final local = value.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
  }

  String _message(Object error) => error.toString().replaceFirst('Bad state: ', '').replaceFirst('Invalid argument(s): ', '');
}
