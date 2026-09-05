enum AccessoryCondition {
  good,
  minorDamage,
  needsRepair,
  lost;

  static AccessoryCondition fromString(String value) {
    return AccessoryCondition.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase().replaceAll('_', ''),
      orElse: () {
        switch (value.toLowerCase()) {
          case 'good':
            return AccessoryCondition.good;
          case 'minor_damage':
          case 'minordamage':
            return AccessoryCondition.minorDamage;
          case 'needs_repair':
          case 'needsrepair':
            return AccessoryCondition.needsRepair;
          case 'lost':
            return AccessoryCondition.lost;
          default:
            return AccessoryCondition.good;
        }
      },
    );
  }
}

class Accessory {
  final String id;
  final String name;
  final String type;
  final String? relatedCostumeId;
  final AccessoryCondition conditionStatus;
  final String? photoUrl;
  final String syncStatus;

  const Accessory({
    required this.id,
    required this.name,
    required this.type,
    this.relatedCostumeId,
    this.conditionStatus = AccessoryCondition.good,
    this.photoUrl,
    this.syncStatus = 'pending',
  });

  String get conditionStatusString {
    switch (conditionStatus) {
      case AccessoryCondition.good:
        return 'good';
      case AccessoryCondition.minorDamage:
        return 'minor_damage';
      case AccessoryCondition.needsRepair:
        return 'needs_repair';
      case AccessoryCondition.lost:
        return 'lost';
    }
  }

  Map<String, dynamic> toSqlite() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'related_costume_id': relatedCostumeId,
      'condition_status': conditionStatusString,
      'photo_url': photoUrl,
      'sync_status': syncStatus,
    };
  }

  factory Accessory.fromSqlite(Map<String, dynamic> map) {
    return Accessory(
      id: map['id'] as String,
      name: map['name'] as String,
      type: map['type'] as String,
      relatedCostumeId: map['related_costume_id'] as String?,
      conditionStatus: AccessoryCondition.fromString(map['condition_status'] as String? ?? 'good'),
      photoUrl: map['photo_url'] as String?,
      syncStatus: map['sync_status'] as String? ?? 'pending',
    );
  }

  Accessory copyWith({
    String? id,
    String? name,
    String? type,
    String? relatedCostumeId,
    AccessoryCondition? conditionStatus,
    String? photoUrl,
    String? syncStatus,
  }) {
    return Accessory(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      relatedCostumeId: relatedCostumeId ?? this.relatedCostumeId,
      conditionStatus: conditionStatus ?? this.conditionStatus,
      photoUrl: photoUrl ?? this.photoUrl,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}
