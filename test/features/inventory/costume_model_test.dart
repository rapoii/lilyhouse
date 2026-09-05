import 'package:flutter_test/flutter_test.dart';
import 'package:lilyhouse/features/costumes/domain/costume.dart';
import 'package:lilyhouse/features/costumes/domain/accessory.dart';

void main() {
  group('Costume Model', () {
    test('instantiates correctly with default and required values', () {
      final costume = Costume(
        id: 'cos-1',
        name: 'Frieren Mage Robe',
        animeSeries: 'Sousou no Frieren',
        size: 'M',
        rentPrice3Days: 150000.0,
        status: CostumeStatus.available,
        coverPhoto: 'frieren_cover.jpg',
        galleryPhotos: ['frieren_1.jpg', 'frieren_2.jpg'],
        includedAccessories: ['Staff', 'Earrings', 'Scarf'],
        notes: 'Handle golden buckle carefully',
      );

      expect(costume.id, 'cos-1');
      expect(costume.name, 'Frieren Mage Robe');
      expect(costume.animeSeries, 'Sousou no Frieren');
      expect(costume.size, 'M');
      expect(costume.rentPrice3Days, 150000.0);
      expect(costume.status, CostumeStatus.available);
      expect(costume.statusString, 'available');
      expect(costume.coverPhoto, 'frieren_cover.jpg');
      expect(costume.galleryPhotos, ['frieren_1.jpg', 'frieren_2.jpg']);
      expect(costume.includedAccessories, ['Staff', 'Earrings', 'Scarf']);
      expect(costume.notes, 'Handle golden buckle carefully');
      expect(costume.syncStatus, 'pending');
    });

    test('serializes to and from SQLite map correctly', () {
      final original = Costume(
        id: 'cos-2',
        name: 'Fern Staff Apprentice Robe',
        animeSeries: 'Sousou no Frieren',
        size: 'L',
        rentPrice3Days: 135000.0,
        status: CostumeStatus.rented,
        coverPhoto: 'fern.jpg',
        galleryPhotos: ['fern1.jpg'],
        includedAccessories: ['Hairclip'],
        notes: 'Cleaned yesterday',
        syncStatus: 'synced',
      );

      final map = original.toSqlite();
      expect(map['id'], 'cos-2');
      expect(map['name'], 'Fern Staff Apprentice Robe');
      expect(map['anime_series'], 'Sousou no Frieren');
      expect(map['size'], 'L');
      expect(map['rent_price_3days'], 135000.0);
      expect(map['status'], 'rented');
      expect(map['cover_photo'], 'fern.jpg');
      expect(map['gallery_photos'], '["fern1.jpg"]');
      expect(map['included_accessories'], '["Hairclip"]');
      expect(map['notes'], 'Cleaned yesterday');
      expect(map['sync_status'], 'synced');

      final deserialized = Costume.fromSqlite(map);
      expect(deserialized.id, original.id);
      expect(deserialized.name, original.name);
      expect(deserialized.animeSeries, original.animeSeries);
      expect(deserialized.size, original.size);
      expect(deserialized.rentPrice3Days, original.rentPrice3Days);
      expect(deserialized.status, CostumeStatus.rented);
      expect(deserialized.coverPhoto, original.coverPhoto);
      expect(deserialized.galleryPhotos, original.galleryPhotos);
      expect(deserialized.includedAccessories, original.includedAccessories);
      expect(deserialized.notes, original.notes);
      expect(deserialized.syncStatus, original.syncStatus);
    });

    test('handles empty or null lists and notes in SQLite deserialization', () {
      final map = {
        'id': 'cos-3',
        'name': 'Bocchi Tracksuit',
        'anime_series': 'Bocchi the Rock!',
        'size': 'S',
        'rent_price_3days': 90000.0,
        'status': 'available',
        'cover_photo': null,
        'gallery_photos': null,
        'included_accessories': null,
        'notes': null,
        'sync_status': 'pending',
      };

      final costume = Costume.fromSqlite(map);
      expect(costume.coverPhoto, isNull);
      expect(costume.galleryPhotos, isEmpty);
      expect(costume.includedAccessories, isEmpty);
      expect(costume.notes, isNull);
      expect(costume.status, CostumeStatus.available);
    });

    test('copyWith creates modified clone correctly', () {
      final costume = Costume(
        id: 'cos-1',
        name: 'Frieren',
        animeSeries: 'Frieren',
        size: 'M',
        rentPrice3Days: 100000.0,
        status: CostumeStatus.available,
      );

      final updated = costume.copyWith(
        status: CostumeStatus.booked,
        rentPrice3Days: 120000.0,
      );

      expect(updated.id, 'cos-1');
      expect(updated.name, 'Frieren');
      expect(updated.status, CostumeStatus.booked);
      expect(updated.rentPrice3Days, 120000.0);
    });
  });

  group('Accessory Model', () {
    test('instantiates and maps to/from SQLite map correctly', () {
      final accessory = Accessory(
        id: 'acc-1',
        name: 'Zoltraak Staff',
        type: 'Weapon Prop',
        relatedCostumeId: 'cos-1',
        conditionStatus: AccessoryCondition.good,
        photoUrl: 'staff.jpg',
        syncStatus: 'pending',
      );

      expect(accessory.id, 'acc-1');
      expect(accessory.name, 'Zoltraak Staff');
      expect(accessory.type, 'Weapon Prop');
      expect(accessory.relatedCostumeId, 'cos-1');
      expect(accessory.conditionStatus, AccessoryCondition.good);
      expect(accessory.conditionStatusString, 'good');

      final map = accessory.toSqlite();
      expect(map['id'], 'acc-1');
      expect(map['name'], 'Zoltraak Staff');
      expect(map['type'], 'Weapon Prop');
      expect(map['related_costume_id'], 'cos-1');
      expect(map['condition_status'], 'good');
      expect(map['photo_url'], 'staff.jpg');
      expect(map['sync_status'], 'pending');

      final deserialized = Accessory.fromSqlite(map);
      expect(deserialized.id, accessory.id);
      expect(deserialized.name, accessory.name);
      expect(deserialized.type, accessory.type);
      expect(deserialized.relatedCostumeId, accessory.relatedCostumeId);
      expect(deserialized.conditionStatus, AccessoryCondition.good);
      expect(deserialized.photoUrl, accessory.photoUrl);
    });

    test('Accessory copyWith updates attributes', () {
      final accessory = Accessory(
        id: 'acc-1',
        name: 'Wig',
        type: 'Wig',
        conditionStatus: AccessoryCondition.good,
      );

      final updated = accessory.copyWith(
        conditionStatus: AccessoryCondition.needsRepair,
        relatedCostumeId: 'cos-99',
      );

      expect(updated.id, 'acc-1');
      expect(updated.conditionStatus, AccessoryCondition.needsRepair);
      expect(updated.relatedCostumeId, 'cos-99');
    });
  });
}
