import 'package:lilyhouse/features/rentals/domain/rental.dart';

/// Engine responsible for detecting costume booking clashes and overlaps.
class BookingConflictEngine {
  /// Checks whether [candidate] conflicts with any rental in [existingRentals].
  static bool hasConflict(List<Rental> existingRentals, Rental candidate) {
    return findConflicts(existingRentals, candidate).isNotEmpty;
  }

  /// Returns a list of all existing rentals that overlap with [candidate] for the same costume.
  static List<Rental> findConflicts(List<Rental> existingRentals, Rental candidate) {
    final candidateStart = _dateOnly(candidate.startDate);
    final candidateEnd = _dateOnly(candidate.endDate);

    return existingRentals.where((existing) {
      // Ignore itself if editing
      if (existing.id == candidate.id) {
        return false;
      }

      // Ignore cancelled bookings
      if (existing.itemStatus == RentalItemStatus.cancelled) {
        return false;
      }

      // Must be for the exact same costume
      if (existing.costumeId != candidate.costumeId) {
        return false;
      }

      final existingStart = _dateOnly(existing.startDate);
      final existingEnd = _dateOnly(existing.endDate);

      // Two inclusive date intervals [A, B] and [C, D] overlap if A <= D and B >= C
      final overlaps = !candidateStart.isAfter(existingEnd) &&
          !candidateEnd.isBefore(existingStart);

      return overlaps;
    }).toList();
  }

  /// Normalizes DateTime to midnight date-only (year, month, day)
  static DateTime _dateOnly(DateTime dt) {
    return DateTime(dt.year, dt.month, dt.day);
  }
}
