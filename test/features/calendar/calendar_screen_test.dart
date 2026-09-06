import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilyhouse/core/theme/app_theme.dart';
import 'package:lilyhouse/features/calendar/domain/booking_conflict_engine.dart';
import 'package:lilyhouse/features/calendar/presentation/calendar_screen.dart';
import 'package:lilyhouse/features/rentals/data/rental_repository.dart';
import 'package:lilyhouse/features/rentals/domain/customer.dart';
import 'package:lilyhouse/features/rentals/domain/rental.dart';

class MockRentalRepository implements IRentalRepository {
  final List<Rental> _rentals = [];
  final List<Customer> _customers = [];

  MockRentalRepository({
    List<Rental>? rentals,
    List<Customer>? customers,
  }) {
    if (rentals != null) _rentals.addAll(rentals);
    if (customers != null) _customers.addAll(customers);
  }

  @override
  Future<int> insertCustomer(Customer customer) async {
    _customers.removeWhere((c) => c.id == customer.id);
    _customers.add(customer);
    return 1;
  }

  @override
  Future<Customer?> getCustomerById(String id) async {
    try {
      return _customers.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Customer>> getAllCustomers() async {
    return List.from(_customers);
  }

  @override
  Future<List<Customer>> searchCustomers(String query) async {
    return _customers
        .where((c) => c.fullName.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  @override
  Future<int> updateCustomer(Customer customer) async {
    final i = _customers.indexWhere((c) => c.id == customer.id);
    if (i >= 0) {
      _customers[i] = customer;
      return 1;
    }
    return 0;
  }

  @override
  Future<int> deleteCustomer(String id) async {
    _customers.removeWhere((c) => c.id == id);
    return 1;
  }

  @override
  Future<int> insertRental(Rental rental) async {
    _rentals.removeWhere((r) => r.id == rental.id);
    _rentals.add(rental);
    return 1;
  }

  @override
  Future<Rental?> getRentalById(String id) async {
    try {
      return _rentals.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Rental>> getAllRentals() async {
    return List.from(_rentals);
  }

  @override
  Future<List<Rental>> getRentalsForDate(DateTime date) async {
    final target = DateTime(date.year, date.month, date.day);
    return _rentals.where((r) {
      final s = DateTime(r.startDate.year, r.startDate.month, r.startDate.day);
      final e = DateTime(r.endDate.year, r.endDate.month, r.endDate.day);
      return !target.isBefore(s) && !target.isAfter(e);
    }).toList();
  }

  @override
  Future<List<Rental>> getRentalsByDateRange(DateTime start, DateTime end) async {
    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);
    return _rentals.where((r) {
      final s = DateTime(r.startDate.year, r.startDate.month, r.startDate.day);
      final e = DateTime(r.endDate.year, r.endDate.month, r.endDate.day);
      return !s.isAfter(endDay) && !e.isBefore(startDay);
    }).toList();
  }

  @override
  Future<List<Rental>> getRentalsByCostumeId(String costumeId) async {
    return _rentals.where((r) => r.costumeId == costumeId).toList();
  }

  @override
  Future<List<Rental>> getRentalsByStatus(RentalItemStatus status) async {
    return _rentals.where((r) => r.itemStatus == status).toList();
  }

  @override
  Future<int> updateRental(Rental rental) async {
    final i = _rentals.indexWhere((r) => r.id == rental.id);
    if (i >= 0) {
      _rentals[i] = rental;
      return 1;
    }
    return 0;
  }

  @override
  Future<int> deleteRental(String id) async {
    _rentals.removeWhere((r) => r.id == id);
    return 1;
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

void main() {
  late MockRentalRepository repository;

  setUp(() {
    repository = MockRentalRepository();
  });

  Widget createWidgetUnderTest() {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: CalendarScreen(
        rentalRepository: repository,
        initialFocusedDay: DateTime(2026, 9, 6),
      ),
    );
  }

  group('CalendarScreen Widget Tests', () {
    testWidgets('renders CalendarScreen, TableCalendar, and Smart Paste button', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();
      await tester.pump();

      expect(find.text('Kalender Rental'), findsOneWidget);
      expect(find.byKey(const Key('smart_paste_button')), findsOneWidget);
      expect(find.text('Smart Paste'), findsOneWidget);
    });

    testWidgets('displays rentals for selected date in daily slot card', (tester) async {
      final customer = Customer(
        id: 'cust_001',
        fullName: 'Jihan Fatin',
        phone: '082245777711',
        address: 'Jakarta',
      );
      await repository.insertCustomer(customer);

      final rental = Rental(
        id: 'rent_001',
        costumeId: 'Citlali',
        customerId: 'cust_001',
        startDate: DateTime(2026, 9, 5),
        endDate: DateTime(2026, 9, 7),
        durationDays: 3,
        purpose: 'homecos',
        totalPrice: 150000.0,
        dpAmount: 50000.0,
        paymentStatus: RentalPaymentStatus.dpPaid,
        itemStatus: RentalItemStatus.booked,
      );
      await repository.insertRental(rental);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();
      await tester.pump();

      // On Sept 6, 2026, rental_001 is active
      expect(find.text('Citlali'), findsWidgets);
      expect(find.text('Jihan Fatin'), findsOneWidget);
      expect(find.text('Dibooking'), findsWidgets);
      expect(find.text('DP Terbayar'), findsWidgets);
    });

    testWidgets('opening Smart Paste dialog allows input and shows conflict warning', (tester) async {
      // Existing rental for Citlali on Sept 5-7
      final customer = Customer(
        id: 'cust_001',
        fullName: 'Jihan Fatin',
        phone: '082245777711',
        address: 'Jakarta',
      );
      await repository.insertCustomer(customer);
      await repository.insertRental(Rental(
        id: 'rent_001',
        costumeId: 'Citlali',
        customerId: 'cust_001',
        startDate: DateTime(2026, 9, 5),
        endDate: DateTime(2026, 9, 7),
        durationDays: 3,
        purpose: 'homecos',
        totalPrice: 150000.0,
      ));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();
      await tester.pump();

      // Tap Smart Paste button
      await tester.tap(find.byKey(const Key('smart_paste_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify dialog appears
      expect(find.text('Smart Rent Form Parser'), findsOneWidget);
      expect(find.byKey(const Key('smart_paste_input')), findsOneWidget);

      // Enter overlapping WhatsApp text
      const rawFormText = '''
🎀Form Rent Lilycosrent🎀
1. Nama asli/nama dipaket : Clara Oswald
2. No HP : 081298765432
3. Alamat lengkap : Bandung
4. No hp ortu : 081298765432
5. Akun sosmed : ig @clara
6. Kostum yg dirental : Citlali
7. Tanggal dipakai (3 hari) : 6-8 sept 2026
8. Untuk keperluan : event
''';

      await tester.enterText(find.byKey(const Key('smart_paste_input')), rawFormText);
      await tester.pump();

      await tester.tap(find.byKey(const Key('smart_paste_parse_btn')));
      await tester.pump();
      await tester.pump();

      // Expect conflict detection warning
      expect(find.text('Clara Oswald'), findsOneWidget);
      expect(find.textContaining('Konflik Terdeteksi'), findsOneWidget);
    });

    testWidgets('saving parsed form adds new customer and rental to repository', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();
      await tester.pump();

      // Tap Smart Paste button
      await tester.tap(find.byKey(const Key('smart_paste_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      const rawFormText = '''
🎀Form Rent Lilycosrent🎀
1. Nama asli/nama dipaket : Rose Tyler
2. No HP : 089988776655
3. Alamat lengkap : London Street No. 4
4. No hp ortu : 089988776655
5. Akun sosmed : ig @rosetyler
6. Kostum yg dirental : Furina
7. Tanggal dipakai (3 hari) : 20-22 sept 2026
8. Untuk keperluan : photoshoot
''';

      await tester.enterText(find.byKey(const Key('smart_paste_input')), rawFormText);
      await tester.pump();

      await tester.tap(find.byKey(const Key('smart_paste_parse_btn')));
      await tester.pump();
      await tester.pump();

      expect(find.text('Rose Tyler'), findsOneWidget);
      expect(find.textContaining('Bebas Konflik'), findsOneWidget);

      // Ensure button is visible in scrollview then tap
      final saveBtn = find.text('Simpan Booking');
      await tester.ensureVisible(saveBtn);
      await tester.pumpAndSettle();

      await tester.tap(saveBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final allRentals = await repository.getAllRentals();
      expect(allRentals.length, 1);
      expect(allRentals.first.costumeId, 'Furina');

      final allCustomers = await repository.getAllCustomers();
      expect(allCustomers.length, 1);
      expect(allCustomers.first.fullName, 'Rose Tyler');
    });
  });
}
