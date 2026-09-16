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
  })  : remainingBalance = remainingBalance ?? ((totalCost - totalPaid) > 0.009 ? (totalCost - totalPaid) : 0.0),
        status = status ?? ((totalCost - totalPaid) <= 0.01 && totalCost > 0 ? InstallmentStatus.paidOff : InstallmentStatus.ongoing);

  double get progress {
    if (totalCost <= 0) return 0.0;
    final p = totalPaid / totalCost;
    if (p > 1.0) return 1.0;
    if (p < 0.0) return 0.0;
    return p;
  }

  bool get isPaidOff => remainingBalance <= 0.01 && totalPaid >= (totalCost - 0.01) && totalCost > 0;

  /// Jumlah hari sampai jatuh tempo, dihitung relatif terhadap [now].
  ///
  /// Mengembalikan null bila tanggal jatuh tempo belum ditentukan. Perhitungan
  /// dilakukan pada level hari (tanggal) sehingga stabil sepanjang hari dan
  /// tidak bergantung pada jam menit detik.
  int? daysUntilDue({DateTime? now}) {
    final due = dueDate;
    if (due == null) return null;

    final reference = (now ?? DateTime.now());
    final today = DateTime(reference.year, reference.month, reference.day);
    final dueDay = DateTime(due.year, due.month, due.day);
    return dueDay.difference(today).inDays;
  }

  /// Sudah melewati tanggal jatuh tempo dan masih ada sisa tagihan.
  bool get isOverdue {
    if (isPaidOff) return false;
    final days = daysUntilDue();
    return days != null && days < 0;
  }

  /// Jatuh tempo dalam <=7 hari atau sudah lewat (selama belum lunas).
  bool get isDueSoon => !isPaidOff && (daysUntilDue() ?? 8) <= 7;

  /// Label ramah pengguna untuk remaining waktu sampai jatuh tempo, misalnya
  /// "Jatuh tempo hari ini", "3 hari lagi", atau "Terlambat 5 hari".
  String dueLabel({DateTime? now}) {
    if (isPaidOff) return 'Lunas';
    final days = daysUntilDue(now: now);
    if (days == null) return 'Tanpa jatuh tempo';

    if (days == 0) return 'Jatuh tempo hari ini';
    if (days > 0) return '$days hari lagi';
    final late = -days;
    return late == 1 ? 'Terlambat 1 hari' : 'Terlambat $late hari';
  }

  /// Rata-rata pembayaran per transaksi berdasarkan [logs]. Mengembalikan 0
  /// bila belum ada catatan pembayaran.
  double averagePayment(List<InstallmentLog> logs) {
    if (logs.isEmpty) return 0.0;
    final total = logs.fold<double>(0.0, (sum, log) => sum + log.amountPaid);
    return total / logs.length;
  }

  /// Estimasi jumlah cicilan tersisa dengan asumsi pembayaran rata-rata
  /// berjalan. Mengembalikan null bila belum ada riwayat pembayaran.
  int? estimatedRemainingPayments(List<InstallmentLog> logs) {
    if (logs.isEmpty || isPaidOff) return null;
    final avg = averagePayment(logs);
    if (avg <= 0) return null;
    return (remainingBalance / avg).ceil();
  }

  Installment recalculateWithLogs(List<InstallmentLog> logs) {
    final newTotalPaid = logs.fold<double>(0.0, (sum, log) => sum + log.amountPaid);
    final rawRemaining = totalCost - newTotalPaid;
    final newRemaining = rawRemaining > 0.009 ? rawRemaining : 0.0;
    final newStatus = (newRemaining <= 0.01 && totalCost > 0) ? InstallmentStatus.paidOff : InstallmentStatus.ongoing;

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
    bool clearDueDate = false,
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
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
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
      dueDate: (map['due_date'] == null || (map['due_date'] as String).trim().isEmpty)
          ? null
          : DateTime.parse(map['due_date'] as String),
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
