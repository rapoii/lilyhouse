import 'dart:convert';
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

  Future<void> _recordSync(Database database, String table, String recordId, String action, Map<String, dynamic> payload) async {
    await database.insert(
      AppTables.syncQueue,
      {
        'id': '${table}_${recordId}_${DateTime.now().millisecondsSinceEpoch}',
        'table_name': table,
        'record_id': recordId,
        'action': action,
        'payload': jsonEncode(payload),
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // --- Customer Operations ---

  @override
  Future<int> insertCustomer(Customer customer) async {
    final database = await _db;
    final row = customer.toSqlite();
    final result = await database.insert(
      AppTables.customers,
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _recordSync(database, AppTables.customers, customer.id, 'INSERT', row);
    return result;
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
    final row = customer.toSqlite();
    final result = await database.update(
      AppTables.customers,
      row,
      where: 'id = ?',
      whereArgs: [customer.id],
    );
    await _recordSync(database, AppTables.customers, customer.id, 'UPDATE', row);
    return result;
  }

  @override
  Future<int> deleteCustomer(String id) async {
    final database = await _db;
    final result = await database.delete(
      AppTables.customers,
      where: 'id = ?',
      whereArgs: [id],
    );
    await _recordSync(database, AppTables.customers, id, 'DELETE', {'id': id});
    return result;
  }

  // --- Rental Operations ---

  @override
  Future<int> insertRental(Rental rental) async {
    final database = await _db;
    final row = rental.toSqlite();
    final result = await database.insert(
      AppTables.rentals,
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _recordSync(database, AppTables.rentals, rental.id, 'INSERT', row);
    return result;
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
    final row = rental.toSqlite();
    final result = await database.update(
      AppTables.rentals,
      row,
      where: 'id = ?',
      whereArgs: [rental.id],
    );
    await _recordSync(database, AppTables.rentals, rental.id, 'UPDATE', row);
    return result;
  }

  @override
  Future<int> deleteRental(String id) async {
    final database = await _db;
    final result = await database.delete(
      AppTables.rentals,
      where: 'id = ?',
      whereArgs: [id],
    );
    await _recordSync(database, AppTables.rentals, id, 'DELETE', {'id': id});
    return result;
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
