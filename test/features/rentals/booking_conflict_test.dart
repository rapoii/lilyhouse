import 'package:flutter_test/flutter_test.dart';
import 'package:lilyhouse/features/rentals/domain/booking_conflict_engine.dart';
import 'package:lilyhouse/features/rentals/domain/rental.dart';

void main() {
  group('Booking Conflict Detection Engine (Rentals Domain)', () {
    final existingBooking = Rental(
      id: 'booking_1',
      costumeId: 'genshin_furina',
      customerId: 'cust_a',
      startDate: DateTime(2026, 9, 10),
      endDate: DateTime(2026, 9, 12),
      durationDays: 3,
      purpose: 'event',
      totalPrice: 180000.0,
      itemStatus: RentalItemStatus.booked,
    );

    test('two bookings for the same costume overlapping dates must trigger conflict', () {
      final overlappingCandidate = Rental(
        id: 'booking_candidate',
        costumeId: 'genshin_furina',
        customerId: 'cust_b',
        startDate: DateTime(2026, 9, 11),
        endDate: DateTime(2026, 9, 13),
        durationDays: 3,
        purpose: 'photoshoot',
        totalPrice: 180000.0,
      );

      final hasConflict = BookingConflictEngine.hasConflict([existingBooking], overlappingCandidate);
      expect(hasConflict, isTrue);

      final conflicts = BookingConflictEngine.findConflicts([existingBooking], overlappingCandidate);
      expect(conflicts.length, 1);
      expect(conflicts.first.id, 'booking_1');
    });

    test('different dates for same costume do not trigger conflict', () {
      final nonOverlappingCandidate = Rental(
        id: 'booking_candidate_ok',
        costumeId: 'genshin_furina',
        customerId: 'cust_c',
        startDate: DateTime(2026, 9, 13),
        endDate: DateTime(2026, 9, 15),
        durationDays: 3,
        purpose: 'photoshoot',
        totalPrice: 180000.0,
      );

      final hasConflict = BookingConflictEngine.hasConflict([existingBooking], nonOverlappingCandidate);
      expect(hasConflict, isFalse);
    });

    test('same dates for different costume do not trigger conflict', () {
      final differentCostumeCandidate = Rental(
        id: 'booking_other_costume',
        costumeId: 'genshin_citlali',
        customerId: 'cust_d',
        startDate: DateTime(2026, 9, 10),
        endDate: DateTime(2026, 9, 12),
        durationDays: 3,
        purpose: 'event',
        totalPrice: 150000.0,
      );

      final hasConflict = BookingConflictEngine.hasConflict([existingBooking], differentCostumeCandidate);
      expect(hasConflict, isFalse);
    });
  });
}
