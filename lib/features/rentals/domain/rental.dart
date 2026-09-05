enum RentalPaymentStatus {
  unpaid,
  dpPaid,
  paid,
  refunded;

  static RentalPaymentStatus fromString(String value) {
    switch (value.toLowerCase().replaceAll('_', '')) {
      case 'unpaid':
        return RentalPaymentStatus.unpaid;
      case 'dppaid':
      case 'dp':
        return RentalPaymentStatus.dpPaid;
      case 'paid':
        return RentalPaymentStatus.paid;
      case 'refunded':
        return RentalPaymentStatus.refunded;
      default:
        return RentalPaymentStatus.unpaid;
    }
  }

  String toSqliteString() {
    switch (this) {
      case RentalPaymentStatus.unpaid:
        return 'unpaid';
      case RentalPaymentStatus.dpPaid:
        return 'dp_paid';
      case RentalPaymentStatus.paid:
        return 'paid';
      case RentalPaymentStatus.refunded:
        return 'refunded';
    }
  }
}

enum RentalItemStatus {
  booked,
  shipped,
  rented,
  returned,
  laundry,
  completed,
  cancelled;

  static RentalItemStatus fromString(String value) {
    switch (value.toLowerCase().replaceAll('_', '')) {
      case 'booked':
        return RentalItemStatus.booked;
      case 'shipped':
        return RentalItemStatus.shipped;
      case 'rented':
        return RentalItemStatus.rented;
      case 'returned':
        return RentalItemStatus.returned;
      case 'laundry':
        return RentalItemStatus.laundry;
      case 'completed':
        return RentalItemStatus.completed;
      case 'cancelled':
        return RentalItemStatus.cancelled;
      default:
        return RentalItemStatus.booked;
    }
  }

  String toSqliteString() {
    switch (this) {
      case RentalItemStatus.booked:
        return 'booked';
      case RentalItemStatus.shipped:
        return 'shipped';
      case RentalItemStatus.rented:
        return 'rented';
      case RentalItemStatus.returned:
        return 'returned';
      case RentalItemStatus.laundry:
        return 'laundry';
      case RentalItemStatus.completed:
        return 'completed';
      case RentalItemStatus.cancelled:
        return 'cancelled';
    }
  }
}

class Rental {
  final String id;
  final String costumeId;
  final String customerId;
  final DateTime startDate;
  final DateTime endDate;
  final int durationDays;
  final String purpose;
  final double totalPrice;
  final double dpAmount;
  final RentalPaymentStatus paymentStatus;
  final RentalItemStatus itemStatus;
  final String? notes;
  final String syncStatus;

  const Rental({
    required this.id,
    required this.costumeId,
    required this.customerId,
    required this.startDate,
    required this.endDate,
    required this.durationDays,
    required this.purpose,
    required this.totalPrice,
    this.dpAmount = 0.0,
    this.paymentStatus = RentalPaymentStatus.unpaid,
    this.itemStatus = RentalItemStatus.booked,
    this.notes,
    this.syncStatus = 'pending',
  });

  Map<String, dynamic> toSqlite() {
    return {
      'id': id,
      'costume_id': costumeId,
      'customer_id': customerId,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'duration_days': durationDays,
      'purpose': purpose,
      'total_price': totalPrice,
      'dp_amount': dpAmount,
      'payment_status': paymentStatus.toSqliteString(),
      'item_status': itemStatus.toSqliteString(),
      'notes': notes,
      'sync_status': syncStatus,
    };
  }

  factory Rental.fromSqlite(Map<String, dynamic> map) {
    return Rental(
      id: map['id'] as String,
      costumeId: map['costume_id'] as String,
      customerId: map['customer_id'] as String,
      startDate: DateTime.parse(map['start_date'] as String),
      endDate: DateTime.parse(map['end_date'] as String),
      durationDays: (map['duration_days'] as num).toInt(),
      purpose: map['purpose'] as String? ?? 'homecos',
      totalPrice: (map['total_price'] as num?)?.toDouble() ?? 0.0,
      dpAmount: (map['dp_amount'] as num?)?.toDouble() ?? 0.0,
      paymentStatus: RentalPaymentStatus.fromString(map['payment_status'] as String? ?? 'unpaid'),
      itemStatus: RentalItemStatus.fromString(map['item_status'] as String? ?? 'booked'),
      notes: map['notes'] as String?,
      syncStatus: map['sync_status'] as String? ?? 'pending',
    );
  }

  Rental copyWith({
    String? id,
    String? costumeId,
    String? customerId,
    DateTime? startDate,
    DateTime? endDate,
    int? durationDays,
    String? purpose,
    double? totalPrice,
    double? dpAmount,
    RentalPaymentStatus? paymentStatus,
    RentalItemStatus? itemStatus,
    String? notes,
    String? syncStatus,
  }) {
    return Rental(
      id: id ?? this.id,
      costumeId: costumeId ?? this.costumeId,
      customerId: customerId ?? this.customerId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      durationDays: durationDays ?? this.durationDays,
      purpose: purpose ?? this.purpose,
      totalPrice: totalPrice ?? this.totalPrice,
      dpAmount: dpAmount ?? this.dpAmount,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      itemStatus: itemStatus ?? this.itemStatus,
      notes: notes ?? this.notes,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}
