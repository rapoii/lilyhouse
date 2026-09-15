import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilyhouse/core/theme/app_theme.dart';
import 'package:lilyhouse/features/costumes/domain/costume.dart';
import 'package:lilyhouse/features/costumes/domain/accessory.dart';
import 'package:lilyhouse/features/costumes/data/costume_repository.dart';
import 'package:lilyhouse/features/costumes/presentation/costume_list_screen.dart';

class FilterMockRepository implements ICostumeRepository {
  final List<Costume> costumes = [
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
      name: 'Hutao Ghost',
      animeSeries: 'Genshin Impact',
      size: 'S',
      rentPrice3Days: 120000,
      status: CostumeStatus.available,
    ),
    const Costume(
      id: 'c3',
      name: 'Kafka Stellaron',
      animeSeries: 'Honkai Star Rail',
      size: 'L',
      rentPrice3Days: 160000,
      status: CostumeStatus.rented,
    ),
  ];

  @override
  Future<List<Costume>> getAllCostumes() async => costumes;

  @override
  Future<List<Costume>> searchCostumes({
    String? query,
    CostumeStatus? status,
    String? size,
    String? series,
    String? sortBy,
  }) async {
    var result = List<Costume>.from(costumes);
    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      result = result.where((c) => c.name.toLowerCase().contains(q) || c.animeSeries.toLowerCase().contains(q)).toList();
    }
    if (status != null) {
      result = result.where((c) => c.status == status).toList();
    }
    if (size != null && size.isNotEmpty && size != 'All') {
      result = result.where((c) => c.size == size).toList();
    }
    if (series != null && series.trim().isNotEmpty && series != 'Semua') {
      result = result.where((c) => c.animeSeries == series.trim()).toList();
    }
    if (sortBy == 'price_asc') {
      result.sort((a, b) => a.rentPrice3Days.compareTo(b.rentPrice3Days));
    } else if (sortBy == 'price_desc') {
      result.sort((a, b) => b.rentPrice3Days.compareTo(a.rentPrice3Days));
    } else if (sortBy == 'name_desc') {
      result.sort((a, b) => b.name.compareTo(a.name));
    } else {
      result.sort((a, b) => a.name.compareTo(b.name));
    }
    return result;
  }

  @override
  Future<List<String>> getDistinctAnimeSeries() async {
    return ['Genshin Impact', 'Honkai Star Rail'];
  }

  @override
  Future<Costume?> getCostumeById(String id) async => costumes.firstWhere((c) => c.id == id);
  @override
  Future<int> insertCostume(Costume costume) async => 1;
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
}

void main() {
  testWidgets('Filter button opens filter sheet and filters by category', (tester) async {
    final repo = FilterMockRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: CostumeListScreen(repository: repo),
      ),
    );

    await tester.pumpAndSettle();

    // Verify initial costumes
    expect(find.text('Furina Archon'), findsOneWidget);
    expect(find.text('Hutao Ghost'), findsOneWidget);
    expect(find.text('Kafka Stellaron'), findsOneWidget);

    // Tap filter button
    final filterButton = find.byIcon(CupertinoIcons.slider_horizontal_3);
    expect(filterButton, findsOneWidget);
    await tester.tap(filterButton);
    await tester.pumpAndSettle();

    // Verify filter sheet is opened
    expect(find.text('Filter & Urutkan'), findsOneWidget);
    expect(find.text('KATEGORI / SERI ANIME'), findsOneWidget);
    expect(find.text('Honkai Star Rail'), findsWidgets);
    expect(find.text('Genshin Impact'), findsWidgets);

    // Select 'Honkai Star Rail' (in the modal sheet)
    await tester.tap(find.text('Honkai Star Rail').last);
    await tester.pumpAndSettle();

    // Tap 'Terapkan'
    await tester.tap(find.text('Terapkan'));
    await tester.pumpAndSettle();

    // Verify filtered result: only Kafka Stellaron appears
    expect(find.text('Kafka Stellaron'), findsOneWidget);
    expect(find.text('Furina Archon'), findsNothing);
    expect(find.text('Hutao Ghost'), findsNothing);

    // Verify active filter chip appears
    expect(find.text('Honkai Star Rail'), findsWidgets);

    // Remove active filter chip by tapping clear
    final clearChip = find.byIcon(CupertinoIcons.clear_circled_solid);
    await tester.tap(clearChip);
    await tester.pumpAndSettle();

    // Verify all costumes return
    expect(find.text('Furina Archon'), findsOneWidget);
    expect(find.text('Hutao Ghost'), findsOneWidget);
    expect(find.text('Kafka Stellaron'), findsOneWidget);
  });
}
