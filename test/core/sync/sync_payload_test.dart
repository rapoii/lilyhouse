import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lilyhouse/core/database/db_helper.dart';
import 'package:lilyhouse/core/database/tables.dart';
import 'package:lilyhouse/core/sync/sync_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('SyncService - Payload serialization & Batch dispatch', () {
    late Database testDb;
    late DatabaseHelper dbHelper;

    setUp(() async {
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
      dbHelper = DatabaseHelper.instance;
      dbHelper.setDatabaseForTesting(testDb);
    });

    tearDown(() async {
      await testDb.close();
    });

    test('Serializes pending queue items into proper sync_batch JSON request payload', () async {
      await dbHelper.enqueueSync(
        id: 'sync-1',
        tableName: AppTables.costumes,
        recordId: 'cos-1',
        action: 'insert',
        payload: jsonEncode({'name': 'Frieren Mage Robe', 'size': 'M'}),
      );

      await dbHelper.enqueueSync(
        id: 'sync-2',
        tableName: AppTables.customers,
        recordId: 'cust-1',
        action: 'update',
        payload: jsonEncode({'full_name': 'Fern', 'phone': '08123456789'}),
      );

      Map<String, dynamic>? capturedBody;
      final mockClient = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.toString(), 'https://script.google.com/macros/s/test-script-id/exec');
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'status': 'success',
            'processed_ids': ['sync-1', 'sync-2'],
            'errors': [],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final syncService = SyncService(
        endpointUrl: 'https://script.google.com/macros/s/test-script-id/exec',
        dbHelper: dbHelper,
        httpClient: mockClient,
      );

      final result = await syncService.syncPending();

      expect(result.isSuccess, isTrue);
      expect(result.syncedCount, equals(2));
      expect(capturedBody, isNotNull);
      expect(capturedBody!['action'], 'sync_batch');
      final items = capturedBody!['items'] as List;
      expect(items.length, 2);
      expect(items[0]['id'], 'sync-1');
      expect(items[0]['table_name'], AppTables.costumes);
      expect(items[0]['record_id'], 'cos-1');
      expect(items[0]['action'], 'insert');
      expect(items[0]['payload'], contains('Frieren Mage Robe'));

      // Verify queue is cleared for processed items
      final remaining = await dbHelper.getPendingSyncItems();
      expect(remaining, isEmpty);
    });

    test('Partial sync success only deletes successfully processed items from queue', () async {
      await dbHelper.enqueueSync(
        id: 'sync-1',
        tableName: AppTables.costumes,
        recordId: 'cos-1',
        action: 'insert',
        payload: '{"name": "Costume A"}',
      );
      await dbHelper.enqueueSync(
        id: 'sync-2',
        tableName: AppTables.rentals,
        recordId: 'rent-1',
        action: 'insert',
        payload: '{"purpose": "Event"}',
      );

      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'status': 'partial_success',
            'processed_ids': ['sync-1'],
            'errors': [
              {'id': 'sync-2', 'error': 'Database lock error in sheet'}
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final syncService = SyncService(
        endpointUrl: 'https://script.google.com/macros/s/test-script-id/exec',
        dbHelper: dbHelper,
        httpClient: mockClient,
      );

      final result = await syncService.syncPending();

      expect(result.isSuccess, isFalse);
      expect(result.syncedCount, equals(1));
      expect(result.errorMessage, contains('Database lock error'));

      final remaining = await dbHelper.getPendingSyncItems();
      expect(remaining.length, equals(1));
      expect(remaining.first['id'], equals('sync-2'));
    });

    test('Handles HTTP server error gracefully and preserves queue', () async {
      await dbHelper.enqueueSync(
        id: 'sync-1',
        tableName: AppTables.costumes,
        recordId: 'cos-1',
        action: 'insert',
        payload: '{"name": "Costume A"}',
      );

      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final syncService = SyncService(
        endpointUrl: 'https://script.google.com/macros/s/test-script-id/exec',
        dbHelper: dbHelper,
        httpClient: mockClient,
      );

      final result = await syncService.syncPending();

      expect(result.isSuccess, isFalse);
      expect(result.syncedCount, equals(0));
      expect(result.errorMessage, contains('500'));

      final remaining = await dbHelper.getPendingSyncItems();
      expect(remaining.length, equals(1));
    });

    test('Uploads media image to Google Drive via Apps Script and returns public url', () async {
      final mockClient = MockClient((request) async {
        final data = jsonDecode(request.body) as Map<String, dynamic>;
        expect(data['action'], 'upload_media');
        expect(data['file_name'], 'costume_front.jpg');
        expect(data['base64_data'], 'aGVsbG8gd29ybGQ=');
        return http.Response(
          jsonEncode({
            'status': 'success',
            'file_id': 'drive-file-12345',
            'url': 'https://drive.google.com/uc?export=view&id=drive-file-12345',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final syncService = SyncService(
        endpointUrl: 'https://script.google.com/macros/s/test-script-id/exec',
        dbHelper: dbHelper,
        httpClient: mockClient,
      );

      final uploadedUrl = await syncService.uploadMedia(
        fileName: 'costume_front.jpg',
        base64Data: 'aGVsbG8gd29ybGQ=',
        mimeType: 'image/jpeg',
      );

      expect(uploadedUrl, 'https://drive.google.com/uc?export=view&id=drive-file-12345');
    });

    test('When sync queue is empty, returns success with 0 syncedCount without calling network', () async {
      var networkCalled = false;
      final mockClient = MockClient((request) async {
        networkCalled = true;
        return http.Response('{}', 200);
      });

      final syncService = SyncService(
        endpointUrl: 'https://script.google.com/macros/s/test-script-id/exec',
        dbHelper: dbHelper,
        httpClient: mockClient,
      );

      final result = await syncService.syncPending();
      expect(result.isSuccess, isTrue);
      expect(result.syncedCount, 0);
      expect(networkCalled, isFalse);
    });
  });
}
