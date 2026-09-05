import 'package:flutter_test/flutter_test.dart';
import 'package:lilyhouse/core/database/tables.dart';
import 'package:lilyhouse/core/database/db_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('AppTables definitions', () {
    test('AppTables definition includes all 6 core tables and sync queue', () {
      expect(AppTables.allTables, contains('costumes'));
      expect(AppTables.allTables, contains('accessories'));
      expect(AppTables.allTables, contains('customers'));
      expect(AppTables.allTables, contains('rentals'));
      expect(AppTables.allTables, contains('installments'));
      expect(AppTables.allTables, contains('installment_logs'));
      expect(AppTables.allTables, contains('sync_queue'));
      expect(AppTables.allTables.length, equals(7));
    });

    test('AppTables create statements are non-empty for all tables', () {
      expect(AppTables.createCostumes, isNotEmpty);
      expect(AppTables.createAccessories, isNotEmpty);
      expect(AppTables.createCustomers, isNotEmpty);
      expect(AppTables.createRentals, isNotEmpty);
      expect(AppTables.createInstallments, isNotEmpty);
      expect(AppTables.createInstallmentLogs, isNotEmpty);
      expect(AppTables.createSyncQueue, isNotEmpty);
    });
  });

  group('DatabaseHelper SQLite in-memory operations', () {
    late Database testDb;
    late DatabaseHelper dbHelper;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      dbHelper = DatabaseHelper.instance;
      // Open in-memory database and run onCreate schema
      testDb = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) async {
            await db.execute(AppTables.createCostumes);
            await db.execute(AppTables.createAccessories);
            await db.execute(AppTables.createCustomers);
            await db.execute(AppTables.createRentals);
            await db.execute(AppTables.createInstallments);
            await db.execute(AppTables.createInstallmentLogs);
            await db.execute(AppTables.createSyncQueue);
          },
        ),
      );
      dbHelper.setDatabaseForTesting(testDb);
    });

    tearDown(() async {
      await testDb.close();
    });

    test('Database creates all 7 tables successfully', () async {
      final tables = await testDb.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_%';",
      );
      final tableNames = tables.map((t) => t['name'] as String).toList();
      for (final expected in AppTables.allTables) {
        expect(tableNames, contains(expected));
      }
    });

    test('CRUD on costumes table', () async {
      await testDb.insert(AppTables.costumes, {
        'id': 'cos-1',
        'name': 'Frieren Mage Robe',
        'anime_series': 'Sousou no Frieren',
        'size': 'M',
        'rent_price_3days': 150000.0,
        'status': 'available',
        'cover_photo': 'frieren.jpg',
        'gallery_photos': '["frieren1.jpg", "frieren2.jpg"]',
        'included_accessories': '["Staff", "Earrings"]',
        'notes': 'Delicate fabric',
        'sync_status': 'pending',
      });

      final result = await testDb.query(
        AppTables.costumes,
        where: 'id = ?',
        whereArgs: ['cos-1'],
      );
      expect(result.length, 1);
      expect(result.first['name'], 'Frieren Mage Robe');
      expect(result.first['rent_price_3days'], 150000.0);
    });

    test('CRUD on accessories table', () async {
      await testDb.insert(AppTables.accessories, {
        'id': 'acc-1',
        'name': 'Frieren Staff',
        'type': 'Weapon Prop',
        'related_costume_id': 'cos-1',
        'condition_status': 'good',
        'photo_url': 'staff.jpg',
        'sync_status': 'pending',
      });

      final result = await testDb.query(
        AppTables.accessories,
        where: 'id = ?',
        whereArgs: ['acc-1'],
      );
      expect(result.length, 1);
      expect(result.first['name'], 'Frieren Staff');
      expect(result.first['type'], 'Weapon Prop');
    });

    test('CRUD on customers table', () async {
      await testDb.insert(AppTables.customers, {
        'id': 'cust-1',
        'full_name': 'Aoi Kanzaki',
        'phone': '08123456789',
        'parent_phone': '08987654321',
        'address': 'Jl. Sakura No. 12',
        'social_media': '@aoi_cos',
        'ktp_photo_url': 'ktp.jpg',
        'selfie_ktp_url': 'selfie.jpg',
        'sync_status': 'pending',
      });

      final result = await testDb.query(
        AppTables.customers,
        where: 'id = ?',
        whereArgs: ['cust-1'],
      );
      expect(result.length, 1);
      expect(result.first['full_name'], 'Aoi Kanzaki');
    });

    test('CRUD on rentals table', () async {
      await testDb.insert(AppTables.rentals, {
        'id': 'rent-1',
        'costume_id': 'cos-1',
        'customer_id': 'cust-1',
        'start_date': '2026-09-10',
        'end_date': '2026-09-13',
        'duration_days': 3,
        'purpose': 'Anime Expo event',
        'total_price': 150000.0,
        'dp_amount': 50000.0,
        'payment_status': 'dp_paid',
        'item_status': 'booked',
        'notes': 'Handle with care',
        'sync_status': 'pending',
      });

      final result = await testDb.query(
        AppTables.rentals,
        where: 'id = ?',
        whereArgs: ['rent-1'],
      );
      expect(result.length, 1);
      expect(result.first['duration_days'], 3);
      expect(result.first['payment_status'], 'dp_paid');
    });

    test('CRUD on installments and installment_logs table', () async {
      await testDb.insert(AppTables.installments, {
        'id': 'inst-1',
        'item_name': 'Raiden Shogun Kimono & Wig',
        'store_name': 'Taobao Cosplay Shop',
        'total_cost': 1200000.0,
        'total_paid': 400000.0,
        'remaining_balance': 800000.0,
        'due_date': '2026-10-01',
        'status': 'ongoing',
        'sync_status': 'pending',
      });

      await testDb.insert(AppTables.installmentLogs, {
        'id': 'log-1',
        'installment_id': 'inst-1',
        'payment_date': '2026-09-01',
        'amount_paid': 400000.0,
        'proof_photo_url': 'tf_receipt.jpg',
        'notes': 'First installment payment',
        'sync_status': 'pending',
      });

      final instResult = await testDb.query(
        AppTables.installments,
        where: 'id = ?',
        whereArgs: ['inst-1'],
      );
      final logResult = await testDb.query(
        AppTables.installmentLogs,
        where: 'installment_id = ?',
        whereArgs: ['inst-1'],
      );

      expect(instResult.length, 1);
      expect(instResult.first['remaining_balance'], 800000.0);
      expect(logResult.length, 1);
      expect(logResult.first['amount_paid'], 400000.0);
    });

    test('Offline sync queue helper methods: enqueueSync, getPendingSyncItems, removeSyncItem, clearSyncQueue', () async {
      // 1. Enqueue sync actions
      await dbHelper.enqueueSync(
        id: 'sync-1',
        tableName: AppTables.costumes,
        recordId: 'cos-1',
        action: 'insert',
        payload: '{"name":"Frieren"}',
      );

      await dbHelper.enqueueSync(
        id: 'sync-2',
        tableName: AppTables.rentals,
        recordId: 'rent-1',
        action: 'update',
        payload: '{"status":"returned"}',
      );

      var pending = await dbHelper.getPendingSyncItems();
      expect(pending.length, 2);
      expect(pending[0]['id'], 'sync-1');
      expect(pending[0]['table_name'], AppTables.costumes);
      expect(pending[1]['id'], 'sync-2');
      expect(pending[1]['table_name'], AppTables.rentals);

      // 2. Remove one sync item
      final removedCount = await dbHelper.removeSyncItem('sync-1');
      expect(removedCount, 1);

      pending = await dbHelper.getPendingSyncItems();
      expect(pending.length, 1);
      expect(pending.first['id'], 'sync-2');

      // 3. Clear sync queue
      await dbHelper.clearSyncQueue();
      pending = await dbHelper.getPendingSyncItems();
      expect(pending, isEmpty);
    });
  });
}
