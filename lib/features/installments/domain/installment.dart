import 'installment_log.dart';

enum InstallmentStatus {
  ongoing,
  paidOff;

  static InstallmentStatus fromString(String value) {
    switch (value.toLowerCase().replaceAll('_', '')) {
      case 'paidoff':
      case 'paid':
      case 'lunas':
        return InstallmentStatus.paidOff;
      case 'ongoing':
      case 'active':
      case 'cicilan':
      default:
        return InstallmentStatus.ongoing;
    }
  }

  String toSqliteString() {
    switch (this) {
      case InstallmentStatus.ongoing:
        return 'ongoing';
      case InstallmentStatus.paidOff:
        return 'paid_off';
    }
  }
}

class Installment {
  final String id;
  final String itemName;
  final String? storeName;
  final double totalCost;
  final double totalPaid;
  final double remainingBalance;
  final DateTime? dueDate;
  final InstallmentStatus status;
  final String syncStatus;

  Installment({
    required this.id,
    required this.itemName,
    this.storeName,
    required this.totalCost,
    this.totalPaid = 0.0,
    double? remainingBalance,
    this.dueDate,
    InstallmentStatus? status,
    this.syncStatus = 'pending',
  })  : remainingBalance = remainingBalance ?? ((totalCost - totalPaid) > 0 ? (totalCost - totalPaid) : 0.0),
        status = status ?? (totalPaid >= totalCost && totalCost > 0 ? InstallmentStatus.paidOff : InstallmentStatus.ongoing);

  double get progress {
    if (totalCost <= 0) return 0.0;
    final p = totalPaid / totalCost;
    if (p > 1.0) return 1.0;
    if (p < 0.0) return 0.0;
    return p;
  }

  bool get isPaidOff => remainingBalance <= 0 && totalPaid >= totalCost && totalCost > 0;

  Installment recalculateWithLogs(List<InstallmentLog> logs) {
    final newTotalPaid = logs.fold<double>(0.0, (sum, log) => sum + log.amountPaid);
    final newRemaining = (totalCost - newTotalPaid) > 0 ? (totalCost - newTotalPaid) : 0.0;
    final newStatus = (newRemaining == 0.0 && totalCost > 0) ? InstallmentStatus.paidOff : InstallmentStatus.ongoing;

    return copyWith(
      totalPaid: newTotalPaid,
      remainingBalance: newRemaining,
      status: newStatus,
    );
  }

  Installment copyWith({
    String? id,
    String? itemName,
    String? storeName,
    double? totalCost,
    double? totalPaid,
    double? remainingBalance,
    DateTime? dueDate,
    InstallmentStatus? status,
    String? syncStatus,
  }) {
    return Installment(
      id: id ?? this.id,
      itemName: itemName ?? this.itemName,
      storeName: storeName ?? this.storeName,
      totalCost: totalCost ?? this.totalCost,
      totalPaid: totalPaid ?? this.totalPaid,
      remainingBalance: remainingBalance ?? this.remainingBalance,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  Map<String, dynamic> toSqlite() {
    return {
      'id': id,
      'item_name': itemName,
      'store_name': storeName,
      'total_cost': totalCost,
      'total_paid': totalPaid,
      'remaining_balance': remainingBalance,
      'due_date': dueDate?.toIso8601String(),
      'status': status == InstallmentStatus.paidOff ? 'paid_off' : 'ongoing',
      'sync_status': syncStatus,
    };
  }

  factory Installment.fromSqlite(Map<String, dynamic> map) {
    return Installment(
      id: map['id'] as String,
      itemName: map['item_name'] as String,
      storeName: map['store_name'] as String?,
      totalCost: (map['total_cost'] as num).toDouble(),
      totalPaid: (map['total_paid'] as num).toDouble(),
      remainingBalance: (map['remaining_balance'] as num).toDouble(),
      dueDate: map['due_date'] != null ? DateTime.parse(map['due_date'] as String) : null,
      status: InstallmentStatus.fromString(map['status'] as String),
      syncStatus: (map['sync_status'] as String?) ?? 'pending',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Installment &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          itemName == other.itemName &&
          storeName == other.storeName &&
          totalCost == other.totalCost &&
          totalPaid == other.totalPaid &&
          remainingBalance == other.remainingBalance &&
          dueDate == other.dueDate &&
          status == other.status &&
          syncStatus == other.syncStatus;

  @override
  int get hashCode =>
      id.hashCode ^
      itemName.hashCode ^
      storeName.hashCode ^
      totalCost.hashCode ^
      totalPaid.hashCode ^
      remainingBalance.hashCode ^
      dueDate.hashCode ^
      status.hashCode ^
      syncStatus.hashCode;
}
