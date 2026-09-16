import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilyhouse/core/theme/app_theme.dart';
import 'package:lilyhouse/features/installments/data/installment_repository.dart';
import 'package:lilyhouse/features/installments/domain/installment.dart';
import 'package:lilyhouse/features/installments/domain/installment_log.dart';
import 'package:lilyhouse/features/installments/presentation/installment_list_screen.dart';
import 'package:lilyhouse/features/installments/presentation/installment_detail_screen.dart';
import 'package:lilyhouse/features/installments/presentation/widgets/add_payment_sheet.dart';
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
  Future<List<Installment>> searchInstallments({
    String? query,
    InstallmentStatus? status,
    String sortBy = 'due_date_asc',
    bool dueSoon = false,
    DateTime? now,
  }) async {
    List<Installment> list = status != null
        ? _installments.where((i) => i.status == status).toList()
        : List.from(_installments);
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
    return list;
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

  @override
  Future<Installment?> recalculateInstallment(String installmentId) async {
    final inst = await getInstallmentById(installmentId);
    if (inst == null) return null;
    final relatedLogs = _logs.where((l) => l.installmentId == installmentId).toList();
    final updated = inst.recalculateWithLogs(relatedLogs);
    final instIdx = _installments.indexWhere((i) => i.id == installmentId);
    if (instIdx >= 0) {
      _installments[instIdx] = updated;
    }
    return updated;
  }
}

void main() {
  group('InstallmentCard Widget Tests', () {
    testWidgets('Renders item title, status badge, remaining balance, and sleek progress bar', (tester) async {
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

      // Verify 3 essential elements: Title, Status Badge, Remaining Balance
      expect(find.text('Furina Fontaine Archon Gown'), findsOneWidget);
      expect(find.text('Cicilan'), findsOneWidget);
      expect(find.text('Sisa Rp 550.000'), findsOneWidget);

      // Verify sleek progress bar exists
      expect(find.byKey(const Key('installment_progress_bar')), findsOneWidget);
    });

    testWidgets('Shows Paid Off / Lunas badge and Lunas Sepenuhnya when installment is complete', (tester) async {
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

      expect(find.text('Lunas Sepenuhnya'), findsOneWidget);
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

      // Tap on card to open ledger / payment history bottom sheet
      await tester.tap(find.text('Kamisato Ayaka Kimono'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify payment history sheet opened
      expect(find.text('RIWAYAT CICILAN'), findsOneWidget);
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
      await tester.pump(const Duration(seconds: 3));

      // Verify installment is now paid off (100% / Lunas)
      final updated = await repository.getInstallmentById('inst_ui_1');
      expect(updated!.isPaidOff, isTrue);
      expect(updated.totalPaid, 900000.0);
      expect(updated.remainingBalance, 0.0);
    });

    testWidgets('Renders Apple HIG Detail Cicilan modal sheet with centered nominal when no notes', (tester) async {
      final customRepo = MockInstallmentRepository(
        installments: [
          Installment(
            id: 'inst_test_furina',
            itemName: 'Wig_Furina',
            storeName: 'Taobao_Cos',
            totalCost: 300000.0,
            totalPaid: 300000.0,
            remainingBalance: 0.0,
            status: InstallmentStatus.paidOff,
          ),
        ],
        logs: [
          InstallmentLog(
            id: 'log_1',
            installmentId: 'inst_test_furina',
            paymentDate: DateTime(2026, 9, 10),
            amountPaid: 200000.0,
            notes: null, // No notes: title should be vertically centered, subtitle null
          ),
          InstallmentLog(
            id: 'log_2',
            installmentId: 'inst_test_furina',
            paymentDate: DateTime(2026, 9, 10),
            amountPaid: 100000.0,
            notes: 'DP Awal',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: InstallmentListScreen(repository: customRepo),
        ),
      );
      await tester.pump();
      await tester.pump();

      // Tap on Wig Furina to open sheet
      await tester.tap(find.text('Wig Furina'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Apple HIG nav bar and sections
      expect(find.text('Rincian Cicilan'), findsOneWidget);
      expect(find.text('Tutup'), findsOneWidget);
      expect(find.text('INFORMASI BARANG'), findsOneWidget);
      expect(find.text('RINGKASAN PEMBAYARAN'), findsOneWidget);
      expect(find.text('RIWAYAT CICILAN'), findsOneWidget);

      // Verify items rendered
      expect(find.text('Rp 200.000'), findsOneWidget);
      expect(find.text('Rp 100.000'), findsOneWidget);
      expect(find.text('DP Awal'), findsOneWidget);

      // Verify CupertinoListTile for log_1 has null subtitle (vertically centered)
      final tileFinder = find.ancestor(
        of: find.text('Rp 200.000'),
        matching: find.byType(CupertinoListTile),
      );
      expect(tileFinder, findsOneWidget);
      final tileWidget = tester.widget<CupertinoListTile>(tileFinder);
      expect(tileWidget.subtitle, isNull);

      // Verify CupertinoListTile for log_2 has non-null subtitle ("DP Awal")
      final tileWithNoteFinder = find.ancestor(
        of: find.text('Rp 100.000'),
        matching: find.byType(CupertinoListTile),
      );
      expect(tileWithNoteFinder, findsOneWidget);
      final tileWithNoteWidget = tester.widget<CupertinoListTile>(tileWithNoteFinder);
      expect(tileWithNoteWidget.subtitle, isNotNull);
    });

    testWidgets('AddPaymentSheet correctly handles dot thousand separator and logs payment', (tester) async {
      final inst = Installment(
        id: 'inst_test',
        itemName: 'Costume A',
        totalCost: 100000.0,
        totalPaid: 0.0,
        remainingBalance: 100000.0,
        status: InstallmentStatus.ongoing,
        dueDate: DateTime.now().add(const Duration(days: 7)),
      );
      final repo = MockInstallmentRepository(installments: [inst]);
      bool saved = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (ctx) => CupertinoButton(
                child: const Text('Open'),
                onPressed: () {
                  showCupertinoModalPopup<void>(
                    context: ctx,
                    builder: (_) => AddPaymentSheet(
                      installment: inst,
                      repository: repo,
                      onSaved: () => saved = true,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Enter amount with dot separator "50.000"
      await tester.enterText(find.byKey(const Key('payment_amount_input')), '50.000');
      await tester.pump();

      // Tap Simpan
      await tester.tap(find.text('Simpan'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(saved, isTrue);
      expect(repo._logs.length, 1);
      expect(repo._logs.first.amountPaid, 50000.0);
    });

    testWidgets('AddPaymentSheet prevents overpayment when amount exceeds remaining balance', (tester) async {
      final inst = Installment(
        id: 'inst_overpay',
        itemName: 'Wig Hu Tao',
        totalCost: 500000.0,
        totalPaid: 300000.0,
        remainingBalance: 200000.0,
        status: InstallmentStatus.ongoing,
      );
      final repo = MockInstallmentRepository(installments: [inst]);
      bool saved = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (ctx) => CupertinoButton(
                child: const Text('Open'),
                onPressed: () {
                  showCupertinoModalPopup<void>(
                    context: ctx,
                    builder: (_) => AddPaymentSheet(
                      installment: inst,
                      repository: repo,
                      onSaved: () => saved = true,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Try paying 500.000 when remaining is only 200.000
      await tester.enterText(find.byKey(const Key('payment_amount_input')), '500.000');
      await tester.pump();

      // Tap Simpan
      await tester.tap(find.text('Simpan'));
      await tester.pump();

      // Verify validation error is displayed and not saved
      expect(find.byKey(const Key('payment_error_message')), findsOneWidget);
      expect(find.textContaining('Nominal melebihi sisa utang (Rp 200.000)'), findsOneWidget);
      expect(saved, isFalse);
      expect(repo._logs.isEmpty, isTrue);
    });

    testWidgets('AddPaymentSheet Bayar Lunas shortcut fills remaining balance directly', (tester) async {
      final inst = Installment(
        id: 'inst_shortcut',
        itemName: 'Sepatu Boots Cosplay',
        totalCost: 350000.0,
        totalPaid: 150000.0,
        remainingBalance: 200000.0,
        status: InstallmentStatus.ongoing,
      );
      final repo = MockInstallmentRepository(installments: [inst]);
      bool saved = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (ctx) => CupertinoButton(
                child: const Text('Open'),
                onPressed: () {
                  showCupertinoModalPopup<void>(
                    context: ctx,
                    builder: (_) => AddPaymentSheet(
                      installment: inst,
                      repository: repo,
                      onSaved: () => saved = true,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Bayar Lunas button exists
      final shortcutButton = find.byKey(const Key('shortcut_pay_in_full_button'));
      expect(shortcutButton, findsOneWidget);

      // Tap Bayar Lunas
      await tester.tap(shortcutButton);
      await tester.pump();

      // Input should now be formatted with 200.000
      final textField = tester.widget<CupertinoTextField>(find.byKey(const Key('payment_amount_input')));
      expect(textField.controller!.text, '200.000');

      // Tap Simpan and verify payment successful
      await tester.tap(find.text('Simpan'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(saved, isTrue);
      expect(repo._logs.length, 1);
      expect(repo._logs.first.amountPaid, 200000.0);
    });

    testWidgets('AddPaymentSheet displays payment date row with default today and opens date picker', (tester) async {
      final inst = Installment(
        id: 'inst_date_test',
        itemName: 'Pedang Nichirin',
        totalCost: 250000.0,
        totalPaid: 0.0,
        remainingBalance: 250000.0,
        status: InstallmentStatus.ongoing,
      );
      final repo = MockInstallmentRepository(installments: [inst]);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (ctx) => CupertinoButton(
                child: const Text('Open'),
                onPressed: () {
                  showCupertinoModalPopup<void>(
                    context: ctx,
                    builder: (_) => AddPaymentSheet(
                      installment: inst,
                      repository: repo,
                      onSaved: () {},
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Tanggal Bayar label and "(Hari ini)" display
      expect(find.text('Tanggal Bayar'), findsOneWidget);
      expect(find.byKey(const Key('payment_date_value_text')), findsOneWidget);
      expect(find.textContaining('(Hari ini)'), findsOneWidget);

      // Tap date picker row
      await tester.tap(find.byKey(const Key('payment_date_picker_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify date picker modal sheet appears
      expect(find.text('Pilih Tanggal Bayar'), findsOneWidget);
      expect(find.text('Selesai'), findsOneWidget);
      expect(find.text('Batal'), findsNWidgets(2)); // 1 in AddPaymentSheet header, 1 in date picker sheet

      // Tap Selesai in picker
      await tester.tap(find.text('Selesai'));
      await tester.pumpAndSettle();
    });

    testWidgets('InstallmentDetailScreen renders Ubah button and opens EditInstallmentSheet to update details', (tester) async {
      final initialInstallment = Installment(
        id: 'inst_edit_1',
        itemName: 'Staff of Homa',
        storeName: 'Mihoyo Shop',
        totalCost: 500000.0,
        totalPaid: 100000.0,
        remainingBalance: 400000.0,
        dueDate: DateTime(2026, 10, 15),
        status: InstallmentStatus.ongoing,
      );

      final repo = MockInstallmentRepository(
        installments: [initialInstallment],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: InstallmentDetailScreen(
            installmentId: 'inst_edit_1',
            repository: repo,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      // Verify item details shown on detail screen
      expect(find.text('Staff of Homa'), findsOneWidget);
      expect(find.text('Mihoyo Shop'), findsOneWidget);

      // Verify "Ubah" button exists in header bar
      final editButton = find.byKey(const Key('edit_installment_button'));
      expect(editButton, findsOneWidget);

      // Tap Ubah
      await tester.tap(editButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify EditInstallmentSheet is displayed
      expect(find.text('Ubah Cicilan'), findsOneWidget);
      expect(find.byKey(const Key('edit_installment_name_input')), findsOneWidget);
      expect(find.byKey(const Key('edit_installment_store_input')), findsOneWidget);
      expect(find.byKey(const Key('edit_installment_due_date_row')), findsOneWidget);

      // Modify item name and store name
      await tester.enterText(find.byKey(const Key('edit_installment_name_input')), 'Staff of Homa R5');
      await tester.enterText(find.byKey(const Key('edit_installment_store_input')), 'Official Genshin Store');
      await tester.pump();

      // Clear due date
      await tester.tap(find.byKey(const Key('clear_due_date_button')));
      await tester.pump();

      // Tap Simpan in modal sheet
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();

      // Verify data updated in repository
      final updated = await repo.getInstallmentById('inst_edit_1');
      expect(updated, isNotNull);
      expect(updated!.itemName, 'Staff of Homa R5');
      expect(updated.storeName, 'Official Genshin Store');
      expect(updated.dueDate, isNull);

      // Verify screen reflects updated data
      expect(find.text('Staff of Homa R5'), findsOneWidget);
      expect(find.text('Official Genshin Store'), findsOneWidget);
    });

    testWidgets('InstallmentListScreen displays Apple HIG Financial Summary Card with total debt and active count', (tester) async {
      final summaryRepo = MockInstallmentRepository(
        installments: [
          Installment(
            id: 'inst_sum_1',
            itemName: 'Costume Raiden Shogun',
            storeName: 'Uwowo',
            totalCost: 1500000.0,
            totalPaid: 500000.0,
            remainingBalance: 1000000.0,
            status: InstallmentStatus.ongoing,
          ),
          Installment(
            id: 'inst_sum_2',
            itemName: 'Wig Arlecchino',
            storeName: 'DokiDoki',
            totalCost: 350000.0,
            totalPaid: 150000.0,
            remainingBalance: 200000.0,
            status: InstallmentStatus.ongoing,
          ),
          Installment(
            id: 'inst_sum_3',
            itemName: 'Sepatu Furina',
            storeName: 'Taobao',
            totalCost: 250000.0,
            totalPaid: 250000.0,
            remainingBalance: 0.0,
            status: InstallmentStatus.paidOff,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: InstallmentListScreen(repository: summaryRepo),
        ),
      );
      await tester.pump();
      await tester.pump();

      // Verify Summary Card exists
      expect(find.byKey(const Key('installment_summary_card')), findsOneWidget);
      expect(find.text('RINGKASAN FINANSIAL CICILAN'), findsOneWidget);
      expect(find.text('Total Sisa Utang'), findsOneWidget);

      // Remaining debt: 1.000.000 + 200.000 = 1.200.000
      expect(find.text('Rp 1.200.000'), findsOneWidget);

      // Active count badge: 2 aktif (since 1 is paid off)
      expect(find.text('2 Aktif'), findsOneWidget);
    });

    testWidgets('InstallmentListScreen creates new installment sanitizing dot and comma thousand separators', (tester) async {
      final newRepo = MockInstallmentRepository(installments: []);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: InstallmentListScreen(repository: newRepo),
        ),
      );
      await tester.pump();
      await tester.pump();

      // Open Add Installment dialog
      final addButton = find.byKey(const Key('add_installment_button'));
      expect(addButton, findsOneWidget);
      await tester.tap(addButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Check dialog opened
      expect(find.text('Cicilan Baru'), findsOneWidget);

      // Enter form data with dots and commas in numbers
      await tester.enterText(find.byKey(const Key('installment_name_input')), 'Kostum Nahida');
      await tester.enterText(find.byKey(const Key('installment_store_input')), 'Uwowo Store');
      await tester.enterText(find.byKey(const Key('installment_cost_input')), '1.500.000');
      await tester.enterText(find.byKey(const Key('installment_dp_input')), '500,000');
      await tester.pump();

      // Tap Simpan
      await tester.tap(find.text('Simpan'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));

      // Verify repository has the properly parsed installment
      final all = await newRepo.getAllInstallments();
      expect(all.length, 1);
      final created = all.first;
      expect(created.itemName, 'Kostum Nahida');
      expect(created.totalCost, 1500000.0);
      expect(created.totalPaid, 500000.0);
      expect(created.remainingBalance, 1000000.0);
      expect(created.status, InstallmentStatus.ongoing);

      // Verify Summary Card updates on screen
      expect(find.byKey(const Key('installment_summary_card')), findsOneWidget);
      expect(find.text('Rp 1.000.000'), findsWidgets);
      expect(find.text('1 Aktif'), findsOneWidget);
    });
  });

  group('Jatuh Tempo Dekat Badge Tests', () {

    Widget harness(Installment installment) => MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: InstallmentCard(installment: installment),
          ),
        );

    // Dates are relative to today because the badge reads the real clock.
    DateTime daysFromToday(int offset) {
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day).add(Duration(days: offset));
    }

    testWidgets('Renders overdue badge with "Terlambat X hari" for past due dates', (tester) async {
      await tester.pumpWidget(
        harness(Installment(
          id: 'late-1',
          itemName: 'Nahida Cosplay',
          totalCost: 1000000.0,
          totalPaid: 400000.0,
          dueDate: daysFromToday(-7),
          status: InstallmentStatus.ongoing,
        )),
      );

      expect(find.byKey(const Key('installment_due_soon_badge')), findsOneWidget);
      expect(find.text('Terlambat 7 hari'), findsOneWidget);
    });

    testWidgets('Renders due-soon badge with "X hari lagi" within 7 days', (tester) async {
      await tester.pumpWidget(
        harness(Installment(
          id: 'soon-1',
          itemName: 'Nahida Cosplay',
          totalCost: 1000000.0,
          totalPaid: 400000.0,
          dueDate: daysFromToday(7),
          status: InstallmentStatus.ongoing,
        )),
      );

      expect(find.byKey(const Key('installment_due_soon_badge')), findsOneWidget);
      expect(find.text('7 hari lagi'), findsOneWidget);
    });

    testWidgets('Hides the badge when due date is more than 7 days away', (tester) async {
      await tester.pumpWidget(
        harness(Installment(
          id: 'far-1',
          itemName: 'Nahida Cosplay',
          totalCost: 1000000.0,
          totalPaid: 400000.0,
          dueDate: DateTime(2026, 10, 30),
          status: InstallmentStatus.ongoing,
        )),
      );

      expect(find.byKey(const Key('installment_due_soon_badge')), findsNothing);
    });

    testWidgets('Hides the badge when there is no due date', (tester) async {
      await tester.pumpWidget(
        harness(Installment(
          id: 'nodate-1',
          itemName: 'Nahida Cosplay',
          totalCost: 1000000.0,
          totalPaid: 400000.0,
          status: InstallmentStatus.ongoing,
        )),
      );

      expect(find.byKey(const Key('installment_due_soon_badge')), findsNothing);
    });

    testWidgets('Hides the badge when the installment is paid off', (tester) async {
      await tester.pumpWidget(
        harness(Installment(
          id: 'paid-1',
          itemName: 'Nahida Cosplay',
          totalCost: 1000000.0,
          totalPaid: 1000000.0,
          dueDate: DateTime(2020, 1, 1),
          status: InstallmentStatus.paidOff,
        )),
      );

      expect(find.byKey(const Key('installment_due_soon_badge')), findsNothing);
    });
  });

  group('AddPaymentSheet Running Summary Tests', () {
    testWidgets('Shows overdue warning, progress, and payment stats', (tester) async {
      final now = DateTime.now();
      final overdueDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7));
      final installment = Installment(
        id: 'inst-pay-late',
        itemName: 'Furina Gown',
        totalCost: 1000000.0,
        totalPaid: 400000.0,
        dueDate: overdueDate,
        status: InstallmentStatus.ongoing,
      );
      final repo = MockInstallmentRepository(
        installments: [
          Installment(
            id: 'inst-pay-late',
            itemName: 'Furina Gown',
            totalCost: 1000000.0,
            totalPaid: 400000.0,
            dueDate: overdueDate,
            status: InstallmentStatus.ongoing,
          ),
        ],
        logs: [
          InstallmentLog(id: 'l1', installmentId: 'inst-pay-late', paymentDate: DateTime(2026, 8, 1), amountPaid: 200000),
          InstallmentLog(id: 'l2', installmentId: 'inst-pay-late', paymentDate: DateTime(2026, 9, 1), amountPaid: 200000),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: AddPaymentSheet(
              installment: installment,
              repository: repo,
              onSaved: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('add_payment_overdue_warning')), findsOneWidget);
      expect(find.byKey(const Key('add_payment_progress_bar')), findsOneWidget);
      expect(find.byKey(const Key('add_payment_last_payment')), findsOneWidget);
      expect(find.byKey(const Key('add_payment_average')), findsOneWidget);
      expect(find.byKey(const Key('add_payment_estimated_remaining')), findsOneWidget);
      expect(find.text('Terlambat 7 hari'), findsOneWidget);
      expect(find.text('2x pembayaran'), findsOneWidget);
      // Rata-rata 200000, sisa 600000 -> 3x lagi
      expect(find.text('3x lagi'), findsOneWidget);
    });

    testWidgets('Hides overdue warning and stats when paid on time', (tester) async {
      final installment = Installment(
        id: 'inst-pay-ok',
        itemName: 'Furina Gown',
        totalCost: 1000000.0,
        totalPaid: 400000.0,
        dueDate: DateTime(2027, 1, 1),
        status: InstallmentStatus.ongoing,
      );
      final repo = MockInstallmentRepository(
        installments: [
          Installment(
            id: 'inst-pay-ok',
            itemName: 'Furina Gown',
            totalCost: 1000000.0,
            totalPaid: 400000.0,
            dueDate: DateTime(2027, 1, 1),
            status: InstallmentStatus.ongoing,
          ),
        ],
        logs: [
          InstallmentLog(id: 'l1', installmentId: 'inst-pay-ok', paymentDate: DateTime(2026, 9, 1), amountPaid: 400000),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: AddPaymentSheet(
              installment: installment,
              repository: repo,
              onSaved: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('add_payment_overdue_warning')), findsNothing);
      expect(find.byKey(const Key('add_payment_last_payment')), findsOneWidget);
      expect(find.text('1x pembayaran'), findsOneWidget);
    });
  });
}
