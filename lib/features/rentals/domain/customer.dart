class Customer {
  final String id;
  final String fullName;
  final String phone;
  final String? parentPhone;
  final String address;
  final String? socialMedia;
  final String? ktpPhotoUrl;
  final String? selfieKtpUrl;
  final String syncStatus;

  const Customer({
    required this.id,
    required this.fullName,
    required this.phone,
    this.parentPhone,
    required this.address,
    this.socialMedia,
    this.ktpPhotoUrl,
    this.selfieKtpUrl,
    this.syncStatus = 'pending',
  });

  Map<String, dynamic> toSqlite() {
    return {
      'id': id,
      'full_name': fullName,
      'phone': phone,
      'parent_phone': parentPhone,
      'address': address,
      'social_media': socialMedia,
      'ktp_photo_url': ktpPhotoUrl,
      'selfie_ktp_url': selfieKtpUrl,
      'sync_status': syncStatus,
    };
  }

  factory Customer.fromSqlite(Map<String, dynamic> map) {
    return Customer(
      id: map['id'] as String,
      fullName: map['full_name'] as String,
      phone: map['phone'] as String,
      parentPhone: map['parent_phone'] as String?,
      address: map['address'] as String? ?? '',
      socialMedia: map['social_media'] as String?,
      ktpPhotoUrl: map['ktp_photo_url'] as String?,
      selfieKtpUrl: map['selfie_ktp_url'] as String?,
      syncStatus: map['sync_status'] as String? ?? 'pending',
    );
  }

  Customer copyWith({
    String? id,
    String? fullName,
    String? phone,
    String? parentPhone,
    String? address,
    String? socialMedia,
    String? ktpPhotoUrl,
    String? selfieKtpUrl,
    String? syncStatus,
  }) {
    return Customer(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      parentPhone: parentPhone ?? this.parentPhone,
      address: address ?? this.address,
      socialMedia: socialMedia ?? this.socialMedia,
      ktpPhotoUrl: ktpPhotoUrl ?? this.ktpPhotoUrl,
      selfieKtpUrl: selfieKtpUrl ?? this.selfieKtpUrl,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}
