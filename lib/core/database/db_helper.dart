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

  static const Map<String, Set<String>> _restoreColumns = {
    AppTables.costumes: {
      'id', 'name', 'anime_series', 'size', 'rent_price_3days', 'status',
      'cover_photo', 'gallery_photos', 'included_accessories', 'notes',
      'sync_status',
    },
    AppTables.accessories: {
      'id', 'name', 'type', 'related_costume_id', 'condition_status',
      'photo_url', 'sync_status',
    },
    AppTables.customers: {
      'id', 'full_name', 'phone', 'parent_phone', 'address', 'social_media',
      'ktp_photo_url', 'selfie_ktp_url', 'sync_status',
    },
    AppTables.rentals: {
      'id', 'costume_id', 'customer_id', 'start_date', 'end_date',
      'duration_days', 'purpose', 'total_price', 'dp_amount',
      'payment_status', 'item_status', 'notes', 'sync_status',
    },
    AppTables.installments: {
      'id', 'item_name', 'store_name', 'total_cost', 'total_paid',
      'remaining_balance', 'due_date', 'status', 'sync_status',
    },
    AppTables.installmentLogs: {
      'id', 'installment_id', 'payment_date', 'amount_paid',
      'proof_photo_url', 'notes', 'sync_status',
    },
  };

  Map<String, dynamic> _normalizeRestoreRow(String table, Map<String, dynamic> row) {
    final out = Map<String, dynamic>.from(row);
    // Drop unknown columns (e.g. GAS updated_at) so INSERT never crashes.
    out.removeWhere((k, _) => !(_restoreColumns[table]?.contains(k) ?? false));
    // Cloud is source of truth — mark clean so it isn't re-queued on next sync.
    out['sync_status'] = 'synced';

    String s(Object? v, [String fallback = '']) {
      if (v == null) return fallback;
      final str = v.toString();
      return str.isEmpty ? fallback : str;
    }

    double numDouble(Object? v) {
      if (v is num) return v.toDouble();
      return double.tryParse(v?.toString() ?? '') ?? 0.0;
    }

    int numInt(Object? v) {
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? 0;
    }

    switch (table) {
      case AppTables.costumes:
        out['name'] = s(out['name']);
        out['anime_series'] = s(out['anime_series']);
        out['size'] = s(out['size'], 'All Size');
        out['rent_price_3days'] = numDouble(out['rent_price_3days']);
        out['status'] = s(out['status'], 'available');
      case AppTables.accessories:
        out['name'] = s(out['name']);
        out['type'] = s(out['type']);
        out['condition_status'] = s(out['condition_status'], 'good');
      case AppTables.customers:
        out['full_name'] = s(out['full_name']);
        out['phone'] = s(out['phone']);
        out['address'] = s(out['address']);
      case AppTables.rentals:
        out['costume_id'] = s(out['costume_id']);
        out['customer_id'] = s(out['customer_id']);
        final nowIso = DateTime.now().toIso8601String();
        out['start_date'] = s(out['start_date'], nowIso);
        out['end_date'] = s(out['end_date'], nowIso);
        out['duration_days'] = numInt(out['duration_days']);
        out['purpose'] = s(out['purpose']);
        out['total_price'] = numDouble(out['total_price']);
        out['dp_amount'] = numDouble(out['dp_amount']);
        out['payment_status'] = s(out['payment_status'], 'unpaid');
        out['item_status'] = s(out['item_status'], 'booked');
      case AppTables.installments:
        out['item_name'] = s(out['item_name']);
        out['total_cost'] = numDouble(out['total_cost']);
        out['total_paid'] = numDouble(out['total_paid']);
        out['remaining_balance'] = numDouble(out['remaining_balance']);
        final dueRaw = out['due_date']?.toString().trim() ?? '';
        out['due_date'] = dueRaw.isEmpty ? null : dueRaw;
        out['status'] = s(out['status'], 'ongoing');
      case AppTables.installmentLogs:
        out['installment_id'] = s(out['installment_id']);
        out['payment_date'] = s(out['payment_date'], DateTime.now().toIso8601String());
        out['amount_paid'] = numDouble(out['amount_paid']);
    }
    return out;
  }

  /// Replaces local tables with cloud data (fresh-install restore path).
  /// Returns per-table inserted counts. Runs in one transaction.
  Future<Map<String, int>> restoreAll(Map<String, dynamic> cloudData) async {
    final db = await database;
    final counts = <String, int>{};
    const tables = [
      AppTables.costumes,
      AppTables.accessories,
      AppTables.customers,
      AppTables.rentals,
      AppTables.installments,
      AppTables.installmentLogs,
    ];
    await db.transaction((txn) async {
      for (final table in tables) {
        final raw = cloudData[table];
        final List list = raw is List ? raw : [];
        await txn.delete(table);
        var inserted = 0;
        for (final item in list) {
          if (item is! Map) continue;
          final row = <String, dynamic>{};
          item.forEach((k, v) => row[k.toString()] = v);
          final id = row['id']?.toString() ?? '';
          if (id.isEmpty) continue;
          row['id'] = id;
          await txn.insert(
            table,
            _normalizeRestoreRow(table, row),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          inserted++;
        }
        counts[table] = inserted;
      }
      await txn.delete(AppTables.syncQueue);
    });
    return counts;
  }
}
