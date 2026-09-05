class InstallmentLog {
  final String id;
  final String installmentId;
  final DateTime paymentDate;
  final double amountPaid;
  final String? proofPhotoUrl;
  final String? notes;
  final String syncStatus;

  const InstallmentLog({
    required this.id,
    required this.installmentId,
    required this.paymentDate,
    required this.amountPaid,
    this.proofPhotoUrl,
    this.notes,
    this.syncStatus = 'pending',
  });

  InstallmentLog copyWith({
    String? id,
    String? installmentId,
    DateTime? paymentDate,
    double? amountPaid,
    String? proofPhotoUrl,
    String? notes,
    String? syncStatus,
  }) {
    return InstallmentLog(
      id: id ?? this.id,
      installmentId: installmentId ?? this.installmentId,
      paymentDate: paymentDate ?? this.paymentDate,
      amountPaid: amountPaid ?? this.amountPaid,
      proofPhotoUrl: proofPhotoUrl ?? this.proofPhotoUrl,
      notes: notes ?? this.notes,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  Map<String, dynamic> toSqlite() {
    return {
      'id': id,
      'installment_id': installmentId,
      'payment_date': paymentDate.toIso8601String(),
      'amount_paid': amountPaid,
      'proof_photo_url': proofPhotoUrl,
      'notes': notes,
      'sync_status': syncStatus,
    };
  }

  factory InstallmentLog.fromSqlite(Map<String, dynamic> map) {
    return InstallmentLog(
      id: map['id'] as String,
      installmentId: map['installment_id'] as String,
      paymentDate: DateTime.parse(map['payment_date'] as String),
      amountPaid: (map['amount_paid'] as num).toDouble(),
      proofPhotoUrl: map['proof_photo_url'] as String?,
      notes: map['notes'] as String?,
      syncStatus: (map['sync_status'] as String?) ?? 'pending',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InstallmentLog &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          installmentId == other.installmentId &&
          paymentDate == other.paymentDate &&
          amountPaid == other.amountPaid &&
          proofPhotoUrl == other.proofPhotoUrl &&
          notes == other.notes &&
          syncStatus == other.syncStatus;

  @override
  int get hashCode =>
      id.hashCode ^
      installmentId.hashCode ^
      paymentDate.hashCode ^
      amountPaid.hashCode ^
      proofPhotoUrl.hashCode ^
      notes.hashCode ^
      syncStatus.hashCode;
}
