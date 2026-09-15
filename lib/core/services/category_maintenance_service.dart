import '../db/app_database.dart';

class CategoryMaintenanceService {
  CategoryMaintenanceService(
    this.database, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final AppDatabase database;
  final DateTime Function() _clock;

  Future<void> renameCategory({
    required String categoryId,
    required String name,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Nama kategori wajib diisi.');
    }

    database.transaction((db) {
      final rows = db.select(
        'SELECT id,type,name,archived_at FROM categories WHERE id=? LIMIT 1',
        [categoryId],
      );
      if (rows.isEmpty) {
        throw StateError('Kategori tidak ditemukan.');
      }
      final category = rows.single;
      if (category['archived_at'] != null) {
        throw StateError('Kategori sudah diarsipkan.');
      }

      final duplicate = db.select(
        '''SELECT id FROM categories
           WHERE archived_at IS NULL
             AND type=?
             AND id<>?
             AND lower(name)=lower(?)
           LIMIT 1''',
        [category['type'], categoryId, trimmed],
      );
      if (duplicate.isNotEmpty) {
        throw StateError('Nama kategori aktif sudah digunakan untuk tipe ini.');
      }

      if ((category['name'] as String) == trimmed) return;

      db.execute(
        '''UPDATE categories
           SET name=?,updated_at=?,version=version+1
           WHERE id=?''',
        [trimmed, _clock().toUtc().toIso8601String(), categoryId],
      );
    });
  }
}
