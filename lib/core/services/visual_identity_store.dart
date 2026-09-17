import 'package:sqlite3/sqlite3.dart';

import '../../domain/enums.dart';
import '../../shared/icon_catalog.dart';
import '../../shared/saku_icon_registry.dart';
import '../../shared/visual_palette.dart';
import '../db/app_database.dart';

class VisualIdentity {
  const VisualIdentity({required this.iconKey, required this.colorKey});

  final String iconKey;
  final String colorKey;
}

class VisualIdentityStore {
  VisualIdentityStore(this._database);

  final AppDatabase _database;

  Database get _db => _database.db;

  Future<void> initialize() => _database.open();

  Future<VisualIdentity?> category(String categoryId) async {
    await initialize();
    final rows = _db.select(
      '''SELECT visual_icon_key,visual_color_key
         FROM categories WHERE id=? LIMIT 1''',
      [categoryId],
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  Future<VisualIdentity?> account(String accountId) async {
    await initialize();
    final rows = _db.select(
      '''SELECT visual_icon_key,visual_color_key
         FROM accounts WHERE id=? LIMIT 1''',
      [accountId],
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  Future<void> setCategory({
    required String categoryId,
    required String iconKey,
    required String colorKey,
  }) async {
    await initialize();
    _validateVisualKeys(iconKey, colorKey);
    _requireEntity('categories', categoryId, 'Kategori');
    _db.execute(
      '''UPDATE categories
         SET visual_icon_key=?, visual_color_key=?
         WHERE id=?''',
      [iconKey, colorKey, categoryId],
    );
  }

  Future<void> setAccount({
    required String accountId,
    required String iconKey,
    required String colorKey,
  }) async {
    await initialize();
    _validateVisualKeys(iconKey, colorKey);
    _requireEntity('accounts', accountId, 'Account');
    _db.execute(
      '''UPDATE accounts
         SET visual_icon_key=?, visual_color_key=?
         WHERE id=?''',
      [iconKey, colorKey, accountId],
    );
  }

  Future<void> ensureBuiltInDefaults() async {
    await initialize();
    _db.execute('BEGIN IMMEDIATE');
    try {
      final categories = _db.select(
        '''SELECT id,type,name
           FROM categories
           WHERE visual_icon_key IS NULL OR visual_color_key IS NULL''',
      );
      for (final row in categories) {
        final type = enumFromDb(row['type'] as String, CategoryType.values);
        final identity = suggestCategory(row['name'] as String, type);
        _setCategoryColumns(row['id'] as String, identity);
      }

      final accounts = _db.select(
        '''SELECT id,name,account_type
           FROM accounts
           WHERE visual_icon_key IS NULL OR visual_color_key IS NULL''',
      );
      for (final row in accounts) {
        final type = enumFromDb(row['account_type'] as String, AccountType.values);
        final identity = suggestAccount(row['name'] as String, type);
        _setAccountColumns(row['id'] as String, identity);
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
      IconCatalogGroup.finance =>
        type == CategoryType.income ? 'green' : 'slate',
      IconCatalogGroup.other => 'slate',
    };
    return VisualIdentity(iconKey: icon.key, colorKey: color);
  }

  VisualIdentity suggestAccount(String name, AccountType type) {
    switch (type) {
      case AccountType.cash:
        return const VisualIdentity(
          iconKey: 'finance.cash',
          colorKey: 'green',
        );
      case AccountType.bank:
        final matches = IconCatalog.search(
          name,
          group: IconCatalogGroup.bank,
          limit: 1,
        );
        return VisualIdentity(
          iconKey: matches.isEmpty ? 'finance.bank' : matches.first.key,
          colorKey: 'blue',
        );
      case AccountType.ewallet:
        final matches = IconCatalog.search(
          name,
          group: IconCatalogGroup.wallet,
          limit: 1,
        );
        return VisualIdentity(
          iconKey: matches.isEmpty ? 'finance.wallet' : matches.first.key,
          colorKey: 'purple',
        );
      case AccountType.creditCard:
        return const VisualIdentity(
          iconKey: 'finance.credit_card',
          colorKey: 'orange',
        );
      case AccountType.loan:
        return const VisualIdentity(
          iconKey: 'finance.loan',
          colorKey: 'red',
        );
      case AccountType.investment:
        return const VisualIdentity(
          iconKey: 'finance.investment',
          colorKey: 'teal',
        );
      default:
        return const VisualIdentity(
          iconKey: 'finance.wallet',
          colorKey: 'slate',
        );
    }
  }

  VisualIdentity? _fromRow(Row row) {
    final iconKey = row['visual_icon_key'];
    final colorKey = row['visual_color_key'];
    if (iconKey is! String || colorKey is! String) return null;
    if (!_isKnownIconKey(iconKey) || VisualPalette.byKey(colorKey) == null) {
      return null;
    }
    return VisualIdentity(iconKey: iconKey, colorKey: colorKey);
  }

  void _setCategoryColumns(String categoryId, VisualIdentity identity) {
    _db.execute(
      '''UPDATE categories
         SET visual_icon_key=?, visual_color_key=?
         WHERE id=?''',
      [identity.iconKey, identity.colorKey, categoryId],
    );
  }

  void _setAccountColumns(String accountId, VisualIdentity identity) {
    _db.execute(
      '''UPDATE accounts
         SET visual_icon_key=?, visual_color_key=?
         WHERE id=?''',
      [identity.iconKey, identity.colorKey, accountId],
    );
  }

  void _validateVisualKeys(String iconKey, String colorKey) {
    if (!_isKnownIconKey(iconKey)) {
      throw ArgumentError('Ikon visual tidak dikenal: $iconKey');
    }
    if (VisualPalette.byKey(colorKey) == null) {
      throw ArgumentError('Warna visual tidak dikenal: $colorKey');
    }
  }

  static bool _isKnownIconKey(String iconKey) =>
      IconCatalog.byKey(iconKey) != null ||
      SakuIconRegistry.isBrandKey(iconKey) ||
      SakuIconRegistry.isCustomKey(iconKey);

  void _requireEntity(String table, String id, String label) {
    final exists = _db.select('SELECT 1 FROM $table WHERE id=? LIMIT 1', [id]);
    if (exists.isEmpty) throw StateError('$label tidak ditemukan.');
  }

  VisualIdentity? _defaultCategoryIdentity(CategoryType type, String name) {
    final key = '${type.name}:${name.trim().toLowerCase()}';
    return _categoryDefaults[key];
  }

  static const Map<String, VisualIdentity> _categoryDefaults = {
    'expense:makanan': VisualIdentity(
      iconKey: 'food.meal',
      colorKey: 'orange',
    ),
    'expense:transport': VisualIdentity(
      iconKey: 'transport.general',
      colorKey: 'blue',
    ),
    'expense:belanja': VisualIdentity(
      iconKey: 'shopping.cart',
      colorKey: 'purple',
    ),
    'expense:rumah': VisualIdentity(iconKey: 'home.house', colorKey: 'teal'),
    'expense:tagihan': VisualIdentity(
      iconKey: 'home.utilities',
      colorKey: 'amber',
    ),
    'expense:kesehatan': VisualIdentity(
      iconKey: 'health.medical',
      colorKey: 'red',
    ),
    'expense:hiburan': VisualIdentity(
      iconKey: 'lifestyle.entertainment',
      colorKey: 'purple',
    ),
    'expense:pendidikan': VisualIdentity(
      iconKey: 'lifestyle.education',
      colorKey: 'indigo',
    ),
    'expense:travel': VisualIdentity(
      iconKey: 'lifestyle.travel',
      colorKey: 'cyan',
    ),
    'expense:biaya transfer': VisualIdentity(
      iconKey: 'finance.fee',
      colorKey: 'slate',
    ),
    'expense:bunga pinjaman': VisualIdentity(
      iconKey: 'finance.loan',
      colorKey: 'red',
    ),
    'expense:biaya pinjaman': VisualIdentity(
      iconKey: 'finance.fee',
      colorKey: 'slate',
    ),
    'expense:lainnya': VisualIdentity(
      iconKey: 'other.category',
      colorKey: 'slate',
    ),
    'income:gaji': VisualIdentity(
      iconKey: 'finance.salary',
      colorKey: 'green',
    ),
    'income:bonus': VisualIdentity(
      iconKey: 'finance.bonus',
      colorKey: 'lime',
    ),
    'income:penjualan': VisualIdentity(
      iconKey: 'finance.wallet',
      colorKey: 'teal',
    ),
    'income:hadiah': VisualIdentity(
      iconKey: 'lifestyle.gift',
      colorKey: 'pink',
    ),
    'income:lainnya': VisualIdentity(
      iconKey: 'other.category',
      colorKey: 'slate',
    ),
  };
}
