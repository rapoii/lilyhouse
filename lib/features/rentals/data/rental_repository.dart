import 'package:sqflite/sqflite.dart';
import '../../../core/database/tables.dart';
import '../../../core/database/db_helper.dart';
import '../../calendar/domain/booking_conflict_engine.dart';
import '../domain/customer.dart';
import '../domain/rental.dart';

abstract class IRentalRepository {
  // Customers
  Future<int> insertCustomer(Customer customer);
  Future<Customer?> getCustomerById(String id);
  Future<List<Customer>> getAllCustomers();
  Future<List<Customer>> searchCustomers(String query);
  Future<int> updateCustomer(Customer customer);
  Future<int> deleteCustomer(String id);

  // Rentals
  Future<int> insertRental(Rental rental);
  Future<Rental?> getRentalById(String id);
  Future<List<Rental>> getAllRentals();
  Future<List<Rental>> getRentalsForDate(DateTime date);
  Future<List<Rental>> getRentalsByDateRange(DateTime start, DateTime end);
  Future<List<Rental>> getRentalsByCostumeId(String costumeId);
  Future<List<Rental>> getRentalsByStatus(RentalItemStatus status);
  Future<int> updateRental(Rental rental);
  Future<int> deleteRental(String id);
  Future<bool> hasConflict(Rental candidate);
  Future<List<Rental>> findConflicts(Rental candidate);
}

class RentalRepository implements IRentalRepository {
  final Database? db;

  RentalRepository({this.db});

  Future<Database> get _db async {
    return db ?? await DatabaseHelper.instance.database;
  }

  // --- Customer Operations ---

  @override
  Future<int> insertCustomer(Customer customer) async {
    final database = await _db;
    return await database.insert(
      AppTables.customers,
      customer.toSqlite(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<Customer?> getCustomerById(String id) async {
    final database = await _db;
    final results = await database.query(
      AppTables.customers,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (results.isEmpty) return null;
    return Customer.fromSqlite(results.first);
  }

  @override
  Future<List<Customer>> getAllCustomers() async {
    final database = await _db;
    final results = await database.query(
      AppTables.customers,
      orderBy: 'full_name ASC',
    );
    return results.map((m) => Customer.fromSqlite(m)).toList();
  }

  @override
  Future<List<Customer>> searchCustomers(String query) async {
    final database = await _db;
    if (query.trim().isEmpty) return getAllCustomers();

    final term = '%${query.trim()}%';
    final results = await database.query(
      AppTables.customers,
      where: 'full_name LIKE ? OR phone LIKE ? OR social_media LIKE ?',
      whereArgs: [term, term, term],
      orderBy: 'full_name ASC',
    );
    return results.map((m) => Customer.fromSqlite(m)).toList();
  }

  @override
  Future<int> updateCustomer(Customer customer) async {
    final database = await _db;
    return await database.update(
      AppTables.customers,
      customer.toSqlite(),
      where: 'id = ?',
      whereArgs: [customer.id],
    );
  }

  @override
  Future<int> deleteCustomer(String id) async {
    final database = await _db;
    return await database.delete(
      AppTables.customers,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Rental Operations ---

  @override
  Future<int> insertRental(Rental rental) async {
    final database = await _db;
    return await database.insert(
      AppTables.rentals,
      rental.toSqlite(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<Rental?> getRentalById(String id) async {
    final database = await _db;
    final results = await database.query(
      AppTables.rentals,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (results.isEmpty) return null;
    return Rental.fromSqlite(results.first);
  }

  @override
  Future<List<Rental>> getAllRentals() async {
    final database = await _db;
    final results = await database.query(
      AppTables.rentals,
      orderBy: 'start_date DESC',
    );
    return results.map((m) => Rental.fromSqlite(m)).toList();
  }

  @override
  Future<List<Rental>> getRentalsForDate(DateTime date) async {
    final all = await getAllRentals();
    final target = DateTime(date.year, date.month, date.day);
    return all.where((r) {
      final s = DateTime(r.startDate.year, r.startDate.month, r.startDate.day);
      final e = DateTime(r.endDate.year, r.endDate.month, r.endDate.day);
      return !target.isBefore(s) && !target.isAfter(e);
    }).toList();
  }

  @override
  Future<List<Rental>> getRentalsByDateRange(DateTime start, DateTime end) async {
    final all = await getAllRentals();
    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);
    return all.where((r) {
      final s = DateTime(r.startDate.year, r.startDate.month, r.startDate.day);
      final e = DateTime(r.endDate.year, r.endDate.month, r.endDate.day);
      return !s.isAfter(endDay) && !e.isBefore(startDay);
    }).toList();
  }

  @override
  Future<List<Rental>> getRentalsByCostumeId(String costumeId) async {
    final database = await _db;
    final results = await database.query(
      AppTables.rentals,
      where: 'costume_id = ?',
      whereArgs: [costumeId],
      orderBy: 'start_date ASC',
    );
    return results.map((m) => Rental.fromSqlite(m)).toList();
  }

  @override
  Future<List<Rental>> getRentalsByStatus(RentalItemStatus status) async {
    final database = await _db;
    final results = await database.query(
      AppTables.rentals,
      where: 'item_status = ?',
      whereArgs: [status.name],
      orderBy: 'start_date ASC',
    );
    return results.map((m) => Rental.fromSqlite(m)).toList();
  }

  @override
  Future<int> updateRental(Rental rental) async {
    final database = await _db;
    return await database.update(
      AppTables.rentals,
      rental.toSqlite(),
      where: 'id = ?',
      whereArgs: [rental.id],
    );
  }

  @override
  Future<int> deleteRental(String id) async {
    final database = await _db;
    return await database.delete(
      AppTables.rentals,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<bool> hasConflict(Rental candidate) async {
    final conflicts = await findConflicts(candidate);
    return conflicts.isNotEmpty;
  }

  @override
  Future<List<Rental>> findConflicts(Rental candidate) async {
    final costumeRentals = await getRentalsByCostumeId(candidate.costumeId);
    return BookingConflictEngine.findConflicts(costumeRentals, candidate);
  }
}
