import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lilyhouse/core/database/db_helper.dart';
import 'package:lilyhouse/core/database/tables.dart';
import 'package:lilyhouse/core/sync/sync_service.dart';
import 'package:lilyhouse/core/sync/sync_state_notifier.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('SyncStateNotifier Riverpod tests', () {
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

    test('Initial state is idle and pending count matches database', () async {
      await dbHelper.enqueueSync(
        id: 'sync-1',
        tableName: AppTables.costumes,
        recordId: 'cos-1',
        action: 'insert',
        payload: '{}',
      );

      final mockClient = MockClient((request) async {
        return http.Response('{"status": "success", "processed_ids": []}', 200);
      });

      final syncService = SyncService(
        endpointUrl: 'https://example.com/sync',
        dbHelper: dbHelper,
        httpClient: mockClient,
      );

      final container = ProviderContainer(
        overrides: [
          syncServiceProvider.overrideWithValue(syncService),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(syncStateProvider.notifier);
      await notifier.refreshPendingCount();

      final state = container.read(syncStateProvider);
      expect(state.status, SyncStatus.idle);
      expect(state.pendingCount, 1);
      expect(state.lastSyncedAt, isNull);
      expect(state.errorMessage, isNull);
    });

    test('Synchronizes queue transitioning from idle -> syncing -> success', () async {
      await dbHelper.enqueueSync(
        id: 'sync-1',
        tableName: AppTables.costumes,
        recordId: 'cos-1',
        action: 'insert',
        payload: '{}',
      );

      final mockClient = MockClient((request) async {
        return http.Response(
          '{"status": "success", "processed_ids": ["sync-1"], "errors": []}',
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final syncService = SyncService(
        endpointUrl: 'https://example.com/sync',
        dbHelper: dbHelper,
        httpClient: mockClient,
      );

      final container = ProviderContainer(
        overrides: [
          syncServiceProvider.overrideWithValue(syncService),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(syncStateProvider.notifier);
      final states = <SyncStatus>[];
      container.listen(syncStateProvider, (previous, next) {
        states.add(next.status);
      });

      final result = await notifier.syncNow();

      expect(result.isSuccess, isTrue);
      final finalState = container.read(syncStateProvider);
      expect(finalState.status, SyncStatus.success);
      expect(finalState.pendingCount, 0);
      expect(finalState.lastSyncedAt, isNotNull);
      expect(states, contains(SyncStatus.syncing));
      expect(states.last, SyncStatus.success);
    });

    test('Synchronizes queue error transitioning from idle -> syncing -> error', () async {
      await dbHelper.enqueueSync(
        id: 'sync-1',
        tableName: AppTables.costumes,
        recordId: 'cos-1',
        action: 'insert',
        payload: '{}',
      );

      final mockClient = MockClient((request) async {
        return http.Response('Internal error', 500);
      });

      final syncService = SyncService(
        endpointUrl: 'https://example.com/sync',
        dbHelper: dbHelper,
        httpClient: mockClient,
      );

      final container = ProviderContainer(
        overrides: [
          syncServiceProvider.overrideWithValue(syncService),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(syncStateProvider.notifier);
      final result = await notifier.syncNow();

      expect(result.isSuccess, isFalse);
      final finalState = container.read(syncStateProvider);
      expect(finalState.status, SyncStatus.error);
      expect(finalState.errorMessage, contains('500'));
      expect(finalState.pendingCount, 1);
    });
  });
}
