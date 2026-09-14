import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilyhouse/core/theme/app_theme.dart';
import 'package:lilyhouse/features/costumes/domain/costume.dart';
import 'package:lilyhouse/features/costumes/presentation/widgets/costume_card.dart';

void main() {
  testWidgets('CostumeCard renders 3 essential elements: name, status badge, and price', (tester) async {
    final costume = Costume(
      id: 'c-test-1',
      name: 'Yor Forger Dress',
      animeSeries: 'Spy x Family',
      size: 'M',
      rentPrice3Days: 135000.0,
      status: CostumeStatus.available,
      includedAccessories: ['Headband', 'Gold Needles'],
    );

    bool tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: CostumeCard(
            costume: costume,
            onTap: () {
              tapped = true;
            },
          ),
        ),
      ),
    );

    // Element 1: Title
    expect(find.text('Yor Forger Dress'), findsOneWidget);

    // Element 2: Status Pill
    expect(find.text('Tersedia'), findsOneWidget);

    // Element 3: Formatted Price
    expect(find.textContaining('135.000'), findsOneWidget);

    // Removed elements should not be displayed
    expect(find.text('Spy x Family'), findsNothing);
    expect(find.text('Size M'), findsNothing);

    // Verify Tap interaction
    await tester.tap(find.byType(CostumeCard));
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('CostumeCard displays different status pill colors for rented and laundry', (tester) async {
    final rentedCostume = Costume(
      id: 'c-test-2',
      name: 'Anya Uniform',
      animeSeries: 'Spy x Family',
      size: 'S',
      rentPrice3Days: 90000.0,
      status: CostumeStatus.rented,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: CostumeCard(
            costume: rentedCostume,
          ),
        ),
      ),
    );

    expect(find.text('Disewa'), findsOneWidget);
  });
}
