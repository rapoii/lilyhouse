import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lilyhouse/core/database/db_helper.dart';
import 'package:lilyhouse/core/database/tables.dart';
import 'package:lilyhouse/core/sync/sync_manager.dart';
import 'package:lilyhouse/core/sync/sync_service.dart';
import 'package:lilyhouse/core/sync/sync_state_notifier.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class FakeConnectivity implements Connectivity {
  final StreamController<List<ConnectivityResult>> _controller =
      StreamController<List<ConnectivityResult>>.broadcast();
  List<ConnectivityResult> currentResult = [ConnectivityResult.wifi];

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => _controller.stream;

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => currentResult;

  void emit(List<ConnectivityResult> result) {
    currentResult = result;
    _controller.add(result);
  }

  void close() {
    _controller.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('SyncManager Offline-First Tests', () {
    late Database testDb;
    late DatabaseHelper dbHelper;
    late FakeConnectivity fakeConnectivity;
    late SyncService syncService;
    late SyncStateNotifier notifier;
    int postRequestCount = 0;

    setUp(() async {
      postRequestCount = 0;
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

      fakeConnectivity = FakeConnectivity();

      final mockClient = MockClient((request) async {
        if (request.method == 'POST') {
          postRequestCount++;
          return http.Response(
            '{"status": "success", "processed_ids": ["sync-auto-1"], "errors": []}',
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{"status": "success"}', 200);
      });

      syncService = SyncService(
        endpointUrl: 'https://example.com/sync',
        dbHelper: dbHelper,
        httpClient: mockClient,
      );

      notifier = SyncStateNotifier(syncService);
      SyncManager.instance.dispose();
    });

    tearDown(() async {
      SyncManager.instance.dispose();
      fakeConnectivity.close();
      await testDb.close();
    });

    test('Initializes, sets online state, and hooks into queue changes', () async {
      SyncManager.instance.initialize(
        notifier: notifier,
        connectivity: fakeConnectivity,
      );

      expect(SyncManager.instance.isOnline, isTrue);

      // Enqueue item via dbHelper, which calls onQueueChanged
      await dbHelper.enqueueSync(
        id: 'sync-auto-1',
        tableName: AppTables.costumes,
        recordId: 'cos-auto',
        action: 'insert',
        payload: '{"name": "Nahida"}',
      );

      // Verify pending count refreshed
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(notifier.state.pendingCount, 1);

      // Trigger immediate sync
      await SyncManager.instance.triggerSync();

      expect(postRequestCount, 1);
      expect(notifier.state.status, SyncStatus.success);
      expect(notifier.state.pendingCount, 0);
    });

    test('Does not attempt network sync when device is offline', () async {
      fakeConnectivity.currentResult = [ConnectivityResult.none];

      SyncManager.instance.initialize(
        notifier: notifier,
        connectivity: fakeConnectivity,
      );

      // Wait a microtask for checkConnectivity to complete
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(SyncManager.instance.isOnline, isFalse);
      expect(notifier.state.isOnline, isFalse);

      await dbHelper.enqueueSync(
        id: 'sync-offline-1',
        tableName: AppTables.costumes,
        recordId: 'cos-offline',
        action: 'insert',
        payload: '{"name": "Raiden Shogun"}',
      );

      // Trigger sync while offline
      await SyncManager.instance.triggerSync();

      // Should not send any HTTP request
      expect(postRequestCount, 0);
      // Item remains in pending queue
      expect(notifier.state.pendingCount, 1);
    });

    test('Automatically triggers sync when transitioning from offline to online', () async {
      fakeConnectivity.currentResult = [ConnectivityResult.none];

      SyncManager.instance.initialize(
        notifier: notifier,
        connectivity: fakeConnectivity,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(SyncManager.instance.isOnline, isFalse);

      await dbHelper.enqueueSync(
        id: 'sync-auto-1',
        tableName: AppTables.costumes,
        recordId: 'cos-auto',
        action: 'insert',
        payload: '{"name": "Zhongli"}',
      );

      expect(postRequestCount, 0);

      // Network comes back online!
      fakeConnectivity.emit([ConnectivityResult.wifi]);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(SyncManager.instance.isOnline, isTrue);
      expect(notifier.state.isOnline, isTrue);

      // Wait for debounced sync to fire
      await Future<void>.delayed(const Duration(milliseconds: 900));

      expect(postRequestCount, 1);
      expect(notifier.state.pendingCount, 0);
    });
  });
}
