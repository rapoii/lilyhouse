import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilyhouse/core/presentation/main_scaffold.dart';
import 'package:lilyhouse/features/calendar/presentation/calendar_screen.dart';
import 'package:lilyhouse/features/costumes/data/costume_repository.dart';
import 'package:lilyhouse/features/costumes/domain/accessory.dart';
import 'package:lilyhouse/features/costumes/domain/costume.dart';
import 'package:lilyhouse/features/costumes/presentation/costume_list_screen.dart';
import 'package:lilyhouse/features/installments/data/installment_repository.dart';
import 'package:lilyhouse/features/installments/domain/installment.dart';
import 'package:lilyhouse/features/installments/domain/installment_log.dart';
import 'package:lilyhouse/features/installments/presentation/installment_list_screen.dart';
import 'package:lilyhouse/features/rentals/data/rental_repository.dart';
import 'package:lilyhouse/features/rentals/domain/customer.dart';
import 'package:lilyhouse/features/rentals/domain/rental.dart';

class MockCostumeRepository implements ICostumeRepository {
  final List<Costume> costumes;
  MockCostumeRepository([this.costumes = const []]);

  @override
  Future<int> insertCostume(Costume costume) async => 1;
  @override
  Future<Costume?> getCostumeById(String id) async => null;
  @override
  Future<List<Costume>> getAllCostumes() async => costumes;
  @override
  Future<List<Costume>> searchCostumes({String? query, CostumeStatus? status, String? size}) async => costumes;
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
}

class MockRentalRepository implements IRentalRepository {
  final List<Rental> rentals;
  final List<Customer> customers;
  MockRentalRepository({this.rentals = const [], this.customers = const []});

  @override
  Future<int> insertCustomer(Customer customer) async => 1;
  @override
  Future<Customer?> getCustomerById(String id) async => null;
  @override
  Future<List<Customer>> getAllCustomers() async => customers;
  @override
  Future<List<Customer>> searchCustomers(String query) async => customers;
  @override
  Future<int> updateCustomer(Customer customer) async => 1;
  @override
  Future<int> deleteCustomer(String id) async => 1;

  @override
  Future<int> insertRental(Rental rental) async => 1;
  @override
  Future<Rental?> getRentalById(String id) async => null;
  @override
  Future<List<Rental>> getAllRentals() async => rentals;
  @override
  Future<List<Rental>> getRentalsForDate(DateTime date) async => rentals;
  @override
  Future<List<Rental>> getRentalsByDateRange(DateTime start, DateTime end) async => rentals;
  @override
  Future<List<Rental>> getRentalsByCostumeId(String costumeId) async => rentals;
  @override
  Future<List<Rental>> getRentalsByStatus(RentalItemStatus status) async => rentals;
  @override
  Future<int> updateRental(Rental rental) async => 1;
  @override
  Future<int> deleteRental(String id) async => 1;
  @override
  Future<bool> hasConflict(Rental candidate) async => false;
  @override
  Future<List<Rental>> findConflicts(Rental candidate) async => [];
}

class MockInstallmentRepository implements IInstallmentRepository {
  final List<Installment> installments;
  MockInstallmentRepository([this.installments = const []]);

  @override
  Future<int> insertInstallment(Installment installment) async => 1;
  @override
  Future<Installment?> getInstallmentById(String id) async => null;
  @override
  Future<List<Installment>> getAllInstallments() async => installments;
  @override
  Future<List<Installment>> getInstallmentsByStatus(InstallmentStatus status) async => installments;
  @override
  Future<int> updateInstallment(Installment installment) async => 1;
  @override
  Future<int> deleteInstallment(String id) async => 1;
  @override
  Future<int> addPaymentLog(InstallmentLog log) async => 1;
  @override
  Future<List<InstallmentLog>> getLogsForInstallment(String installmentId) async => [];
  @override
  Future<int> deletePaymentLog(String logId, String installmentId) async => 1;
}

void main() {
  testWidgets('MainScaffold renders navigation bar with 4 tabs and switches screens', (WidgetTester tester) async {
    final mockCostumes = MockCostumeRepository();
    final mockRentals = MockRentalRepository();
    final mockInstallments = MockInstallmentRepository();

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: MainScaffold(
            costumeRepository: mockCostumes,
            rentalRepository: mockRentals,
            installmentRepository: mockInstallments,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    // Verify all 4 tabs exist in navigation bar
    expect(find.text('Katalog'), findsOneWidget);
    expect(find.text('Kalender'), findsOneWidget);
    expect(find.text('Cicilan'), findsOneWidget);
    expect(find.text('Pengaturan'), findsOneWidget);

    // Initial screen is CostumeListScreen (Katalog)
    expect(find.byType(CostumeListScreen), findsOneWidget);

    // Tap Kalender tab
    await tester.tap(find.text('Kalender'));
    await tester.pumpAndSettle();
    expect(find.byType(CalendarScreen), findsOneWidget);

    // Tap Cicilan tab
    await tester.tap(find.text('Cicilan'));
    await tester.pumpAndSettle();
    expect(find.byType(InstallmentListScreen), findsOneWidget);

    // Tap Pengaturan tab
    await tester.tap(find.text('Pengaturan'));
    await tester.pumpAndSettle();
    expect(find.text('Pengaturan'), findsWidgets);
    expect(find.text('Sinkronkan Sekarang'), findsOneWidget);
  });
}
