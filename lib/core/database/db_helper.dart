import 'dart:async';
import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'tables.dart';

class DatabaseHelper {
  static const String _dbName = 'lilyhouse.db';
  static const int _dbVersion = 1;

  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // Allow injecting custom database instance or factory (useful for tests/in-memory)
  void setDatabaseForTesting(Database db) {
    _database = db;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute(AppTables.createCostumes);
    await db.execute(AppTables.createAccessories);
    await db.execute(AppTables.createCustomers);
    await db.execute(AppTables.createRentals);
    await db.execute(AppTables.createInstallments);
    await db.execute(AppTables.createInstallmentLogs);
    await db.execute(AppTables.createSyncQueue);
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  // Sync queue helper methods for offline queueing
  Future<int> enqueueSync({
    required String id,
    required String tableName,
    required String recordId,
    required String action,
    required String payload,
  }) async {
    final db = await database;
    return await db.insert(
      AppTables.syncQueue,
      {
        'id': id,
        'table_name': tableName,
        'record_id': recordId,
        'action': action,
        'payload': payload,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getPendingSyncItems() async {
    final db = await database;
    return await db.query(
      AppTables.syncQueue,
      orderBy: 'created_at ASC',
    );
  }

  Future<int> removeSyncItem(String id) async {
    final db = await database;
    return await db.delete(
      AppTables.syncQueue,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> clearSyncQueue() async {
    final db = await database;
    return await db.delete(AppTables.syncQueue);
  }

  /// Automatically enqueues any existing records in all tables that have not yet been synced.
  Future<int> enqueueAllUnsyncedRecords() async {
    final db = await database;
    int enqueuedCount = 0;

    final existingQueue = await db.query(AppTables.syncQueue);
    final queuedKeys = existingQueue.map((q) => '${q['table_name']}_${q['record_id']}').toSet();

    final tablesToSync = [
      AppTables.costumes,
      AppTables.accessories,
      AppTables.customers,
      AppTables.rentals,
      AppTables.installments,
      AppTables.installmentLogs,
    ];

    for (final table in tablesToSync) {
      final rows = await db.query(table);
      for (final row in rows) {
        final id = row['id'] as String;
        final key = '${table}_$id';
        if (!queuedKeys.contains(key)) {
          await enqueueSync(
            id: '${table}_${id}_${DateTime.now().millisecondsSinceEpoch}',
            tableName: table,
            recordId: id,
            action: 'INSERT',
            payload: jsonEncode(row),
          );
          queuedKeys.add(key);
          enqueuedCount++;
        }
      }
    }
    return enqueuedCount;
  }

  Future<Map<String, int>> getTableCounts() async {
    final db = await database;
    try {
      final costumes = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM ${AppTables.costumes}'),
      ) ?? 0;
      final rentals = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM ${AppTables.rentals}'),
      ) ?? 0;
      final customers = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM ${AppTables.customers}'),
      ) ?? 0;
      final installments = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM ${AppTables.installments}'),
      ) ?? 0;
      return {
        'costumes': costumes,
        'rentals': rentals,
        'customers': customers,
        'installments': installments,
      };
    } catch (_) {
      return {
        'costumes': 0,
        'rentals': 0,
        'customers': 0,
        'installments': 0,
      };
    }
  }
}
