import 'package:flutter_test/flutter_test.dart';
import 'package:lilyhouse/features/calendar/domain/booking_conflict_engine.dart';
import 'package:lilyhouse/features/rentals/domain/rental.dart';

void main() {
  group('BookingConflictEngine', () {
    final existingRental = Rental(
      id: 'rent_existing_1',
      costumeId: 'costume_citlali',
      customerId: 'cust_001',
      startDate: DateTime(2026, 9, 5),
      endDate: DateTime(2026, 9, 7),
      durationDays: 3,
      purpose: 'homecos',
      totalPrice: 150000.0,
      itemStatus: RentalItemStatus.booked,
    );

    test('returns true when candidate overlaps with existing rental for same costume', () {
      final overlappingCandidate = Rental(
        id: 'rent_candidate_1',
        costumeId: 'costume_citlali',
        customerId: 'cust_002',
        startDate: DateTime(2026, 9, 6),
        endDate: DateTime(2026, 9, 8),
        durationDays: 3,
        purpose: 'event',
        totalPrice: 150000.0,
      );

      final hasConflict = BookingConflictEngine.hasConflict([existingRental], overlappingCandidate);
      expect(hasConflict, isTrue);

      final conflicts = BookingConflictEngine.findConflicts([existingRental], overlappingCandidate);
      expect(conflicts.length, 1);
      expect(conflicts.first.id, 'rent_existing_1');
    });

    test('returns false when dates do not overlap', () {
      final nonOverlappingCandidate = Rental(
        id: 'rent_candidate_2',
        costumeId: 'costume_citlali',
        customerId: 'cust_003',
        startDate: DateTime(2026, 9, 8),
        endDate: DateTime(2026, 9, 10),
        durationDays: 3,
        purpose: 'photoshoot',
        totalPrice: 150000.0,
      );

      final hasConflict = BookingConflictEngine.hasConflict([existingRental], nonOverlappingCandidate);
      expect(hasConflict, isFalse);

      final conflicts = BookingConflictEngine.findConflicts([existingRental], nonOverlappingCandidate);
      expect(conflicts, isEmpty);
    });

    test('returns false when costumes are different even if dates overlap', () {
      final differentCostumeCandidate = Rental(
        id: 'rent_candidate_3',
        costumeId: 'costume_furina',
        customerId: 'cust_004',
        startDate: DateTime(2026, 9, 5),
        endDate: DateTime(2026, 9, 7),
        durationDays: 3,
        purpose: 'event',
        totalPrice: 150000.0,
      );

      final hasConflict = BookingConflictEngine.hasConflict([existingRental], differentCostumeCandidate);
      expect(hasConflict, isFalse);
    });

    test('ignores cancelled rentals when detecting conflicts', () {
      final cancelledRental = existingRental.copyWith(
        itemStatus: RentalItemStatus.cancelled,
      );

      final candidate = Rental(
        id: 'rent_candidate_4',
        costumeId: 'costume_citlali',
        customerId: 'cust_005',
        startDate: DateTime(2026, 9, 5),
        endDate: DateTime(2026, 9, 7),
        durationDays: 3,
        purpose: 'event',
        totalPrice: 150000.0,
      );

      final hasConflict = BookingConflictEngine.hasConflict([cancelledRental], candidate);
      expect(hasConflict, isFalse);
    });

    test('ignores self when editing an existing rental (same id)', () {
      final updatedRental = existingRental.copyWith(
        notes: 'Updated notes',
      );

      final hasConflict = BookingConflictEngine.hasConflict([existingRental], updatedRental);
      expect(hasConflict, isFalse);
    });

    test('detects conflict on exact boundary date (candidate starts on existing end date)', () {
      final boundaryCandidate = Rental(
        id: 'rent_candidate_5',
        costumeId: 'costume_citlali',
        customerId: 'cust_006',
        startDate: DateTime(2026, 9, 7),
        endDate: DateTime(2026, 9, 9),
        durationDays: 3,
        purpose: 'event',
        totalPrice: 150000.0,
      );

      final hasConflict = BookingConflictEngine.hasConflict([existingRental], boundaryCandidate);
      expect(hasConflict, isTrue);
    });
  });
}
