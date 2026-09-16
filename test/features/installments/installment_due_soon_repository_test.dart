import 'package:flutter_test/flutter_test.dart';
import 'package:lilyhouse/core/database/tables.dart';
import 'package:lilyhouse/features/installments/data/installment_repository.dart';
import 'package:lilyhouse/features/installments/domain/installment.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database testDb;
  late InstallmentRepository repository;

  final now = DateTime(2026, 9, 16, 12, 0, 0);

  setUp(() async {
    testDb = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute(AppTables.createInstallments);
          await db.execute(AppTables.createInstallmentLogs);
          await db.execute(AppTables.createSyncQueue);
        },
      ),
    );
    repository = InstallmentRepository(db: testDb);

    Future<void> seed(String id, DateTime? dueDate, {double? paid}) async {
      await repository.insertInstallment(
        Installment(
          id: id,
          itemName: 'Item $id',
          totalCost: 1000000.0,
          totalPaid: paid ?? 0.0,
          dueDate: dueDate,
          status: (paid ?? 0.0) >= 1000000.0
              ? InstallmentStatus.paidOff
              : InstallmentStatus.ongoing,
        ),
      );
    }

    await seed('overdue', DateTime(2026, 9, 10)); // 6 days late
    await seed('today', DateTime(2026, 9, 16)); // due today
    await seed('in_3_days', DateTime(2026, 9, 19));
    await seed('in_7_days', DateTime(2026, 9, 23)); // boundary, inclusive
    await seed('in_8_days', DateTime(2026, 9, 24)); // just outside
    await seed('far', DateTime(2027, 1, 1));
    await seed('no_date', null);
    await seed('paid_off_late', DateTime(2020, 1, 1), paid: 1000000.0);
  });

  tearDown(() async {
    await testDb.close();
  });

  group('searchInstallments dueSoon filter', () {
    test('Returns only unpaid items due within 7 days (including overdue)', () async {
      final results = await repository.searchInstallments(
        dueSoon: true,
        now: now,
      );

      final ids = results.map((i) => i.id).toSet();
      expect(ids, {'overdue', 'today', 'in_3_days', 'in_7_days'});
      expect(ids, isNot(contains('in_8_days')));
      expect(ids, isNot(contains('far')));
      expect(ids, isNot(contains('no_date')));
      expect(ids, isNot(contains('paid_off_late')),
          reason: 'paid off items never count as due soon');
    });

    test('dueSoon composes with a status filter and a query', () async {
      final results = await repository.searchInstallments(
        dueSoon: true,
        status: InstallmentStatus.ongoing,
        query: 'in_',
        now: now,
      );

      final ids = results.map((i) => i.id).toSet();
      expect(ids, {'in_3_days', 'in_7_days'});
    });

    test('dueSoon is a no-op when disabled', () async {
      final all = await repository.searchInstallments(now: now);
      expect(all.length, 8);
    });
  });
}
