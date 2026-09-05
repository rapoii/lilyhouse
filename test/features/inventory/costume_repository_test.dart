import 'package:flutter_test/flutter_test.dart';
import 'package:lilyhouse/core/database/tables.dart';
import 'package:lilyhouse/features/costumes/domain/costume.dart';
import 'package:lilyhouse/features/costumes/domain/accessory.dart';
import 'package:lilyhouse/features/costumes/data/costume_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database testDb;
  late CostumeRepository repository;

  setUp(() async {
    testDb = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute(AppTables.createCostumes);
          await db.execute(AppTables.createAccessories);
          await db.execute(AppTables.createSyncQueue);
        },
      ),
    );
    repository = CostumeRepository(db: testDb);
  });

  tearDown(() async {
    await testDb.close();
  });

  group('CostumeRepository CRUD', () {
    test('insertCostume and getCostumeById retrieve costume properly', () async {
      final costume = Costume(
        id: 'cos-1',
        name: 'Hatsune Miku Magical Mirai',
        animeSeries: 'Vocaloid',
        size: 'M',
        rentPrice3Days: 160000.0,
        status: CostumeStatus.available,
        coverPhoto: 'miku.jpg',
        galleryPhotos: ['miku1.jpg', 'miku2.jpg'],
        includedAccessories: ['Headphone', 'Twin Ribbon'],
      );

      await repository.insertCostume(costume);

      final retrieved = await repository.getCostumeById('cos-1');
      expect(retrieved, isNotNull);
      expect(retrieved!.name, 'Hatsune Miku Magical Mirai');
      expect(retrieved.animeSeries, 'Vocaloid');
      expect(retrieved.rentPrice3Days, 160000.0);
      expect(retrieved.galleryPhotos.length, 2);
      expect(retrieved.includedAccessories.length, 2);
    });

    test('updateCostume modifies existing record', () async {
      final costume = Costume(
        id: 'cos-2',
        name: 'Furina Archon Dress',
        animeSeries: 'Genshin Impact',
        size: 'S',
        rentPrice3Days: 180000.0,
        status: CostumeStatus.available,
      );
      await repository.insertCostume(costume);

      final updated = costume.copyWith(
        status: CostumeStatus.rented,
        rentPrice3Days: 190000.0,
        notes: 'Includes hat with feather',
      );
      await repository.updateCostume(updated);

      final retrieved = await repository.getCostumeById('cos-2');
      expect(retrieved, isNotNull);
      expect(retrieved!.status, CostumeStatus.rented);
      expect(retrieved.rentPrice3Days, 190000.0);
      expect(retrieved.notes, 'Includes hat with feather');
    });

    test('deleteCostume removes costume by id', () async {
      final costume = Costume(
        id: 'cos-3',
        name: 'Chisato Nishikigi Uniform',
        animeSeries: 'Lycoris Recoil',
        size: 'M',
        rentPrice3Days: 140000.0,
      );
      await repository.insertCostume(costume);

      await repository.deleteCostume('cos-3');
      final retrieved = await repository.getCostumeById('cos-3');
      expect(retrieved, isNull);
    });
  });

  group('CostumeRepository Search & Filter', () {
    setUp(() async {
      await repository.insertCostume(Costume(
        id: 'c1',
        name: 'Frieren Mage Robe',
        animeSeries: 'Sousou no Frieren',
        size: 'M',
        rentPrice3Days: 150000.0,
        status: CostumeStatus.available,
      ));
      await repository.insertCostume(Costume(
        id: 'c2',
        name: 'Fern Apprentice Dress',
        animeSeries: 'Sousou no Frieren',
        size: 'L',
        rentPrice3Days: 140000.0,
        status: CostumeStatus.booked,
      ));
      await repository.insertCostume(Costume(
        id: 'c3',
        name: 'Bocchi Tracksuit',
        animeSeries: 'Bocchi the Rock!',
        size: 'S',
        rentPrice3Days: 90000.0,
        status: CostumeStatus.laundry,
      ));
      await repository.insertCostume(Costume(
        id: 'c4',
        name: 'Kita Uniform',
        animeSeries: 'Bocchi the Rock!',
        size: 'M',
        rentPrice3Days: 95000.0,
        status: CostumeStatus.available,
      ));
    });

    test('getAllCostumes returns all costumes sorted by name', () async {
      final all = await repository.getAllCostumes();
      expect(all.length, 4);
    });

    test('searchCostumes filters by costume name or anime series', () async {
      final frierenResults = await repository.searchCostumes(query: 'Frieren');
      expect(frierenResults.length, 2);

      final bocchiResults = await repository.searchCostumes(query: 'Tracksuit');
      expect(bocchiResults.length, 1);
      expect(bocchiResults.first.name, 'Bocchi Tracksuit');
    });

    test('filterCostumes filters by status and size', () async {
      final availableOnly = await repository.getCostumesByStatus(CostumeStatus.available);
      expect(availableOnly.length, 2);

      final sizeMOnly = await repository.searchCostumes(size: 'M');
      expect(sizeMOnly.length, 2);

      final availableSizeM = await repository.searchCostumes(
        status: CostumeStatus.available,
        size: 'M',
      );
      expect(availableSizeM.length, 2);
    });
  });

  group('CostumeRepository Accessory management', () {
    test('addAccessory and getAccessoriesByCostumeId', () async {
      final acc1 = Accessory(
        id: 'acc-1',
        name: 'Staff of Frieren',
        type: 'Weapon Prop',
        relatedCostumeId: 'c1',
        conditionStatus: AccessoryCondition.good,
      );
      final acc2 = Accessory(
        id: 'acc-2',
        name: 'Mage Ring',
        type: 'Jewelry',
        relatedCostumeId: 'c1',
        conditionStatus: AccessoryCondition.good,
      );
      final acc3 = Accessory(
        id: 'acc-3',
        name: 'Guitar',
        type: 'Prop',
        relatedCostumeId: 'c3',
        conditionStatus: AccessoryCondition.minorDamage,
      );

      await repository.insertAccessory(acc1);
      await repository.insertAccessory(acc2);
      await repository.insertAccessory(acc3);

      final fAccessories = await repository.getAccessoriesByCostumeId('c1');
      expect(fAccessories.length, 2);

      final allAccessories = await repository.getAllAccessories();
      expect(allAccessories.length, 3);
    });
  });
}
