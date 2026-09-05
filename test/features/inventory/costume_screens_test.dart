import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilyhouse/core/theme/app_theme.dart';
import 'package:lilyhouse/features/costumes/domain/costume.dart';
import 'package:lilyhouse/features/costumes/domain/accessory.dart';
import 'package:lilyhouse/features/costumes/data/costume_repository.dart';
import 'package:lilyhouse/features/costumes/presentation/costume_list_screen.dart';
import 'package:lilyhouse/features/costumes/presentation/costume_detail_screen.dart';

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
  Future<List<Costume>> searchCostumes({String? query, CostumeStatus? status, String? size}) async {
    var result = List<Costume>.from(_costumes);
    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      result = result.where((c) => c.name.toLowerCase().contains(q) || c.animeSeries.toLowerCase().contains(q)).toList();
    }
    if (status != null) {
      result = result.where((c) => c.status == status).toList();
    }
    if (size != null && size.isNotEmpty) {
      result = result.where((c) => c.size == size).toList();
    }
    result.sort((a, b) => a.name.compareTo(b.name));
    return result;
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
    final searchField = find.byType(TextField);
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

    await tester.pump();
    await tester.pump();

    expect(find.text('Makima Suit'), findsWidgets);
    expect(find.text('Chainsaw Man'), findsWidgets);
    expect(find.text('Tie & Badge'), findsOneWidget);
    expect(find.text('Rented'), findsWidgets);
  });
}
