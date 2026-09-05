import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../../core/database/tables.dart';
import '../../../core/database/db_helper.dart';
import '../domain/installment.dart';
import '../domain/installment_log.dart';

abstract class IInstallmentRepository {
  Future<int> insertInstallment(Installment installment);
  Future<Installment?> getInstallmentById(String id);
  Future<List<Installment>> getAllInstallments();
  Future<List<Installment>> getInstallmentsByStatus(InstallmentStatus status);
  Future<int> updateInstallment(Installment installment);
  Future<int> deleteInstallment(String id);

  Future<int> addPaymentLog(InstallmentLog log);
  Future<List<InstallmentLog>> getLogsForInstallment(String installmentId);
  Future<int> deletePaymentLog(String logId, String installmentId);
}

class InstallmentRepository implements IInstallmentRepository {
  final Database? db;

  InstallmentRepository({this.db});

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

  @override
  Future<int> insertInstallment(Installment installment) async {
    final database = await _db;
    final row = installment.toSqlite();
    final result = await database.insert(
      AppTables.installments,
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _recordSync(database, AppTables.installments, installment.id, 'INSERT', row);
    return result;
  }

  @override
  Future<Installment?> getInstallmentById(String id) async {
    final database = await _db;
    final results = await database.query(
      AppTables.installments,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (results.isEmpty) return null;
    return Installment.fromSqlite(results.first);
  }

  @override
  Future<List<Installment>> getAllInstallments() async {
    final database = await _db;
    final results = await database.query(
      AppTables.installments,
      orderBy: 'due_date ASC, item_name ASC',
    );
    return results.map((m) => Installment.fromSqlite(m)).toList();
  }

  @override
  Future<List<Installment>> getInstallmentsByStatus(InstallmentStatus status) async {
    final database = await _db;
    final statusStr = status == InstallmentStatus.paidOff ? 'paid_off' : 'ongoing';
    final results = await database.query(
      AppTables.installments,
      where: 'status = ?',
      whereArgs: [statusStr],
      orderBy: 'due_date ASC, item_name ASC',
    );
    return results.map((m) => Installment.fromSqlite(m)).toList();
  }

  @override
  Future<int> updateInstallment(Installment installment) async {
    final database = await _db;
    final row = installment.toSqlite();
    final result = await database.update(
      AppTables.installments,
      row,
      where: 'id = ?',
      whereArgs: [installment.id],
    );
    await _recordSync(database, AppTables.installments, installment.id, 'UPDATE', row);
    return result;
  }

  @override
  Future<int> deleteInstallment(String id) async {
    final database = await _db;
    await database.delete(
      AppTables.installmentLogs,
      where: 'installment_id = ?',
      whereArgs: [id],
    );
    final result = await database.delete(
      AppTables.installments,
      where: 'id = ?',
      whereArgs: [id],
    );
    await _recordSync(database, AppTables.installments, id, 'DELETE', {'id': id});
    return result;
  }

  @override
  Future<int> addPaymentLog(InstallmentLog log) async {
    final database = await _db;
    final row = log.toSqlite();
    final result = await database.insert(
      AppTables.installmentLogs,
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _recordSync(database, AppTables.installmentLogs, log.id, 'INSERT', row);

    // Recalculate parent installment
    await _recalculateAndSave(database, log.installmentId);

    return result;
  }

  @override
  Future<List<InstallmentLog>> getLogsForInstallment(String installmentId) async {
    final database = await _db;
    final results = await database.query(
      AppTables.installmentLogs,
      where: 'installment_id = ?',
      whereArgs: [installmentId],
      orderBy: 'payment_date DESC',
    );
    return results.map((m) => InstallmentLog.fromSqlite(m)).toList();
  }

  @override
  Future<int> deletePaymentLog(String logId, String installmentId) async {
    final database = await _db;
    final result = await database.delete(
      AppTables.installmentLogs,
      where: 'id = ?',
      whereArgs: [logId],
    );
    await _recordSync(database, AppTables.installmentLogs, logId, 'DELETE', {'id': logId});

    // Recalculate parent installment
    await _recalculateAndSave(database, installmentId);

    return result;
  }

  Future<void> _recalculateAndSave(Database database, String installmentId) async {
    final instResult = await database.query(
      AppTables.installments,
      where: 'id = ?',
      whereArgs: [installmentId],
    );
    if (instResult.isEmpty) return;

    final currentInst = Installment.fromSqlite(instResult.first);
    final logsResult = await database.query(
      AppTables.installmentLogs,
      where: 'installment_id = ?',
      whereArgs: [installmentId],
    );
    final logs = logsResult.map((m) => InstallmentLog.fromSqlite(m)).toList();

    final updatedInst = currentInst.recalculateWithLogs(logs);
    final updatedRow = updatedInst.toSqlite();

    await database.update(
      AppTables.installments,
      updatedRow,
      where: 'id = ?',
      whereArgs: [installmentId],
    );
    await _recordSync(database, AppTables.installments, installmentId, 'UPDATE', updatedRow);
  }
}
