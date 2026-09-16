import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilyhouse/core/theme/app_theme.dart';
import 'package:lilyhouse/features/calendar/presentation/calendar_screen.dart';
import 'package:lilyhouse/features/costumes/data/costume_repository.dart';
import 'package:lilyhouse/features/costumes/domain/accessory.dart';
import 'package:lilyhouse/features/costumes/domain/costume.dart';
import 'package:lilyhouse/features/costumes/domain/costume_rental_history.dart';
import 'package:lilyhouse/features/costumes/presentation/costume_list_screen.dart';
import 'package:lilyhouse/features/rentals/data/rental_repository.dart';
import 'package:lilyhouse/features/rentals/domain/customer.dart';
import 'package:lilyhouse/features/rentals/domain/rental.dart';

/// Minimal in-memory rental repository for the ops-pulse tests.
class OpsMockRentalRepository implements IRentalRepository {
  final List<Rental> _rentals = [];
  final List<Customer> _customers = [];

  OpsMockRentalRepository({
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
  Future<List<Customer>> getAllCustomers() async => List<Customer>.from(_customers);

  @override
  Future<List<Customer>> searchCustomers(String query) async =>
      _customers.where((c) => c.fullName.toLowerCase().contains(query.toLowerCase())).toList();

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
  Future<int> getActiveRentalsCountByCustomer(String customerId) async => 0;

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
  Future<List<Rental>> getAllRentals() async => List<Rental>.from(_rentals);

  @override
  Future<List<Rental>> getRentalsForDate(DateTime date) async =>
      getAllRentals();

  @override
  Future<List<Rental>> getRentalsByDateRange(DateTime start, DateTime end) async =>
      getAllRentals();

  @override
  Future<List<Rental>> getRentalsByCostumeId(String costumeId) async =>
      _rentals.where((r) => r.costumeId == costumeId).toList();

  @override
  Future<List<Rental>> getRentalsByStatus(RentalItemStatus status) async =>
      _rentals.where((r) => r.itemStatus == status).toList();

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
  Future<bool> hasConflict(Rental candidate) async => false;

  @override
  Future<List<Rental>> findConflicts(Rental candidate) async => const [];
}

/// In-memory costume repository that actually applies status updates, so the
/// 'Sedang Disewa' filter can be verified end-to-end.
class OpsMockCostumeRepository implements ICostumeRepository {
  final List<Costume> costumes;

  OpsMockCostumeRepository(this.costumes);

  @override
  Future<int> insertCostume(Costume costume) async {
    costumes.removeWhere((c) => c.id == costume.id);
    costumes.add(costume);
    return 1;
  }

  @override
  Future<Costume?> getCostumeById(String id) async {
    try {
      return costumes.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Costume>> getAllCostumes() async => List<Costume>.from(costumes);

  @override
  Future<List<Costume>> searchCostumes({
    String? query,
    CostumeStatus? status,
    String? size,
    String? series,
    String? sortBy,
  }) async {
    var result = List<Costume>.from(costumes);
    if (status != null) {
      result = result.where((c) => c.status == status).toList();
    }
    return result;
  }

  @override
  Future<int> updateCostume(Costume costume) async {
    final i = costumes.indexWhere((c) => c.id == costume.id);
    if (i >= 0) {
      costumes[i] = costume;
      return 1;
    }
    return 0;
  }

  @override
  Future<List<String>> getDistinctAnimeSeries() async => [];

  @override
  Future<int> deleteCostume(String id) async {
    costumes.removeWhere((c) => c.id == id);
    return 1;
  }

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
  group('Daily ops pulse card', () {
    testWidgets('shows zeroed metrics when there are no bookings', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: CalendarScreen(
            rentalRepository: OpsMockRentalRepository(),
            costumeRepository: OpsMockCostumeRepository([]),
            initialFocusedDay: DateTime(2026, 9, 6),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('daily_ops_card')), findsOneWidget);
      expect(find.text('PULASAN OPERASIONAL HARI INI'), findsOneWidget);
      expect(find.byKey(const Key('ops_metric_active_bookings')), findsOneWidget);
      expect(find.byKey(const Key('ops_metric_unsettled_dp')), findsOneWidget);
      expect(find.byKey(const Key('ops_metric_due_today')), findsOneWidget);
      expect(find.text('Aman'), findsOneWidget);
    });

    testWidgets('counts active booking, unsettled DP, and due-today rental', (tester) async {
      final rentalRepo = OpsMockRentalRepository();
      await rentalRepo.insertCustomer(Customer(
        id: 'cust_001',
        fullName: 'Jihan Fatin',
        phone: '082245777711',
        address: 'Jakarta',
      ));

      // Active booking with DP recorded but not yet fully paid.
      await rentalRepo.insertRental(Rental(
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
        itemStatus: RentalItemStatus.rented,
      ));

      // Second booking on the same day that is already fully paid.
      await rentalRepo.insertRental(Rental(
        id: 'rent_002',
        costumeId: 'Citlali',
        customerId: 'cust_001',
        startDate: DateTime(2026, 9, 6),
        endDate: DateTime(2026, 9, 6),
        durationDays: 1,
        purpose: 'homecos',
        totalPrice: 100000.0,
        dpAmount: 100000.0,
        paymentStatus: RentalPaymentStatus.paid,
        itemStatus: RentalItemStatus.rented,
      ));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: CalendarScreen(
            rentalRepository: rentalRepo,
            costumeRepository: OpsMockCostumeRepository([]),
            initialFocusedDay: DateTime(2026, 9, 6),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      // rent_001 + rent_002 both run on Sept 6.
      expect(_metricValue(tester, 'ops_metric_active_bookings'), '2');
      // Only rent_001 has an unsettled DP.
      expect(_metricValue(tester, 'ops_metric_unsettled_dp'), '1');
      // rent_002 ends on Sept 6 and is not yet returned.
      expect(_metricValue(tester, 'ops_metric_due_today'), '1');
      expect(find.text('1 Jatuh Tempo'), findsOneWidget);
    });

    testWidgets('excludes cancelled and completed bookings from metrics', (tester) async {
      final rentalRepo = OpsMockRentalRepository();
      await rentalRepo.insertCustomer(Customer(
        id: 'cust_001',
        fullName: 'Jihan Fatin',
        phone: '082245777711',
        address: 'Jakarta',
      ));

      await rentalRepo.insertRental(Rental(
        id: 'rent_cancelled',
        costumeId: 'Citlali',
        customerId: 'cust_001',
        startDate: DateTime(2026, 9, 5),
        endDate: DateTime(2026, 9, 7),
        durationDays: 3,
        purpose: 'homecos',
        totalPrice: 150000.0,
        dpAmount: 50000.0,
        paymentStatus: RentalPaymentStatus.dpPaid,
        itemStatus: RentalItemStatus.cancelled,
      ));

      await rentalRepo.insertRental(Rental(
        id: 'rent_completed',
        costumeId: 'Citlali',
        customerId: 'cust_001',
        startDate: DateTime(2026, 9, 6),
        endDate: DateTime(2026, 9, 6),
        durationDays: 1,
        purpose: 'homecos',
        totalPrice: 100000.0,
        paymentStatus: RentalPaymentStatus.paid,
        itemStatus: RentalItemStatus.completed,
      ));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: CalendarScreen(
            rentalRepository: rentalRepo,
            costumeRepository: OpsMockCostumeRepository([]),
            initialFocusedDay: DateTime(2026, 9, 6),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(_metricValue(tester, 'ops_metric_active_bookings'), '0');
      expect(_metricValue(tester, 'ops_metric_unsettled_dp'), '0');
      expect(_metricValue(tester, 'ops_metric_due_today'), '0');
      expect(find.text('Aman'), findsOneWidget);
    });
  });

  group('Sedang Disewa costume filter', () {
    testWidgets('filter sheet exposes the "Sedang Disewa" status option', (tester) async {
      final repo = OpsMockCostumeRepository([
        const Costume(
          id: 'c1',
          name: 'Furina Archon',
          animeSeries: 'Genshin Impact',
          size: 'M',
          rentPrice3Days: 150000,
          status: CostumeStatus.available,
        ),
        const Costume(
          id: 'c2',
          name: 'Kafka Stellaron',
          animeSeries: 'Honkai Star Rail',
          size: 'L',
          rentPrice3Days: 160000,
          status: CostumeStatus.rented,
        ),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: CostumeListScreen(repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      // Open the filter sheet.
      await tester.tap(find.byIcon(CupertinoIcons.slider_horizontal_3));
      await tester.pumpAndSettle();

      expect(find.text('Sedang Disewa'), findsOneWidget);

      // Select it.
      await tester.tap(find.text('Sedang Disewa'));
      await tester.pumpAndSettle();

      // Apply the filter.
      await tester.tap(find.text('Terapkan'));
      await tester.pumpAndSettle();

      // Only the rented costume remains.
      expect(find.text('Kafka Stellaron'), findsOneWidget);
      expect(find.text('Furina Archon'), findsNothing);

      // The active filter chip shows the "Sedang Disewa" label.
      expect(find.widgetWithText(CupertinoButton, 'Sedang Disewa'), findsOneWidget);
    });
  });
}

String _metricValue(WidgetTester tester, String key) {
  final column = tester.widget<Column>(find.byKey(Key(key)));
  final valueText = column.children.whereType<Text>().first;
  return valueText.data!;
}
