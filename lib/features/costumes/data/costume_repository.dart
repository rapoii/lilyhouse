import 'package:sqflite/sqflite.dart';
import '../../../core/database/tables.dart';
import '../../../core/database/db_helper.dart';
import '../domain/costume.dart';
import '../domain/accessory.dart';

abstract class ICostumeRepository {
  Future<int> insertCostume(Costume costume);
  Future<Costume?> getCostumeById(String id);
  Future<List<Costume>> getAllCostumes();
  Future<List<Costume>> searchCostumes({String? query, CostumeStatus? status, String? size});
  Future<int> updateCostume(Costume costume);
  Future<int> deleteCostume(String id);
  Future<int> addAccessory(Accessory accessory);
  Future<List<Accessory>> getAccessoriesByCostumeId(String costumeId);
  Future<int> updateAccessory(Accessory accessory);
  Future<int> deleteAccessory(String id);
}

class CostumeRepository implements ICostumeRepository {
  final Database? db;

  CostumeRepository({this.db});

  Future<Database> get _db async {
    return db ?? await DatabaseHelper.instance.database;
  }

  @override
  Future<int> insertCostume(Costume costume) async {
    final database = await _db;
    return await database.insert(
      AppTables.costumes,
      costume.toSqlite(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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

    if (size != null && size.isNotEmpty) {
      whereClauses.add('size = ?');
      whereArgs.add(size);
    }

    final where = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;
    final results = await database.query(
      AppTables.costumes,
      where: where,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'name ASC',
    );

    return results.map((m) => Costume.fromSqlite(m)).toList();
  }

  @override
  Future<int> updateCostume(Costume costume) async {
    final database = await _db;
    return await database.update(
      AppTables.costumes,
      costume.toSqlite(),
      where: 'id = ?',
      whereArgs: [costume.id],
    );
  }

  @override
  Future<int> deleteCostume(String id) async {
    final database = await _db;
    return await database.delete(
      AppTables.costumes,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<int> addAccessory(Accessory accessory) async {
    final database = await _db;
    return await database.insert(
      AppTables.accessories,
      accessory.toSqlite(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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
    return await database.update(
      AppTables.accessories,
      accessory.toSqlite(),
      where: 'id = ?',
      whereArgs: [accessory.id],
    );
  }

  @override
  Future<int> deleteAccessory(String id) async {
    final database = await _db;
    return await database.delete(
      AppTables.accessories,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
