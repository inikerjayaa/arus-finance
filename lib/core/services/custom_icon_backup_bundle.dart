import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../db/app_database.dart';
import '../../shared/saku_icon_registry.dart';
import 'custom_icon_repository.dart';

class CustomIconBackupEntry {
  const CustomIconBackupEntry({required this.key, required this.bytes});

  final String key;
  final Uint8List bytes;

  Map<String, Object?> toJson() => <String, Object?>{
        'key': key,
        'bytes': base64Encode(bytes),
      };
}

/// Bounded, device-owned custom-icon payload used by portable backup.
///
/// Financial restore remains independent from the presence of an icon: capture
/// skips a referenced icon whose local file is already missing. Any icon bytes
/// that *are* present are authenticated by the outer encrypted backup and then
/// revalidated here by key, content hash, file signature, count, and total size.
class CustomIconBackupBundle {
  CustomIconBackupBundle(
    this.database, {
    CustomIconRepository? repository,
  }) : repository = repository ?? CustomIconRepository();

  final AppDatabase database;
  final CustomIconRepository repository;

  static const int maxEntries = 64;
  static const int maxTotalBytes = 8 * 1024 * 1024;

  Future<List<Map<String, Object?>>> captureReferenced() async {
    await database.open();
    final keys = <String>{};
    for (final table in const ['accounts', 'categories']) {
      final rows = database.db.select(
        '''SELECT DISTINCT visual_icon_key AS icon_key
           FROM $table
           WHERE visual_icon_key LIKE 'custom:%' ''',
      );
      for (final row in rows) {
        final key = row['icon_key'];
        if (key is String && SakuIconRegistry.isCustomKey(key)) {
          keys.add(key);
        }
      }
    }

    if (keys.length > maxEntries) {
      throw StateError('Terlalu banyak ikon custom untuk satu backup.');
    }

    final result = <Map<String, Object?>>[];
    var total = 0;
    for (final key in keys.toList()..sort()) {
      final bytes = await repository.read(key);
      if (bytes == null) continue;
      total += bytes.length;
      if (total > maxTotalBytes) {
        throw StateError('Total ukuran ikon custom melebihi batas backup.');
      }
      result.add(CustomIconBackupEntry(key: key, bytes: bytes).toJson());
    }
    return result;
  }

  static List<CustomIconBackupEntry> decode(Object? raw) {
    if (raw == null) return const <CustomIconBackupEntry>[];
    if (raw is! List) {
      throw const FormatException('Payload ikon custom tidak valid.');
    }
    if (raw.length > maxEntries) {
      throw const FormatException('Terlalu banyak ikon custom pada backup.');
    }

    final result = <CustomIconBackupEntry>[];
    final seen = <String>{};
    var total = 0;
    for (final item in raw) {
      if (item is! Map) {
        throw const FormatException('Entri ikon custom tidak valid.');
      }
      final key = item['key'];
      final encoded = item['bytes'];
      if (key is! String ||
          !SakuIconRegistry.isCustomKey(key) ||
          encoded is! String ||
          encoded.isEmpty ||
          !seen.add(key)) {
        throw const FormatException('Identitas ikon custom tidak valid.');
      }

      late final Uint8List bytes;
      try {
        bytes = Uint8List.fromList(base64Decode(encoded));
      } catch (_) {
        throw const FormatException('Data ikon custom bukan base64 valid.');
      }
      if (bytes.isEmpty || bytes.length > CustomIconRepository.maxBytes) {
        throw const FormatException('Ukuran ikon custom pada backup tidak valid.');
      }
      total += bytes.length;
      if (total > maxTotalBytes) {
        throw const FormatException('Total ikon custom pada backup terlalu besar.');
      }

      final extension = CustomIconRepository.detectExtension(bytes);
      if (extension == null || !key.endsWith('.$extension')) {
        throw const FormatException('Format ikon custom tidak cocok dengan key.');
      }
      final expectedHash = key
          .substring(SakuIconRegistry.customPrefix.length)
          .split('.')
          .first;
      final actualHash = sha256.convert(bytes).toString();
      if (expectedHash != actualHash) {
        throw const FormatException('Hash ikon custom pada backup tidak valid.');
      }

      result.add(CustomIconBackupEntry(key: key, bytes: bytes));
    }
    return result;
  }

  Future<void> restoreValidated(List<CustomIconBackupEntry> entries) async {
    for (final entry in entries) {
      final stored = await repository.save(entry.bytes);
      if (stored.key != entry.key) {
        throw const FormatException('Identitas ikon custom berubah saat restore.');
      }
    }
  }
}
