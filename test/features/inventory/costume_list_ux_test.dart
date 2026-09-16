import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilyhouse/core/theme/app_theme.dart';
import 'package:lilyhouse/core/widgets/skeleton_loader.dart';
import 'package:lilyhouse/features/costumes/data/costume_repository.dart';
import 'package:lilyhouse/features/costumes/domain/accessory.dart';
import 'package:lilyhouse/features/costumes/domain/costume.dart';
import 'package:lilyhouse/features/costumes/domain/costume_rental_history.dart';
import 'package:lilyhouse/features/costumes/presentation/costume_list_screen.dart';

/// Minimal in-memory costume repository.  When [gate] is supplied the search
/// call stays pending until the gate completes, which lets a test observe the
/// loading (skeleton) state.
class _CostumeRepo implements ICostumeRepository {
  _CostumeRepo({List<Costume>? costumes, this.gate})
      : _costumes = <Costume>[...?costumes];

  final List<Costume> _costumes;
  final Completer<void>? gate;

  /// Number of times [searchCostumes] has been invoked — used to prove that
  /// rapid keystrokes are coalesced into a single query.
  int searchCallCount = 0;

  @override
  Future<List<Costume>> searchCostumes({
    String? query,
    CostumeStatus? status,
    String? size,
    String? series,
    String? sortBy,
  }) async {
    searchCallCount++;
    if (gate != null) await gate!.future;
    var result = List<Costume>.from(_costumes);
    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      result = result
          .where((c) =>
              c.name.toLowerCase().contains(q) ||
              c.animeSeries.toLowerCase().contains(q))
          .toList();
    }
    if (status != null) {
      result = result.where((c) => c.status == status).toList();
    }
    result.sort((a, b) => a.name.compareTo(b.name));
    return result;
  }

  @override
  Future<List<Costume>> getAllCostumes() async => List<Costume>.from(_costumes);

  @override
  Future<Costume?> getCostumeById(String id) async {
    for (final c in _costumes) {
      if (c.id == id) return c;
    }
    return null;
  }

  @override
  Future<int> insertCostume(Costume costume) async {
    _costumes.removeWhere((c) => c.id == costume.id);
    _costumes.add(costume);
    return 1;
  }

  @override
  Future<int> updateCostume(Costume costume) async => 1;

  @override
  Future<int> deleteCostume(String id) async {
    _costumes.removeWhere((c) => c.id == id);
    return 1;
  }

  @override
  Future<List<String>> getDistinctAnimeSeries() async =>
      _costumes.map((c) => c.animeSeries).toSet().toList()..sort();

  @override
  Future<int> addAccessory(Accessory accessory) async => 1;

  @override
  Future<List<Accessory>> getAccessoriesByCostumeId(String costumeId) async =>
      const <Accessory>[];

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

const _miku = Costume(
  id: 'cos-1',
  name: 'Hatsune Miku',
  animeSeries: 'Vocaloid',
  size: 'M',
  rentPrice3Days: 150000,
  status: CostumeStatus.available,
);

const _makima = Costume(
  id: 'cos-2',
  name: 'Makima Suit',
  animeSeries: 'Chainsaw Man',
  size: 'L',
  rentPrice3Days: 200000,
  status: CostumeStatus.rented,
);

Widget _wrap(ICostumeRepository repo) => MaterialApp(
      theme: AppTheme.lightTheme,
      home: CostumeListScreen(repository: repo),
    );

void main() {
  group('CostumeListScreen search debounce', () {
    testWidgets('waits 300 ms before applying the typed query', (tester) async {
      final repo = _CostumeRepo(costumes: [_miku, _makima]);
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      expect(find.text('Hatsune Miku'), findsOneWidget);
      expect(find.text('Makima Suit'), findsOneWidget);

      await tester.enterText(find.byType(CupertinoSearchTextField), 'Makima');
      await tester.pump(); // register the keystroke, arm the debounce

      // Well within the window: the previous results must still be on screen.
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Hatsune Miku'), findsOneWidget,
          reason: 'debounce must not fire before 300 ms');

      // Past the window: the query is applied and results narrow.
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();

      expect(find.text('Makima Suit'), findsOneWidget);
      expect(find.text('Hatsune Miku'), findsNothing);
    });

    testWidgets('coalesces a burst of keystrokes into one query', (tester) async {
      final repo = _CostumeRepo(costumes: [_miku, _makima]);
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      final before = repo.searchCallCount;

      await tester.enterText(find.byType(CupertinoSearchTextField), 'M');
      await tester.pump(const Duration(milliseconds: 80));
      await tester.enterText(find.byType(CupertinoSearchTextField), 'Ma');
      await tester.pump(const Duration(milliseconds: 80));
      await tester.enterText(find.byType(CupertinoSearchTextField), 'Mak');
      await tester.pump(const Duration(milliseconds: 80));

      expect(repo.searchCallCount, before,
          reason: 'no query should run while the user is still typing');

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(repo.searchCallCount, before + 1,
          reason: 'the burst must collapse into a single search');
    });
  });

  group('CostumeListScreen result-count indicator', () {
    testWidgets('shows the unfiltered catalog size', (tester) async {
      final repo = _CostumeRepo(costumes: [_miku, _makima]);
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('costume_result_count')), findsOneWidget);
      expect(find.text('2 kostum'), findsOneWidget);
    });

    testWidgets('switches to a filtered count when searching', (tester) async {
      final repo = _CostumeRepo(costumes: [_miku, _makima]);
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(CupertinoSearchTextField), 'Makima');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(find.byKey(const Key('costume_result_count')), findsOneWidget);
      expect(find.text('1 hasil'), findsOneWidget);
      expect(find.text('2 kostum'), findsNothing);
    });

    testWidgets('hides the indicator when nothing matches', (tester) async {
      final repo = _CostumeRepo(costumes: [_miku, _makima]);
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byType(CupertinoSearchTextField), 'zzz-no-match');
      await tester.pump(const Duration(milliseconds: 300));
      // Let the content → empty crossfade finish; AnimatedSwitcher keeps the
      // outgoing content (and its count chip) mounted during the 220 ms fade.
      await tester.pumpAndSettle();

      expect(find.text('Tidak ada hasil yang cocok'), findsOneWidget);
      expect(find.byKey(const Key('costume_result_count')), findsNothing);
    });
  });

  group('CostumeListScreen skeleton loading', () {
    testWidgets('shows skeleton placeholders while the first fetch is pending',
        (tester) async {
      final gate = Completer<void>();
      final repo = _CostumeRepo(costumes: [_miku, _makima], gate: gate);

      await tester.pumpWidget(_wrap(repo));
      await tester.pump();

      expect(find.byType(SkeletonLoader), findsOneWidget);
      expect(find.byKey(const Key('skeleton_item_0')), findsOneWidget);
      expect(find.byType(CupertinoActivityIndicator), findsNothing);

      gate.complete();
      await tester.pumpAndSettle();

      expect(find.byType(SkeletonLoader), findsNothing);
      expect(find.text('Hatsune Miku'), findsOneWidget);
    });
  });
}
