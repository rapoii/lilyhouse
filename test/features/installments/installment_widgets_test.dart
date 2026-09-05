import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilyhouse/core/theme/app_theme.dart';
import 'package:lilyhouse/features/installments/data/installment_repository.dart';
import 'package:lilyhouse/features/installments/domain/installment.dart';
import 'package:lilyhouse/features/installments/domain/installment_log.dart';
import 'package:lilyhouse/features/installments/presentation/installment_list_screen.dart';
import 'package:lilyhouse/features/installments/presentation/widgets/installment_card.dart';

class MockInstallmentRepository implements IInstallmentRepository {
  final List<Installment> _installments = [];
  final List<InstallmentLog> _logs = [];

  MockInstallmentRepository({
    List<Installment>? installments,
    List<InstallmentLog>? logs,
  }) {
    if (installments != null) _installments.addAll(installments);
    if (logs != null) _logs.addAll(logs);
  }

  @override
  Future<int> insertInstallment(Installment installment) async {
    _installments.removeWhere((i) => i.id == installment.id);
    _installments.add(installment);
    return 1;
  }

  @override
  Future<Installment?> getInstallmentById(String id) async {
    try {
      return _installments.firstWhere((i) => i.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Installment>> getAllInstallments() async {
    return List.from(_installments);
  }

  @override
  Future<List<Installment>> getInstallmentsByStatus(InstallmentStatus status) async {
    return _installments.where((i) => i.status == status).toList();
  }

  @override
  Future<int> updateInstallment(Installment installment) async {
    final idx = _installments.indexWhere((i) => i.id == installment.id);
    if (idx >= 0) {
      _installments[idx] = installment;
      return 1;
    }
    return 0;
  }

  @override
  Future<int> deleteInstallment(String id) async {
    _installments.removeWhere((i) => i.id == id);
    _logs.removeWhere((l) => l.installmentId == id);
    return 1;
  }

  @override
  Future<int> addPaymentLog(InstallmentLog log) async {
    _logs.removeWhere((l) => l.id == log.id);
    _logs.add(log);

    // Recalculate
    final instIdx = _installments.indexWhere((i) => i.id == log.installmentId);
    if (instIdx >= 0) {
      final current = _installments[instIdx];
      final relatedLogs = _logs.where((l) => l.installmentId == log.installmentId).toList();
      _installments[instIdx] = current.recalculateWithLogs(relatedLogs);
    }
    return 1;
  }

  @override
  Future<List<InstallmentLog>> getLogsForInstallment(String installmentId) async {
    return _logs.where((l) => l.installmentId == installmentId).toList();
  }

  @override
  Future<int> deletePaymentLog(String logId, String installmentId) async {
    _logs.removeWhere((l) => l.id == logId);
    final instIdx = _installments.indexWhere((i) => i.id == installmentId);
    if (instIdx >= 0) {
      final current = _installments[instIdx];
      final relatedLogs = _logs.where((l) => l.installmentId == installmentId).toList();
      _installments[instIdx] = current.recalculateWithLogs(relatedLogs);
    }
    return 1;
  }
}

void main() {
  group('InstallmentCard Widget Tests', () {
    testWidgets('Renders item details, progress percentage, and rounded pill progress bar', (tester) async {
      final installment = Installment(
        id: 'inst-card-1',
        itemName: 'Furina Fontaine Archon Gown',
        storeName: 'Uwowo Shop',
        totalCost: 1000000.0,
        totalPaid: 450000.0,
        remainingBalance: 550000.0,
        dueDate: DateTime(2026, 9, 25),
        status: InstallmentStatus.ongoing,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: InstallmentCard(
              installment: installment,
              onTap: () {},
            ),
          ),
        ),
      );

      // Verify texts
      expect(find.text('Furina Fontaine Archon Gown'), findsOneWidget);
      expect(find.text('Uwowo Shop'), findsOneWidget);
      expect(find.text('45%'), findsOneWidget); // 450k / 1000k = 45%
      expect(find.text('Rp 450.000'), findsOneWidget);
      expect(find.text('Rp 1.000.000'), findsOneWidget);
      expect(find.text('Sisa: Rp 550.000'), findsOneWidget);

      // Verify custom cute rounded pill progress bar exists
      expect(find.byKey(const Key('installment_progress_bar')), findsOneWidget);
    });

    testWidgets('Shows Paid Off / Lunas badge when installment is complete', (tester) async {
      final installment = Installment(
        id: 'inst-card-2',
        itemName: 'Hu Tao Ghost Plushie',
        storeName: 'Taobao Official',
        totalCost: 300000.0,
        totalPaid: 300000.0,
        remainingBalance: 0.0,
        status: InstallmentStatus.paidOff,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: InstallmentCard(
              installment: installment,
            ),
          ),
        ),
      );

      expect(find.text('100%'), findsOneWidget);
      expect(find.text('Lunas'), findsOneWidget);
    });
  });

  group('InstallmentListScreen & Ledger Sheet Tests', () {
    late MockInstallmentRepository repository;

    setUp(() {
      repository = MockInstallmentRepository(
        installments: [
          Installment(
            id: 'inst_ui_1',
            itemName: 'Kamisato Ayaka Kimono',
            storeName: 'Miaowu',
            totalCost: 900000.0,
            totalPaid: 300000.0,
            remainingBalance: 600000.0,
            status: InstallmentStatus.ongoing,
          ),
        ],
        logs: [
          InstallmentLog(
            id: 'log_ui_1',
            installmentId: 'inst_ui_1',
            paymentDate: DateTime(2026, 9, 1),
            amountPaid: 300000.0,
            notes: 'Cicilan 1',
          ),
        ],
      );
    });

    testWidgets('Renders list of installments and opens payment history bottom sheet', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: InstallmentListScreen(repository: repository),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Kamisato Ayaka Kimono'), findsOneWidget);
      expect(find.text('Miaowu'), findsOneWidget);

      // Tap on card to open ledger / payment history bottom sheet
      await tester.tap(find.text('Kamisato Ayaka Kimono'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify payment history sheet opened
      expect(find.text('Riwayat Cicilan'), findsOneWidget);
      expect(find.text('Cicilan 1'), findsOneWidget);
      expect(find.text('+ Catat Pembayaran'), findsOneWidget);
    });

    testWidgets('Allows adding a new installment payment log from the bottom sheet', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: InstallmentListScreen(repository: repository),
        ),
      );
      await tester.pump();
      await tester.pump();

      // Open sheet
      await tester.tap(find.text('Kamisato Ayaka Kimono'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap "+ Catat Pembayaran"
      await tester.tap(find.text('+ Catat Pembayaran'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify add payment dialog appears
      expect(find.text('Catat Pembayaran Cicilan'), findsOneWidget);

      // Enter amount and notes
      await tester.enterText(find.byKey(const Key('payment_amount_input')), '600000');
      await tester.enterText(find.byKey(const Key('payment_notes_input')), 'Pelunasan Akhir');
      await tester.pump();

      // Tap Simpan
      await tester.tap(find.text('Simpan'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify installment is now paid off (100% / Lunas)
      final updated = await repository.getInstallmentById('inst_ui_1');
      expect(updated!.isPaidOff, isTrue);
      expect(updated.totalPaid, 900000.0);
      expect(updated.remainingBalance, 0.0);
    });
  });
}
