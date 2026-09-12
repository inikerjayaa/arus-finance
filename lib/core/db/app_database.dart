import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import 'schema.dart';

class FreshRecoverySession {
  const FreshRecoverySession({
    required this.quarantineDirectory,
    required this.hadDatabase,
    required this.hadDatabaseKey,
  });

  final String quarantineDirectory;
  final bool hadDatabase;
  final bool hadDatabaseKey;
}

class AppDatabase {
  AppDatabase({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(resetOnError: false),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.unlocked_this_device,
              ),
            ),
        _inMemory = false;

  AppDatabase.inMemory()
      : _secureStorage = const FlutterSecureStorage(),
        _inMemory = true;

  static const _databaseKeyStorageKey = 'arus_db_key_v1';
  static const _localRecoveryKeyStorageKey = 'arus_local_recovery_key_v1';
  static const _recoveryMarkerName = 'arus_recovery_in_progress_v1.json';

  final FlutterSecureStorage _secureStorage;
  final bool _inMemory;
  Database? _db;
  bool _validatedRecoveryPendingFinalize = false;

  Database get db => _db ?? (throw StateError('Database not initialized'));

  Future<void> open() async {
    if (_db != null) return;
    Database? database;
    try {
      if (_inMemory) {
        database = sqlite3.openInMemory();
      } else {
        await _resolveInterruptedRecoveryIfNeeded();
        final dir = await getApplicationSupportDirectory();
        final path = p.join(dir.path, 'arus_finance.db');
        final file = File(path);
        final databaseAlreadyExists =
            file.existsSync() && file.lengthSync() > 0;

        // Resolve the key before sqlite3.open() can create/modify the DB file.
        // If an existing encrypted DB has lost its secure-storage key, fail
        // closed instead of silently generating a new key that can never
        // decrypt the existing financial data.
        final key = await _getOrCreateDatabaseKey(
          databaseAlreadyExists: databaseAlreadyExists,
        );
        database = sqlite3.open(path);
        final escaped = key.replaceAll("'", "''");
        database.execute("PRAGMA key = '$escaped'");
        database.select('SELECT count(*) FROM sqlite_master');
      }

      database.execute('PRAGMA foreign_keys = ON');
      database.execute('PRAGMA secure_delete = ON');
      database.execute('PRAGMA busy_timeout = 5000');
      if (!_inMemory) {
        database.execute('PRAGMA journal_mode = WAL');
        database.execute('PRAGMA synchronous = FULL');
        database.execute('PRAGMA wal_autocheckpoint = 1000');
      }

      _initializeSchema(database);
      if (!_inMemory && _validatedRecoveryPendingFinalize) {
        try {
          await _finishValidatedRecoveryAfterSuccessfulOpen();
        } catch (_) {
          // Cleanup is retryable on a later process start. A validated database
          // that opened successfully must not become unavailable only because
          // quarantine housekeeping failed.
        }
      }
      _db = database;
    } catch (_) {
      // open() must never leak a live/locked handle when key validation,
      // schema migration, or startup hardening fails.
      database?.close();
      rethrow;
    }
  }

  void _initializeSchema(Database database) {
    final metaExists = database
        .select(
          "SELECT COUNT(*) AS c FROM sqlite_master WHERE type='table' AND name='app_meta'",
        )
        .first['c'] as int;

    if (metaExists == 0) {
      database.execute('BEGIN IMMEDIATE');
      try {
        for (final sql in kSchemaStatements) {
          database.execute(sql);
        }
        database.execute(
          'INSERT OR REPLACE INTO app_meta(key,value) VALUES (?,?)',
          ['schema_version', '$kSchemaVersion'],
        );
        database.execute('COMMIT');
      } catch (_) {
        database.execute('ROLLBACK');
        rethrow;
      }
      _ensureDerivedSearchIndex(database);
      return;
    }

    final versionRows = database.select(
      "SELECT value FROM app_meta WHERE key='schema_version'",
    );
    if (versionRows.length != 1) {
      throw StateError(
        'Metadata versi database hilang/ambigu. Restore dari backup yang valid sebelum melanjutkan.',
      );
    }
    final rawVersion = versionRows.first['value'];
    final versionValue = rawVersion is String ? int.tryParse(rawVersion) : null;
    if (versionValue == null || versionValue < 1) {
      throw StateError(
        'Metadata versi database rusak. Restore dari backup yang valid sebelum melanjutkan.',
      );
    }
    var version = versionValue;
    if (version > kSchemaVersion) {
      throw StateError('Database dibuat oleh versi aplikasi yang lebih baru.');
    }

    // IMPORTANT: migrate the historical schema first. Current idempotent
    // objects may reference columns introduced by migrations (for example
    // bills.paid_transaction_id from v2). Ensuring current indexes/triggers
    // before migrations can make a legitimate old database fail to open.
    while (version < kSchemaVersion) {
      final target = version + 1;
      final statements = kSchemaMigrations[target];
      if (statements == null) {
        throw StateError('Migration database ke versi $target tidak tersedia.');
      }
      database.execute('BEGIN IMMEDIATE');
      try {
        for (final sql in statements) {
          database.execute(sql);
        }
        database.execute(
          'INSERT OR REPLACE INTO app_meta(key,value) VALUES (?,?)',
          ['schema_version', '$target'],
        );
        database.execute('COMMIT');
        version = target;
      } catch (_) {
        database.execute('ROLLBACK');
        rethrow;
      }
    }

    _ensureCurrentSchemaObjects(database);
    _ensureDerivedSearchIndex(database);
  }

  void _ensureCurrentSchemaObjects(Database database) {
    database.execute('BEGIN IMMEDIATE');
    try {
      for (final sql in kSchemaStatements) {
        database.execute(sql);
      }
      database.execute('COMMIT');
    } catch (_) {
      database.execute('ROLLBACK');
      rethrow;
    }
  }

  void _ensureDerivedSearchIndex(Database database) {
    final exists = database
        .select(
          "SELECT COUNT(*) AS c FROM sqlite_master WHERE type='table' AND name='transaction_search'",
        )
        .first['c'] as int;
    if (exists == 0) return;

    var needsRebuild = false;
    try {
      database.execute(
        "INSERT INTO transaction_search(transaction_search) VALUES('integrity-check')",
      );
      final txCount = database
          .select('SELECT COUNT(*) AS c FROM transactions')
          .first['c'] as int;
      final searchCount = database
          .select('SELECT COUNT(*) AS c FROM transaction_search')
          .first['c'] as int;
      needsRebuild = txCount != searchCount;
    } catch (_) {
      needsRebuild = true;
    }
    if (!needsRebuild) return;

    database.execute('BEGIN IMMEDIATE');
    try {
      database.execute('DELETE FROM transaction_search');
      database.execute('''
        INSERT INTO transaction_search(
          transaction_id,note,type,amount,account,category
        )
        SELECT
          t.id,
          COALESCE(t.note,''),
          t.type,
          CAST(t.primary_amount_minor AS TEXT),
          COALESCE((
            SELECT group_concat(a.name,' ')
            FROM transaction_legs l
            JOIN accounts a ON a.id=l.account_id
            WHERE l.transaction_id=t.id
          ),''),
          COALESCE((
            SELECT group_concat(c.name,' ')
            FROM transaction_splits s
            JOIN categories c ON c.id=s.category_id
            WHERE s.transaction_id=t.id
          ),'')
        FROM transactions t
      ''');
      database.execute(
        "INSERT INTO transaction_search(transaction_search) VALUES('integrity-check')",
      );
      database.execute('COMMIT');
    } catch (_) {
      database.execute('ROLLBACK');
      rethrow;
    }
  }

  Future<String> _getOrCreateDatabaseKey({
    required bool databaseAlreadyExists,
  }) async {
    final existing = await _secureStorage.read(key: _databaseKeyStorageKey);
    if (existing != null && existing.isNotEmpty) return existing;

    if (databaseAlreadyExists) {
      throw StateError(
        'Kunci database lokal tidak tersedia. Data terenkripsi tidak akan ditimpa; pulihkan melalui backup portable yang valid.',
      );
    }

    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    final value = base64UrlEncode(bytes);
    await _secureStorage.write(key: _databaseKeyStorageKey, value: value);
    return value;
  }



  Future<List<int>?> localRecoveryKey({bool createIfMissing = true}) async {
    if (_inMemory) return null;
    final existing = await _secureStorage.read(key: _localRecoveryKeyStorageKey);
    if (existing != null && existing.isNotEmpty) {
      try {
        final decoded = base64Url.decode(existing);
        if (decoded.length == 32) return decoded;
      } catch (_) {
        throw StateError(
          'Kunci recovery lokal rusak. Gunakan portable backup dengan passphrase.',
        );
      }
      throw StateError(
        'Kunci recovery lokal tidak valid. Gunakan portable backup dengan passphrase.',
      );
    }
    if (!createIfMissing) return null;
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    await _secureStorage.write(
      key: _localRecoveryKeyStorageKey,
      value: base64UrlEncode(bytes),
    );
    return bytes;
  }

  Future<void> deleteLocalRecoveryKey() async {
    if (_inMemory) return;
    await _secureStorage.delete(key: _localRecoveryKeyStorageKey);
  }

  Future<FreshRecoverySession> beginFreshRecovery() async {
    if (_inMemory) {
      throw StateError('Fresh recovery hanya tersedia untuk database perangkat.');
    }
    close();
    final dir = await getApplicationSupportDirectory();
    final dbFile = File(p.join(dir.path, 'arus_finance.db'));
    final hadDatabase = dbFile.existsSync() && dbFile.lengthSync() > 0;
    final hadDatabaseKey =
        (await _secureStorage.read(key: _databaseKeyStorageKey))?.isNotEmpty == true;
    final quarantineRoot = Directory(p.join(dir.path, 'recovery_quarantine'));
    await quarantineRoot.create(recursive: true);
    final quarantine = Directory(
      p.join(
        quarantineRoot.path,
        DateTime.now().toUtc().microsecondsSinceEpoch.toString(),
      ),
    );
    await quarantine.create(recursive: true);

    final session = FreshRecoverySession(
      quarantineDirectory: quarantine.path,
      hadDatabase: hadDatabase,
      hadDatabaseKey: hadDatabaseKey,
    );
    await _writeRecoveryMarker(
      <String, Object?>{
        'version': 1,
        'state': 'preparing',
        'quarantine_directory': quarantine.path,
        'had_database': hadDatabase,
        'had_database_key': hadDatabaseKey,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      },
    );

    try {
      await _moveDatabaseFamilyToQuarantine(quarantine);
      await _writeRecoveryMarker(
        <String, Object?>{
          'version': 1,
          'state': 'quarantined',
          'quarantine_directory': quarantine.path,
          'had_database': hadDatabase,
          'had_database_key': hadDatabaseKey,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        },
      );
      return session;
    } catch (_) {
      await _rollbackRecoveryFiles(session);
      rethrow;
    }
  }

  Future<void> markFreshRecoveryValidated(FreshRecoverySession session) async {
    if (_inMemory) return;
    await _writeRecoveryMarker(
      <String, Object?>{
        'version': 1,
        'state': 'replacement_validated',
        'quarantine_directory': session.quarantineDirectory,
        'had_database': session.hadDatabase,
        'had_database_key': session.hadDatabaseKey,
        'validated_at': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  Future<void> finalizeFreshRecovery(FreshRecoverySession session) async {
    if (_inMemory) return;
    final marker = await _recoveryMarkerFile();
    final pending = File('${marker.path}.pending');
    if (await marker.exists()) await marker.delete();
    if (await pending.exists()) await pending.delete();
    await _pruneRecoveryQuarantine(keep: 1);
  }

  Future<void> rollbackFreshRecovery(FreshRecoverySession session) async {
    if (_inMemory) return;
    close();
    await _rollbackRecoveryFiles(session);
  }

  Future<void> purgeRecoveryQuarantine() async {
    if (_inMemory) return;
    final dir = await getApplicationSupportDirectory();
    final marker = File(p.join(dir.path, _recoveryMarkerName));
    final markerPending = File(p.join(dir.path, '$_recoveryMarkerName.pending'));
    if (await marker.exists()) await marker.delete();
    if (await markerPending.exists()) await markerPending.delete();
    final quarantine = Directory(p.join(dir.path, 'recovery_quarantine'));
    if (await quarantine.exists()) await quarantine.delete(recursive: true);
  }

  Future<void> _resolveInterruptedRecoveryIfNeeded() async {
    final marker = await _recoveryMarkerFile();
    final pending = File('${marker.path}.pending');
    if (!await marker.exists()) {
      // A pending-only marker means the process died before the atomic publish.
      // No recovery state transition is considered committed yet.
      if (await pending.exists()) {
        try {
          await pending.delete();
        } catch (_) {}
      }
      return;
    }
    Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(await marker.readAsString());
      if (decoded is! Map<String, dynamic> || decoded['version'] != 1) {
        throw const FormatException('Recovery marker tidak valid.');
      }
      data = decoded;
    } catch (_) {
      throw StateError(
        'Recovery lokal pernah terputus dan marker-nya rusak. Jangan timpa data; gunakan portable backup atau bantuan recovery.',
      );
    }
    final quarantinePath = data['quarantine_directory'];
    final hadDatabase = data['had_database'];
    final hadKey = data['had_database_key'];
    if (quarantinePath is! String ||
        hadDatabase is! bool ||
        hadKey is! bool) {
      throw StateError('Recovery marker tidak lengkap; data lama tidak akan ditimpa.');
    }
    final session = FreshRecoverySession(
      quarantineDirectory: quarantinePath,
      hadDatabase: hadDatabase,
      hadDatabaseKey: hadKey,
    );
    if (data['state'] == 'replacement_validated') {
      // Keep marker + quarantine until the canonical replacement successfully
      // opens and finishes schema initialization. This avoids discarding the
      // old recovery trail one step too early.
      _validatedRecoveryPendingFinalize = true;
      return;
    }
    await _rollbackRecoveryFiles(session);
  }

  Future<void> _finishValidatedRecoveryAfterSuccessfulOpen() async {
    final marker = await _recoveryMarkerFile();
    final pending = File('${marker.path}.pending');
    if (await marker.exists()) await marker.delete();
    if (await pending.exists()) await pending.delete();
    _validatedRecoveryPendingFinalize = false;
    await _pruneRecoveryQuarantine(keep: 1);
  }

  Future<File> _recoveryMarkerFile() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, _recoveryMarkerName));
  }

  Future<void> _writeRecoveryMarker(Map<String, Object?> value) async {
    final marker = await _recoveryMarkerFile();
    final pending = File('${marker.path}.pending');
    try {
      await pending.writeAsString(jsonEncode(value), flush: true);
      // Android/iOS use POSIX-style filesystems. A rename in one directory is
      // the publish boundary: until it succeeds, the previous committed marker
      // remains authoritative.
      await pending.rename(marker.path);
    } catch (_) {
      try {
        if (await pending.exists()) await pending.delete();
      } catch (_) {}
      rethrow;
    }
  }

  Future<void> _moveDatabaseFamilyToQuarantine(Directory quarantine) async {
    final dir = await getApplicationSupportDirectory();
    for (final name in const [
      'arus_finance.db',
      'arus_finance.db-wal',
      'arus_finance.db-shm',
    ]) {
      final source = File(p.join(dir.path, name));
      if (!await source.exists()) continue;
      await source.rename(p.join(quarantine.path, name));
    }
  }

  Future<void> _rollbackRecoveryFiles(FreshRecoverySession session) async {
    final dir = await getApplicationSupportDirectory();
    final quarantine = Directory(session.quarantineDirectory);
    final quarantinedDatabase = File(
      p.join(quarantine.path, 'arus_finance.db'),
    );

    // A crash can happen after the marker is flushed but before the original
    // DB is moved. In that state the canonical DB is still the only copy of
    // the user's data and MUST NOT be deleted.
    if (session.hadDatabase && !await quarantinedDatabase.exists()) {
      final marker = await _recoveryMarkerFile();
      final pending = File('${marker.path}.pending');
      if (await marker.exists()) await marker.delete();
      if (await pending.exists()) await pending.delete();
      if (await quarantine.exists()) {
        try {
          await quarantine.delete(recursive: true);
        } catch (_) {}
      }
      return;
    }

    for (final name in const [
      'arus_finance.db-wal',
      'arus_finance.db-shm',
      'arus_finance.db',
    ]) {
      final current = File(p.join(dir.path, name));
      if (await current.exists()) await current.delete();
    }
    if (await quarantine.exists()) {
      for (final name in const [
        'arus_finance.db',
        'arus_finance.db-wal',
        'arus_finance.db-shm',
      ]) {
        final old = File(p.join(quarantine.path, name));
        if (await old.exists()) {
          await old.rename(p.join(dir.path, name));
        }
      }
      if (await quarantine.exists()) {
        try {
          await quarantine.delete(recursive: true);
        } catch (_) {}
      }
    }
    if (!session.hadDatabaseKey) {
      await _secureStorage.delete(key: _databaseKeyStorageKey);
    }
    final marker = await _recoveryMarkerFile();
    final pending = File('${marker.path}.pending');
    if (await marker.exists()) await marker.delete();
    if (await pending.exists()) await pending.delete();
  }

  Future<void> _pruneRecoveryQuarantine({required int keep}) async {
    final dir = await getApplicationSupportDirectory();
    final root = Directory(p.join(dir.path, 'recovery_quarantine'));
    if (!await root.exists()) return;
    final entries = await root
        .list()
        .where((entity) => entity is Directory)
        .cast<Directory>()
        .toList();
    entries.sort((a, b) => b.path.compareTo(a.path));
    for (final extra in entries.skip(keep)) {
      try {
        await extra.delete(recursive: true);
      } catch (_) {}
    }
  }

  /// Structural checks used before/after portable recovery operations.
  void assertQuickIntegrity() {
    final rows = db.select('PRAGMA quick_check');
    if (rows.isEmpty) {
      throw StateError('Database integrity check tidak menghasilkan status.');
    }
    final failures = rows
        .where(
          (r) =>
              r.values.isEmpty ||
              r.values.first.toString().toLowerCase() != 'ok',
        )
        .toList();
    if (failures.isNotEmpty) {
      throw StateError(
        'Database lokal gagal integrity check. Jangan membuat backup baru sebelum data dipulihkan.',
      );
    }

    final foreignKeyFailures = db.select('PRAGMA foreign_key_check');
    if (foreignKeyFailures.isNotEmpty) {
      throw StateError(
        'Database lokal memiliki referensi data yang rusak. Jangan membuat backup baru sebelum data dipulihkan.',
      );
    }

    try {
      db.execute(
        "INSERT INTO transaction_search(transaction_search) VALUES('integrity-check')",
      );
      final txCount =
          db.select('SELECT COUNT(*) AS c FROM transactions').first['c'] as int;
      final searchCount = db
          .select('SELECT COUNT(*) AS c FROM transaction_search')
          .first['c'] as int;
      if (txCount != searchCount) {
        throw StateError('Search index tidak sinkron dengan transaksi.');
      }
    } catch (e) {
      throw StateError('Search index lokal gagal integrity check: $e');
    }
  }

  void secureMaintenanceAfterWipe() {
    if (_inMemory) return;
    db.execute('PRAGMA wal_checkpoint(TRUNCATE)');
    db.execute('VACUUM');
  }

  T readSnapshot<T>(T Function(Database db) body) {
    db.execute('BEGIN');
    try {
      final result = body(db);
      db.execute('COMMIT');
      return result;
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  T transaction<T>(T Function(Database db) body) {
    db.execute('BEGIN IMMEDIATE');
    try {
      final result = body(db);
      db.execute('COMMIT');
      return result;
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  void close() {
    _db?.close();
    _db = null;
  }
}
