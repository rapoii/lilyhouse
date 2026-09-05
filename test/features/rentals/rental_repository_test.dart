import 'package:flutter_test/flutter_test.dart';
import 'package:lilyhouse/core/database/tables.dart';
import 'package:lilyhouse/features/rentals/data/rental_repository.dart';
import 'package:lilyhouse/features/rentals/domain/customer.dart';
import 'package:lilyhouse/features/rentals/domain/rental.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database testDb;
  late RentalRepository repository;

  setUp(() async {
    testDb = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute(AppTables.createCustomers);
          await db.execute(AppTables.createRentals);
          await db.execute(AppTables.createSyncQueue);
        },
      ),
    );
    repository = RentalRepository(db: testDb);
  });

  tearDown(() async {
    await testDb.close();
  });

  group('RentalRepository Customer CRUD', () {
    final testCustomer = Customer(
      id: 'cust_101',
      fullName: 'Jihan Fatin',
      phone: '082245777711',
      parentPhone: '082245777711',
      address: 'Jalan Karang Pola Dalam IV No. 10, Jakarta Selatan',
      socialMedia: 'tiktok @kodzukenlucu',
    );

    test('insertCustomer and getCustomerById succeed', () async {
      await repository.insertCustomer(testCustomer);

      final retrieved = await repository.getCustomerById('cust_101');
      expect(retrieved, isNotNull);
      expect(retrieved!.fullName, 'Jihan Fatin');
      expect(retrieved.phone, '082245777711');
      expect(retrieved.socialMedia, 'tiktok @kodzukenlucu');
    });

    test('getAllCustomers and searchCustomers work accurately', () async {
      await repository.insertCustomer(testCustomer);
      await repository.insertCustomer(Customer(
        id: 'cust_102',
        fullName: 'Natsuki Subaru',
        phone: '081234567890',
        address: 'Tokyo',
      ));

      final all = await repository.getAllCustomers();
      expect(all.length, 2);

      final search1 = await repository.searchCustomers('Jihan');
      expect(search1.length, 1);
      expect(search1.first.id, 'cust_101');

      final search2 = await repository.searchCustomers('081234');
      expect(search2.length, 1);
      expect(search2.first.id, 'cust_102');
    });

    test('updateCustomer and deleteCustomer work properly', () async {
      await repository.insertCustomer(testCustomer);

      final updated = testCustomer.copyWith(
        address: 'Jl. Melati No. 4, Jakarta',
      );
      await repository.updateCustomer(updated);

      final retrieved = await repository.getCustomerById('cust_101');
      expect(retrieved!.address, 'Jl. Melati No. 4, Jakarta');

      await repository.deleteCustomer('cust_101');
      final deleted = await repository.getCustomerById('cust_101');
      expect(deleted, isNull);
    });
  });

  group('RentalRepository Rental CRUD & Filtering', () {
    final rental1 = Rental(
      id: 'rent_001',
      costumeId: 'cos_citlali',
      customerId: 'cust_101',
      startDate: DateTime(2026, 9, 5),
      endDate: DateTime(2026, 9, 7),
      durationDays: 3,
      purpose: 'homecos',
      totalPrice: 150000.0,
      dpAmount: 50000.0,
      paymentStatus: RentalPaymentStatus.dpPaid,
      itemStatus: RentalItemStatus.booked,
    );

    final rental2 = Rental(
      id: 'rent_002',
      costumeId: 'cos_furina',
      customerId: 'cust_102',
      startDate: DateTime(2026, 9, 10),
      endDate: DateTime(2026, 9, 12),
      durationDays: 3,
      purpose: 'event',
      totalPrice: 200000.0,
      dpAmount: 200000.0,
      paymentStatus: RentalPaymentStatus.paid,
      itemStatus: RentalItemStatus.rented,
    );

    test('insertRental and getRentalById work properly', () async {
      await repository.insertRental(rental1);

      final retrieved = await repository.getRentalById('rent_001');
      expect(retrieved, isNotNull);
      expect(retrieved!.costumeId, 'cos_citlali');
      expect(retrieved.customerId, 'cust_101');
      expect(retrieved.paymentStatus, RentalPaymentStatus.dpPaid);
      expect(retrieved.itemStatus, RentalItemStatus.booked);
      expect(retrieved.startDate.year, 2026);
    });

    test('getAllRentals returns sorted by startDate descending or ascending', () async {
      await repository.insertRental(rental1);
      await repository.insertRental(rental2);

      final all = await repository.getAllRentals();
      expect(all.length, 2);
    });

    test('getRentalsByDateRange returns rentals overlapping the range', () async {
      await repository.insertRental(rental1);
      await repository.insertRental(rental2);

      final activeSept5To7 = await repository.getRentalsForDate(DateTime(2026, 9, 6));
      expect(activeSept5To7.length, 1);
      expect(activeSept5To7.first.id, 'rent_001');

      final activeSept10To12 = await repository.getRentalsForDate(DateTime(2026, 9, 11));
      expect(activeSept10To12.length, 1);
      expect(activeSept10To12.first.id, 'rent_002');

      final range = await repository.getRentalsByDateRange(
        DateTime(2026, 9, 1),
        DateTime(2026, 9, 8),
      );
      expect(range.length, 1);
      expect(range.first.id, 'rent_001');
    });

    test('checkConflict uses BookingConflictEngine across stored rentals', () async {
      await repository.insertRental(rental1);

      final candidateClash = Rental(
        id: 'rent_003',
        costumeId: 'cos_citlali',
        customerId: 'cust_103',
        startDate: DateTime(2026, 9, 6),
        endDate: DateTime(2026, 9, 8),
        durationDays: 3,
        purpose: 'photoshoot',
        totalPrice: 150000.0,
      );

      final hasConflict = await repository.hasConflict(candidateClash);
      expect(hasConflict, isTrue);

      final candidateNoClash = Rental(
        id: 'rent_004',
        costumeId: 'cos_citlali',
        customerId: 'cust_104',
        startDate: DateTime(2026, 9, 8),
        endDate: DateTime(2026, 9, 10),
        durationDays: 3,
        purpose: 'photoshoot',
        totalPrice: 150000.0,
      );

      final hasConflict2 = await repository.hasConflict(candidateNoClash);
      expect(hasConflict2, isFalse);
    });

    test('updateRental and deleteRental update database records', () async {
      await repository.insertRental(rental1);

      final updated = rental1.copyWith(
        itemStatus: RentalItemStatus.rented,
        paymentStatus: RentalPaymentStatus.paid,
      );
      await repository.updateRental(updated);

      final retrieved = await repository.getRentalById('rent_001');
      expect(retrieved!.itemStatus, RentalItemStatus.rented);
      expect(retrieved.paymentStatus, RentalPaymentStatus.paid);

      await repository.deleteRental('rent_001');
      final deleted = await repository.getRentalById('rent_001');
      expect(deleted, isNull);
    });
  });
}
