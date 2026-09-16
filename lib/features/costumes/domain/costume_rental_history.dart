import '../../rentals/domain/rental.dart';

/// Reads-only snapshot of one renter's rental of a costume, used for the
/// "RIWAYAT SEWA" tracking section in CostumeDetailScreen.
class CostumeRentalRecord {
  final String rentalId;
  final String customerId;
  final String customerName;
  final DateTime startDate;
  final DateTime endDate;
  final RentalItemStatus itemStatus;

  const CostumeRentalRecord({
    required this.rentalId,
    required this.customerId,
    required this.customerName,
    required this.startDate,
    required this.endDate,
    required this.itemStatus,
  });

  factory CostumeRentalRecord.fromJoinRow(Map<String, dynamic> row) {
    final rawStart = row['start_date'] as String? ?? '';
    final rawEnd = row['end_date'] as String? ?? '';
    DateTime tryParse(Object? v) {
      if (v is DateTime) return v;
      final s = v?.toString() ?? '';
      return DateTime.tryParse(s) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }

    return CostumeRentalRecord(
      rentalId: row['rental_id']?.toString() ?? '',
      customerId: row['customer_id']?.toString() ?? '',
      customerName: row['customer_name']?.toString() ?? 'Penyewa Tidak Diketahui',
      startDate: tryParse(rawStart),
      endDate: tryParse(rawEnd),
      itemStatus: RentalItemStatus.fromString(row['item_status']?.toString() ?? 'booked'),
    );
  }

  /// Whether this rental is in an in-progress lifecycle state
  /// (booked / shipped / rented / laundry) — used for the active-usage badge.
  bool get isActive => itemStatus == RentalItemStatus.booked ||
      itemStatus == RentalItemStatus.shipped ||
      itemStatus == RentalItemStatus.rented ||
      itemStatus == RentalItemStatus.laundry;

  /// Whether [moment] falls inside this rental's date range (inclusive).
  bool coversDate(DateTime moment) {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    final point = DateTime(moment.year, moment.month, moment.day);
    return !point.isBefore(start) && !point.isAfter(end);
  }
}

/// Aggregate rental-history stats for a single costume.
class CostumeRentalHistory {
  /// Total completed-and-counted rental cycles (excludes cancelled).
  final int totalRentals;

  /// Rentals whose lifecycle is still in progress.
  final int activeRentals;

  /// Most recent end_date among counted rentals (null when never rented).
  final DateTime? lastServiceDate;

  /// Currently in-progress rental, if any.
  final CostumeRentalRecord? activeRental;

  /// Renters ordered most-recent-first.
  final List<CostumeRentalRecord> records;

  const CostumeRentalHistory({
    this.totalRentals = 0,
    this.activeRentals = 0,
    this.lastServiceDate,
    this.activeRental,
    this.records = const [],
  });

  bool get hasHistory => totalRentals > 0 || activeRentals > 0;

  String get badgeLabel => 'Disewa $totalRentals kali';

  CostumeRentalHistory copyWith({
    int? totalRentals,
    int? activeRentals,
    DateTime? lastServiceDate,
    CostumeRentalRecord? activeRental,
    List<CostumeRentalRecord>? records,
  }) {
    return CostumeRentalHistory(
      totalRentals: totalRentals ?? this.totalRentals,
      activeRentals: activeRentals ?? this.activeRentals,
      lastServiceDate: lastServiceDate ?? this.lastServiceDate,
      activeRental: activeRental ?? this.activeRental,
      records: records ?? this.records,
    );
  }
}
