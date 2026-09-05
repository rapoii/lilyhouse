import 'package:flutter_test/flutter_test.dart';
import 'package:lilyhouse/core/database/tables.dart';
import 'package:lilyhouse/features/installments/data/installment_repository.dart';
import 'package:lilyhouse/features/installments/domain/installment.dart';
import 'package:lilyhouse/features/installments/domain/installment_log.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database testDb;
  late InstallmentRepository repository;

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
  });

  tearDown(() async {
    await testDb.close();
  });

  group('InstallmentRepository Tests', () {
    final testInstallment = Installment(
      id: 'inst_001',
      itemName: 'Raiden Shogun Fullset',
      storeName: 'Miaowu Cosplay',
      totalCost: 1200000.0,
      totalPaid: 400000.0,
      remainingBalance: 800000.0,
      dueDate: DateTime(2026, 10, 1),
      status: InstallmentStatus.ongoing,
    );

    test('insertInstallment and getInstallmentById succeed', () async {
      await repository.insertInstallment(testInstallment);

      final retrieved = await repository.getInstallmentById('inst_001');
      expect(retrieved, isNotNull);
      expect(retrieved!.itemName, 'Raiden Shogun Fullset');
      expect(retrieved.storeName, 'Miaowu Cosplay');
      expect(retrieved.totalCost, 1200000.0);
      expect(retrieved.totalPaid, 400000.0);
      expect(retrieved.remainingBalance, 800000.0);
      expect(retrieved.status, InstallmentStatus.ongoing);
    });

    test('getAllInstallments & getInstallmentsByStatus filter accurately', () async {
      await repository.insertInstallment(testInstallment);
      await repository.insertInstallment(Installment(
        id: 'inst_002',
        itemName: 'Furina Sword Prop',
        storeName: 'Taobao Dokidoki',
        totalCost: 350000.0,
        totalPaid: 350000.0,
        remainingBalance: 0.0,
        status: InstallmentStatus.paidOff,
      ));

      final all = await repository.getAllInstallments();
      expect(all.length, 2);

      final ongoing = await repository.getInstallmentsByStatus(InstallmentStatus.ongoing);
      expect(ongoing.length, 1);
      expect(ongoing.first.id, 'inst_001');

      final paidOff = await repository.getInstallmentsByStatus(InstallmentStatus.paidOff);
      expect(paidOff.length, 1);
      expect(paidOff.first.id, 'inst_002');
    });

    test('updateInstallment and deleteInstallment work properly', () async {
      await repository.insertInstallment(testInstallment);

      final updated = testInstallment.copyWith(storeName: 'Updated Miaowu');
      await repository.updateInstallment(updated);

      final fetched = await repository.getInstallmentById('inst_001');
      expect(fetched!.storeName, 'Updated Miaowu');

      await repository.deleteInstallment('inst_001');
      final afterDelete = await repository.getInstallmentById('inst_001');
      expect(afterDelete, isNull);
    });

    test('addPaymentLog automatically recalculates and updates installment balance & status', () async {
      final initialInst = Installment(
        id: 'inst_003',
        itemName: 'Kafka Wig & Accessories',
        storeName: 'AliExpress',
        totalCost: 500000.0,
        totalPaid: 0.0,
        remainingBalance: 500000.0,
        status: InstallmentStatus.ongoing,
      );
      await repository.insertInstallment(initialInst);

      final log1 = InstallmentLog(
        id: 'log_001',
        installmentId: 'inst_003',
        paymentDate: DateTime(2026, 9, 1),
        amountPaid: 200000.0,
        notes: 'DP 1 via QRIS',
      );
      await repository.addPaymentLog(log1);

      var inst = await repository.getInstallmentById('inst_003');
      expect(inst!.totalPaid, 200000.0);
      expect(inst.remainingBalance, 300000.0);
      expect(inst.progress, closeTo(0.4, 0.001));
      expect(inst.status, InstallmentStatus.ongoing);

      var logs = await repository.getLogsForInstallment('inst_003');
      expect(logs.length, 1);
      expect(logs.first.id, 'log_001');

      // Pay remainder
      final log2 = InstallmentLog(
        id: 'log_002',
        installmentId: 'inst_003',
        paymentDate: DateTime(2026, 9, 4),
        amountPaid: 300000.0,
        notes: 'Pelunasan transfer Bank',
      );
      await repository.addPaymentLog(log2);

      inst = await repository.getInstallmentById('inst_003');
      expect(inst!.totalPaid, 500000.0);
      expect(inst.remainingBalance, 0.0);
      expect(inst.progress, 1.0);
      expect(inst.isPaidOff, isTrue);
      expect(inst.status, InstallmentStatus.paidOff);

      logs = await repository.getLogsForInstallment('inst_003');
      expect(logs.length, 2);
    });

    test('deletePaymentLog recalculates installment balance correctly', () async {
      final initialInst = Installment(
        id: 'inst_004',
        itemName: 'Yae Miko Boots',
        totalCost: 400000.0,
        totalPaid: 0.0,
        remainingBalance: 400000.0,
      );
      await repository.insertInstallment(initialInst);

      final log = InstallmentLog(
        id: 'log_del',
        installmentId: 'inst_004',
        paymentDate: DateTime(2026, 9, 2),
        amountPaid: 150000.0,
      );
      await repository.addPaymentLog(log);

      var inst = await repository.getInstallmentById('inst_004');
      expect(inst!.totalPaid, 150000.0);

      await repository.deletePaymentLog('log_del', 'inst_004');

      inst = await repository.getInstallmentById('inst_004');
      expect(inst!.totalPaid, 0.0);
      expect(inst.remainingBalance, 400000.0);
      expect(inst.status, InstallmentStatus.ongoing);
    });
  });
}
