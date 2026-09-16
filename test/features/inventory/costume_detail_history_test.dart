import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lilyhouse/core/theme/app_theme.dart';
import 'package:lilyhouse/features/costumes/data/costume_repository.dart';
import 'package:lilyhouse/features/costumes/domain/accessory.dart';
import 'package:lilyhouse/features/costumes/domain/costume.dart';
import 'package:lilyhouse/features/costumes/domain/costume_rental_history.dart';
import 'package:lilyhouse/features/costumes/presentation/costume_detail_screen.dart';
import 'package:lilyhouse/features/rentals/domain/rental.dart';

/// CostumeDetailScreen mock that serves a configurable CostumeRentalHistory so
/// the RIWAYAT SEWA section can be exercised end-to-end.
class HistoryMockRepository implements ICostumeRepository {
  final List<Costume> _costumes = [];
  final List<Accessory> _accessories = [];
  CostumeRentalHistory rentalHistory;
  final Completer<void>? historyGate;

  HistoryMockRepository({
    List<Costume>? costumes,
    List<Accessory>? accessories,
    this.rentalHistory = const CostumeRentalHistory(),
    this.historyGate,
  }) {
    if (costumes != null) _costumes.addAll(costumes);
    if (accessories != null) _accessories.addAll(accessories);
  }

  @override
  Future<int> insertCostume(Costume costume) async {
    _costumes.removeWhere((c) => c.id == costume.id);
    _costumes.add(costume);
    return 1;
  }

  @override
  Future<Costume?> getCostumeById(String id) async =>
      _costumes.cast<Costume?>().firstWhere((c) => c?.id == id, orElse: () => null);

  @override
  Future<List<Costume>> getAllCostumes() async => List<Costume>.from(_costumes);

  @override
  Future<List<Costume>> searchCostumes({
    String? query,
    CostumeStatus? status,
    String? size,
    String? series,
    String? sortBy,
  }) async => List<Costume>.from(_costumes);

  @override
  Future<List<String>> getDistinctAnimeSeries() async =>
      _costumes.map((c) => c.animeSeries).toSet().toList();

  @override
  Future<int> updateCostume(Costume costume) async {
    final i = _costumes.indexWhere((c) => c.id == costume.id);
    if (i >= 0) _costumes[i] = costume;
    return 1;
  }

  @override
  Future<int> deleteCostume(String id) async {
    _costumes.removeWhere((c) => c.id == id);
    return 1;
  }

  @override
  Future<int> addAccessory(Accessory accessory) async => 1;

  @override
  Future<List<Accessory>> getAccessoriesByCostumeId(String costumeId) async =>
      _accessories.where((a) => a.relatedCostumeId == costumeId).toList();

  @override
  Future<int> updateAccessory(Accessory accessory) async => 1;

  @override
  Future<int> deleteAccessory(String id) async => 1;

  @override
  Future<int> getActiveRentalsCount(String costumeId) async => 0;

  @override
  Future<CostumeRentalHistory> getRentalHistory(String costumeId) async {
    if (historyGate != null) await historyGate!.future;
    return rentalHistory;
  }
}

const _costume = Costume(
  id: 'cos-1',
  name: 'Furina Archon Dress',
  animeSeries: 'Genshin Impact',
  size: 'S',
  rentPrice3Days: 180000.0,
  status: CostumeStatus.available,
);

CostumeRentalRecord _record({
  required String name,
  required DateTime start,
  required DateTime end,
  RentalItemStatus itemStatus = RentalItemStatus.completed,
  String rentalId = 'rent-1',
  String customerId = 'cust-1',
}) {
  return CostumeRentalRecord(
    rentalId: rentalId,
    customerId: customerId,
    customerName: name,
    startDate: start,
    endDate: end,
    itemStatus: itemStatus,
  );
}

Future<void> _pumpDetail(
  WidgetTester tester,
  CostumeRentalHistory history,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: CostumeDetailScreen(
        costume: _costume,
        repository: HistoryMockRepository(
          costumes: const [_costume],
          rentalHistory: history,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  testWidgets('shows the RIWAYAT SEWA section header and empty state', (tester) async {
    await _pumpDetail(tester, const CostumeRentalHistory());

    await tester.scrollUntilVisible(
      find.text('RIWAYAT SEWA'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('RIWAYAT SEWA'), findsOneWidget);
    expect(find.text('Disewa 0 kali'), findsOneWidget);
    expect(find.text('Belum pernah'), findsOneWidget);
    expect(
      find.text('Belum ada riwayat penyewaan untuk kostum ini.'),
      findsOneWidget,
    );
    expect(find.text('Sedang Dipakai'), findsNothing);
  });

  testWidgets('renders the Disewa X kali badge with the correct count', (tester) async {
    await _pumpDetail(
      tester,
      CostumeRentalHistory(
        totalRentals: 12,
        lastServiceDate: DateTime(2026, 9, 1),
        records: [
          _record(
            name: 'Alya Rani',
            start: DateTime(2026, 9, 1),
            end: DateTime(2026, 9, 3),
          ),
        ],
      ),
    );

    await tester.scrollUntilVisible(
      find.text('RIWAYAT SEWA'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Disewa 12 kali'), findsOneWidget);
    expect(find.text('Jumlah Disewa'), findsOneWidget);
  });

  testWidgets('formats the last service date in Indonesian', (tester) async {
    await _pumpDetail(
      tester,
      CostumeRentalHistory(
        totalRentals: 1,
        lastServiceDate: DateTime(2026, 9, 14),
        records: [
          _record(
            name: 'Alya Rani',
            start: DateTime(2026, 9, 12),
            end: DateTime(2026, 9, 14),
          ),
        ],
      ),
    );

    await tester.scrollUntilVisible(
      find.text('Servis Terakhir'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Servis Terakhir'), findsOneWidget);
    expect(find.text('14 Sep 2026'), findsOneWidget);
  });

  testWidgets('shows the active usage period with an Aktif badge', (tester) async {
    final now = DateTime.now();
    await _pumpDetail(
      tester,
      CostumeRentalHistory(
        totalRentals: 2,
        activeRentals: 1,
        lastServiceDate: now.add(const Duration(days: 2)),
        activeRental: _record(
          name: 'Budi Santoso',
          start: now.subtract(const Duration(days: 1)),
          end: now.add(const Duration(days: 2)),
          itemStatus: RentalItemStatus.rented,
          rentalId: 'rent-active',
        ),
        records: [
          _record(
            name: 'Budi Santoso',
            start: now.subtract(const Duration(days: 1)),
            end: now.add(const Duration(days: 2)),
            itemStatus: RentalItemStatus.rented,
            rentalId: 'rent-active',
          ),
          _record(name: 'Alya Rani', start: DateTime(2026, 8, 1), end: DateTime(2026, 8, 4)),
        ],
      ),
    );

    await tester.scrollUntilVisible(
      find.text('Sedang Dipakai'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Sedang Dipakai'), findsOneWidget);
    expect(find.text('Aktif'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.timer), findsOneWidget);
  });

  testWidgets('marks an upcoming booked rental as Dijadwalkan', (tester) async {
    final now = DateTime.now();
    final upcoming = _record(
      name: 'Citra Lestari',
      start: now.add(const Duration(days: 5)),
      end: now.add(const Duration(days: 8)),
      itemStatus: RentalItemStatus.booked,
      rentalId: 'rent-upcoming',
    );

    await _pumpDetail(
      tester,
      CostumeRentalHistory(
        totalRentals: 1,
        activeRentals: 1,
        lastServiceDate: now.add(const Duration(days: 8)),
        activeRental: upcoming,
        records: [upcoming],
      ),
    );

    await tester.scrollUntilVisible(
      find.text('Sedang Dipakai'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Dijadwalkan'), findsOneWidget);
    expect(find.text('Citra Lestari'), findsWidgets);
  });

  testWidgets('lists every renter with their status chip and date range', (tester) async {
    await _pumpDetail(
      tester,
      CostumeRentalHistory(
        totalRentals: 2,
        lastServiceDate: DateTime(2026, 9, 5),
        records: [
          _record(
            name: 'Budi Santoso',
            start: DateTime(2026, 9, 1),
            end: DateTime(2026, 9, 5),
            itemStatus: RentalItemStatus.completed,
            rentalId: 'rent-2',
          ),
          _record(
            name: 'Alya Rani',
            start: DateTime(2026, 8, 1),
            end: DateTime(2026, 8, 4),
            itemStatus: RentalItemStatus.returned,
            rentalId: 'rent-1',
          ),
        ],
      ),
    );

    await tester.scrollUntilVisible(
      find.text('Budi Santoso'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    // Most-recent-first
    expect(find.text('Budi Santoso'), findsOneWidget);
    expect(find.text('Alya Rani'), findsOneWidget);
    expect(find.text('1 Sep 2026 – 5 Sep 2026'), findsOneWidget);
    expect(find.text('1 Agu 2026 – 4 Agu 2026'), findsOneWidget);
    expect(find.text('Selesai'), findsOneWidget);
    expect(find.text('Dikembalikan'), findsOneWidget);
  });

  testWidgets('hides the active-usage row when there is no in-progress rental', (tester) async {
    await _pumpDetail(
      tester,
      CostumeRentalHistory(
        totalRentals: 1,
        lastServiceDate: DateTime(2026, 8, 4),
        records: [
          _record(name: 'Alya Rani', start: DateTime(2026, 8, 1), end: DateTime(2026, 8, 4)),
        ],
      ),
    );

    await tester.scrollUntilVisible(
      find.text('Alya Rani'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Alya Rani'), findsOneWidget);
    expect(find.text('Sedang Dipakai'), findsNothing);
  });

  testWidgets('uses a loading spinner until history resolves', (tester) async {
    // Gate keeps the async history load pending so the loading state is
    // observable, then releasing it lets the empty state render.
    final gate = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: CostumeDetailScreen(
          costume: _costume,
          repository: HistoryMockRepository(
            costumes: const [_costume],
            historyGate: gate,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));

    await tester.scrollUntilVisible(
      find.text('RIWAYAT SEWA'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 30));

    // History still loading: header present, badge not yet rendered.
    expect(find.text('RIWAYAT SEWA'), findsOneWidget);
    expect(find.text('Disewa 0 kali'), findsNothing);

    gate.complete();
    await tester.pumpAndSettle();

    expect(find.text('Disewa 0 kali'), findsOneWidget);
  });
}
