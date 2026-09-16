import 'package:flutter_test/flutter_test.dart';
import 'package:lilyhouse/features/costumes/domain/costume_rental_history.dart';
import 'package:lilyhouse/features/rentals/domain/rental.dart';

void main() {
  group('CostumeRentalRecord', () {
    test('fromJoinRow parses a JOIN row with all fields populated', () {
      final record = CostumeRentalRecord.fromJoinRow({
        'rental_id': 'rent-1',
        'customer_id': 'cust-1',
        'customer_name': 'Alya Rani',
        'start_date': '2026-09-10T00:00:00.000Z',
        'end_date': '2026-09-13T00:00:00.000Z',
        'item_status': 'completed',
      });

      expect(record.rentalId, 'rent-1');
      expect(record.customerId, 'cust-1');
      expect(record.customerName, 'Alya Rani');
      expect(record.startDate, DateTime.parse('2026-09-10T00:00:00.000Z'));
      expect(record.endDate, DateTime.parse('2026-09-13T00:00:00.000Z'));
      expect(record.itemStatus, RentalItemStatus.completed);
    });

    test('fromJoinRow falls back to safe defaults for a missing customer', () {
      final record = CostumeRentalRecord.fromJoinRow({
        'rental_id': 'rent-2',
        'customer_id': 'cust-2',
        // LEFT JOIN yields NULL customer_name when the customer row is gone
        'customer_name': null,
        'start_date': '2026-09-01T00:00:00.000Z',
        'end_date': '2026-09-04T00:00:00.000Z',
        'item_status': 'rented',
      });

      expect(record.customerName, 'Penyewa Tidak Diketahui');
      expect(record.itemStatus, RentalItemStatus.rented);
    });

    test('fromJoinRow recovers from a corrupt/unparseable date', () {
      final record = CostumeRentalRecord.fromJoinRow({
        'rental_id': 'rent-3',
        'customer_id': 'cust-3',
        'customer_name': 'Budi',
        'start_date': 'not-a-date',
        'end_date': null,
        'item_status': 'booked',
      });

      // Falls back to epoch instead of throwing
      expect(record.startDate, DateTime.fromMillisecondsSinceEpoch(0));
      expect(record.endDate, DateTime.fromMillisecondsSinceEpoch(0));
    });

    test('isActive is true only for in-progress lifecycle states', () {
      final inProgress = <RentalItemStatus>[
        RentalItemStatus.booked,
        RentalItemStatus.shipped,
        RentalItemStatus.rented,
        RentalItemStatus.laundry,
      ];
      final finished = <RentalItemStatus>[
        RentalItemStatus.returned,
        RentalItemStatus.completed,
        RentalItemStatus.cancelled,
      ];

      for (final s in inProgress) {
        expect(
          CostumeRentalRecord(
            rentalId: 'r',
            customerId: 'c',
            customerName: 'n',
            startDate: DateTime(2026, 9, 1),
            endDate: DateTime(2026, 9, 3),
            itemStatus: s,
          ).isActive,
          isTrue,
          reason: '$s should count as active',
        );
      }
      for (final s in finished) {
        expect(
          CostumeRentalRecord(
            rentalId: 'r',
            customerId: 'c',
            customerName: 'n',
            startDate: DateTime(2026, 9, 1),
            endDate: DateTime(2026, 9, 3),
            itemStatus: s,
          ).isActive,
          isFalse,
          reason: '$s should NOT count as active',
        );
      }
    });

    test('coversDate is inclusive of both start and end bounds', () {
      final record = CostumeRentalRecord(
        rentalId: 'r',
        customerId: 'c',
        customerName: 'n',
        startDate: DateTime(2026, 9, 10),
        endDate: DateTime(2026, 9, 15),
        itemStatus: RentalItemStatus.rented,
      );

      expect(record.coversDate(DateTime(2026, 9, 9)), isFalse);
      expect(record.coversDate(DateTime(2026, 9, 10)), isTrue);
      expect(record.coversDate(DateTime(2026, 9, 12, 14, 30)), isTrue);
      expect(record.coversDate(DateTime(2026, 9, 15)), isTrue);
      expect(record.coversDate(DateTime(2026, 9, 16)), isFalse);
    });

    test('coversDate handles a reversed (start after end) date pair', () {
      final record = CostumeRentalRecord(
        rentalId: 'r',
        customerId: 'c',
        customerName: 'n',
        startDate: DateTime(2026, 9, 15),
        endDate: DateTime(2026, 9, 10),
        itemStatus: RentalItemStatus.rented,
      );

      // Must not crash or mislead the UI; reversed range covers nothing
      expect(record.coversDate(DateTime(2026, 9, 12)), isFalse);
    });
  });

  group('CostumeRentalHistory', () {
    test('defaults represent a never-rented costume', () {
      const history = CostumeRentalHistory();

      expect(history.totalRentals, 0);
      expect(history.activeRentals, 0);
      expect(history.lastServiceDate, isNull);
      expect(history.activeRental, isNull);
      expect(history.records, isEmpty);
      expect(history.hasHistory, isFalse);
      expect(history.badgeLabel, 'Disewa 0 kali');
    });

    test('badgeLabel reflects the total rental count', () {
      const history = CostumeRentalHistory(totalRentals: 7);
      expect(history.badgeLabel, 'Disewa 7 kali');
    });

    test('hasHistory is true when any rental has been counted', () {
      const active = CostumeRentalHistory(activeRentals: 1);
      expect(active.hasHistory, isTrue);
    });

    test('copyWith preserves untouched fields', () {
      final base = CostumeRentalHistory(
        totalRentals: 3,
        activeRentals: 1,
        lastServiceDate: DateTime(2026, 8, 1),
        records: [
          CostumeRentalRecord(
            rentalId: 'r1',
            customerId: 'c1',
            customerName: 'Alya',
            startDate: DateTime(2026, 8, 1),
            endDate: DateTime(2026, 8, 4),
            itemStatus: RentalItemStatus.completed,
          ),
        ],
      );

      final updated = base.copyWith(totalRentals: 4);

      expect(updated.totalRentals, 4);
      expect(updated.activeRentals, 1);
      expect(updated.lastServiceDate, DateTime(2026, 8, 1));
      expect(updated.records, hasLength(1));
      expect(updated.records.first.customerName, 'Alya');
    });
  });
}
