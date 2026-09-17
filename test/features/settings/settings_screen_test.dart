import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lilyhouse/core/database/db_helper.dart';
import 'package:lilyhouse/core/sync/sync_service.dart';
import 'package:lilyhouse/core/sync/sync_state_notifier.dart';
import 'package:lilyhouse/core/utils/date_time_utils.dart';
import 'package:lilyhouse/features/settings/presentation/settings_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MockSyncService extends SyncService {
  MockSyncService({required super.endpointUrl, super.dbHelper});

  @override
  Future<SyncResult> syncTwoWay({bool uploadLocalMedia = true}) async {
    return const SyncResult(isSuccess: true, syncedCount: 0);
  }

  @override
  Future<RestoreResult> restoreFromCloud() async {
    return const RestoreResult(isSuccess: true, totalCount: 15);
  }
}

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await initializeDateFormatting('id_ID', null);
  });

  group('DateTimeUtils.formatSyncRelative', () {
    final fixedNow = DateTime(2026, 9, 16, 14, 30, 0);

    test('returns "Belum pernah" when timestamp is null', () {
      expect(DateTimeUtils.formatSyncRelative(null), equals('Belum pernah'));
    });

    test('returns "Baru saja" when under 45 seconds ago or future', () {
      final justNow = fixedNow.subtract(const Duration(seconds: 20));
      expect(DateTimeUtils.formatSyncRelative(justNow, now: fixedNow), equals('Baru saja'));

      final future = fixedNow.add(const Duration(seconds: 10));
      expect(DateTimeUtils.formatSyncRelative(future, now: fixedNow), equals('Baru saja'));
    });

    test('returns minutes ago when under 60 minutes', () {
      final fiveMinAgo = fixedNow.subtract(const Duration(minutes: 5));
      expect(DateTimeUtils.formatSyncRelative(fiveMinAgo, now: fixedNow), equals('5 menit lalu'));

      final fiftyNineMinAgo = fixedNow.subtract(const Duration(minutes: 59));
      expect(DateTimeUtils.formatSyncRelative(fiftyNineMinAgo, now: fixedNow), equals('59 menit lalu'));
    });

    test('returns "Hari ini pukul HH:mm" when earlier today (> 60 mins)', () {
      final earlierToday = DateTime(2026, 9, 16, 9, 15, 0);
      expect(
        DateTimeUtils.formatSyncRelative(earlierToday, now: fixedNow),
        equals('Hari ini pukul 09:15'),
      );
    });

    test('returns "Kemarin pukul HH:mm" for yesterday', () {
      final yesterday = DateTime(2026, 9, 15, 18, 45, 0);
      expect(
        DateTimeUtils.formatSyncRelative(yesterday, now: fixedNow),
        equals('Kemarin pukul 18:45'),
      );
    });

    test('returns day of week for 2 to 6 days ago', () {
      // 2026-09-16 is Wednesday. 2026-09-13 is Sunday (Minggu).
      final sunday = DateTime(2026, 9, 13, 11, 20, 0);
      expect(
        DateTimeUtils.formatSyncRelative(sunday, now: fixedNow),
        equals('Minggu pukul 11:20'),
      );
    });

    test('returns date and month with time when in same calendar year but > 7 days ago', () {
      final lastMonth = DateTime(2026, 8, 10, 10, 0, 0);
      expect(
        DateTimeUtils.formatSyncRelative(lastMonth, now: fixedNow),
        equals('10 Agu, 10:00'),
      );
    });

    test('returns full date including year when in different calendar year', () {
      final lastYear = DateTime(2025, 11, 20, 8, 30, 0);
      expect(
        DateTimeUtils.formatSyncRelative(lastYear, now: fixedNow),
        equals('20 Nov 2025, 08:30'),
      );
    });
  });

  group('SettingsScreen UX & Protection Tests', () {
    late Database inMemoryDb;
    late MockSyncService mockSync;

    setUp(() async {
      inMemoryDb = await openDatabase(inMemoryDatabasePath, version: 1);
      DatabaseHelper.instance.setDatabaseForTesting(inMemoryDb);
      mockSync = MockSyncService(endpointUrl: 'https://mock.example.com');
    });

    tearDown(() async {
      await inMemoryDb.close();
    });

    testWidgets('displays human-readable relative time and absolute subtitle for last sync', (tester) async {
      final syncTime = DateTime.now().subtract(const Duration(minutes: 12));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            syncStateProvider.overrideWith(
              (ref) => SyncStateNotifier(mockSync)
                ..state = SyncState(
                  status: SyncStatus.success,
                  lastSyncedAt: syncTime,
                  pendingCount: 0,
                  isOnline: true,
                ),
            ),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Terakhir Sinkron row title
      expect(find.text('Terakhir Sinkron'), findsOneWidget);
      // Human-readable relative time in additionalInfo
      expect(find.text('12 menit lalu'), findsOneWidget);
    });

    testWidgets('shows "Belum pernah" when no sync has occurred', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            syncStateProvider.overrideWith(
              (ref) => SyncStateNotifier(mockSync)
                ..state = const SyncState(
                  status: SyncStatus.idle,
                  lastSyncedAt: null,
                  pendingCount: 0,
                  isOnline: true,
                ),
            ),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Belum pernah'), findsOneWidget);
    });

    testWidgets('Bersihkan Cache Gambar skips the destructive dialog when cache is empty', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            syncServiceProvider.overrideWithValue(mockSync),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Scroll to "Bersihkan Cache Gambar"
      final cacheTile = find.text('Bersihkan Cache Gambar');
      await tester.scrollUntilVisible(cacheTile, 300);
      await tester.pumpAndSettle();
      await tester.tap(cacheTile);
      await tester.pumpAndSettle();

      // An empty cache must NOT raise the destructive confirmation dialog —
      // there is nothing to clear, so a friendly toast is shown instead.
      expect(find.byType(CupertinoAlertDialog), findsNothing);
      expect(find.text('Cache gambar sudah kosong'), findsOneWidget);
    });

    testWidgets('protects "Pulihkan dari Cloud" with explicit confirmation dialog', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            syncServiceProvider.overrideWithValue(mockSync),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find "Pulihkan dari Cloud" button
      final restoreBtn = find.text('Pulihkan dari Cloud');
      expect(restoreBtn, findsOneWidget);
      await tester.tap(restoreBtn);
      await tester.pumpAndSettle();

      // Verify CupertinoAlertDialog is shown
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      expect(find.text('Pulihkan dari Cloud?'), findsOneWidget);
      expect(find.textContaining('Data offline yang belum disinkronkan akan hilang secara permanen'), findsOneWidget);

      // Verify Batal button
      final batalBtn = find.text('Batal');
      expect(batalBtn, findsOneWidget);
      await tester.tap(batalBtn);
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsNothing);
    });

    testWidgets('changelog merges the duplicate 1.0.90 header and drops non-standard wording', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            syncServiceProvider.overrideWithValue(mockSync),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final changelogTile = find.text('Catatan Rilis');
      await tester.scrollUntilVisible(changelogTile, 300);
      await tester.pumpAndSettle();
      await tester.tap(changelogTile);
      await tester.pumpAndSettle();

      // A single release header per build — duplicates must be merged into one section.
      // v1.0.92 was superseded by this build, so its notes now live under 1.0.93.
      expect(find.text('VERSI 1.0.94 (BUILD 129) - TERBARU'), findsOneWidget);

      // Older release notes live further down the same list — scroll to confirm
      // they survived the merge (and that the sheet is not truncated).
      await tester.scrollUntilVisible(
        find.text('VERSI 1.0.91 (BUILD 126)'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      expect(find.text('VERSI 1.0.91 (BUILD 126)'), findsOneWidget);

      // Non-standard KBBI spellings must not survive in the changelog copy.
      expect(find.textContaining('Pulasan'), findsNothing);
      expect(find.textContaining('Pulsan'), findsNothing);
    });
  });
}
