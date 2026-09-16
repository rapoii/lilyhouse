import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilyhouse/core/widgets/unsaved_changes_guard.dart';

void main() {
  Widget harness({required VoidCallback onResult}) {
    return CupertinoApp(
      home: CupertinoPageScaffold(
        child: Center(
          child: Builder(
            builder: (context) => CupertinoButton(
              onPressed: () async {
                final discard = await confirmDiscardChanges(context);
                onResult.call();
                expect(discard, isTrue);
              },
              child: const Text('Buka'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('shows an Apple HIG alert with both safe and destructive actions',
      (tester) async {
    await tester.pumpWidget(harness(onResult: () {}));

    await tester.tap(find.text('Buka'));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    expect(find.text('Batalkan Perubahan?'), findsOneWidget);
    expect(find.text('Perubahan yang belum disimpan akan hilang.'), findsOneWidget);
    // The safe choice is listed first and never destructive.
    expect(find.text('Lanjut Mengisi'), findsOneWidget);
    expect(find.text('Keluar'), findsOneWidget);
  });

  testWidgets('returning "Keluar" resolves to true (allow leaving)', (tester) async {
    var called = false;
    await tester.pumpWidget(harness(onResult: () => called = true));

    await tester.tap(find.text('Buka'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keluar'));
    await tester.pumpAndSettle();

    expect(called, isTrue);
    expect(find.byType(CupertinoAlertDialog), findsNothing);
  });

  testWidgets('returning "Lanjut Mengisi" resolves to false (stay on form)',
      (tester) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: Center(
            child: Builder(
              builder: (context) => CupertinoButton(
                onPressed: () async {
                  final discard = await confirmDiscardChanges(context);
                  expect(discard, isFalse);
                },
                child: const Text('Buka'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Buka'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lanjut Mengisi'));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoAlertDialog), findsNothing);
  });
}
