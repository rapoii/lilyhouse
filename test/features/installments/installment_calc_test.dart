import 'package:flutter_test/flutter_test.dart';
import 'package:lilyhouse/features/installments/domain/installment.dart';
import 'package:lilyhouse/features/installments/domain/installment_log.dart';

void main() {
  group('Installment Domain Model & Calculation Tests', () {
    test('Calculates remaining balance and progress percentage accurately', () {
      final installment = Installment(
        id: 'inst-1',
        itemName: 'Raiden Shogun Cosplay Complete Set',
        storeName: 'Taobao Dokidoki',
        totalCost: 1000000.0,
        totalPaid: 400000.0,
        dueDate: DateTime(2026, 9, 30),
        status: InstallmentStatus.ongoing,
      );

      expect(installment.remainingBalance, equals(600000.0));
      expect(installment.progress, closeTo(0.4, 0.001));
      expect(installment.isPaidOff, isFalse);
    });

    test('Progress is 1.0 and isPaidOff is true when totalPaid equals totalCost', () {
      final installment = Installment(
        id: 'inst-2',
        itemName: 'Furina Wig & Shoes',
        storeName: 'Shopee Official',
        totalCost: 500000.0,
        totalPaid: 500000.0,
        status: InstallmentStatus.paidOff,
      );

      expect(installment.remainingBalance, equals(0.0));
      expect(installment.progress, equals(1.0));
      expect(installment.isPaidOff, isTrue);
    });

    test('Handles zero totalCost gracefully without division by zero', () {
      final installment = Installment(
        id: 'inst-3',
        itemName: 'Free Gift',
        totalCost: 0.0,
        totalPaid: 0.0,
      );

      expect(installment.remainingBalance, equals(0.0));
      expect(installment.progress, equals(0.0));
    });

    test('recalculateWithLogs updates totalPaid, remainingBalance, and status correctly', () {
      final base = Installment(
        id: 'inst-4',
        itemName: 'Hutao Staff of Homa Prop',
        storeName: 'Taobao Shop',
        totalCost: 800000.0,
        totalPaid: 0.0,
        status: InstallmentStatus.ongoing,
      );

      final logs = [
        InstallmentLog(
          id: 'log-1',
          installmentId: 'inst-4',
          paymentDate: DateTime(2026, 8, 1),
          amountPaid: 300000.0,
          notes: 'DP 1',
        ),
        InstallmentLog(
          id: 'log-2',
          installmentId: 'inst-4',
          paymentDate: DateTime(2026, 8, 15),
          amountPaid: 500000.0,
          notes: 'Pelunasan',
        ),
      ];

      final updated = base.recalculateWithLogs(logs);

      expect(updated.totalPaid, equals(800000.0));
      expect(updated.remainingBalance, equals(0.0));
      expect(updated.progress, equals(1.0));
      expect(updated.isPaidOff, isTrue);
      expect(updated.status, equals(InstallmentStatus.paidOff));
    });

    test('SQLite serialization and deserialization works correctly', () {
      final installment = Installment(
        id: 'inst-5',
        itemName: 'Kafka Coat',
        storeName: 'AliExpress',
        totalCost: 750000.0,
        totalPaid: 250000.0,
        remainingBalance: 500000.0,
        dueDate: DateTime(2026, 10, 15),
        status: InstallmentStatus.ongoing,
        syncStatus: 'pending',
      );

      final map = installment.toSqlite();
      expect(map['id'], equals('inst-5'));
      expect(map['item_name'], equals('Kafka Coat'));
      expect(map['store_name'], equals('AliExpress'));
      expect(map['total_cost'], equals(750000.0));
      expect(map['total_paid'], equals(250000.0));
      expect(map['remaining_balance'], equals(500000.0));
      expect(map['due_date'], equals('2026-10-15T00:00:00.000'));
      expect(map['status'], equals('ongoing'));
      expect(map['sync_status'], equals('pending'));

      final fromMap = Installment.fromSqlite(map);
      expect(fromMap.id, equals(installment.id));
      expect(fromMap.itemName, equals(installment.itemName));
      expect(fromMap.storeName, equals(installment.storeName));
      expect(fromMap.totalCost, equals(installment.totalCost));
      expect(fromMap.totalPaid, equals(installment.totalPaid));
      expect(fromMap.remainingBalance, equals(installment.remainingBalance));
      expect(fromMap.dueDate, equals(installment.dueDate));
      expect(fromMap.status, equals(installment.status));
      expect(fromMap.syncStatus, equals(installment.syncStatus));
    });

    test('InstallmentLog SQLite serialization and deserialization works correctly', () {
      final log = InstallmentLog(
        id: 'log-10',
        installmentId: 'inst-5',
        paymentDate: DateTime(2026, 9, 4, 14, 30),
        amountPaid: 150000.0,
        proofPhotoUrl: 'https://example.com/proof.jpg',
        notes: 'Transfer BCA',
        syncStatus: 'pending',
      );

      final map = log.toSqlite();
      expect(map['id'], equals('log-10'));
      expect(map['installment_id'], equals('inst-5'));
      expect(map['payment_date'], equals('2026-09-04T14:30:00.000'));
      expect(map['amount_paid'], equals(150000.0));
      expect(map['proof_photo_url'], equals('https://example.com/proof.jpg'));
      expect(map['notes'], equals('Transfer BCA'));
      expect(map['sync_status'], equals('pending'));

      final fromMap = InstallmentLog.fromSqlite(map);
      expect(fromMap.id, equals(log.id));
      expect(fromMap.installmentId, equals(log.installmentId));
      expect(fromMap.paymentDate, equals(log.paymentDate));
      expect(fromMap.amountPaid, equals(log.amountPaid));
      expect(fromMap.proofPhotoUrl, equals(log.proofPhotoUrl));
      expect(fromMap.notes, equals(log.notes));
      expect(fromMap.syncStatus, equals(log.syncStatus));
    });
  });
}
