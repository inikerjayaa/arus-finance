import 'package:sqlite3/sqlite3.dart';

import '../../domain/enums.dart';
import '../../shared/icon_catalog.dart';
import '../../shared/visual_palette.dart';
import '../db/app_database.dart';

class VisualIdentity {
  const VisualIdentity({required this.iconKey, required this.colorKey});

  final String iconKey;
  final String colorKey;
}

class VisualIdentityStore {
  VisualIdentityStore(this._database, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final AppDatabase _database;
  final DateTime Function() _clock;
  bool _initialized = false;

  Database get _db => _database.db;

  Future<void> initialize() async {
    await _database.open();
    if (_initialized) return;
    _db.execute('''
      CREATE TABLE IF NOT EXISTS category_visual_identity (
        category_id TEXT PRIMARY KEY
          REFERENCES categories(id) ON DELETE CASCADE,
        icon_key TEXT NOT NULL,
        color_key TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS account_visual_identity (
        account_id TEXT PRIMARY KEY
          REFERENCES accounts(id) ON DELETE CASCADE,
        icon_key TEXT NOT NULL,
        color_key TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS icon_catalog_usage (
        icon_key TEXT PRIMARY KEY,
        favorite INTEGER NOT NULL DEFAULT 0 CHECK(favorite IN (0,1)),
        use_count INTEGER NOT NULL DEFAULT 0 CHECK(use_count >= 0),
        last_used_at TEXT
      )
    ''');
    _initialized = true;
  }

  Future<VisualIdentity?> category(String categoryId) async {
    await initialize();
    final rows = _db.select(
      'SELECT icon_key,color_key FROM category_visual_identity WHERE category_id=?',
      [categoryId],
    );
    if (rows.isEmpty) return null;
    return VisualIdentity(
      iconKey: rows.first['icon_key'] as String,
      colorKey: rows.first['color_key'] as String,
    );
  }

  Future<VisualIdentity?> account(String accountId) async {
    await initialize();
    final rows = _db.select(
      'SELECT icon_key,color_key FROM account_visual_identity WHERE account_id=?',
      [accountId],
    );
    if (rows.isEmpty) return null;
    return VisualIdentity(
      iconKey: rows.first['icon_key'] as String,
      colorKey: rows.first['color_key'] as String,
    );
  }

  Future<void> setCategory({
    required String categoryId,
    required String iconKey,
    required String colorKey,
  }) async {
    await initialize();
    _validateVisualKeys(iconKey, colorKey);
    _requireEntity('categories', categoryId, 'Kategori');
    _db.execute('BEGIN IMMEDIATE');
    try {
      _upsertCategory(categoryId, VisualIdentity(iconKey: iconKey, colorKey: colorKey));
      _recordUsage(iconKey);
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  Future<void> setAccount({
    required String accountId,
    required String iconKey,
    required String colorKey,
  }) async {
    await initialize();
    _validateVisualKeys(iconKey, colorKey);
    _requireEntity('accounts', accountId, 'Account');
    _db.execute('BEGIN IMMEDIATE');
    try {
      _upsertAccount(accountId, VisualIdentity(iconKey: iconKey, colorKey: colorKey));
      _recordUsage(iconKey);
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  Future<void> setFavorite(String iconKey, bool favorite) async {
    await initialize();
    _requireIconKey(iconKey);
    _db.execute(
      '''INSERT INTO icon_catalog_usage(icon_key,favorite,use_count,last_used_at)
         VALUES (?, ?, 0, NULL)
         ON CONFLICT(icon_key) DO UPDATE SET favorite=excluded.favorite''',
      [iconKey, favorite ? 1 : 0],
    );
  }

  Future<List<String>> favoriteIconKeys() async {
    await initialize();
    final rows = _db.select(
      '''SELECT icon_key FROM icon_catalog_usage
         WHERE favorite=1
         ORDER BY COALESCE(last_used_at,'') DESC, icon_key COLLATE NOCASE''',
    );
    return rows.map((row) => row['icon_key'] as String).toList(growable: false);
  }

  Future<List<String>> recentIconKeys({int limit = 12}) async {
    await initialize();
    if (limit <= 0) return const [];
    final rows = _db.select(
      '''SELECT icon_key FROM icon_catalog_usage
         WHERE last_used_at IS NOT NULL
         ORDER BY last_used_at DESC, use_count DESC
         LIMIT ?''',
      [limit],
    );
    return rows.map((row) => row['icon_key'] as String).toList(growable: false);
  }

  Future<void> ensureBuiltInDefaults() async {
    await initialize();
    _db.execute('BEGIN IMMEDIATE');
    try {
      final categories = _db.select(
        '''SELECT c.id,c.type,c.name
           FROM categories c
           LEFT JOIN category_visual_identity v ON v.category_id=c.id
           WHERE v.category_id IS NULL''',
      );
      for (final row in categories) {
        final type = enumFromDb(row['type'] as String, CategoryType.values);
        final identity = suggestCategory(row['name'] as String, type);
        _upsertCategory(row['id'] as String, identity);
      }

      final accounts = _db.select(
        '''SELECT a.id,a.name,a.account_type
           FROM accounts a
           LEFT JOIN account_visual_identity v ON v.account_id=a.id
           WHERE v.account_id IS NULL''',
      );
      for (final row in accounts) {
        final identity = _suggestAccount(
          row['name'] as String,
          row['account_type'] as String,
        );
        _upsertAccount(row['id'] as String, identity);
      }
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  VisualIdentity suggestCategory(String name, CategoryType type) {
    final exact = _defaultCategoryIdentity(type, name);
    if (exact != null) return exact;

    final icon = IconCatalog.suggest(name);
    final color = switch (icon.group) {
      IconCatalogGroup.food => 'orange',
      IconCatalogGroup.shopping => 'purple',
      IconCatalogGroup.transport => 'blue',
      IconCatalogGroup.home => 'teal',
      IconCatalogGroup.health => 'red',
      IconCatalogGroup.subscription => 'indigo',
      IconCatalogGroup.wallet => 'purple',
      IconCatalogGroup.bank => 'blue',
      IconCatalogGroup.lifestyle => 'cyan',
      IconCatalogGroup.finance => type == CategoryType.income ? 'green' : 'slate',
      IconCatalogGroup.other => 'slate',
    };
    return VisualIdentity(iconKey: icon.key, colorKey: color);
  }

  void _upsertCategory(String categoryId, VisualIdentity identity) {
    _db.execute(
      '''INSERT INTO category_visual_identity(category_id,icon_key,color_key,updated_at)
         VALUES (?,?,?,?)
         ON CONFLICT(category_id) DO UPDATE SET
           icon_key=excluded.icon_key,
           color_key=excluded.color_key,
           updated_at=excluded.updated_at''',
      [categoryId, identity.iconKey, identity.colorKey, _now()],
    );
  }

  void _upsertAccount(String accountId, VisualIdentity identity) {
    _db.execute(
      '''INSERT INTO account_visual_identity(account_id,icon_key,color_key,updated_at)
         VALUES (?,?,?,?)
         ON CONFLICT(account_id) DO UPDATE SET
           icon_key=excluded.icon_key,
           color_key=excluded.color_key,
           updated_at=excluded.updated_at''',
      [accountId, identity.iconKey, identity.colorKey, _now()],
    );
  }

  void _recordUsage(String iconKey) {
    _db.execute(
      '''INSERT INTO icon_catalog_usage(icon_key,favorite,use_count,last_used_at)
         VALUES (?,0,1,?)
         ON CONFLICT(icon_key) DO UPDATE SET
           use_count=use_count+1,
           last_used_at=excluded.last_used_at''',
      [iconKey, _now()],
    );
  }

  void _validateVisualKeys(String iconKey, String colorKey) {
    _requireIconKey(iconKey);
    if (VisualPalette.byKey(colorKey) == null) {
      throw ArgumentError('Warna visual tidak dikenal: $colorKey');
    }
  }

  void _requireIconKey(String iconKey) {
    if (IconCatalog.byKey(iconKey) == null) {
      throw ArgumentError('Ikon visual tidak dikenal: $iconKey');
    }
  }

  void _requireEntity(String table, String id, String label) {
    final exists = _db.select('SELECT 1 FROM $table WHERE id=? LIMIT 1', [id]);
    if (exists.isEmpty) throw StateError('$label tidak ditemukan.');
  }

  String _now() => _clock().toUtc().toIso8601String();

  VisualIdentity _suggestAccount(String name, String rawType) {
    switch (rawType) {
      case 'CASH':
        return const VisualIdentity(iconKey: 'finance.cash', colorKey: 'green');
      case 'BANK':
        final matches = IconCatalog.search(name, group: IconCatalogGroup.bank, limit: 1);
        return VisualIdentity(
          iconKey: matches.isEmpty ? 'finance.bank' : matches.first.key,
          colorKey: 'blue',
        );
      case 'EWALLET':
        final matches = IconCatalog.search(name, group: IconCatalogGroup.wallet, limit: 1);
        return VisualIdentity(
          iconKey: matches.isEmpty ? 'finance.wallet' : matches.first.key,
          colorKey: 'purple',
        );
      case 'CREDIT_CARD':
        return const VisualIdentity(iconKey: 'finance.credit_card', colorKey: 'orange');
      case 'LOAN':
        return const VisualIdentity(iconKey: 'finance.loan', colorKey: 'red');
      case 'INVESTMENT':
        return const VisualIdentity(iconKey: 'finance.investment', colorKey: 'teal');
      default:
        return const VisualIdentity(iconKey: 'finance.wallet', colorKey: 'slate');
    }
  }

  VisualIdentity? _defaultCategoryIdentity(CategoryType type, String name) {
    final key = '${type.name}:${name.trim().toLowerCase()}';
    return _categoryDefaults[key];
  }

  static const Map<String, VisualIdentity> _categoryDefaults = {
    'expense:makanan': VisualIdentity(iconKey: 'food.meal', colorKey: 'orange'),
    'expense:transport': VisualIdentity(iconKey: 'transport.general', colorKey: 'blue'),
    'expense:belanja': VisualIdentity(iconKey: 'shopping.cart', colorKey: 'purple'),
    'expense:rumah': VisualIdentity(iconKey: 'home.house', colorKey: 'teal'),
    'expense:tagihan': VisualIdentity(iconKey: 'home.utilities', colorKey: 'amber'),
    'expense:kesehatan': VisualIdentity(iconKey: 'health.medical', colorKey: 'red'),
    'expense:hiburan': VisualIdentity(iconKey: 'lifestyle.entertainment', colorKey: 'purple'),
    'expense:pendidikan': VisualIdentity(iconKey: 'lifestyle.education', colorKey: 'indigo'),
    'expense:travel': VisualIdentity(iconKey: 'lifestyle.travel', colorKey: 'cyan'),
    'expense:biaya transfer': VisualIdentity(iconKey: 'finance.fee', colorKey: 'slate'),
    'expense:bunga pinjaman': VisualIdentity(iconKey: 'finance.loan', colorKey: 'red'),
    'expense:biaya pinjaman': VisualIdentity(iconKey: 'finance.fee', colorKey: 'slate'),
    'expense:lainnya': VisualIdentity(iconKey: 'other.category', colorKey: 'slate'),
    'income:gaji': VisualIdentity(iconKey: 'finance.salary', colorKey: 'green'),
    'income:bonus': VisualIdentity(iconKey: 'finance.bonus', colorKey: 'lime'),
    'income:penjualan': VisualIdentity(iconKey: 'finance.wallet', colorKey: 'teal'),
    'income:hadiah': VisualIdentity(iconKey: 'lifestyle.gift', colorKey: 'pink'),
    'income:lainnya': VisualIdentity(iconKey: 'other.category', colorKey: 'slate'),
  };
}
