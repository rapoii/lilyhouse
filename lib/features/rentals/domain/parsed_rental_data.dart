/// Domain model representing parsed customer rent form data.
class ParsedRentalData {
  final String? fullName;
  final String? phone;
  final String? address;
  final String? parentPhone;
  final String? socialMedia;
  final String? costumeName;
  final String? datesRaw;
  final String? purpose;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? rentalDurationDays;
  final String? rawText;

  const ParsedRentalData({
    this.fullName,
    this.phone,
    this.address,
    this.parentPhone,
    this.socialMedia,
    this.costumeName,
    this.datesRaw,
    this.purpose,
    this.startDate,
    this.endDate,
    this.rentalDurationDays,
    this.rawText,
  });

  /// Compatibility alias for emergency contact phone
  String? get emergencyContact => parentPhone;

  /// Returns sanitized Indonesian phone number (e.g. +62 822-4577-7711 -> 082245777711)
  String? get normalizedPhone {
    if (phone == null) return null;
    final digits = phone!.replaceAll(RegExp(r'[^\d+]'), '');
    if (digits.startsWith('+62')) {
      return '0${digits.substring(3)}';
    } else if (digits.startsWith('62')) {
      return '0${digits.substring(2)}';
    }
    return digits.replaceAll('+', '');
  }

  /// Check if the essential fields were captured
  bool get isValid =>
      (fullName != null && fullName!.trim().isNotEmpty) &&
      (phone != null && phone!.trim().isNotEmpty);

  ParsedRentalData copyWith({
    String? fullName,
    String? phone,
    String? address,
    String? parentPhone,
    String? socialMedia,
    String? costumeName,
    String? datesRaw,
    String? purpose,
    DateTime? startDate,
    DateTime? endDate,
    int? rentalDurationDays,
    String? rawText,
  }) {
    return ParsedRentalData(
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      parentPhone: parentPhone ?? this.parentPhone,
      socialMedia: socialMedia ?? this.socialMedia,
      costumeName: costumeName ?? this.costumeName,
      datesRaw: datesRaw ?? this.datesRaw,
      purpose: purpose ?? this.purpose,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      rentalDurationDays: rentalDurationDays ?? this.rentalDurationDays,
      rawText: rawText ?? this.rawText,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'phone': phone,
      'normalizedPhone': normalizedPhone,
      'address': address,
      'parentPhone': parentPhone,
      'emergencyContact': emergencyContact,
      'socialMedia': socialMedia,
      'costumeName': costumeName,
      'datesRaw': datesRaw,
      'purpose': purpose,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'rentalDurationDays': rentalDurationDays,
      'rawText': rawText,
    };
  }

  @override
  String toString() {
    return 'ParsedRentalData(name: $fullName, phone: $phone, costume: $costumeName, dates: $datesRaw)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ParsedRentalData &&
        other.fullName == fullName &&
        other.phone == phone &&
        other.address == address &&
        other.parentPhone == parentPhone &&
        other.socialMedia == socialMedia &&
        other.costumeName == costumeName &&
        other.datesRaw == datesRaw &&
        other.purpose == purpose &&
        other.startDate == startDate &&
        other.endDate == endDate;
  }

  @override
  int get hashCode => Object.hash(
        fullName,
        phone,
        address,
        parentPhone,
        socialMedia,
        costumeName,
        datesRaw,
        purpose,
        startDate,
        endDate,
      );
}

/// Alias for RentFormParser & ParsedCustomerForm naming
typedef ParsedCustomerForm = ParsedRentalData;
