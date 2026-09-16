import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilyhouse/core/widgets/skeleton_loader.dart';

void main() {
  group('SkeletonLoader', () {
    testWidgets('renders one placeholder per requested item', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SkeletonLoader(itemCount: 4),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(SkeletonLoader), findsOneWidget);
      for (var i = 0; i < 4; i++) {
        expect(find.byKey(Key('skeleton_item_$i')), findsOneWidget,
            reason: 'placeholder #$i should be rendered');
      }
      expect(find.byKey(const Key('skeleton_item_4')), findsNothing);
    });

    testWidgets('renders skeleton boxes that pulse', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SkeletonLoader(itemCount: 2),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(SkeletonBox), findsWidgets);
    });

    testWidgets('supports the card layout used by the installments list',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SkeletonLoader(itemCount: 3, layout: SkeletonLayout.card),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('skeleton_item_2')), findsOneWidget);
    });

    testWidgets('SkeletonBox renders standalone without a pulse scope',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SkeletonBox(width: 40, height: 40),
          ),
        ),
      );

      expect(find.byType(SkeletonBox), findsOneWidget);
    });

    testWidgets('stops animating once removed from the tree', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SkeletonLoader(itemCount: 3),
          ),
        ),
      );
      await tester.pump();

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SizedBox.shrink()),
        ),
      );
      // A settled pump proves the repeating controller was disposed with the
      // widget instead of leaking frames forever.
      await tester.pumpAndSettle();

      expect(find.byType(SkeletonLoader), findsNothing);
    });
  });
}
