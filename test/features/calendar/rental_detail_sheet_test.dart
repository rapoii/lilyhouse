import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lilyhouse/core/theme/app_theme.dart';
import 'package:lilyhouse/features/calendar/presentation/rental_detail_sheet.dart';
import 'package:lilyhouse/features/costumes/domain/costume.dart';
import 'package:lilyhouse/features/rentals/data/rental_repository.dart';
import 'package:lilyhouse/features/rentals/domain/customer.dart';
import 'package:lilyhouse/features/rentals/domain/rental.dart';

class MockRentalRepo implements IRentalRepository {
  Rental? lastUpdatedRental;
  final List<Rental> rentals = [];

  @override
  Future<int> insertRental(Rental rental) async {
    rentals.add(rental);
    return 1;
  }

  @override
  Future<int> updateRental(Rental rental) async {
    lastUpdatedRental = rental;
    final idx = rentals.indexWhere((r) => r.id == rental.id);
    if (idx != -1) {
      rentals[idx] = rental;
    }
    return 1;
  }

  @override
  Future<List<Rental>> getAllRentals() async => List.from(rentals);

  @override
  Future<Rental?> getRentalById(String id) async => null;

  @override
  Future<int> deleteRental(String id) async => 1;

  @override
  Future<List<Rental>> getRentalsForDate(DateTime date) async => [];

  @override
  Future<List<Rental>> getRentalsByDateRange(DateTime start, DateTime end) async => [];

  @override
  Future<List<Rental>> getRentalsByCostumeId(String costumeId) async => [];

  @override
  Future<List<Rental>> getRentalsByStatus(RentalItemStatus status) async => [];

  @override
  Future<bool> hasConflict(Rental candidate) async => false;

  @override
  Future<List<Rental>> findConflicts(Rental candidate) async => [];

  @override
  Future<List<Customer>> getAllCustomers() async => [];

  @override
  Future<Customer?> getCustomerById(String id) async => null;

  @override
  Future<int> insertCustomer(Customer customer) async => 1;

  @override
  Future<List<Customer>> searchCustomers(String query) async => [];

  @override
  Future<int> updateCustomer(Customer customer) async => 1;

  @override
  Future<int> deleteCustomer(String id) async => 1;

  @override
  Future<int> getActiveRentalsCountByCustomer(String customerId) async => 0;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  final testCustomer = Customer(
    id: 'cust-1',
    fullName: 'Alya Rani',
    phone: '08123456789',
    parentPhone: '08987654321',
    address: 'Jl. Merdeka No. 10, Jakarta',
    socialMedia: '@alyacosplay',
    ktpPhotoUrl: 'https://example.com/ktp.jpg',
    selfieKtpUrl: 'https://example.com/selfie.jpg',
  );

  final testCostume = const Costume(
    id: 'cos-1',
    name: 'Furina Archon',
    animeSeries: 'Genshin Impact',
    size: 'M',
    rentPrice3Days: 150000.0,
  );

  Widget createTestWidget({
    required Rental rental,
    required MockRentalRepo repo,
    VoidCallback? onUpdated,
  }) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Builder(
          builder: (ctx) => CupertinoButton(
            child: const Text('Open Sheet'),
            onPressed: () {
              showCupertinoModalPopup<void>(
                context: ctx,
                builder: (_) => RentalDetailSheet(
                  rental: rental,
                  customer: testCustomer,
                  costume: testCostume,
                  repository: repo,
                  onRentalUpdated: onUpdated,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  testWidgets('RentalDetailSheet displays all details in Apple HIG layout', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0; // 1080x2400 logical points
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repo = MockRentalRepo();
    final rental = Rental(
      id: 'rent-1',
      costumeId: 'cos-1',
      customerId: 'cust-1',
      startDate: DateTime(2026, 9, 13),
      endDate: DateTime(2026, 9, 16),
      durationDays: 3,
      purpose: 'Photoshoot Event',
      totalPrice: 150000.0,
      dpAmount: 50000.0,
      paymentStatus: RentalPaymentStatus.dpPaid,
      itemStatus: RentalItemStatus.booked,
      notes: 'Harap packing rapi wig dan aksesori',
    );

    await tester.pumpWidget(createTestWidget(rental: rental, repo: repo));
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    // Verify Nav title
    expect(find.text('Detail Rental'), findsOneWidget);

    // Verify Hero card info
    expect(find.text('Furina Archon'), findsOneWidget);
    expect(find.text('Genshin Impact'), findsOneWidget);
    expect(find.text('Dibooking'), findsOneWidget);
    expect(find.text('DP Terbayar'), findsOneWidget);
    expect(find.text('Photoshoot Event'), findsOneWidget);
    expect(find.text('3 Hari'), findsOneWidget);

    // Verify Customer Info Section
    expect(find.text('INFORMASI PENYEWA'), findsOneWidget);
    expect(find.text('Alya Rani'), findsOneWidget);
    expect(find.text('08123456789'), findsOneWidget);
    expect(find.text('@alyacosplay'), findsOneWidget);
    expect(find.text('Jl. Merdeka No. 10, Jakarta'), findsOneWidget);

    // Verify Identity Documents Section
    expect(find.text('DOKUMEN IDENTITAS & JAMINAN'), findsOneWidget);
    expect(find.text('Foto KTP / Identitas'), findsOneWidget);
    expect(find.text('Foto Selfie + Identitas'), findsOneWidget);

    // Verify Billing Section
    expect(find.text('RINCIAN BIAYA & PEMBAYARAN'), findsOneWidget);
    expect(find.text('Total Biaya Sewa'), findsOneWidget);
    expect(find.text('Rp 150.000'), findsOneWidget);
    expect(find.text('Uang Muka (DP)'), findsOneWidget);
    expect(find.text('Rp 50.000'), findsOneWidget);
    expect(find.text('Sisa Tagihan Pelunasan'), findsOneWidget);
    expect(find.text('Rp 100.000'), findsOneWidget);
    expect(find.text('Harap packing rapi wig dan aksesori'), findsOneWidget);

    // Scroll to Actions Section if needed
    final actionSection = find.text('KELOLA STATUS RENTAL');
    await tester.scrollUntilVisible(actionSection, 200, scrollable: find.byType(Scrollable).last);
    expect(actionSection, findsOneWidget);
    expect(find.text('Tandai Sedang Disewa'), findsOneWidget);
    expect(find.text('Tandai Sudah Dikembalikan'), findsOneWidget);
    expect(find.text('Tandai Pembayaran Lunas'), findsOneWidget);
    expect(find.text('Batalkan Booking'), findsOneWidget);
  });

  testWidgets('Tapping Tandai Sedang Disewa updates rental itemStatus', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repo = MockRentalRepo();
    bool updatedCalled = false;
    final rental = Rental(
      id: 'rent-1',
      costumeId: 'cos-1',
      customerId: 'cust-1',
      startDate: DateTime(2026, 9, 13),
      endDate: DateTime(2026, 9, 16),
      durationDays: 3,
      purpose: 'Photoshoot',
      totalPrice: 150000.0,
      paymentStatus: RentalPaymentStatus.unpaid,
      itemStatus: RentalItemStatus.booked,
    );

    await tester.pumpWidget(createTestWidget(
      rental: rental,
      repo: repo,
      onUpdated: () => updatedCalled = true,
    ));
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    // Scroll to and tap "Tandai Sedang Disewa"
    final disewaTile = find.text('Tandai Sedang Disewa');
    await tester.scrollUntilVisible(disewaTile, 200, scrollable: find.byType(Scrollable).last);
    await tester.tap(disewaTile);
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(updatedCalled, isTrue);
    expect(repo.lastUpdatedRental?.itemStatus, RentalItemStatus.rented);
  });

  testWidgets('Tapping Tandai Pembayaran Lunas updates payment status', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repo = MockRentalRepo();
    bool updatedCalled = false;
    final rental = Rental(
      id: 'rent-2',
      costumeId: 'cos-1',
      customerId: 'cust-1',
      startDate: DateTime(2026, 9, 13),
      endDate: DateTime(2026, 9, 16),
      durationDays: 3,
      purpose: 'Photoshoot',
      totalPrice: 150000.0,
      paymentStatus: RentalPaymentStatus.unpaid,
      itemStatus: RentalItemStatus.booked,
    );

    await tester.pumpWidget(createTestWidget(
      rental: rental,
      repo: repo,
      onUpdated: () => updatedCalled = true,
    ));
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    // Scroll to and tap "Tandai Pembayaran Lunas"
    final lunasTile = find.text('Tandai Pembayaran Lunas');
    await tester.scrollUntilVisible(lunasTile, 200, scrollable: find.byType(Scrollable).last);
    await tester.tap(lunasTile);
    await tester.pumpAndSettle();

    // Confirm in dialog
    await tester.tap(find.text('Ya, Sudah Lunas'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(updatedCalled, isTrue);
    expect(repo.lastUpdatedRental?.paymentStatus, RentalPaymentStatus.paid);
  });

  testWidgets('Batalkan Booking shows CupertinoAlertDialog and cancels when confirmed', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repo = MockRentalRepo();
    bool updatedCalled = false;
    final rental = Rental(
      id: 'rent-3',
      costumeId: 'cos-1',
      customerId: 'cust-1',
      startDate: DateTime(2026, 9, 13),
      endDate: DateTime(2026, 9, 16),
      durationDays: 3,
      purpose: 'Photoshoot',
      totalPrice: 150000.0,
      paymentStatus: RentalPaymentStatus.unpaid,
      itemStatus: RentalItemStatus.booked,
    );

    await tester.pumpWidget(createTestWidget(
      rental: rental,
      repo: repo,
      onUpdated: () => updatedCalled = true,
    ));
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    // Scroll to and tap "Batalkan Booking"
    final batalTile = find.text('Batalkan Booking');
    await tester.scrollUntilVisible(batalTile, 200, scrollable: find.byType(Scrollable).last);
    await tester.tap(batalTile);
    await tester.pumpAndSettle();

    // Confirm dialog is shown
    expect(find.text('Batalkan Booking?'), findsOneWidget);
    expect(find.text('Kembali'), findsOneWidget);

    // Tap destructive confirm in dialog
    final confirmBtn = find.widgetWithText(CupertinoDialogAction, 'Batalkan Booking');
    await tester.tap(confirmBtn);
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(updatedCalled, isTrue);
    expect(repo.lastUpdatedRental?.itemStatus, RentalItemStatus.cancelled);
  });
}
