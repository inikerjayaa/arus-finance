import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../shared/saku_icon_registry.dart';

class StoredCustomIcon {
  const StoredCustomIcon({
    required this.key,
    required this.file,
    required this.extension,
    required this.byteLength,
  });

  final String key;
  final File file;
  final String extension;
  final int byteLength;
}

/// Device-owned custom icon storage for SAKU.
///
/// The repository never uploads icon bytes and never requires a server. Keys
/// are content-addressed so importing the same image twice reuses one file.
class CustomIconRepository {
  static const int maxBytes = 1024 * 1024;

  Future<StoredCustomIcon> save(Uint8List bytes) async {
    if (bytes.isEmpty) {
      throw const FormatException('File ikon kosong.');
    }
    if (bytes.length > maxBytes) {
      throw const FormatException('Ukuran ikon maksimal 1 MB.');
    }
    final extension = detectExtension(bytes);
    if (extension == null) {
      throw const FormatException('Gunakan ikon PNG, JPG/JPEG, atau WEBP.');
    }

    final hash = sha256.convert(bytes).toString();
    final directory = await _directory();
    await directory.create(recursive: true);
    final filename = '$hash.$extension';
    final file = File(p.join(directory.path, filename));
    if (!await file.exists()) {
      final pending = File('${file.path}.pending');
      try {
        await pending.writeAsBytes(bytes, flush: true);
        if (await pending.length() != bytes.length) {
          throw const FileSystemException('Ikon custom tidak tersimpan lengkap.');
        }
        await pending.rename(file.path);
      } catch (_) {
        try {
          if (await pending.exists()) await pending.delete();
        } catch (_) {}
        rethrow;
      }
    }
    return StoredCustomIcon(
      key: '${SakuIconRegistry.customPrefix}$filename',
      file: file,
      extension: extension,
      byteLength: bytes.length,
    );
  }

  Future<File?> resolve(String? key) async {
    final filename = _filenameFromKey(key);
    if (filename == null) return null;
    final directory = await _directory();
    final file = File(p.join(directory.path, filename));
    return await file.exists() ? file : null;
  }

  Future<Uint8List?> read(String? key) async {
    final file = await resolve(key);
    if (file == null) return null;
    final length = await file.length();
    if (length <= 0 || length > maxBytes) return null;
    final bytes = await file.readAsBytes();
    return detectExtension(bytes) == null ? null : bytes;
  }

  Future<void> delete(String? key) async {
    final file = await resolve(key);
    if (file != null) await file.delete();
  }

  Future<void> purgeAll() async {
    final directory = await _directory();
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  static String? detectExtension(List<int> bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A) {
      return 'png';
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'jpg';
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'webp';
    }
    return null;
  }

  static String? _filenameFromKey(String? key) {
    if (!SakuIconRegistry.isCustomKey(key)) return null;
    final filename = key!.substring(SakuIconRegistry.customPrefix.length);
    if (filename.contains('/') || filename.contains('\\')) return null;
    if (!RegExp(r'^[0-9a-f]{64}\.(png|jpg|webp)$').hasMatch(filename)) {
      return null;
    }
    return filename;
  }

  Future<Directory> _directory() async {
    final support = await getApplicationSupportDirectory();
    return Directory(p.join(support.path, 'custom_icons'));
  }
}
