import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilyhouse/core/theme/app_theme.dart';
import 'package:lilyhouse/features/costumes/domain/costume.dart';
import 'package:lilyhouse/features/costumes/domain/accessory.dart';
import 'package:lilyhouse/features/costumes/data/costume_repository.dart';
import 'package:lilyhouse/features/costumes/presentation/costume_list_screen.dart';
import 'package:lilyhouse/features/costumes/presentation/costume_detail_screen.dart';
import 'package:lilyhouse/features/costumes/presentation/add_costume_sheet.dart';

class MockCostumeRepository implements ICostumeRepository {
  final List<Costume> _costumes = [];
  final List<Accessory> _accessories = [];

  MockCostumeRepository({List<Costume>? costumes, List<Accessory>? accessories}) {
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
  Future<Costume?> getCostumeById(String id) async {
    try {
      return _costumes.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Costume>> getAllCostumes() async {
    final list = List<Costume>.from(_costumes);
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  @override
  Future<List<Costume>> searchCostumes({
    String? query,
    CostumeStatus? status,
    String? size,
    String? series,
    String? sortBy,
  }) async {
    var result = List<Costume>.from(_costumes);
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
    return _costumes.map((c) => c.animeSeries).where((s) => s.isNotEmpty && s != '-').toSet().toList()..sort();
  }

  @override
  Future<int> updateCostume(Costume costume) async {
    final index = _costumes.indexWhere((c) => c.id == costume.id);
    if (index >= 0) {
      _costumes[index] = costume;
      return 1;
    }
    return 0;
  }

  @override
  Future<int> deleteCostume(String id) async {
    _costumes.removeWhere((c) => c.id == id);
    return 1;
  }

  @override
  Future<int> addAccessory(Accessory accessory) async {
    _accessories.removeWhere((a) => a.id == accessory.id);
    _accessories.add(accessory);
    return 1;
  }

  @override
  Future<List<Accessory>> getAccessoriesByCostumeId(String costumeId) async {
    return _accessories.where((a) => a.relatedCostumeId == costumeId).toList();
  }

  @override
  Future<int> updateAccessory(Accessory accessory) async {
    final index = _accessories.indexWhere((a) => a.id == accessory.id);
    if (index >= 0) {
      _accessories[index] = accessory;
      return 1;
    }
    return 0;
  }

  @override
  Future<int> deleteAccessory(String id) async {
    _accessories.removeWhere((a) => a.id == id);
    return 1;
  }

  @override
  Future<int> getActiveRentalsCount(String costumeId) async => 0;
}

void main() {
  late MockCostumeRepository repository;

  setUp(() {
    repository = MockCostumeRepository(
      costumes: [
        const Costume(
          id: 'cos-1',
          name: 'Hatsune Miku',
          animeSeries: 'Vocaloid',
          size: 'M',
          rentPrice3Days: 150000,
          status: CostumeStatus.available,
        ),
        const Costume(
          id: 'cos-2',
          name: 'Makima Suit',
          animeSeries: 'Chainsaw Man',
          size: 'L',
          rentPrice3Days: 120000,
          status: CostumeStatus.rented,
        ),
      ],
      accessories: [
        const Accessory(
          id: 'acc-1',
          name: 'Tie & Badge',
          type: 'Neckwear',
          relatedCostumeId: 'cos-2',
        ),
      ],
    );
  });

  testWidgets('CostumeListScreen lists costumes and responds to search', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: CostumeListScreen(repository: repository),
      ),
    );

    // Initial async fetch
    await tester.pump();
    await tester.pump();

    expect(find.text('Hatsune Miku'), findsOneWidget);
    expect(find.text('Makima Suit'), findsOneWidget);

    // Search
    final searchField = find.byType(CupertinoSearchTextField);
    await tester.enterText(searchField, 'Makima');
    await tester.pump();
    await tester.pump();

    expect(find.text('Makima Suit'), findsOneWidget);
    expect(find.text('Hatsune Miku'), findsNothing);
  });

  testWidgets('CostumeDetailScreen displays costume details and accessories', (tester) async {
    final costume = await repository.getCostumeById('cos-2');
    expect(costume, isNotNull);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: CostumeDetailScreen(
          costume: costume!,
          repository: repository,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Makima Suit'), findsWidgets);
    expect(find.text('Chainsaw Man'), findsWidgets);

    // Scroll down to see accessories section
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(find.text('Tie & Badge'), findsOneWidget);
    expect(find.text('Disewa'), findsWidgets);
    expect(find.text('Ubah'), findsOneWidget);
  });

  testWidgets('AddCostumeSheet in edit mode loads existing data and updates', (tester) async {
    final costume = await repository.getCostumeById('cos-1');
    expect(costume, isNotNull);

    bool savedCalled = false;
    bool deletedCalled = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: AddCostumeSheet(
            repository: repository,
            initialCostume: costume,
            onSaved: () => savedCalled = true,
            onDeleted: () => deletedCalled = true,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Ubah Kostum'), findsOneWidget);
    expect(find.text('Hatsune Miku'), findsOneWidget);
    expect(find.text('Vocaloid'), findsOneWidget);

    // Scroll until 'Hapus Kostum' is visible
    final deleteFinder = find.text('Hapus Kostum');
    await tester.scrollUntilVisible(
      deleteFinder,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(deleteFinder, findsOneWidget);

    // Change name
    final nameField = find.widgetWithText(CupertinoTextField, 'Hatsune Miku');
    await tester.enterText(nameField, 'Hatsune Miku NT');
    await tester.pump();

    // Tap Simpan
    final saveButton = find.widgetWithText(CupertinoButton, 'Simpan');
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(savedCalled, isTrue);
    expect(deletedCalled, isFalse);
    final updated = await repository.getCostumeById('cos-1');
    expect(updated?.name, 'Hatsune Miku NT');
  });

  testWidgets('AddCostumeSheet in edit mode displays and manages accessories', (tester) async {
    final costume = await repository.getCostumeById('cos-2');
    expect(costume, isNotNull);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: AddCostumeSheet(
            repository: repository,
            initialCostume: costume,
            onSaved: () {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Section Aksesori & Kelengkapan harus ada di edit mode
    expect(find.text('AKSESORI & KELENGKAPAN'), findsOneWidget);
    // Aksesori yang ada di DB ('Tie & Badge') harus terlihat
    expect(find.text('Tie & Badge'), findsOneWidget);
    expect(find.text('Tambah Aksesori'), findsOneWidget);

    // Hapus aksesori 'Tie & Badge'
    final minusBtn = find.widgetWithIcon(CupertinoButton, CupertinoIcons.minus_circle_fill);
    expect(minusBtn, findsOneWidget);
    await tester.ensureVisible(minusBtn);
    await tester.pumpAndSettle();
    await tester.tap(minusBtn);
    await tester.pumpAndSettle();

    // Setelah dihapus dari daftar di form
    expect(find.text('Tie & Badge'), findsNothing);
    expect(find.text('Belum ada aksesori terdaftar'), findsOneWidget);

    // Simpan
    final saveButton = find.widgetWithText(CupertinoButton, 'Simpan');
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    // Pastikan di repository aksesori ikut terhapus
    final accs = await repository.getAccessoriesByCostumeId('cos-2');
    expect(accs, isEmpty);
  });

  testWidgets('CostumeListScreen filter button has min 44x44pt touch target and opens filter sheet', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: CostumeListScreen(repository: repository),
      ),
    );

    await tester.pumpAndSettle();

    // Verify filter button exists and meets Apple HIG >= 44x44pt
    final filterButtonFinder = find.byWidgetPredicate(
      (w) => w is CupertinoButton && w.child is Container && (w.child as Container).child is Stack,
    );
    expect(filterButtonFinder, findsOneWidget);

    final RenderBox filterBox = tester.renderObject(filterButtonFinder);
    expect(filterBox.size.width, greaterThanOrEqualTo(44.0));
    expect(filterBox.size.height, greaterThanOrEqualTo(44.0));

    // Tap filter button to open sheet
    await tester.tap(filterButtonFinder);
    await tester.pumpAndSettle();

    expect(find.text('Filter & Urutkan'), findsOneWidget);
  });

  testWidgets('CostumeListScreen shows interactive active filter chips with individual remove and reset all', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: CostumeListScreen(repository: repository),
      ),
    );

    await tester.pumpAndSettle();

    // Open filter sheet
    final filterButtonFinder = find.byWidgetPredicate(
      (w) => w is CupertinoButton && w.child is Container && (w.child as Container).child is Stack,
    );
    await tester.tap(filterButtonFinder);
    await tester.pumpAndSettle();

    // Select Vocaloid series
    await tester.tap(find.text('Vocaloid').last);
    await tester.pumpAndSettle();

    // Select Size M: scroll down in sheet if needed
    final sizeMFinder = find.widgetWithText(CupertinoListTile, 'M');
    await tester.scrollUntilVisible(
      sizeMFinder,
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(sizeMFinder);
    await tester.pumpAndSettle();

    // Scroll to Terapkan or tap directly
    final applyFinder = find.text('Terapkan');
    await tester.scrollUntilVisible(
      applyFinder,
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(applyFinder);
    await tester.pumpAndSettle();

    // Verify both active filter chips and "Reset Filter" chip are visible
    expect(find.text('Vocaloid'), findsWidgets);
    expect(find.text('Size M'), findsOneWidget);
    final resetAllChips = find.widgetWithText(CupertinoButton, 'Reset Filter');
    expect(resetAllChips, findsOneWidget);

    // Verify filter chip touch target >= 44pt
    final vocaloidChip = find.widgetWithText(CupertinoButton, 'Vocaloid');
    expect(vocaloidChip, findsOneWidget);
    final RenderBox chipBox = tester.renderObject(vocaloidChip);
    expect(chipBox.size.height, greaterThanOrEqualTo(44.0));

    // Remove one individual filter chip (Size M)
    final sizeChip = find.widgetWithText(CupertinoButton, 'Size M');
    expect(sizeChip, findsOneWidget);
    await tester.tap(sizeChip);
    await tester.pumpAndSettle();

    // Size chip should now be gone, Vocaloid remains
    expect(find.text('Size M'), findsNothing);
    expect(find.text('Vocaloid'), findsWidgets);

    // Open filter sheet to add another filter to test "Reset Filter" chip
    await tester.tap(filterButtonFinder);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      sizeMFinder,
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(sizeMFinder);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      applyFinder,
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(applyFinder);
    await tester.pumpAndSettle();

    // Reset all filters using the interactive reset chip
    await tester.tap(find.widgetWithText(CupertinoButton, 'Reset Filter'));
    await tester.pumpAndSettle();

    // Active chips should be gone
    expect(find.widgetWithText(CupertinoButton, 'Reset Filter'), findsNothing);
    expect(find.text('Size M'), findsNothing);
    // Both costumes shown
    expect(find.text('Hatsune Miku'), findsOneWidget);
    expect(find.text('Makima Suit'), findsOneWidget);
  });

  testWidgets('CostumeListScreen displays friendly empty state and instant Reset Filter & Pencarian button', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: CostumeListScreen(repository: repository),
      ),
    );

    await tester.pumpAndSettle();

    // Search something nonexistent
    final searchField = find.byType(CupertinoSearchTextField);
    await tester.enterText(searchField, 'NonExistentCostume12345');
    await tester.pump();
    await tester.pump();

    // Verify empty state UI elements
    expect(find.text('Tidak ada hasil yang cocok'), findsOneWidget);
    expect(find.text('Coba sesuaikan kata kunci atau filter pencarian'), findsOneWidget);

    final resetBtnFinder = find.widgetWithText(CupertinoButton, 'Reset Filter & Pencarian');
    expect(resetBtnFinder, findsOneWidget);

    // Verify touch target min 44pt
    final RenderBox resetBox = tester.renderObject(resetBtnFinder);
    expect(resetBox.size.width, greaterThanOrEqualTo(44.0));
    expect(resetBox.size.height, greaterThanOrEqualTo(44.0));

    // Tap reset button
    await tester.tap(resetBtnFinder);
    await tester.pumpAndSettle();

    // Search query should be cleared and full catalog restored
    expect(find.text('Tidak ada hasil yang cocok'), findsNothing);
    expect(find.text('Hatsune Miku'), findsOneWidget);
    expect(find.text('Makima Suit'), findsOneWidget);
  });
}
