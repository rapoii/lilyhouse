import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../../core/database/tables.dart';
import '../../../core/database/db_helper.dart';
import '../domain/costume.dart';
import '../domain/accessory.dart';
import '../domain/costume_rental_history.dart';
import '../../rentals/domain/rental.dart';

abstract class ICostumeRepository {
  Future<int> insertCostume(Costume costume);
  Future<Costume?> getCostumeById(String id);
  Future<List<Costume>> getAllCostumes();
  Future<List<Costume>> searchCostumes({
    String? query,
    CostumeStatus? status,
    String? size,
    String? series,
    String? sortBy,
  });
  Future<List<String>> getDistinctAnimeSeries();
  Future<int> updateCostume(Costume costume);
  Future<int> deleteCostume(String id);
  Future<int> addAccessory(Accessory accessory);
  Future<List<Accessory>> getAccessoriesByCostumeId(String costumeId);
  Future<int> updateAccessory(Accessory accessory);
  Future<int> deleteAccessory(String id);
  Future<int> getActiveRentalsCount(String costumeId) async => 0;

  /// Full rental-history tracking for one costume: total completed rentals,
  /// the last service (return) date, any in-progress rental, and the renter list.
  /// Defaults to an empty history for mock/test repositories that don't track rentals.
  Future<CostumeRentalHistory> getRentalHistory(String costumeId) async =>
      const CostumeRentalHistory();
}

class CostumeRepository implements ICostumeRepository {
  final Database? db;

  CostumeRepository({this.db});

  Future<Database> get _db async {
    return db ?? await DatabaseHelper.instance.database;
  }

  Future<void> _recordSync(Database database, String table, String recordId, String action, Map<String, dynamic> payload) async {
    await database.insert(
      AppTables.syncQueue,
      {
        'id': '${table}_${recordId}_${DateTime.now().millisecondsSinceEpoch}',
        'table_name': table,
        'record_id': recordId,
        'action': action,
        'payload': jsonEncode(payload),
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    DatabaseHelper.instance.onQueueChanged?.call();
  }

  @override
  Future<int> insertCostume(Costume costume) async {
    final database = await _db;
    final row = costume.toSqlite();
    final result = await database.insert(
      AppTables.costumes,
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _recordSync(database, AppTables.costumes, costume.id, 'INSERT', row);
    return result;
  }

  @override
  Future<Costume?> getCostumeById(String id) async {
    final database = await _db;
    final results = await database.query(
      AppTables.costumes,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (results.isEmpty) return null;
    return Costume.fromSqlite(results.first);
  }

  @override
  Future<List<Costume>> getAllCostumes() async {
    final database = await _db;
    final results = await database.query(
      AppTables.costumes,
      orderBy: 'name ASC',
    );
    return results.map((m) => Costume.fromSqlite(m)).toList();
  }

  @override
  Future<List<Costume>> searchCostumes({
    String? query,
    CostumeStatus? status,
    String? size,
    String? series,
    String? sortBy,
  }) async {
    final database = await _db;
    final List<String> whereClauses = [];
    final List<dynamic> whereArgs = [];

    if (query != null && query.trim().isNotEmpty) {
      whereClauses.add('(name LIKE ? OR anime_series LIKE ?)');
      final term = '%${query.trim()}%';
      whereArgs.add(term);
      whereArgs.add(term);
    }

    if (status != null) {
      whereClauses.add('status = ?');
      whereArgs.add(status.name);
    }

    if (size != null && size.isNotEmpty && size != 'All') {
      whereClauses.add('size = ?');
      whereArgs.add(size);
    }

    if (series != null && series.trim().isNotEmpty && series != 'Semua') {
      whereClauses.add('(anime_series = ? OR REPLACE(anime_series, "_", " ") = ?)');
      whereArgs.add(series.trim());
      whereArgs.add(series.trim().replaceAll('_', ' '));
    }

    String orderBy = 'name ASC';
    if (sortBy != null) {
      switch (sortBy) {
        case 'name_desc':
          orderBy = 'name DESC';
          break;
        case 'price_asc':
          orderBy = 'rent_price_3days ASC';
          break;
        case 'price_desc':
          orderBy = 'rent_price_3days DESC';
          break;
        case 'name_asc':
        default:
          orderBy = 'name ASC';
          break;
      }
    }

    final where = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;
    final results = await database.query(
      AppTables.costumes,
      where: where,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: orderBy,
    );

    return results.map((m) => Costume.fromSqlite(m)).toList();
  }

  @override
  Future<List<String>> getDistinctAnimeSeries() async {
    final database = await _db;
    final results = await database.rawQuery(
      'SELECT DISTINCT anime_series FROM ${AppTables.costumes} WHERE anime_series IS NOT NULL AND TRIM(anime_series) != "" AND anime_series != "-" ORDER BY anime_series ASC',
    );
    final Set<String> unique = {};
    for (final r in results) {
      final s = r['anime_series'] as String?;
      if (s != null && s.trim().isNotEmpty && s != '-') {
        unique.add(s.replaceAll('_', ' ').trim());
      }
    }
    final list = unique.toList()..sort();
    return list;
  }

  @override
  Future<int> updateCostume(Costume costume) async {
    final database = await _db;
    final row = costume.toSqlite();
    final result = await database.update(
      AppTables.costumes,
      row,
      where: 'id = ?',
      whereArgs: [costume.id],
    );
    await _recordSync(database, AppTables.costumes, costume.id, 'UPDATE', row);
    return result;
  }

  @override
  Future<int> getActiveRentalsCount(String costumeId) async {
    final database = await _db;
    try {
      final result = await database.rawQuery(
        'SELECT COUNT(*) as count FROM ${AppTables.rentals} '
        'WHERE costume_id = ? AND item_status NOT IN (?, ?)',
        [costumeId, 'completed', 'cancelled'],
      );
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (_) {
      // In isolated partial-schema test databases where rentals table is omitted
      return 0;
    }
  }

  @override
  Future<CostumeRentalHistory> getRentalHistory(String costumeId) async {
    final database = await _db;
    try {
      // JOIN rentals with customers so each record carries the renter's name.
      // Cancelled rentals are excluded from every stat so a cancelled booking
      // never inflates the "Disewa X kali" badge or the last-service date.
      final rows = await database.rawQuery(
        'SELECT r.id AS rental_id, r.customer_id AS customer_id, '
        'c.full_name AS customer_name, r.start_date AS start_date, '
        'r.end_date AS end_date, r.item_status AS item_status '
        'FROM ${AppTables.rentals} AS r '
        'LEFT JOIN ${AppTables.customers} AS c ON c.id = r.customer_id '
        'WHERE r.costume_id = ? AND r.item_status != ? '
        'ORDER BY r.start_date DESC, r.end_date DESC',
        [costumeId, RentalItemStatus.cancelled.toSqliteString()],
      );

      final records = rows.map(CostumeRentalRecord.fromJoinRow).toList();
      final active = records.where((r) => r.isActive).toList();
      final now = DateTime.now();

      // Rows are ordered by start_date DESC, which does NOT guarantee the
      // first row has the latest end_date (a rental can start earlier yet end
      // later). Reduce explicitly so "Servis Terakhir" is always correct.
      final lastService = records.isEmpty
          ? null
          : records.map((r) => r.endDate).reduce((a, b) => a.isAfter(b) ? a : b);

      return CostumeRentalHistory(
        totalRentals: records.length,
        activeRentals: active.length,
        lastServiceDate: lastService,
        activeRental: active.isEmpty
            ? null
            : (active.firstWhere(
                (r) => r.coversDate(now),
                orElse: () => active.first,
              )),
        records: records,
      );
    } catch (_) {
      // Partial-schema test databases (no rentals/customers tables) fall back
      // to an empty history instead of crashing the detail screen.
      return const CostumeRentalHistory();
    }
  }

  @override
  Future<int> deleteCostume(String id) async {
    final database = await _db;
    final activeRentals = await getActiveRentalsCount(id);
    if (activeRentals > 0) {
      throw StateError('Kostum tidak dapat dihapus karena masih memiliki jadwal sewa aktif');
    }
    await database.delete(
      AppTables.accessories,
      where: 'related_costume_id = ?',
      whereArgs: [id],
    );
    final result = await database.delete(
      AppTables.costumes,
      where: 'id = ?',
      whereArgs: [id],
    );
    await _recordSync(database, AppTables.costumes, id, 'DELETE', {'id': id});
    return result;
  }

  @override
  Future<int> addAccessory(Accessory accessory) async {
    final database = await _db;
    final row = accessory.toSqlite();
    final result = await database.insert(
      AppTables.accessories,
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _recordSync(database, AppTables.accessories, accessory.id, 'INSERT', row);
    return result;
  }

  // Alias
  Future<int> insertAccessory(Accessory accessory) => addAccessory(accessory);

  Future<List<Costume>> getCostumesByStatus(CostumeStatus status) async {
    return searchCostumes(status: status);
  }

  Future<List<Accessory>> getAllAccessories() async {
    final database = await _db;
    final results = await database.query(
      AppTables.accessories,
      orderBy: 'name ASC',
    );
    return results.map((m) => Accessory.fromSqlite(m)).toList();
  }

  @override
  Future<List<Accessory>> getAccessoriesByCostumeId(String costumeId) async {
    final database = await _db;
    final results = await database.query(
      AppTables.accessories,
      where: 'related_costume_id = ?',
      whereArgs: [costumeId],
    );
    return results.map((m) => Accessory.fromSqlite(m)).toList();
  }

  @override
  Future<int> updateAccessory(Accessory accessory) async {
    final database = await _db;
    final row = accessory.toSqlite();
    final result = await database.update(
      AppTables.accessories,
      row,
      where: 'id = ?',
      whereArgs: [accessory.id],
    );
    await _recordSync(database, AppTables.accessories, accessory.id, 'UPDATE', row);
    return result;
  }

  @override
  Future<int> deleteAccessory(String id) async {
    final database = await _db;
    final result = await database.delete(
      AppTables.accessories,
      where: 'id = ?',
      whereArgs: [id],
    );
    await _recordSync(database, AppTables.accessories, id, 'DELETE', {'id': id});
    return result;
  }
}
