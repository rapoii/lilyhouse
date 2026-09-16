import 'package:flutter_test/flutter_test.dart';
import 'package:lilyhouse/features/installments/domain/installment.dart';
import 'package:lilyhouse/features/installments/domain/installment_log.dart';

void main() {
  final today = DateTime(2026, 9, 16);

  Installment ongoing({
    required String id,
    DateTime? dueDate,
    double totalPaid = 400000.0,
  }) =>
      Installment(
        id: id,
        itemName: 'Raiden Shogun Cosplay Set',
        storeName: 'Miaowu Cosplay',
        totalCost: 1000000.0,
        totalPaid: totalPaid,
        dueDate: dueDate,
        status: InstallmentStatus.ongoing,
      );

  group('daysUntilDue / dueLabel Tests', () {
    test('Returns null when dueDate is absent', () {
      final inst = ongoing(id: 'a');
      expect(inst.daysUntilDue(now: today), isNull);
      expect(inst.dueLabel(now: today), 'Tanpa jatuh tempo');
    });

    test('Counts whole days, stable throughout the day', () {
      final inst = ongoing(id: 'b', dueDate: DateTime(2026, 9, 25));
      expect(inst.daysUntilDue(now: today), 9);
      // 23:59 on the due day still resolves to the same day boundary.
      expect(
        inst.daysUntilDue(now: DateTime(2026, 9, 25, 23, 59)),
        0,
      );
      expect(inst.dueLabel(now: DateTime(2026, 9, 25)), 'Jatuh tempo hari ini');
    });

    test('Produces pluralized "X hari lagi" labels', () {
      expect(
        ongoing(id: 'c', dueDate: DateTime(2026, 9, 19)).dueLabel(now: today),
        '3 hari lagi',
      );
      expect(
        ongoing(id: 'd', dueDate: DateTime(2026, 9, 17)).dueLabel(now: today),
        '1 hari lagi',
      );
    });

    test('Produces "Terlambat X hari" labels for past due dates', () {
      expect(
        ongoing(id: 'e', dueDate: DateTime(2026, 9, 11)).dueLabel(now: today),
        'Terlambat 5 hari',
      );
      expect(
        ongoing(id: 'f', dueDate: DateTime(2026, 9, 15)).dueLabel(now: today),
        'Terlambat 1 hari',
      );
    });

    test('Paid-off installments always label as Lunas', () {
      final paid = Installment(
        id: 'g',
        itemName: 'Wig',
        totalCost: 500000.0,
        totalPaid: 500000.0,
        dueDate: DateTime(2025, 1, 1),
        status: InstallmentStatus.paidOff,
      );
      expect(paid.dueLabel(now: today), 'Lunas');
      expect(paid.daysUntilDue(now: today), isNotNull);
      expect(paid.isOverdue, isFalse);
      expect(paid.isDueSoon, isFalse);
    });
  });

  group('isOverdue & isDueSoon Tests', () {
    test('isOverdue only when unpaid and past the due date', () {
      expect(ongoing(id: 'h', dueDate: DateTime(2026, 9, 10)).isOverdue, isTrue);
      expect(ongoing(id: 'i', dueDate: DateTime(2026, 9, 16)).isOverdue, isFalse);
      expect(ongoing(id: 'j', dueDate: DateTime(2026, 10, 1)).isOverdue, isFalse);
      expect(ongoing(id: 'k').isOverdue, isFalse,
          reason: 'no due date is never overdue');
    });

    test('isDueSoon covers overdue, today, and <=7 days', () {
      expect(ongoing(id: 'l', dueDate: DateTime(2026, 9, 5)).isDueSoon, isTrue,
          reason: 'already late still counts as due soon');
      expect(ongoing(id: 'm', dueDate: DateTime(2026, 9, 16)).isDueSoon, isTrue);
      expect(ongoing(id: 'n', dueDate: DateTime(2026, 9, 23)).isDueSoon, isTrue);
      expect(ongoing(id: 'o', dueDate: DateTime(2026, 9, 24)).isDueSoon, isFalse,
          reason: '8 days away is outside the window');
      expect(ongoing(id: 'p').isDueSoon, isFalse);
    });

    test('isDueSoon is false when fully paid even if due date passed', () {
      final paid = Installment(
        id: 'q',
        itemName: 'Wig',
        totalCost: 500000.0,
        totalPaid: 500000.0,
        dueDate: DateTime(2025, 1, 1),
        status: InstallmentStatus.paidOff,
      );
      expect(paid.isDueSoon, isFalse);
    });
  });

  group('Running Payment Summary Helpers', () {
    final logs = [
      InstallmentLog(id: 'l1', installmentId: 'x', paymentDate: DateTime(2026, 8, 1), amountPaid: 200000),
      InstallmentLog(id: 'l2', installmentId: 'x', paymentDate: DateTime(2026, 9, 1), amountPaid: 400000),
    ];

    test('averagePayment is totalPaid divided by log count', () {
      final inst = ongoing(id: 'x');
      expect(inst.averagePayment(logs), 300000.0);
      expect(inst.averagePayment(const []), 0.0);
    });

    test('estimatedRemainingPayments rounds up the remaining balance', () {
      final inst = ongoing(id: 'y', dueDate: DateTime(2026, 10, 1));
      // remaining 600000 / avg 300000 = 2
      expect(inst.estimatedRemainingPayments(logs), 2);

      final odd = ongoing(id: 'z', totalPaid: 440000);
      // remaining 560000 / avg 300000 = 1.87 -> 2 (ceil)
      expect(odd.estimatedRemainingPayments(logs), 2);
    });

    test('estimatedRemainingPayments is null without history or when paid off', () {
      expect(ongoing(id: 'aa').estimatedRemainingPayments(const []), isNull);
      final paid = Installment(
        id: 'ab',
        itemName: 'Wig',
        totalCost: 1000000.0,
        totalPaid: 1000000.0,
        status: InstallmentStatus.paidOff,
      );
      expect(paid.estimatedRemainingPayments(logs), isNull);
    });
  });
}
