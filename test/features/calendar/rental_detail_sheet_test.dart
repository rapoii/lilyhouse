import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    expect(find.text('Salin Pesan Konfirmasi WA'), findsOneWidget);

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
    expect(find.text('Batal'), findsOneWidget);

    // Tap destructive confirm in dialog
    final confirmBtn = find.widgetWithText(CupertinoDialogAction, 'Batalkan Booking');
    await tester.tap(confirmBtn);
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(updatedCalled, isTrue);
    expect(repo.lastUpdatedRental?.itemStatus, RentalItemStatus.cancelled);
  });

  testWidgets('RentalDetailSheet shows late return indicator when rented and past endDate', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repo = MockRentalRepo();
    final pastEndDate = DateTime.now().subtract(const Duration(days: 3));
    final startDate = pastEndDate.subtract(const Duration(days: 3));

    final lateRental = Rental(
      id: 'rent-late',
      costumeId: 'cos-1',
      customerId: 'cust-1',
      startDate: startDate,
      endDate: pastEndDate,
      durationDays: 3,
      purpose: 'Event Cosplay',
      totalPrice: 150000.0,
      paymentStatus: RentalPaymentStatus.paid,
      itemStatus: RentalItemStatus.rented,
    );

    await tester.pumpWidget(createTestWidget(rental: lateRental, repo: repo));
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    // Verify late return badge in status Wrap
    expect(find.text('Terlambat 3 Hari'), findsOneWidget);
    // Verify late return text in schedule bar
    expect(find.text('Telat 3 Hari'), findsOneWidget);
  });

  testWidgets('RentalDetailSheet does NOT show late return indicator when returned or completed', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repo = MockRentalRepo();
    final pastEndDate = DateTime.now().subtract(const Duration(days: 3));
    final startDate = pastEndDate.subtract(const Duration(days: 3));

    final returnedRental = Rental(
      id: 'rent-returned',
      costumeId: 'cos-1',
      customerId: 'cust-1',
      startDate: startDate,
      endDate: pastEndDate,
      durationDays: 3,
      purpose: 'Event Cosplay',
      totalPrice: 150000.0,
      paymentStatus: RentalPaymentStatus.paid,
      itemStatus: RentalItemStatus.returned,
    );

    await tester.pumpWidget(createTestWidget(rental: returnedRental, repo: repo));
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    // Indicator must NOT be shown
    expect(find.textContaining('Terlambat'), findsNothing);
    expect(find.textContaining('Telat'), findsNothing);
  });

  testWidgets('Tapping Tandai Sudah Dikembalikan shows return dialog with penalty and condition notes', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repo = MockRentalRepo();
    bool updatedCalled = false;
    final pastEndDate = DateTime.now().subtract(const Duration(days: 2));
    final startDate = pastEndDate.subtract(const Duration(days: 3));

    final rental = Rental(
      id: 'rent-return-test',
      costumeId: 'cos-1',
      customerId: 'cust-1',
      startDate: startDate,
      endDate: pastEndDate,
      durationDays: 3,
      purpose: 'Photoshoot',
      totalPrice: 150000.0,
      paymentStatus: RentalPaymentStatus.paid,
      itemStatus: RentalItemStatus.rented,
      notes: 'Bawa wig net cadangan',
    );

    await tester.pumpWidget(createTestWidget(
      rental: rental,
      repo: repo,
      onUpdated: () => updatedCalled = true,
    ));
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    final kembalikanTile = find.text('Tandai Sudah Dikembalikan');
    await tester.scrollUntilVisible(kembalikanTile, 200, scrollable: find.byType(Scrollable).last);
    await tester.tap(kembalikanTile);
    await tester.pumpAndSettle();

    // Verify Return Dialog appears
    expect(find.text('Konfirmasi Pengembalian Kostum'), findsOneWidget);
    expect(find.textContaining('terlambat 2 hari'), findsOneWidget);

    // Enter penalty 50000 and notes
    final textFields = find.byType(CupertinoTextField);
    expect(textFields, findsNWidgets(2));

    await tester.enterText(textFields.first, '50000');
    await tester.enterText(textFields.last, 'Wig sedikit kusut tapi aman');
    await tester.pumpAndSettle();

    // Tap Simpan & Selesai
    await tester.tap(find.text('Simpan & Selesai'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(updatedCalled, isTrue);
    expect(repo.lastUpdatedRental?.itemStatus, RentalItemStatus.returned);
    // Total price should increase by penalty (150.000 + 50.000 = 200.000)
    expect(repo.lastUpdatedRental?.totalPrice, 200000.0);
    // Notes should combine existing notes + Denda + Kondisi
    expect(repo.lastUpdatedRental?.notes, contains('Bawa wig net cadangan'));
    expect(repo.lastUpdatedRental?.notes, contains('Denda: Rp 50.000'));
    expect(repo.lastUpdatedRental?.notes, contains('Kondisi: Wig sedikit kusut tapi aman'));
  });

  testWidgets('Tapping Salin Pesan Konfirmasi WA copies formatted WhatsApp message to clipboard with IosToast', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repo = MockRentalRepo();
    final rental = Rental(
      id: 'rent-wa-1',
      costumeId: 'cos-1',
      customerId: 'cust-1',
      startDate: DateTime(2026, 9, 13),
      endDate: DateTime(2026, 9, 16),
      durationDays: 3,
      purpose: 'Event Cosplay',
      totalPrice: 150000.0,
      dpAmount: 50000.0,
      paymentStatus: RentalPaymentStatus.dpPaid,
      itemStatus: RentalItemStatus.booked,
      notes: 'Tolong pastikan wig bersih',
    );

    // Track clipboard calls
    final List<MethodCall> log = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall methodCall) async {
        log.add(methodCall);
        if (methodCall.method == 'Clipboard.setData') {
          return null;
        }
        return null;
      },
    );

    await tester.pumpWidget(createTestWidget(rental: rental, repo: repo));
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    final copyTile = find.text('Salin Pesan Konfirmasi WA');
    expect(copyTile, findsOneWidget);

    // Tap tile
    await tester.tap(copyTile);
    await tester.pump();

    // Verify toast appeared
    expect(find.text('Pesan konfirmasi WA berhasil disalin'), findsOneWidget);

    // Verify clipboard content
    final clipboardCalls = log.where((call) => call.method == 'Clipboard.setData').toList();
    expect(clipboardCalls.isNotEmpty, isTrue);

    final dynamic copiedMap = clipboardCalls.last.arguments;
    final copiedText = copiedMap is Map ? copiedMap['text'] as String : '';
    expect(copiedText, contains('*KONFIRMASI RESERVASI SEWA KOSTUM - LILYHOUSE*'));
    expect(copiedText, contains('Alya Rani'));
    expect(copiedText, contains('Furina Archon'));
    expect(copiedText, contains('Genshin Impact'));
    expect(copiedText, contains('13 Sep 2026 - 16 Sep 2026 (3 Hari)'));
    expect(copiedText, contains('Total Biaya: Rp 150.000'));
    expect(copiedText, contains('Uang Muka (DP): Rp 50.000'));
    expect(copiedText, contains('DP Terbayar (Sisa Rp 100.000)'));
    expect(copiedText, contains('*Petunjuk & Peraturan Rental:*'));
    expect(copiedText, contains('Kostum tidak perlu dicuci saat dikembalikan'));

    // Check no emojis in the copied message
    final emojiRegex = RegExp(r'[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]', unicode: true);
    expect(emojiRegex.hasMatch(copiedText), isFalse);

    // Let the toast animation finish
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('Tapping trailing circular copy button copies formatted WhatsApp message to clipboard', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repo = MockRentalRepo();
    final rental = Rental(
      id: 'rent-wa-2',
      costumeId: 'cos-1',
      customerId: 'cust-1',
      startDate: DateTime(2026, 9, 20),
      endDate: DateTime(2026, 9, 23),
      durationDays: 3,
      purpose: 'Photoshoot',
      totalPrice: 200000.0,
      dpAmount: 200000.0,
      paymentStatus: RentalPaymentStatus.paid,
      itemStatus: RentalItemStatus.rented,
    );

    final List<MethodCall> log = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall methodCall) async {
        log.add(methodCall);
        if (methodCall.method == 'Clipboard.setData') {
          return null;
        }
        return null;
      },
    );

    await tester.pumpWidget(createTestWidget(rental: rental, repo: repo));
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    // Verify touch target: button has minimumSize of 44x44
    final trailingButtonFinder = find.widgetWithIcon(CupertinoButton, CupertinoIcons.doc_on_clipboard_fill);
    expect(trailingButtonFinder, findsOneWidget);

    final buttonWidget = tester.widget<CupertinoButton>(trailingButtonFinder);
    expect(buttonWidget.minimumSize, const Size(44, 44));

    // Tap trailing button
    await tester.tap(trailingButtonFinder);
    await tester.pump();

    // Verify toast
    expect(find.text('Pesan konfirmasi WA berhasil disalin'), findsOneWidget);

    final clipboardCalls = log.where((call) => call.method == 'Clipboard.setData').toList();
    expect(clipboardCalls.isNotEmpty, isTrue);

    final dynamic copiedMap = clipboardCalls.last.arguments;
    final copiedText = copiedMap is Map ? copiedMap['text'] as String : '';
    expect(copiedText, contains('Status Pembayaran: Lunas'));

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
}
