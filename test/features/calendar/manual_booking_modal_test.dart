import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilyhouse/core/theme/app_theme.dart';
import 'package:lilyhouse/features/calendar/presentation/manual_booking_modal.dart';
import 'package:lilyhouse/features/costumes/data/costume_repository.dart';
import 'package:lilyhouse/features/costumes/domain/accessory.dart';
import 'package:lilyhouse/features/costumes/domain/costume.dart';
import 'package:lilyhouse/features/costumes/domain/costume_rental_history.dart';
import 'package:lilyhouse/features/rentals/data/rental_repository.dart';
import 'package:lilyhouse/features/rentals/domain/customer.dart';
import 'package:lilyhouse/features/rentals/domain/parsed_rental_data.dart';
import 'package:lilyhouse/features/rentals/domain/rental.dart';

class MockRentalRepository implements IRentalRepository {
  final List<Rental> rentals = [];
  final List<Customer> customers = [];

  @override
  Future<int> insertCustomer(Customer customer) async {
    customers.add(customer);
    return 1;
  }

  @override
  Future<Customer?> getCustomerById(String id) async => null;

  @override
  Future<List<Customer>> getAllCustomers() async => List.from(customers);

  @override
  Future<List<Customer>> searchCustomers(String query) async => [];

  @override
  Future<int> updateCustomer(Customer customer) async => 1;

  @override
  Future<int> deleteCustomer(String id) async => 1;

  @override
  Future<int> getActiveRentalsCountByCustomer(String customerId) async => 0;

  @override
  Future<int> insertRental(Rental rental) async {
    rentals.add(rental);
    return 1;
  }

  @override
  Future<Rental?> getRentalById(String id) async => null;

  @override
  Future<List<Rental>> getAllRentals() async => List.from(rentals);

  @override
  Future<List<Rental>> getRentalsForDate(DateTime date) async => [];

  @override
  Future<List<Rental>> getRentalsByDateRange(DateTime start, DateTime end) async => [];

  @override
  Future<List<Rental>> getRentalsByCostumeId(String costumeId) async => [];

  @override
  Future<List<Rental>> getRentalsByStatus(RentalItemStatus status) async => [];

  @override
  Future<int> updateRental(Rental rental) async => 1;

  @override
  Future<int> deleteRental(String id) async => 1;

  @override
  Future<bool> hasConflict(Rental candidate) async => false;

  @override
  Future<List<Rental>> findConflicts(Rental candidate) async => [];
}

class MockCostumeRepository implements ICostumeRepository {
  final List<Costume> costumes;

  MockCostumeRepository(this.costumes);

  @override
  Future<int> insertCostume(Costume costume) async => 1;

  @override
  Future<Costume?> getCostumeById(String id) async =>
      costumes.firstWhere((c) => c.id == id);

  @override
  Future<List<Costume>> getAllCostumes() async => List.from(costumes);

  @override
  Future<List<Costume>> searchCostumes({
    String? query,
    CostumeStatus? status,
    String? size,
    String? series,
    String? sortBy,
  }) async =>
      List.from(costumes);

  @override
  Future<List<String>> getDistinctAnimeSeries() async => [];

  @override
  Future<int> updateCostume(Costume costume) async => 1;

  @override
  Future<int> deleteCostume(String id) async => 1;

  @override
  Future<int> addAccessory(Accessory accessory) async => 1;

  @override
  Future<List<Accessory>> getAccessoriesByCostumeId(String costumeId) async => [];

  @override
  Future<int> updateAccessory(Accessory accessory) async => 1;

  @override
  Future<int> deleteAccessory(String id) async => 1;

  @override
  Future<int> getActiveRentalsCount(String costumeId) async => 0;

  @override
  Future<CostumeRentalHistory> getRentalHistory(String costumeId) async =>
      const CostumeRentalHistory();
}

void main() {
  const sampleCostume = Costume(
    id: 'costume_01',
    name: 'Furina Archon',
    animeSeries: 'Genshin Impact',
    size: 'M',
    rentPrice3Days: 150000,
  );

  late MockRentalRepository rentalRepo;
  late MockCostumeRepository costumeRepo;

  setUp(() {
    rentalRepo = MockRentalRepository();
    costumeRepo = MockCostumeRepository([sampleCostume]);
  });

  Widget buildModal({ParsedRentalData? initialParsedData, DateTime? initialDate}) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: CupertinoPageScaffold(
        child: Builder(
          builder: (context) => CupertinoButton(
            onPressed: () {
              showCupertinoModalPopup<void>(
                context: context,
                builder: (_) => ManualBookingModal(
                  rentalRepository: rentalRepo,
                  costumeRepository: costumeRepo,
                  initialDate: initialDate,
                  initialParsedData: initialParsedData,
                  onBookingAdded: () {},
                ),
              );
            },
            child: const Text('Open Modal'),
          ),
        ),
      ),
    );
  }

  testWidgets('ManualBookingModal auto-fills recommended price for duration > 3 days when costume is selected', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildModal(
      initialParsedData: ParsedRentalData(
        costumeName: 'Furina Archon',
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 5), // 5 days -> 3 days base + 2 days extra (150k + 2*50k = 250k)
      ),
    ));
    await tester.pumpAndSettle();

    // Open modal
    await tester.tap(find.text('Open Modal'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    // Verify duration badge indicates extra days
    expect(find.text('5 hari sewa (+2 hari)'), findsOneWidget);

    // Verify auto-calculated price is 250000
    final priceInput = tester.widget<CupertinoTextField>(find.byKey(const Key('manual_total_price_field')));
    expect(priceInput.controller?.text, '250000');

    // Verify extended duration hint card is visible
    expect(find.byKey(const Key('manual_extended_duration_hint')), findsOneWidget);
    expect(find.textContaining('Durasi 5 Hari (+2 hari tambahan)'), findsOneWidget);
    expect(find.textContaining('Tarif dasar 3 hari: Rp 150.000'), findsOneWidget);
    expect(find.textContaining('Hari tambahan (+2 hari): Rp 100.000 (Rp 50.000/hari)'), findsOneWidget);
    expect(find.text('Rp 250.000'), findsOneWidget);
  });

  testWidgets('ManualBookingModal preserves manual price edits and allows applying recommendation via Pakai button', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildModal(
      initialParsedData: ParsedRentalData(
        costumeName: 'Furina Archon',
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 5), // 5 days -> recommended 250k
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Modal'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    // Owner manually edits price to 220000 (discount)
    final priceFinder = find.byKey(const Key('manual_total_price_field'));
    await tester.enterText(priceFinder, '220000');
    await tester.pumpAndSettle();

    // 'Pakai' button should appear because price was manually edited
    expect(find.byKey(const Key('manual_apply_recommended_price_btn')), findsOneWidget);

    // Tap 'Pakai' button
    await tester.tap(find.byKey(const Key('manual_apply_recommended_price_btn')));
    await tester.pumpAndSettle();

    // Price should be reset to recommended 250000
    final priceInput = tester.widget<CupertinoTextField>(priceFinder);
    expect(priceInput.controller?.text, '250000');

    // 'Pakai' button disappears because price is now synced to recommendation
    expect(find.byKey(const Key('manual_apply_recommended_price_btn')), findsNothing);
  });

  testWidgets('ManualBookingModal for duration <= 3 days shows standard price without extended duration card', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildModal(
      initialParsedData: ParsedRentalData(
        costumeName: 'Furina Archon',
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 3), // 3 days
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Modal'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    // Verify 3 hari sewa (no (+N hari))
    expect(find.text('3 hari sewa'), findsOneWidget);

    // Price is 150000
    final priceInput = tester.widget<CupertinoTextField>(find.byKey(const Key('manual_total_price_field')));
    expect(priceInput.controller?.text, '150000');

    // Extended duration card should not be displayed
    expect(find.byKey(const Key('manual_extended_duration_hint')), findsNothing);
  });

  testWidgets('ManualBookingModal sanitizes phone input (+62/spaces/hyphens) on save', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildModal(
      initialParsedData: ParsedRentalData(
        costumeName: 'Furina Archon',
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 3),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Modal'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    // Fill Nama
    await tester.enterText(find.byKey(const Key('manual_name_input')), 'Budi Cosplayer');

    // Fill Phone with messy format (+62 812-3456-7890)
    await tester.enterText(find.byKey(const Key('manual_phone_input')), '+62 812-3456-7890');

    // Fill Parent Phone with messy format (+62 898-7654-3210)
    await tester.enterText(find.byKey(const Key('manual_parent_phone_input')), '+62 898-7654-3210');

    // Tap Simpan
    final saveButton = find.byKey(const Key('manual_save_booking_button'));
    await tester.tap(saveButton);
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    // Verify Customer saved with sanitized phone numbers
    expect(rentalRepo.customers.length, 1);
    final savedCustomer = rentalRepo.customers.first;
    expect(savedCustomer.phone, '081234567890');
    expect(savedCustomer.parentPhone, '089876543210');
  });

  testWidgets('ManualBookingModal blocks phone numbers with less than 8 digits', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildModal(
      initialParsedData: ParsedRentalData(
        costumeName: 'Furina Archon',
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 3),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Modal'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    // Fill Nama
    await tester.enterText(find.byKey(const Key('manual_name_input')), 'Budi Cosplayer');

    // Fill Short Phone (less than 8 digits: "12345")
    await tester.enterText(find.byKey(const Key('manual_phone_input')), '12345');

    // Tap Simpan
    final saveButton = find.byKey(const Key('manual_save_booking_button'));
    await tester.tap(saveButton);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Toast error shown & nothing saved
    expect(find.text('Nomor telepon tidak valid (minimal 8 digit)'), findsOneWidget);
    expect(rentalRepo.customers, isEmpty);
    expect(rentalRepo.rentals, isEmpty);
  });

  testWidgets('ManualBookingModal payment status selection: default unpaid, DP shows DP input and remaining balance', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildModal(
      initialParsedData: ParsedRentalData(
        costumeName: 'Furina Archon',
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 3), // 3 days -> 150000
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Modal'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    // Verify Payment Status Segmented Control is present with 3 items
    expect(find.byKey(const Key('manual_payment_status_control')), findsOneWidget);
    expect(find.byKey(const Key('payment_status_unpaid')), findsOneWidget);
    expect(find.byKey(const Key('payment_status_dp')), findsOneWidget);
    expect(find.byKey(const Key('payment_status_paid')), findsOneWidget);

    // In default Unpaid state, DP field and remaining balance tile should NOT be visible
    expect(find.byKey(const Key('manual_dp_input')), findsNothing);
    expect(find.byKey(const Key('manual_remaining_balance_tile')), findsNothing);

    // Switch to DP status
    await tester.tap(find.byKey(const Key('payment_status_dp')));
    await tester.pumpAndSettle();

    // Now DP field and remaining balance tile should appear
    expect(find.byKey(const Key('manual_dp_input')), findsOneWidget);
    expect(find.byKey(const Key('manual_remaining_balance_tile')), findsOneWidget);

    // Initial remaining balance with 0 DP should be full price (Rp 150.000)
    expect(find.text('Rp 150.000'), findsWidgets);

    // Enter DP amount with dots/commas: 50.000
    await tester.enterText(find.byKey(const Key('manual_dp_amount_field')), '50.000');
    await tester.pumpAndSettle();

    // Remaining balance should update to 150.000 - 50.000 = 100.000
    expect(find.text('Rp 100.000'), findsOneWidget);

    // Switch to Lunas status
    await tester.tap(find.byKey(const Key('payment_status_paid')));
    await tester.pumpAndSettle();

    // DP input and remaining balance should hide
    expect(find.byKey(const Key('manual_dp_input')), findsNothing);
    expect(find.byKey(const Key('manual_remaining_balance_tile')), findsNothing);
  });

  testWidgets('ManualBookingModal validates DP amount and saves rental with paymentStatus and dpAmount', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildModal(
      initialParsedData: ParsedRentalData(
        costumeName: 'Furina Archon',
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 3), // 3 days -> 150000
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Modal'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    // Fill customer info
    await tester.enterText(find.byKey(const Key('manual_name_input')), 'Aether Cosplayer');
    await tester.enterText(find.byKey(const Key('manual_phone_input')), '081234567890');

    // Select DP status
    await tester.tap(find.byKey(const Key('payment_status_dp')));
    await tester.pumpAndSettle();

    // Try saving without entering DP
    final saveButton = find.byKey(const Key('manual_save_booking_button'));
    await tester.tap(saveButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Toast error shown for empty DP
    expect(find.text('Nominal DP wajib diisi (minimal Rp 1.000)'), findsWidgets);
    expect(rentalRepo.rentals, isEmpty);

    // Enter DP equal to or exceeding total price
    await tester.enterText(find.byKey(const Key('manual_dp_amount_field')), '150.000');
    await tester.pumpAndSettle();

    await tester.tap(saveButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Toast error for DP >= total price
    expect(find.text('Nominal DP harus lebih kecil dari total harga (gunakan status Lunas)'), findsWidgets);
    expect(rentalRepo.rentals, isEmpty);

    // Enter valid DP with thousand separators: 60.000
    await tester.enterText(find.byKey(const Key('manual_dp_amount_field')), '60.000');
    await tester.pumpAndSettle();

    // Remaining balance displays Rp 90.000
    expect(find.text('Rp 90.000'), findsOneWidget);

    // Save valid booking
    await tester.tap(saveButton);
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    // Verify rental was inserted with correct paymentStatus and dpAmount
    expect(rentalRepo.rentals.length, 1);
    final savedRental = rentalRepo.rentals.first;
    expect(savedRental.totalPrice, 150000.0);
    expect(savedRental.dpAmount, 60000.0);
    expect(savedRental.paymentStatus, RentalPaymentStatus.dpPaid);
    expect(savedRental.itemStatus, RentalItemStatus.booked);
  });

  testWidgets('ManualBookingModal saves rental with Lunas status sets dpAmount to totalPrice', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildModal(
      initialParsedData: ParsedRentalData(
        costumeName: 'Furina Archon',
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 3), // 150000
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Modal'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    // Fill customer info
    await tester.enterText(find.byKey(const Key('manual_name_input')), 'Lumine Cosplayer');
    await tester.enterText(find.byKey(const Key('manual_phone_input')), '081234567890');

    // Select Lunas status
    await tester.tap(find.byKey(const Key('payment_status_paid')));
    await tester.pumpAndSettle();

    // Tap Simpan
    final saveButton = find.byKey(const Key('manual_save_booking_button'));
    await tester.tap(saveButton);
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    // Verify rental was inserted with Lunas status and dpAmount == totalPrice
    expect(rentalRepo.rentals.length, 1);
    final savedRental = rentalRepo.rentals.first;
    expect(savedRental.totalPrice, 150000.0);
    expect(savedRental.dpAmount, 150000.0);
    expect(savedRental.paymentStatus, RentalPaymentStatus.paid);
  });

  testWidgets('ManualBookingModal guards unsaved edits when tapping Batal', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildModal());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Modal'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    // Type into a field so the form becomes "dirty".
    await tester.enterText(find.byKey(const Key('manual_name_input')), 'Alya Rani');
    await tester.pumpAndSettle();

    // Tapping Batal must raise the discard confirmation instead of closing.
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    expect(find.text('Batalkan Perubahan?'), findsOneWidget);

    // Choosing "Lanjut Mengisi" keeps the sheet open with data intact.
    await tester.tap(find.text('Lanjut Mengisi'));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoAlertDialog), findsNothing);
    expect(find.byKey(const Key('manual_name_input')), findsOneWidget);
    expect(find.text('Alya Rani'), findsOneWidget);

    // Choosing "Keluar" finally discards and closes the sheet.
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keluar'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('manual_name_input')), findsNothing);
  });

  testWidgets('ManualBookingModal closes without prompting when nothing was edited', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildModal());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Modal'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoAlertDialog), findsNothing);
    expect(find.byKey(const Key('manual_name_input')), findsNothing);
  });

  testWidgets('ManualBookingModal does not treat Smart Paste pre-fill as an edit', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // Auto-filled values must not trigger the guard on their own.
    await tester.pumpWidget(buildModal(
      initialParsedData: ParsedRentalData(
        fullName: 'Alya Rani',
        phone: '081234567890',
        costumeName: 'Furina Archon',
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 3),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Modal'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('Alya Rani'), findsOneWidget);

    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoAlertDialog), findsNothing);
    expect(find.byKey(const Key('manual_name_input')), findsNothing);
  });

}
