import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../db/app_database.dart';
import '../db/schema.dart';
import '../../domain/money_limits.dart';

class _DecodedBackup {
  const _DecodedBackup({required this.schemaVersion, required this.tables});
  final int schemaVersion;
  final Map<String, dynamic> tables;
}

class BackupService {
  BackupService(this.database);
  final AppDatabase database;

  void verifyLocalDatabase() {
    database.assertQuickIntegrity();
    _validateLedger(database.db);
  }

  static const _tables = <String>[
    'accounts',
    'categories',
    'transaction_groups',
    'transactions',
    'transaction_legs',
    'transaction_splits',
    'budgets',
    'bills',
    'recurring_rules',
    'recurring_occurrences',
    'import_fingerprints',
  ];

  Future<File> createPortableBackup(String passphrase) async {
    _validatePassphrase(passphrase);
    database.assertQuickIntegrity();

    final payload = _capturePayload();
    final clear = utf8.encode(jsonEncode(payload));
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    final nonce = List<int>.generate(12, (_) => random.nextInt(256));
    final key = await _deriveKey(passphrase, salt);
    final algorithm = AesGcm.with256bits();
    final box = await algorithm.encrypt(clear, secretKey: key, nonce: nonce);
    final envelope = {
      'format': 'arus-finance-encrypted-backup',
      'version': 1,
      'kdf': 'ARGON2ID',
      'memory_kib': 65536,
      'iterations': 3,
      'parallelism': 2,
      'salt': base64Encode(salt),
      'nonce': base64Encode(box.nonce),
      'ciphertext': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    };
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final pending = File(p.join(dir.path, '.arus_backup_$stamp.pending'));
    final file = File(p.join(dir.path, 'arus_backup_$stamp.arusbackup'));
    try {
      await pending.writeAsString(jsonEncode(envelope), flush: true);
      return await pending.rename(file.path);
    } catch (_) {
      try {
        if (await pending.exists()) await pending.delete();
      } catch (_) {}
      rethrow;
    }
  }

  Future<void> restorePortableBackup(File file, String passphrase) async {
    final decoded = await _decodePortableBackup(file, passphrase);
    // A normal in-app restore is destructive even when the selected backup is
    // perfectly valid. Capture an exact pre-restore local generation first.
    // If storage is full, abort before touching live financial data.
    await createLocalRecoveryGeneration(force: true);
    _restoreDecodedBackup(decoded);
  }

  Future<void> restorePortableBackupAsRecovery(
    File file,
    String passphrase,
  ) async {
    final decoded = await _decodePortableBackup(file, passphrase);
    await _restoreDecodedAsFreshRecovery(decoded);
  }

  Future<void> createLocalRecoveryGeneration({
    bool force = false,
    Duration minimumInterval = const Duration(hours: 12),
    int keep = 3,
  }) async {
    final dir = await _localRecoveryDirectory();
    await dir.create(recursive: true);
    final existing = await listLocalRecoveryGenerations();
    if (!force && existing.isNotEmpty) {
      final modified = await existing.first.lastModified();
      if (DateTime.now().difference(modified) < minimumInterval) return;
    }

    database.assertQuickIntegrity();
    final payload = _capturePayload();
    final clear = utf8.encode(jsonEncode(payload));
    final rawKey = await database.localRecoveryKey();
    if (rawKey == null || rawKey.length != 32) {
      throw StateError('Kunci recovery lokal tidak tersedia.');
    }
    final random = Random.secure();
    final nonce = List<int>.generate(12, (_) => random.nextInt(256));
    final box = await AesGcm.with256bits().encrypt(
      clear,
      secretKey: SecretKey(rawKey),
      nonce: nonce,
    );
    final envelope = <String, Object?>{
      'format': 'arus-finance-local-recovery',
      'version': 1,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'nonce': base64Encode(box.nonce),
      'ciphertext': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    };
    final stamp = DateTime.now().toUtc().microsecondsSinceEpoch;
    final pending = File(p.join(dir.path, '.generation_$stamp.pending'));
    final finalFile = File(p.join(dir.path, 'generation_$stamp.arusrecovery'));
    try {
      await pending.writeAsString(jsonEncode(envelope), flush: true);
      // Verify the candidate before it can become a generation. Existing good
      // generations are not pruned until the new one is fully written and
      // decryptable, so ENOSPC/interruption cannot destroy the last fallback.
      await _decodeLocalRecovery(pending);
      await pending.rename(finalFile.path);
      final generations = await listLocalRecoveryGenerations();
      for (final extra in generations.skip(keep)) {
        try {
          await extra.delete();
        } catch (_) {}
      }
    } catch (_) {
      try {
        if (await pending.exists()) await pending.delete();
      } catch (_) {}
      rethrow;
    }
  }

  Future<List<File>> listLocalRecoveryGenerations() async {
    final dir = await _localRecoveryDirectory();
    if (!await dir.exists()) return <File>[];
    final files = await dir
        .list()
        .where(
          (entity) =>
              entity is File && entity.path.endsWith('.arusrecovery'),
        )
        .cast<File>()
        .toList();
    files.sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  Future<DateTime?> latestLocalRecoveryAt() async {
    final generations = await listLocalRecoveryGenerations();
    if (generations.isEmpty) return null;
    return generations.first.lastModified();
  }

  Future<void> restoreLatestLocalRecoveryAsRecovery() async {
    final generations = await listLocalRecoveryGenerations();
    if (generations.isEmpty) {
      throw StateError('Belum ada titik pemulihan lokal yang tersedia.');
    }
    final decoded = await _decodeLocalRecovery(generations.first);
    await _restoreDecodedAsFreshRecovery(decoded);
  }

  Future<void> destroyLocalRecoveryMaterial() async {
    // Delete actual recovery artifacts before deleting the key. If filesystem
    // removal fails, keep the key so the user can retry cleanup instead of
    // stranding undeleted encrypted artifacts in an ambiguous state.
    await database.purgeRecoveryQuarantine();
    final dir = await _localRecoveryDirectory();
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    await database.deleteLocalRecoveryKey();
  }

  Map<String, Object?> _capturePayload() {
    final tableSnapshot = database.readSnapshot((db) {
      _validateLedger(db);
      return <String, Object?>{
        for (final table in _tables)
          table: db
              .select('SELECT * FROM $table')
              .map((row) => Map<String, Object?>.from(row))
              .toList(),
      };
    });
    return <String, Object?>{
      'format': 'arus-finance-backup',
      'format_version': 1,
      'schema_version': kSchemaVersion,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'tables': tableSnapshot,
    };
  }

  Future<_DecodedBackup> _decodePortableBackup(
    File file,
    String passphrase,
  ) async {
    _validatePassphrase(passphrase);
    const maxBackupBytes = 64 * 1024 * 1024;
    final size = await file.length();
    if (size <= 0 || size > maxBackupBytes) {
      throw const FormatException('Ukuran backup tidak valid atau terlalu besar.');
    }
    final decodedEnvelope = jsonDecode(await file.readAsString());
    if (decodedEnvelope is! Map<String, dynamic>) {
      throw const FormatException('Envelope backup tidak valid.');
    }
    final envelope = decodedEnvelope;
    if (envelope['format'] != 'arus-finance-encrypted-backup' ||
        envelope['version'] != 1 ||
        envelope['kdf'] != 'ARGON2ID' ||
        envelope['memory_kib'] != 65536 ||
        envelope['iterations'] != 3 ||
        envelope['parallelism'] != 2) {
      throw const FormatException('Format/parameter backup tidak didukung.');
    }
    final salt = _requiredBase64(envelope, 'salt');
    final nonce = _requiredBase64(envelope, 'nonce');
    final cipher = _requiredBase64(envelope, 'ciphertext');
    final macBytes = _requiredBase64(envelope, 'mac');
    if (salt.length != 16 ||
        nonce.length != 12 ||
        macBytes.length != 16 ||
        cipher.isEmpty) {
      throw const FormatException('Envelope kriptografi backup tidak valid.');
    }
    final key = await _deriveKey(passphrase, salt);
    final clear = await AesGcm.with256bits().decrypt(
      SecretBox(cipher, nonce: nonce, mac: Mac(macBytes)),
      secretKey: key,
    );
    return _decodePayload(clear);
  }

  Future<_DecodedBackup> _decodeLocalRecovery(File file) async {
    const maxRecoveryBytes = 64 * 1024 * 1024;
    final size = await file.length();
    if (size <= 0 || size > maxRecoveryBytes) {
      throw const FormatException('Ukuran titik pemulihan lokal tidak valid.');
    }
    final rawKey = await database.localRecoveryKey(createIfMissing: false);
    if (rawKey == null || rawKey.length != 32) {
      throw StateError(
        'Kunci titik pemulihan lokal tidak tersedia. Gunakan portable backup dengan passphrase.',
      );
    }
    final decodedEnvelope = jsonDecode(await file.readAsString());
    if (decodedEnvelope is! Map<String, dynamic> ||
        decodedEnvelope['format'] != 'arus-finance-local-recovery' ||
        decodedEnvelope['version'] != 1) {
      throw const FormatException('Format titik pemulihan lokal tidak valid.');
    }
    final nonce = _requiredBase64(decodedEnvelope, 'nonce');
    final cipher = _requiredBase64(decodedEnvelope, 'ciphertext');
    final macBytes = _requiredBase64(decodedEnvelope, 'mac');
    if (nonce.length != 12 || macBytes.length != 16 || cipher.isEmpty) {
      throw const FormatException('Kriptografi titik pemulihan lokal tidak valid.');
    }
    final clear = await AesGcm.with256bits().decrypt(
      SecretBox(cipher, nonce: nonce, mac: Mac(macBytes)),
      secretKey: SecretKey(rawKey),
    );
    return _decodePayload(clear);
  }

  List<int> _requiredBase64(Map<String, dynamic> envelope, String key) {
    final raw = envelope[key];
    if (raw is! String || raw.isEmpty) {
      throw FormatException('Field backup tidak valid: $key');
    }
    try {
      return base64Decode(raw);
    } catch (_) {
      throw FormatException('Field backup bukan base64 valid: $key');
    }
  }

  _DecodedBackup _decodePayload(List<int> clear) {
    final decoded = jsonDecode(utf8.decode(clear));
    if (decoded is! Map<String, dynamic> ||
        decoded['format'] != 'arus-finance-backup' ||
        decoded['format_version'] != 1) {
      throw const FormatException('Isi backup tidak valid.');
    }
    final schemaVersion = decoded['schema_version'];
    if (schemaVersion is! int || schemaVersion < 1) {
      throw const FormatException('Versi schema backup tidak valid.');
    }
    if (schemaVersion > kSchemaVersion) {
      throw StateError('Backup dibuat oleh versi database yang lebih baru.');
    }
    final rawTables = decoded['tables'];
    if (rawTables is! Map<String, dynamic>) {
      throw const FormatException('Struktur tabel backup tidak valid.');
    }
    for (final table in _tables) {
      if (table == 'import_fingerprints' && rawTables[table] == null) continue;
      if (rawTables[table] is! List) {
        throw FormatException('Tabel backup tidak valid: $table');
      }
    }
    return _DecodedBackup(schemaVersion: schemaVersion, tables: rawTables);
  }

  void _restoreDecodedBackup(_DecodedBackup decoded) {
    final schemaVersion = decoded.schemaVersion;
    final tables = decoded.tables;
    // Restore is atomic. Existing live data is unchanged if any
    // insert/validation fails.
    database.transaction((db) {
      db.execute('PRAGMA defer_foreign_keys = ON');
      for (final table in _tables.reversed) {
        db.execute('DELETE FROM $table');
      }

      final legacyPaidBillTransactions = <String>{};
      for (final table in _tables) {
        final rows = (tables[table] as List<dynamic>? ?? const []);
        for (final item in rows) {
          if (item is! Map) {
            throw FormatException('Baris backup tidak valid: $table');
          }
          final row = Map<String, dynamic>.from(item);
          if (row.isEmpty) continue;
          if (table == 'bills' && schemaVersion < 8) {
            final paidTransactionId = row['paid_transaction_id'];
            if (paidTransactionId is String && paidTransactionId.isNotEmpty) {
              if (!legacyPaidBillTransactions.add(paidTransactionId)) {
                row['paid_transaction_id'] = null;
                row['status'] = 'UPCOMING';
              }
            }
          }
          final columns = row.keys.toList();
          final placeholders = List.filled(columns.length, '?').join(',');
          final quoted = columns.map((c) {
            final escaped = c.replaceAll('"', '""');
            return '"$escaped"';
          }).join(',');
          db.execute(
            'INSERT INTO $table($quoted) VALUES ($placeholders)',
            columns.map((c) => row[c]).toList(),
          );
        }
      }
      _repairLegacyPortableBackupState(db, schemaVersion);
      _repairLegacyLocalOnlyState(db);
      _validateLedger(db);
    });
    database.assertQuickIntegrity();
  }

  Future<void> _restoreDecodedAsFreshRecovery(_DecodedBackup decoded) async {
    final session = await database.beginFreshRecovery();
    var validated = false;
    try {
      await database.open();
      _restoreDecodedBackup(decoded);
      await database.markFreshRecoveryValidated(session);
      validated = true;
      try {
        await createLocalRecoveryGeneration(force: true);
      } catch (_) {
        // Replacement data is already valid. Preserve it even when storage is
        // too full to create an additional recovery generation.
      }
      try {
        await database.finalizeFreshRecovery(session);
      } catch (_) {
        // A validated marker is intentionally crash-safe; startup can finish
        // cleanup without rolling back the validated replacement.
      }
    } catch (_) {
      if (!validated) {
        await database.rollbackFreshRecovery(session);
      }
      rethrow;
    }
  }

  Future<Directory> _localRecoveryDirectory() async {
    final dir = await getApplicationSupportDirectory();
    return Directory(p.join(dir.path, 'local_recovery'));
  }

  Future<SecretKey> _deriveKey(String passphrase, List<int> salt) {
    final kdf = Argon2id(memory: 64 * 1024, parallelism: 2, iterations: 3, hashLength: 32);
    return kdf.deriveKeyFromPassword(password: passphrase, nonce: salt);
  }

  void _validatePassphrase(String value) {
    if (value.length < 8) throw ArgumentError('Passphrase backup minimal 8 karakter.');
  }

  void _repairLegacyPortableBackupState(dynamic db, int schemaVersion) {
    if (schemaVersion < 4) {
      // V3 occurrence identity included the recurring-rule version. Collapse
      // duplicate occurrence markers by rule+calendar date before normalizing
      // the key so UNIQUE(rule_id, occurrence_key) cannot abort restore. Any
      // extra DRAFT transaction is intentionally left as an ordinary draft;
      // no posted financial effect is silently deleted.
      db.execute('''DELETE FROM recurring_occurrences
        WHERE rowid NOT IN (
          SELECT MIN(rowid) FROM recurring_occurrences
          GROUP BY rule_id, substr(scheduled_for,1,10)
        )''');
      db.execute(
        "UPDATE recurring_occurrences SET occurrence_key = rule_id || ':' || substr(scheduled_for,1,10)",
      );
      db.execute('''INSERT INTO transaction_legs(id, transaction_id, account_id, delta_minor, currency)
        SELECT lower(hex(randomblob(16))), t.id, rr.account_id,
               CASE WHEN a.account_class='ASSET' THEN -t.primary_amount_minor ELSE t.primary_amount_minor END,
               t.primary_currency
        FROM transactions t
        JOIN recurring_occurrences ro ON ro.transaction_id=t.id
        JOIN recurring_rules rr ON rr.id=ro.rule_id
        JOIN accounts a ON a.id=rr.account_id
        WHERE t.status='DRAFT' AND t.deleted_at IS NULL
          AND NOT EXISTS (SELECT 1 FROM transaction_legs l WHERE l.transaction_id=t.id)''');
    }
    if (schemaVersion < 5) {
      db.execute(
        "UPDATE recurring_rules SET next_run = substr(next_run,1,10) WHERE length(next_run) > 10",
      );
    }
  }

  void _repairLegacyLocalOnlyState(dynamic db) {
    // V9 local-only pivot removed sync-era tombstones. Old portable backups may
    // still contain them, so normalize the linked planning/refund state before
    // semantic validation. This mirrors the v8 -> v9 database migration.
    db.execute("UPDATE bills SET paid_transaction_id=NULL,status='UPCOMING' WHERE paid_transaction_id IN (SELECT id FROM transactions WHERE deleted_at IS NOT NULL)");
    db.execute("UPDATE recurring_occurrences SET transaction_id=NULL WHERE transaction_id IN (SELECT id FROM transactions WHERE deleted_at IS NOT NULL)");
    db.execute("UPDATE transactions SET status='VOIDED',original_transaction_id=NULL WHERE type='REFUND' AND original_transaction_id IN (SELECT id FROM transactions WHERE deleted_at IS NOT NULL)");
    db.execute("DELETE FROM transactions WHERE deleted_at IS NOT NULL");
    db.execute("DELETE FROM transaction_groups WHERE NOT EXISTS (SELECT 1 FROM transactions WHERE transaction_group_id=transaction_groups.id)");
  }

  void _validateLedger(dynamic db) {
    final fkErrors = db.select('PRAGMA foreign_key_check');
    final orphanLegs = db.select('SELECT COUNT(*) AS c FROM transaction_legs l LEFT JOIN transactions t ON t.id=l.transaction_id WHERE t.id IS NULL').first['c'] as int;
    final orphanSplits = db.select('SELECT COUNT(*) AS c FROM transaction_splits s LEFT JOIN transactions t ON t.id=s.transaction_id WHERE t.id IS NULL').first['c'] as int;
    final postedWithoutLeg = db.select("SELECT COUNT(*) AS c FROM transactions t WHERE t.status='POSTED' AND t.deleted_at IS NULL AND NOT EXISTS (SELECT 1 FROM transaction_legs l WHERE l.transaction_id=t.id)").first['c'] as int;
    final badCurrency = db.select('SELECT COUNT(*) AS c FROM transaction_legs l JOIN transactions t ON t.id=l.transaction_id WHERE l.currency<>t.primary_currency').first['c'] as int;
    final nonIdr = db.select("""SELECT (
      (SELECT COUNT(*) FROM accounts WHERE currency<>'IDR') +
      (SELECT COUNT(*) FROM transactions WHERE primary_currency<>'IDR') +
      (SELECT COUNT(*) FROM transaction_legs WHERE currency<>'IDR') +
      (SELECT COUNT(*) FROM transaction_splits WHERE currency<>'IDR') +
      (SELECT COUNT(*) FROM budgets WHERE currency<>'IDR') +
      (SELECT COUNT(*) FROM bills WHERE currency<>'IDR') +
      (SELECT COUNT(*) FROM recurring_rules WHERE currency<>'IDR')
    ) AS c""").first['c'] as int;
    final invalidTxEnum = db.select("SELECT COUNT(*) AS c FROM transactions WHERE type NOT IN ('EXPENSE','INCOME','TRANSFER','REFUND','ADJUSTMENT','OPENING_BALANCE','CREDIT_CARD_PAYMENT','LOAN_DISBURSEMENT','LOAN_PAYMENT') OR status NOT IN ('POSTED','DRAFT','SCHEDULED','VOIDED')").first['c'] as int;
    final invalidRecurring = db.select("SELECT COUNT(*) AS c FROM recurring_rules WHERE mode NOT IN ('REMINDER_ONLY','AUTO_CREATE','AUTO_CREATE_DRAFT') OR day_of_month NOT BETWEEN 1 AND 31").first['c'] as int;
    final invalidBill = db.select("SELECT COUNT(*) AS c FROM bills WHERE status NOT IN ('UPCOMING','DUE','PAID','SKIPPED','OVERDUE')").first['c'] as int;
    final invalidBudgetSemantics = db.select("""SELECT COUNT(*) AS c FROM budgets b
      LEFT JOIN categories c ON c.id=b.category_id
      WHERE trim(b.name)='' OR b.limit_minor<=0 OR b.currency<>'IDR' OR b.period_end<b.period_start OR
        (b.category_id IS NOT NULL AND (c.id IS NULL OR c.type<>'EXPENSE'))
      """).first['c'] as int;
    final invalidBillSemantics = db.select("""SELECT COUNT(*) AS c FROM bills
      WHERE trim(name)='' OR expected_amount_minor<=0 OR currency<>'IDR' OR length(due_date)<>10
      """).first['c'] as int;
    final invalidRecurringSemantics = db.select("""SELECT COUNT(*) AS c FROM recurring_rules r
      LEFT JOIN accounts a ON a.id=r.account_id
      LEFT JOIN categories c ON c.id=r.category_id
      WHERE trim(r.name)='' OR r.amount_minor<=0 OR r.currency<>'IDR' OR r.active NOT IN (0,1) OR
        a.id IS NULL OR c.id IS NULL OR a.currency<>r.currency OR c.type<>'EXPENSE' OR
        NOT (a.account_class='ASSET' OR (a.account_class='LIABILITY' AND a.account_type='CREDIT_CARD')) OR
        (r.active=1 AND (a.archived_at IS NOT NULL OR c.archived_at IS NOT NULL)) OR
        length(r.next_run)<>10
      """).first['c'] as int;
    final invalidAccountSemantics = db.select("""SELECT COUNT(*) AS c FROM accounts
      WHERE trim(name)='' OR currency<>'IDR' OR include_available NOT IN (0,1) OR include_net_worth NOT IN (0,1) OR
        NOT ((account_class='ASSET' AND account_type IN ('CASH','BANK','EWALLET','INVESTMENT','OTHER_ASSET')) OR
             (account_class='LIABILITY' AND account_type IN ('CREDIT_CARD','LOAN','OTHER_LIABILITY')))
      """).first['c'] as int;
    final invalidCategorySemantics = db.select("""SELECT COUNT(*) AS c FROM categories c
      LEFT JOIN categories p ON p.id=c.parent_id
      WHERE trim(c.name)='' OR c.parent_id=c.id OR
        (c.parent_id IS NOT NULL AND (p.id IS NULL OR p.type<>c.type))
      """).first['c'] as int;
    final invalidImportFingerprint = db.select("""SELECT COUNT(*) AS c FROM import_fingerprints
      WHERE length(fingerprint)<>64 OR fingerprint GLOB '*[^0-9a-f]*'
      """).first['c'] as int;
    final invalidMoneyRange = db.select("""SELECT (
      (SELECT COUNT(*) FROM transactions WHERE primary_amount_minor<=0 OR primary_amount_minor>$kMaxMoneyMinor) +
      (SELECT COUNT(*) FROM transaction_legs WHERE delta_minor<-${kMaxMoneyMinor} OR delta_minor>$kMaxMoneyMinor) +
      (SELECT COUNT(*) FROM transaction_splits WHERE amount_minor<=0 OR amount_minor>$kMaxMoneyMinor) +
      (SELECT COUNT(*) FROM budgets WHERE limit_minor<=0 OR limit_minor>$kMaxMoneyMinor) +
      (SELECT COUNT(*) FROM bills WHERE expected_amount_minor<=0 OR expected_amount_minor>$kMaxMoneyMinor) +
      (SELECT COUNT(*) FROM recurring_rules WHERE amount_minor<=0 OR amount_minor>$kMaxMoneyMinor)
    ) AS c""").first['c'] as int;
    final invalidDateSemantics = db.select("""SELECT (
      (SELECT COUNT(*) FROM accounts WHERE archived_at IS NOT NULL AND julianday(archived_at) IS NULL) +
      (SELECT COUNT(*) FROM categories WHERE archived_at IS NOT NULL AND julianday(archived_at) IS NULL) +
      (SELECT COUNT(*) FROM transactions WHERE julianday(occurred_at_utc) IS NULL OR length(local_date)<>10 OR date(local_date) IS NULL OR date(local_date)<>local_date OR julianday(created_at) IS NULL OR julianday(updated_at) IS NULL) +
      (SELECT COUNT(*) FROM transaction_groups WHERE julianday(created_at) IS NULL OR julianday(updated_at) IS NULL) +
      (SELECT COUNT(*) FROM budgets WHERE length(period_start)<>10 OR date(period_start) IS NULL OR date(period_start)<>period_start OR length(period_end)<>10 OR date(period_end) IS NULL OR date(period_end)<>period_end OR julianday(created_at) IS NULL OR julianday(updated_at) IS NULL OR (archived_at IS NOT NULL AND julianday(archived_at) IS NULL)) +
      (SELECT COUNT(*) FROM bills WHERE length(due_date)<>10 OR date(due_date) IS NULL OR date(due_date)<>due_date OR julianday(created_at) IS NULL OR julianday(updated_at) IS NULL) +
      (SELECT COUNT(*) FROM recurring_rules WHERE length(next_run)<>10 OR date(next_run) IS NULL OR date(next_run)<>next_run OR julianday(created_at) IS NULL OR julianday(updated_at) IS NULL) +
      (SELECT COUNT(*) FROM recurring_occurrences WHERE julianday(scheduled_for) IS NULL OR length(substr(scheduled_for,1,10))<>10 OR date(substr(scheduled_for,1,10)) IS NULL OR date(substr(scheduled_for,1,10))<>substr(scheduled_for,1,10) OR julianday(created_at) IS NULL) +
      (SELECT COUNT(*) FROM import_fingerprints WHERE julianday(created_at) IS NULL)
    ) AS c""").first['c'] as int;
    final invalidRefundSemantics = db.select("""SELECT COUNT(*) AS c FROM transactions r
      JOIN transactions o ON o.id=r.original_transaction_id
      WHERE r.type='REFUND' AND r.deleted_at IS NULL AND (
        r.local_date<o.local_date OR r.primary_currency<>o.primary_currency OR
        (SELECT s.category_id FROM transaction_splits s WHERE s.transaction_id=r.id LIMIT 1) <>
        (SELECT s.category_id FROM transaction_splits s WHERE s.transaction_id=o.id LIMIT 1)
      )""").first['c'] as int;
    final invalidRecurringOccurrenceSemantics = db.select("""SELECT COUNT(*) AS c FROM recurring_occurrences ro
      JOIN recurring_rules rr ON rr.id=ro.rule_id
      LEFT JOIN transactions t ON t.id=ro.transaction_id
      LEFT JOIN accounts a ON a.id=rr.account_id
      WHERE ro.occurrence_key<>(ro.rule_id || ':' || substr(ro.scheduled_for,1,10)) OR
        (rr.mode='REMINDER_ONLY' AND ro.transaction_id IS NOT NULL) OR
        (ro.transaction_id IS NOT NULL AND rr.mode<>'REMINDER_ONLY' AND (
          t.id IS NULL OR t.type<>'EXPENSE' OR t.status<>'DRAFT' OR t.deleted_at IS NOT NULL OR
          t.primary_amount_minor<>rr.amount_minor OR t.primary_currency<>rr.currency OR
          (SELECT COUNT(*) FROM transaction_legs l WHERE l.transaction_id=t.id)<>1 OR
          NOT EXISTS (SELECT 1 FROM transaction_legs l WHERE l.transaction_id=t.id AND l.account_id=rr.account_id AND
            l.currency=rr.currency AND l.delta_minor=CASE WHEN a.account_class='ASSET' THEN -rr.amount_minor ELSE rr.amount_minor END) OR
          (SELECT COUNT(*) FROM transaction_splits s WHERE s.transaction_id=t.id)<>1 OR
          NOT EXISTS (SELECT 1 FROM transaction_splits s WHERE s.transaction_id=t.id AND s.category_id=rr.category_id AND s.amount_minor=rr.amount_minor AND s.currency=rr.currency)
        )) OR
        (ro.transaction_id IS NOT NULL AND (SELECT COUNT(*) FROM recurring_occurrences x WHERE x.transaction_id=ro.transaction_id)>1)
      """).first['c'] as int;
    final duplicateAccounts = db.select("SELECT COUNT(*) AS c FROM (SELECT lower(name) n FROM accounts WHERE archived_at IS NULL GROUP BY lower(name) HAVING COUNT(*)>1)").first['c'] as int;
    final duplicateCategories = db.select("SELECT COUNT(*) AS c FROM (SELECT type,lower(name) n FROM categories WHERE archived_at IS NULL GROUP BY type,lower(name) HAVING COUNT(*)>1)").first['c'] as int;
    final splitMismatch = db.select("""SELECT COUNT(*) AS c FROM transactions t
      WHERE t.type IN ('EXPENSE','INCOME','REFUND') AND t.deleted_at IS NULL
        AND COALESCE((SELECT SUM(s.amount_minor) FROM transaction_splits s WHERE s.transaction_id=t.id),0) <> t.primary_amount_minor""").first['c'] as int;
    final badSplitCurrency = db.select('SELECT COUNT(*) AS c FROM transaction_splits s JOIN transactions t ON t.id=s.transaction_id WHERE s.currency<>t.primary_currency').first['c'] as int;
    final invalidSimpleShape = db.select("""SELECT COUNT(*) AS c FROM transactions t
      WHERE t.type IN ('EXPENSE','INCOME','REFUND') AND t.deleted_at IS NULL AND (
        t.primary_amount_minor<=0 OR
        (SELECT COUNT(*) FROM transaction_legs l WHERE l.transaction_id=t.id)<>1 OR
        (SELECT COUNT(*) FROM transaction_splits s WHERE s.transaction_id=t.id)<>1
      )""").first['c'] as int;
    final invalidSimpleSemantics = db.select("""SELECT COUNT(*) AS c FROM transactions t
      WHERE t.type IN ('EXPENSE','INCOME','REFUND') AND t.deleted_at IS NULL AND NOT EXISTS (
        SELECT 1 FROM transaction_legs l
        JOIN accounts a ON a.id=l.account_id
        JOIN transaction_splits s ON s.transaction_id=t.id
        JOIN categories c ON c.id=s.category_id
        WHERE l.transaction_id=t.id AND (
          (t.type='EXPENSE' AND c.type='EXPENSE' AND (
            (a.account_class='ASSET' AND l.delta_minor=-t.primary_amount_minor) OR
            (a.account_class='LIABILITY' AND a.account_type='CREDIT_CARD' AND l.delta_minor=t.primary_amount_minor)
          )) OR
          (t.type='INCOME' AND c.type='INCOME' AND a.account_class='ASSET' AND l.delta_minor=t.primary_amount_minor) OR
          (t.type='REFUND' AND c.type='EXPENSE' AND (
            (a.account_class='ASSET' AND l.delta_minor=t.primary_amount_minor) OR
            (a.account_class='LIABILITY' AND a.account_type='CREDIT_CARD' AND l.delta_minor=-t.primary_amount_minor)
          ))
        )
      )""").first['c'] as int;
    final invalidNonCategorizedShape = db.select("""SELECT COUNT(*) AS c FROM transactions t
      WHERE t.type IN ('TRANSFER','ADJUSTMENT','OPENING_BALANCE','CREDIT_CARD_PAYMENT','LOAN_DISBURSEMENT','LOAN_PAYMENT')
        AND t.deleted_at IS NULL AND (
          t.primary_amount_minor<=0 OR
          (SELECT COUNT(*) FROM transaction_splits s WHERE s.transaction_id=t.id)<>0 OR
          (t.type IN ('ADJUSTMENT','OPENING_BALANCE') AND (SELECT COUNT(*) FROM transaction_legs l WHERE l.transaction_id=t.id)<>1) OR
          (t.type IN ('TRANSFER','CREDIT_CARD_PAYMENT','LOAN_DISBURSEMENT','LOAN_PAYMENT') AND (SELECT COUNT(*) FROM transaction_legs l WHERE l.transaction_id=t.id)<>2)
        )""").first['c'] as int;
    final invalidSpecialSemantics = db.select("""SELECT COUNT(*) AS c FROM transactions t
      WHERE t.type IN ('TRANSFER','ADJUSTMENT','OPENING_BALANCE','CREDIT_CARD_PAYMENT','LOAN_DISBURSEMENT','LOAN_PAYMENT')
        AND t.deleted_at IS NULL AND (
          (t.type='TRANSFER' AND (
            (SELECT COUNT(DISTINCT l.account_id) FROM transaction_legs l WHERE l.transaction_id=t.id)<>2 OR
            NOT EXISTS (SELECT 1 FROM transaction_legs l JOIN accounts a ON a.id=l.account_id WHERE l.transaction_id=t.id AND a.account_class='ASSET' AND l.delta_minor=-t.primary_amount_minor) OR
            NOT EXISTS (SELECT 1 FROM transaction_legs l JOIN accounts a ON a.id=l.account_id WHERE l.transaction_id=t.id AND a.account_class='ASSET' AND l.delta_minor=t.primary_amount_minor)
          )) OR
          (t.type='CREDIT_CARD_PAYMENT' AND (
            (SELECT COUNT(DISTINCT l.account_id) FROM transaction_legs l WHERE l.transaction_id=t.id)<>2 OR
            NOT EXISTS (SELECT 1 FROM transaction_legs l JOIN accounts a ON a.id=l.account_id WHERE l.transaction_id=t.id AND a.account_class='ASSET' AND l.delta_minor=-t.primary_amount_minor) OR
            NOT EXISTS (SELECT 1 FROM transaction_legs l JOIN accounts a ON a.id=l.account_id WHERE l.transaction_id=t.id AND a.account_class='LIABILITY' AND a.account_type='CREDIT_CARD' AND l.delta_minor=-t.primary_amount_minor)
          )) OR
          (t.type='LOAN_DISBURSEMENT' AND (
            (SELECT COUNT(DISTINCT l.account_id) FROM transaction_legs l WHERE l.transaction_id=t.id)<>2 OR
            NOT EXISTS (SELECT 1 FROM transaction_legs l JOIN accounts a ON a.id=l.account_id WHERE l.transaction_id=t.id AND a.account_class='ASSET' AND l.delta_minor=t.primary_amount_minor) OR
            NOT EXISTS (SELECT 1 FROM transaction_legs l JOIN accounts a ON a.id=l.account_id WHERE l.transaction_id=t.id AND a.account_class='LIABILITY' AND a.account_type='LOAN' AND l.delta_minor=t.primary_amount_minor)
          )) OR
          (t.type='LOAN_PAYMENT' AND (
            (SELECT COUNT(DISTINCT l.account_id) FROM transaction_legs l WHERE l.transaction_id=t.id)<>2 OR
            NOT EXISTS (SELECT 1 FROM transaction_legs l JOIN accounts a ON a.id=l.account_id WHERE l.transaction_id=t.id AND a.account_class='ASSET' AND l.delta_minor=-t.primary_amount_minor) OR
            NOT EXISTS (SELECT 1 FROM transaction_legs l JOIN accounts a ON a.id=l.account_id WHERE l.transaction_id=t.id AND a.account_class='LIABILITY' AND a.account_type='LOAN' AND l.delta_minor=-t.primary_amount_minor)
          )) OR
          (t.type IN ('ADJUSTMENT','OPENING_BALANCE') AND NOT EXISTS (
            SELECT 1 FROM transaction_legs l WHERE l.transaction_id=t.id AND abs(l.delta_minor)=t.primary_amount_minor
          ))
        )""").first['c'] as int;
    final invalidOriginalLink = db.select("SELECT COUNT(*) AS c FROM transactions WHERE deleted_at IS NULL AND ((type='REFUND' AND status='POSTED' AND original_transaction_id IS NULL) OR (type<>'REFUND' AND original_transaction_id IS NOT NULL))").first['c'] as int;
    final invalidGroupShape = db.select("""SELECT COUNT(*) AS c FROM transaction_groups g
      WHERE g.group_type NOT IN ('TRANSFER_WITH_FEE','LOAN_PAYMENT') OR
        (SELECT COUNT(*) FROM transactions t WHERE t.transaction_group_id=g.id) < 1 OR
        (SELECT COUNT(*) FROM transactions t WHERE t.transaction_group_id=g.id AND t.group_primary=1) <> 1 OR
        EXISTS (SELECT 1 FROM transactions t WHERE t.transaction_group_id=g.id AND t.group_primary NOT IN (0,1))
      """).first['c'] as int;
    final invalidGroupSemantics = db.select("""SELECT COUNT(*) AS c FROM transaction_groups g
      WHERE
        (g.group_type='TRANSFER_WITH_FEE' AND (
          (SELECT COUNT(*) FROM transactions t WHERE t.transaction_group_id=g.id)<>2 OR
          (SELECT COUNT(*) FROM transactions t WHERE t.transaction_group_id=g.id AND t.group_primary=1 AND t.type='TRANSFER')<>1 OR
          (SELECT COUNT(*) FROM transactions t WHERE t.transaction_group_id=g.id AND t.group_primary=0 AND t.type='EXPENSE')<>1 OR
          EXISTS (SELECT 1 FROM transactions t WHERE t.transaction_group_id=g.id AND
            t.status<>(SELECT p.status FROM transactions p WHERE p.transaction_group_id=g.id AND p.group_primary=1 LIMIT 1))
        )) OR
        (g.group_type='LOAN_PAYMENT' AND (
          (SELECT COUNT(*) FROM transactions t WHERE t.transaction_group_id=g.id) NOT BETWEEN 1 AND 3 OR
          (SELECT COUNT(*) FROM transactions t WHERE t.transaction_group_id=g.id AND t.group_primary=1 AND t.type='LOAN_PAYMENT')<>1 OR
          EXISTS (SELECT 1 FROM transactions t WHERE t.transaction_group_id=g.id AND t.group_primary=0 AND t.type<>'EXPENSE') OR
          EXISTS (SELECT 1 FROM transactions t WHERE t.transaction_group_id=g.id AND
            t.status<>(SELECT p.status FROM transactions p WHERE p.transaction_group_id=g.id AND p.group_primary=1 LIMIT 1))
        )) OR
        EXISTS (SELECT 1 FROM transactions t WHERE t.transaction_group_id=g.id AND t.group_primary=1 AND
          ((g.group_type='TRANSFER_WITH_FEE' AND t.type<>'TRANSFER') OR
           (g.group_type='LOAN_PAYMENT' AND t.type<>'LOAN_PAYMENT')))
      """).first['c'] as int;
    final invalidGroupMembership = db.select("""SELECT COUNT(*) AS c FROM transactions t
      WHERE t.deleted_at IS NULL AND (
        (t.transaction_group_id IS NULL AND t.group_primary<>1) OR
        (t.type='LOAN_PAYMENT' AND (t.transaction_group_id IS NULL OR t.group_primary<>1)) OR
        (t.transaction_group_id IS NOT NULL AND t.group_primary=0 AND t.type<>'EXPENSE')
      )
      """).first['c'] as int;
    final orphanPostedRefund = db.select("""SELECT COUNT(*) AS c FROM transactions r
      LEFT JOIN transactions o ON o.id=r.original_transaction_id
      WHERE r.type='REFUND' AND r.status='POSTED' AND r.deleted_at IS NULL
        AND (o.id IS NULL OR o.type<>'EXPENSE' OR o.status<>'POSTED' OR o.deleted_at IS NOT NULL)""").first['c'] as int;
    final overRefund = db.select("""SELECT COUNT(*) AS c FROM transactions o
      WHERE o.type='EXPENSE' AND o.status='POSTED' AND o.deleted_at IS NULL
        AND COALESCE((SELECT SUM(r.primary_amount_minor) FROM transactions r
          WHERE r.original_transaction_id=o.id AND r.type='REFUND' AND r.status='POSTED' AND r.deleted_at IS NULL),0) > o.primary_amount_minor""").first['c'] as int;
    final invalidPaidBill = db.select("""SELECT COUNT(*) AS c FROM bills b
      LEFT JOIN transactions t ON t.id=b.paid_transaction_id
      WHERE b.status='PAID' AND (
        t.id IS NULL OR t.type<>'EXPENSE' OR t.status<>'POSTED' OR t.deleted_at IS NOT NULL OR
        COALESCE((SELECT SUM(r.primary_amount_minor) FROM transactions r
          WHERE r.original_transaction_id=t.id AND r.type='REFUND' AND r.status='POSTED' AND r.deleted_at IS NULL),0) >= t.primary_amount_minor
      )""").first['c'] as int;
    final invalidUnpaidBillActivePayment = db.select("""SELECT COUNT(*) AS c FROM bills b
      JOIN transactions t ON t.id=b.paid_transaction_id
      WHERE b.status<>'PAID' AND b.paid_transaction_id IS NOT NULL
        AND t.type='EXPENSE' AND t.status='POSTED' AND t.deleted_at IS NULL
        AND COALESCE((SELECT SUM(r.primary_amount_minor) FROM transactions r
          WHERE r.original_transaction_id=t.id AND r.type='REFUND' AND r.status='POSTED' AND r.deleted_at IS NULL),0) < t.primary_amount_minor
      """).first['c'] as int;
    if (fkErrors.isNotEmpty || orphanLegs != 0 || orphanSplits != 0 || postedWithoutLeg != 0 ||
        badCurrency != 0 || badSplitCurrency != 0 || nonIdr != 0 || invalidTxEnum != 0 || invalidRecurring != 0 || invalidBill != 0 ||
        invalidBudgetSemantics != 0 || invalidBillSemantics != 0 || invalidRecurringSemantics != 0 ||
        invalidAccountSemantics != 0 || invalidCategorySemantics != 0 || invalidImportFingerprint != 0 ||
        invalidMoneyRange != 0 || invalidDateSemantics != 0 ||
        invalidRefundSemantics != 0 || invalidRecurringOccurrenceSemantics != 0 ||
        duplicateAccounts != 0 || duplicateCategories != 0 || splitMismatch != 0 ||
        invalidSimpleShape != 0 || invalidSimpleSemantics != 0 || invalidNonCategorizedShape != 0 ||
        invalidSpecialSemantics != 0 || invalidOriginalLink != 0 || invalidGroupShape != 0 ||
        invalidGroupSemantics != 0 || invalidGroupMembership != 0 ||
        orphanPostedRefund != 0 || overRefund != 0 || invalidPaidBill != 0 || invalidUnpaidBillActivePayment != 0) {
      throw StateError('Backup gagal integrity check.');
    }
  }
}
