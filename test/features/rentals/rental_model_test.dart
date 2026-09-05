import 'package:flutter_test/flutter_test.dart';
import 'package:lilyhouse/features/rentals/domain/rental.dart';

void main() {
  group('Rental Model', () {
    final rental = Rental(
      id: 'rent_001',
      costumeId: 'costume_citlali',
      customerId: 'cust_001',
      startDate: DateTime(2026, 9, 5),
      endDate: DateTime(2026, 9, 7),
      durationDays: 3,
      purpose: 'homecos',
      totalPrice: 150000.0,
      dpAmount: 50000.0,
      paymentStatus: RentalPaymentStatus.dpPaid,
      itemStatus: RentalItemStatus.booked,
      notes: 'Harap packing rapi',
      syncStatus: 'synced',
    );

    test('instantiates with proper default values and fields', () {
      expect(rental.id, 'rent_001');
      expect(rental.costumeId, 'costume_citlali');
      expect(rental.customerId, 'cust_001');
      expect(rental.startDate, DateTime(2026, 9, 5));
      expect(rental.endDate, DateTime(2026, 9, 7));
      expect(rental.durationDays, 3);
      expect(rental.purpose, 'homecos');
      expect(rental.totalPrice, 150000.0);
      expect(rental.dpAmount, 50000.0);
      expect(rental.paymentStatus, RentalPaymentStatus.dpPaid);
      expect(rental.itemStatus, RentalItemStatus.booked);
      expect(rental.notes, 'Harap packing rapi');
      expect(rental.syncStatus, 'synced');
    });

    test('toSqlite serializes dates and enums properly', () {
      final map = rental.toSqlite();
      expect(map['id'], 'rent_001');
      expect(map['costume_id'], 'costume_citlali');
      expect(map['customer_id'], 'cust_001');
      expect(map['start_date'], '2026-09-05T00:00:00.000');
      expect(map['end_date'], '2026-09-07T00:00:00.000');
      expect(map['duration_days'], 3);
      expect(map['purpose'], 'homecos');
      expect(map['total_price'], 150000.0);
      expect(map['dp_amount'], 50000.0);
      expect(map['payment_status'], 'dp_paid');
      expect(map['item_status'], 'booked');
      expect(map['notes'], 'Harap packing rapi');
      expect(map['sync_status'], 'synced');
    });

    test('fromSqlite parses database map correctly', () {
      final map = {
        'id': 'rent_002',
        'costume_id': 'costume_furina',
        'customer_id': 'cust_002',
        'start_date': '2026-09-10T00:00:00.000',
        'end_date': '2026-09-12T00:00:00.000',
        'duration_days': 3,
        'purpose': 'event',
        'total_price': 180000.0,
        'dp_amount': 180000.0,
        'payment_status': 'paid',
        'item_status': 'rented',
        'notes': null,
        'sync_status': 'pending',
      };

      final parsed = Rental.fromSqlite(map);
      expect(parsed.id, 'rent_002');
      expect(parsed.costumeId, 'costume_furina');
      expect(parsed.customerId, 'cust_002');
      expect(parsed.startDate, DateTime(2026, 9, 10));
      expect(parsed.endDate, DateTime(2026, 9, 12));
      expect(parsed.durationDays, 3);
      expect(parsed.purpose, 'event');
      expect(parsed.totalPrice, 180000.0);
      expect(parsed.dpAmount, 180000.0);
      expect(parsed.paymentStatus, RentalPaymentStatus.paid);
      expect(parsed.itemStatus, RentalItemStatus.rented);
      expect(parsed.notes, isNull);
      expect(parsed.syncStatus, 'pending');
    });

    test('copyWith properly duplicates and modifies Rental', () {
      final updated = rental.copyWith(
        itemStatus: RentalItemStatus.returned,
        paymentStatus: RentalPaymentStatus.paid,
      );
      expect(updated.id, rental.id);
      expect(updated.itemStatus, RentalItemStatus.returned);
      expect(updated.paymentStatus, RentalPaymentStatus.paid);
      expect(updated.costumeId, rental.costumeId);
    });
  });
}
