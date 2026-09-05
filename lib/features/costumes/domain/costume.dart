import 'dart:convert';

enum CostumeStatus {
  available,
  booked,
  rented,
  laundry,
  maintenance;

  static CostumeStatus fromString(String value) {
    return CostumeStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase().replaceAll('_', ''),
      orElse: () {
        switch (value.toLowerCase()) {
          case 'available':
            return CostumeStatus.available;
          case 'booked':
            return CostumeStatus.booked;
          case 'rented':
            return CostumeStatus.rented;
          case 'laundry':
            return CostumeStatus.laundry;
          case 'maintenance':
            return CostumeStatus.maintenance;
          default:
            return CostumeStatus.available;
        }
      },
    );
  }
}

class Costume {
  final String id;
  final String name;
  final String animeSeries;
  final String size;
  final double rentPrice3Days;
  final CostumeStatus status;
  final String? coverPhoto;
  final List<String> galleryPhotos;
  final List<String> includedAccessories;
  final String? notes;
  final String syncStatus;

  const Costume({
    required this.id,
    required this.name,
    required this.animeSeries,
    required this.size,
    required this.rentPrice3Days,
    this.status = CostumeStatus.available,
    this.coverPhoto,
    this.galleryPhotos = const [],
    this.includedAccessories = const [],
    this.notes,
    this.syncStatus = 'pending',
  });

  String get statusString => status.name;

  Map<String, dynamic> toSqlite() {
    return {
      'id': id,
      'name': name,
      'anime_series': animeSeries,
      'size': size,
      'rent_price_3days': rentPrice3Days,
      'status': statusString,
      'cover_photo': coverPhoto,
      'gallery_photos': jsonEncode(galleryPhotos),
      'included_accessories': jsonEncode(includedAccessories),
      'notes': notes,
      'sync_status': syncStatus,
    };
  }

  factory Costume.fromSqlite(Map<String, dynamic> map) {
    List<String> parseJsonList(dynamic val) {
      if (val == null) return [];
      if (val is List) return val.map((e) => e.toString()).toList();
      if (val is String && val.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(val);
          if (decoded is List) {
            return decoded.map((e) => e.toString()).toList();
          }
        } catch (_) {}
      }
      return [];
    }

    return Costume(
      id: map['id'] as String,
      name: map['name'] as String,
      animeSeries: map['anime_series'] as String? ?? '',
      size: map['size'] as String? ?? 'All Size',
      rentPrice3Days: (map['rent_price_3days'] as num?)?.toDouble() ?? 0.0,
      status: CostumeStatus.fromString(map['status'] as String? ?? 'available'),
      coverPhoto: map['cover_photo'] as String?,
      galleryPhotos: parseJsonList(map['gallery_photos']),
      includedAccessories: parseJsonList(map['included_accessories']),
      notes: map['notes'] as String?,
      syncStatus: map['sync_status'] as String? ?? 'pending',
    );
  }

  Costume copyWith({
    String? id,
    String? name,
    String? animeSeries,
    String? size,
    double? rentPrice3Days,
    CostumeStatus? status,
    String? coverPhoto,
    List<String>? galleryPhotos,
    List<String>? includedAccessories,
    String? notes,
    String? syncStatus,
  }) {
    return Costume(
      id: id ?? this.id,
      name: name ?? this.name,
      animeSeries: animeSeries ?? this.animeSeries,
      size: size ?? this.size,
      rentPrice3Days: rentPrice3Days ?? this.rentPrice3Days,
      status: status ?? this.status,
      coverPhoto: coverPhoto ?? this.coverPhoto,
      galleryPhotos: galleryPhotos ?? this.galleryPhotos,
      includedAccessories: includedAccessories ?? this.includedAccessories,
      notes: notes ?? this.notes,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}
