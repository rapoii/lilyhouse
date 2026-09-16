import 'package:flutter_test/flutter_test.dart';
import 'package:lilyhouse/core/database/tables.dart';
import 'package:lilyhouse/features/costumes/data/costume_repository.dart';
import 'package:lilyhouse/features/costumes/domain/costume.dart';
import 'package:lilyhouse/features/rentals/data/rental_repository.dart';
import 'package:lilyhouse/features/rentals/domain/customer.dart';
import 'package:lilyhouse/features/rentals/domain/rental.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database testDb;
  late CostumeRepository costumeRepository;
  late RentalRepository rentalRepository;

  setUp(() async {
    testDb = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute(AppTables.createCostumes);
          await db.execute(AppTables.createRentals);
          await db.execute(AppTables.createCustomers);
          await db.execute(AppTables.createSyncQueue);
        },
      ),
    );
    costumeRepository = CostumeRepository(db: testDb);
    rentalRepository = RentalRepository(db: testDb);
  });

  tearDown(() async {
    await testDb.close();
  });

  Future<void> seedCostume(String id) async {
    await costumeRepository.insertCostume(
      Costume(
        id: id,
        name: 'Furina Archon Dress',
        animeSeries: 'Genshin Impact',
        size: 'S',
        rentPrice3Days: 180000.0,
        status: CostumeStatus.rented,
      ),
    );
  }

  Future<void> seedCustomer(String id, String name) async {
    await rentalRepository.insertCustomer(
      Customer(
        id: id,
        fullName: name,
        phone: '08123456789',
        address: 'Jl. Merdeka No. 10, Jakarta',
      ),
    );
  }

  Future<void> seedRental(
    String rentalId,
    String costumeId,
    String customerId,
    DateTime start,
    DateTime end, {
    RentalItemStatus itemStatus = RentalItemStatus.completed,
  }) async {
    await rentalRepository.insertRental(
      Rental(
        id: rentalId,
        costumeId: costumeId,
        customerId: customerId,
        startDate: start,
        endDate: end,
        durationDays: end.difference(start).inDays + 1,
        purpose: 'Photoshoot',
        totalPrice: 180000.0,
        dpAmount: 0.0,
        paymentStatus: RentalPaymentStatus.paid,
        itemStatus: itemStatus,
      ),
    );
  }

  group('getRentalHistory', () {
    test('returns an empty history for a costume with no rentals', () async {
      await seedCostume('cos-empty');

      final history = await costumeRepository.getRentalHistory('cos-empty');

      expect(history.totalRentals, 0);
      expect(history.activeRentals, 0);
      expect(history.lastServiceDate, isNull);
      expect(history.activeRental, isNull);
      expect(history.records, isEmpty);
      expect(history.hasHistory, isFalse);
      expect(history.badgeLabel, 'Disewa 0 kali');
    });

    test('counts completed rentals and reports the most recent end date', () async {
      await seedCostume('cos-1');
      await seedCustomer('cust-1', 'Alya Rani');
      await seedCustomer('cust-2', 'Budi Santoso');

      await seedRental('rent-1', 'cos-1', 'cust-1', DateTime(2026, 8, 1), DateTime(2026, 8, 4));
      await seedRental('rent-2', 'cos-1', 'cust-2', DateTime(2026, 9, 1), DateTime(2026, 9, 5));

      final history = await costumeRepository.getRentalHistory('cos-1');

      expect(history.totalRentals, 2);
      expect(history.activeRentals, 0);
      expect(history.lastServiceDate, DateTime(2026, 9, 5));
      expect(history.activeRental, isNull);
      expect(history.hasHistory, isTrue);
      expect(history.badgeLabel, 'Disewa 2 kali');

      // Records are ordered most-recent-first
      expect(history.records.first.customerName, 'Budi Santoso');
      expect(history.records.last.customerName, 'Alya Rani');
    });

    test('joins customer names and orders renters most-recent-first', () async {
      await seedCostume('cos-2');
      await seedCustomer('cust-a', 'Zelda');
      await seedCustomer('cust-b', 'Alya');

      // Inserted out of chronological order on purpose
      await seedRental('rent-old', 'cos-2', 'cust-a', DateTime(2026, 5, 1), DateTime(2026, 5, 2));
      await seedRental('rent-new', 'cos-2', 'cust-b', DateTime(2026, 7, 1), DateTime(2026, 7, 3));

      final history = await costumeRepository.getRentalHistory('cos-2');

      expect(history.records.map((r) => r.customerName).toList(), ['Alya', 'Zelda']);
      expect(history.records.first.startDate, DateTime(2026, 7, 1));
    });

    test('isolates history per costume (no cross-contamination)', () async {
      await seedCostume('cos-a');
      await seedCostume('cos-b');
      await seedCustomer('cust-1', 'Alya');

      await seedRental('r-a', 'cos-a', 'cust-1', DateTime(2026, 8, 1), DateTime(2026, 8, 3));

      final a = await costumeRepository.getRentalHistory('cos-a');
      final b = await costumeRepository.getRentalHistory('cos-b');

      expect(a.totalRentals, 1);
      expect(a.records.first.customerName, 'Alya');
      expect(b.totalRentals, 0);
    });

    test('survives a deleted customer via LEFT JOIN fallback', () async {
      await seedCostume('cos-3');
      await seedCustomer('cust-ghost', 'Ghost Customer');

      await seedRental('rent-ghost', 'cos-3', 'cust-ghost', DateTime(2026, 8, 1), DateTime(2026, 8, 3));

      // Customer row removed after the rental exists
      await rentalRepository.deleteCustomer('cust-ghost');

      final history = await costumeRepository.getRentalHistory('cos-3');

      expect(history.totalRentals, 1);
      expect(history.records.first.customerName, 'Penyewa Tidak Diketahui');
    });

    test('excludes cancelled rentals from the count and last service date', () async {
      await seedCostume('cos-4');
      await seedCustomer('cust-1', 'Alya');

      // Only rental for this costume is cancelled — it must not count
      await seedRental(
        'rent-cancelled',
        'cos-4',
        'cust-1',
        DateTime(2026, 9, 1),
        DateTime(2026, 9, 5),
        itemStatus: RentalItemStatus.cancelled,
      );

      final history = await costumeRepository.getRentalHistory('cos-4');

      expect(history.totalRentals, 0);
      expect(history.lastServiceDate, isNull);
      expect(history.hasHistory, isFalse);
    });

    test('does not let a cancelled rental inflate the count over a real one', () async {
      await seedCostume('cos-5');
      await seedCustomer('cust-1', 'Alya');

      await seedRental('rent-real', 'cos-5', 'cust-1', DateTime(2026, 8, 1), DateTime(2026, 8, 4));
      await seedRental(
        'rent-cancelled',
        'cos-5',
        'cust-1',
        DateTime(2026, 9, 1),
        DateTime(2026, 9, 10),
        itemStatus: RentalItemStatus.cancelled,
      );

      final history = await costumeRepository.getRentalHistory('cos-5');

      expect(history.totalRentals, 1);
      expect(history.badgeLabel, 'Disewa 1 kali');
    });

    test('picks the latest end_date even when rentals overlap out of order', () async {
      await seedCostume('cos-6b');
      await seedCustomer('cust-1', 'Alya');

      // Starts first, but ends LAST — this later end date must be reported,
      // not the end date of the most-recently-started rental.
      await seedRental('rent-long', 'cos-6b', 'cust-1', DateTime(2026, 7, 1), DateTime(2026, 9, 20));
      await seedRental('rent-short', 'cos-6b', 'cust-1', DateTime(2026, 8, 1), DateTime(2026, 8, 5));

      final history = await costumeRepository.getRentalHistory('cos-6b');

      expect(history.totalRentals, 2);
      expect(history.lastServiceDate, DateTime(2026, 9, 20));
    });

    test('reports an active rental currently in its usage window', () async {
      await seedCostume('cos-6');
      await seedCustomer('cust-1', 'Alya Rani');
      final now = DateTime.now();

      await seedRental(
        'rent-active',
        'cos-6',
        'cust-1',
        now.subtract(const Duration(days: 1)),
        now.add(const Duration(days: 2)),
        itemStatus: RentalItemStatus.rented,
      );

      final history = await costumeRepository.getRentalHistory('cos-6');

      expect(history.totalRentals, 1);
      expect(history.activeRentals, 1);
      expect(history.activeRental, isNotNull);
      expect(history.activeRental!.customerName, 'Alya Rani');
      expect(history.activeRental!.coversDate(now), isTrue);
    });

    test('reports an upcoming booked rental as active but not yet in use', () async {
      await seedCostume('cos-7');
      await seedCustomer('cust-1', 'Budi');
      final now = DateTime.now();

      await seedRental(
        'rent-upcoming',
        'cos-7',
        'cust-1',
        now.add(const Duration(days: 5)),
        now.add(const Duration(days: 8)),
        itemStatus: RentalItemStatus.booked,
      );

      final history = await costumeRepository.getRentalHistory('cos-7');

      expect(history.activeRentals, 1);
      expect(history.activeRental, isNotNull);
      expect(history.activeRental!.itemStatus, RentalItemStatus.booked);
      expect(history.activeRental!.coversDate(now), isFalse);
    });
  });
}
