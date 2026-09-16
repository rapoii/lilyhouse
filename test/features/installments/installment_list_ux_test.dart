import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilyhouse/core/theme/app_theme.dart';
import 'package:lilyhouse/core/widgets/skeleton_loader.dart';
import 'package:lilyhouse/features/installments/data/installment_repository.dart';
import 'package:lilyhouse/features/installments/domain/installment.dart';
import 'package:lilyhouse/features/installments/domain/installment_log.dart';
import 'package:lilyhouse/features/installments/presentation/installment_list_screen.dart';

/// Minimal in-memory installment repository.  A supplied [gate] keeps the
/// search pending so the skeleton state is observable.
class _InstallmentRepo implements IInstallmentRepository {
  _InstallmentRepo({List<Installment>? installments, this.gate})
      : _installments = <Installment>[...?installments];

  final List<Installment> _installments;
  final Completer<void>? gate;

  int searchCallCount = 0;

  @override
  Future<List<Installment>> searchInstallments({
    String? query,
    InstallmentStatus? status,
    String sortBy = 'due_date_asc',
    bool dueSoon = false,
    DateTime? now,
  }) async {
    searchCallCount++;
    if (gate != null) await gate!.future;
    var list = List<Installment>.from(_installments);
    if (status != null) {
      list = list.where((i) => i.status == status).toList();
    }
    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      list = list
          .where((i) =>
              i.itemName.toLowerCase().contains(q) ||
              (i.storeName?.toLowerCase().contains(q) ?? false))
          .toList();
    }
    return list;
  }

  @override
  Future<List<Installment>> getAllInstallments() async =>
      List<Installment>.from(_installments);

  @override
  Future<List<Installment>> getInstallmentsByStatus(
          InstallmentStatus status) async =>
      _installments.where((i) => i.status == status).toList();

  @override
  Future<Installment?> getInstallmentById(String id) async {
    for (final i in _installments) {
      if (i.id == id) return i;
    }
    return null;
  }

  @override
  Future<int> insertInstallment(Installment installment) async {
    _installments.removeWhere((i) => i.id == installment.id);
    _installments.add(installment);
    return 1;
  }

  @override
  Future<int> updateInstallment(Installment installment) async => 1;

  @override
  Future<int> deleteInstallment(String id) async {
    _installments.removeWhere((i) => i.id == id);
    return 1;
  }

  @override
  Future<int> addPaymentLog(InstallmentLog log) async => 1;

  @override
  Future<List<InstallmentLog>> getLogsForInstallment(String installmentId) async =>
      const <InstallmentLog>[];

  @override
  Future<int> deletePaymentLog(String logId, String installmentId) async => 1;

  @override
  Future<Installment?> recalculateInstallment(String installmentId) async => null;
}

Installment _inst(String id, String name, String store) => Installment(
      id: id,
      itemName: name,
      storeName: store,
      totalCost: 900000.0,
      totalPaid: 300000.0,
      remainingBalance: 600000.0,
      status: InstallmentStatus.ongoing,
    );

Widget _wrap(IInstallmentRepository repo) => MaterialApp(
      theme: AppTheme.lightTheme,
      home: InstallmentListScreen(repository: repo),
    );

void main() {
  group('InstallmentListScreen search debounce', () {
    testWidgets('waits 300 ms before applying the typed query', (tester) async {
      final repo = _InstallmentRepo(installments: [
        _inst('i1', 'Kamisato Ayaka Kimono', 'Miaowu'),
        _inst('i2', 'Raiden Shogun Dress', 'Uwowo'),
      ]);
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      expect(find.text('Kamisato Ayaka Kimono'), findsOneWidget);
      expect(find.text('Raiden Shogun Dress'), findsOneWidget);

      await tester.enterText(find.byType(CupertinoSearchTextField), 'Raiden');
      await tester.pump();

      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Kamisato Ayaka Kimono'), findsOneWidget,
          reason: 'debounce must not fire before 300 ms');

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();

      expect(find.text('Raiden Shogun Dress'), findsOneWidget);
      expect(find.text('Kamisato Ayaka Kimono'), findsNothing);
    });

    testWidgets('coalesces a burst of keystrokes into one query', (tester) async {
      final repo = _InstallmentRepo(installments: [
        _inst('i1', 'Kamisato Ayaka Kimono', 'Miaowu'),
        _inst('i2', 'Raiden Shogun Dress', 'Uwowo'),
      ]);
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      final before = repo.searchCallCount;

      await tester.enterText(find.byType(CupertinoSearchTextField), 'R');
      await tester.pump(const Duration(milliseconds: 80));
      await tester.enterText(find.byType(CupertinoSearchTextField), 'Ra');
      await tester.pump(const Duration(milliseconds: 80));
      await tester.enterText(find.byType(CupertinoSearchTextField), 'Rai');
      await tester.pump(const Duration(milliseconds: 80));

      expect(repo.searchCallCount, before);

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(repo.searchCallCount, before + 1);
    });
  });

  group('InstallmentListScreen result-count indicator', () {
    testWidgets('shows the unfiltered list size', (tester) async {
      final repo = _InstallmentRepo(installments: [
        _inst('i1', 'Kamisato Ayaka Kimono', 'Miaowu'),
        _inst('i2', 'Raiden Shogun Dress', 'Uwowo'),
      ]);
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('installment_result_count')), findsOneWidget);
      expect(find.text('2 cicilan'), findsOneWidget);
    });

    testWidgets('switches to a filtered count when searching', (tester) async {
      final repo = _InstallmentRepo(installments: [
        _inst('i1', 'Kamisato Ayaka Kimono', 'Miaowu'),
        _inst('i2', 'Raiden Shogun Dress', 'Uwowo'),
      ]);
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(CupertinoSearchTextField), 'Raiden');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(find.byKey(const Key('installment_result_count')), findsOneWidget);
      expect(find.text('1 hasil'), findsOneWidget);
      expect(find.text('2 cicilan'), findsNothing);
    });

    testWidgets('hides the indicator when nothing matches', (tester) async {
      final repo = _InstallmentRepo(installments: [
        _inst('i1', 'Kamisato Ayaka Kimono', 'Miaowu'),
      ]);
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byType(CupertinoSearchTextField), 'zzz-no-match');
      await tester.pump(const Duration(milliseconds: 300));
      // Let the content → empty crossfade finish; AnimatedSwitcher keeps the
      // outgoing content (and its count chip) mounted during the 220 ms fade.
      await tester.pumpAndSettle();

      expect(find.text('Tidak ada cicilan yang cocok'), findsOneWidget);
      expect(find.byKey(const Key('installment_result_count')), findsNothing);
    });
  });

  group('InstallmentListScreen skeleton loading', () {
    testWidgets('shows skeleton placeholders while the first fetch is pending',
        (tester) async {
      final gate = Completer<void>();
      final repo = _InstallmentRepo(
        installments: [_inst('i1', 'Kamisato Ayaka Kimono', 'Miaowu')],
        gate: gate,
      );

      await tester.pumpWidget(_wrap(repo));
      await tester.pump();

      expect(find.byType(SkeletonLoader), findsOneWidget);
      expect(find.byKey(const Key('skeleton_item_0')), findsOneWidget);
      expect(find.byType(CupertinoActivityIndicator), findsNothing);

      gate.complete();
      await tester.pumpAndSettle();

      expect(find.byType(SkeletonLoader), findsNothing);
      expect(find.text('Kamisato Ayaka Kimono'), findsOneWidget);
    });
  });
}
