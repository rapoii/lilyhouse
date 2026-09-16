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
  Future<Installment?> recalculateInstallment(String installmentId);

  Future<List<Installment>> searchInstallments({
    String? query,
    InstallmentStatus? status,
    String sortBy = 'due_date_asc',
    bool dueSoon = false,
    DateTime? now,
  }) async {
    List<Installment> list = status != null
        ? await getInstallmentsByStatus(status)
        : await getAllInstallments();
    if (dueSoon) {
      final ref = now ?? DateTime.now();
      list = list.where((i) {
        if (i.isPaidOff || i.dueDate == null) return false;
        final days = i.daysUntilDue(now: ref);
        return days != null && days <= 7;
      }).toList();
    }
    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      list = list.where((i) =>
        i.itemName.toLowerCase().contains(q) ||
        (i.storeName?.toLowerCase().contains(q) ?? false)
      ).toList();
    }
    list.sort((a, b) {
      switch (sortBy) {
        case 'due_date_desc':
          if (a.dueDate == null && b.dueDate == null) return a.itemName.compareTo(b.itemName);
          if (a.dueDate == null) return 1;
          if (b.dueDate == null) return -1;
          return b.dueDate!.compareTo(a.dueDate!);
        case 'balance_desc':
          return b.remainingBalance.compareTo(a.remainingBalance);
        case 'cost_desc':
          return b.totalCost.compareTo(a.totalCost);
        case 'name_asc':
          return a.itemName.toLowerCase().compareTo(b.itemName.toLowerCase());
        case 'due_date_asc':
        default:
          if (a.dueDate == null && b.dueDate == null) return a.itemName.compareTo(b.itemName);
          if (a.dueDate == null) return 1;
          if (b.dueDate == null) return -1;
          return a.dueDate!.compareTo(b.dueDate!);
      }
    });
    return list;
  }
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
    DatabaseHelper.instance.onQueueChanged?.call();
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
  Future<List<Installment>> searchInstallments({
    String? query,
    InstallmentStatus? status,
    String sortBy = 'due_date_asc',
    bool dueSoon = false,
    DateTime? now,
  }) async {
    final database = await _db;
    final List<String> whereClauses = [];
    final List<dynamic> whereArgs = [];

    if (query != null && query.trim().isNotEmpty) {
      whereClauses.add('(item_name LIKE ? OR store_name LIKE ?)');
      final term = '%${query.trim()}%';
      whereArgs.add(term);
      whereArgs.add(term);
    }

    if (status != null) {
      whereClauses.add('status = ?');
      whereArgs.add(status == InstallmentStatus.paidOff ? 'paid_off' : 'ongoing');
    }

    // Filter "Jatuh Tempo Dekat": belum lunas, memiliki tanggal jatuh tempo, dan
    // jatuh tempo <= 7 hari dari sekarang (termasuk yang sudah terlambat).
    if (dueSoon) {
      final reference = (now ?? DateTime.now());
      final today = DateTime(reference.year, reference.month, reference.day);
      // Akhir hari ke-7 -> semua tanggal jatuh tempo <= H+7 masuk.
      final cutoff = today.add(const Duration(days: 7, hours: 23, minutes: 59, seconds: 59));
      whereClauses.add('status != ?');
      whereArgs.add('paid_off');
      whereClauses.add('(due_date IS NOT NULL AND due_date != \'\')');
      whereClauses.add('due_date <= ?');
      whereArgs.add(cutoff.toIso8601String());
    }

    String orderBy = 'CASE WHEN due_date IS NULL OR due_date = \'\' THEN 1 ELSE 0 END, due_date ASC, item_name ASC';
    switch (sortBy) {
      case 'due_date_desc':
        orderBy = 'CASE WHEN due_date IS NULL OR due_date = \'\' THEN 1 ELSE 0 END, due_date DESC, item_name ASC';
        break;
      case 'balance_desc':
        orderBy = 'remaining_balance DESC, item_name ASC';
        break;
      case 'cost_desc':
        orderBy = 'total_cost DESC, item_name ASC';
        break;
      case 'name_asc':
        orderBy = 'item_name ASC';
        break;
      case 'due_date_asc':
      default:
        orderBy = 'CASE WHEN due_date IS NULL OR due_date = \'\' THEN 1 ELSE 0 END, due_date ASC, item_name ASC';
        break;
    }

    final where = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;
    final results = await database.query(
      AppTables.installments,
      where: where,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: orderBy,
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

  @override
  Future<Installment?> recalculateInstallment(String installmentId) async {
    final database = await _db;
    return _recalculateAndSave(database, installmentId);
  }

  Future<Installment?> _recalculateAndSave(Database database, String installmentId) async {
    final instResult = await database.query(
      AppTables.installments,
      where: 'id = ?',
      whereArgs: [installmentId],
    );
    if (instResult.isEmpty) return null;

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
    return updatedInst;
  }
}
