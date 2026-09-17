import 'dart:io';
import 'dart:typed_data';

import 'package:arus_finance/core/db/app_database.dart';
import 'package:arus_finance/core/services/custom_icon_backup_bundle.dart';
import 'package:arus_finance/core/services/custom_icon_repository.dart';
import 'package:arus_finance/core/services/visual_identity_store.dart';
import 'package:arus_finance/data/local_finance_repository.dart';
import 'package:arus_finance/domain/enums.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryCustomIcons extends CustomIconRepository {
  _MemoryCustomIcons(this.files);

  final Map<String, Uint8List> files;
  final List<String> restored = <String>[];

  @override
  Future<Uint8List?> read(String? key) async => files[key];

  @override
  Future<StoredCustomIcon> save(Uint8List bytes) async {
    final extension = CustomIconRepository.detectExtension(bytes)!;
    final key = 'custom:${sha256.convert(bytes)}.$extension';
    restored.add(key);
    files[key] = bytes;
    return StoredCustomIcon(
      key: key,
      file: File('memory/$key'),
      extension: extension,
      byteLength: bytes.length,
    );
  }
}

Uint8List _pngBytes([int marker = 0]) => Uint8List.fromList(<int>[
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
      marker,
    ]);

String _keyFor(Uint8List bytes) => 'custom:${sha256.convert(bytes)}.png';

void main() {
  test('capture includes only referenced readable custom icons', () async {
    final database = AppDatabase.inMemory();
    addTearDown(database.close);
    final finance = LocalFinanceRepository(database);
    await finance.initialize();
    final visuals = VisualIdentityStore(database);

    final usedBytes = _pngBytes(1);
    final orphanBytes = _pngBytes(2);
    final usedKey = _keyFor(usedBytes);
    final orphanKey = _keyFor(orphanBytes);
    final icons = _MemoryCustomIcons(<String, Uint8List>{
      usedKey: usedBytes,
      orphanKey: orphanBytes,
    });

    final cash = (await finance.listAccounts()).firstWhere(
      (account) => account.accountType == AccountType.cash,
    );
    await visuals.setAccount(
      accountId: cash.id,
      iconKey: usedKey,
      colorKey: 'green',
    );

    final payload = await CustomIconBackupBundle(
      database,
      repository: icons,
    ).captureReferenced();

    expect(payload, hasLength(1));
    expect(payload.single['key'], usedKey);
    expect(payload.single['key'], isNot(orphanKey));
  });

  test('decode rejects custom icon whose bytes do not match content hash', () {
    final original = _pngBytes(3);
    final tampered = _pngBytes(4);
    final key = _keyFor(original);
    final encodedTampered = CustomIconBackupEntry(
      key: key,
      bytes: tampered,
    ).toJson();

    expect(
      () => CustomIconBackupBundle.decode(<Object?>[encodedTampered]),
      throwsFormatException,
    );
  });

  test('validated restore preserves the content-addressed custom key', () async {
    final bytes = _pngBytes(5);
    final key = _keyFor(bytes);
    final icons = _MemoryCustomIcons(<String, Uint8List>{});
    final database = AppDatabase.inMemory();
    addTearDown(database.close);

    final decoded = CustomIconBackupBundle.decode(<Object?>[
      CustomIconBackupEntry(key: key, bytes: bytes).toJson(),
    ]);
    await CustomIconBackupBundle(
      database,
      repository: icons,
    ).restoreValidated(decoded);

    expect(icons.restored, <String>[key]);
    expect(icons.files[key], orderedEquals(bytes));
  });
}
