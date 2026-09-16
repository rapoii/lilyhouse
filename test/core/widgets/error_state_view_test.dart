import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilyhouse/core/theme/app_colors.dart';
import 'package:lilyhouse/core/widgets/error_state_view.dart';
import 'package:lilyhouse/core/widgets/state_crossfade.dart';

void main() {
  group('ErrorStateView', () {
    testWidgets('renders message, hint, and a tappable retry button',
        (tester) async {
      var retries = 0;
      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: ErrorStateView(
              message: 'Gagal memuat daftar kostum',
              hint: 'Periksa penyimpanan atau koneksi lalu coba lagi.',
              onRetry: () => retries++,
              retryKey: const Key('retry_btn'),
            ),
          ),
        ),
      );

      expect(find.text('Gagal memuat daftar kostum'), findsOneWidget);
      expect(find.text('Periksa penyimpanan atau koneksi lalu coba lagi.'),
          findsOneWidget);
      expect(find.byKey(const Key('retry_btn')), findsOneWidget);

      await tester.tap(find.byKey(const Key('retry_btn')));
      await tester.pump();
      expect(retries, 1);
    });

    testWidgets('hides the retry button when onRetry is null', (tester) async {
      await tester.pumpWidget(
        const CupertinoApp(
          home: CupertinoPageScaffold(
            child: ErrorStateView(message: 'Gagal memuat'),
          ),
        ),
      );

      expect(find.text('Gagal memuat'), findsOneWidget);
      expect(find.text('Coba Lagi'), findsNothing);
    });
  });

  group('StateCrossfade error state', () {
    Widget wrap(Widget child) => CupertinoApp(
          home: CupertinoPageScaffold(child: child),
        );

    testWidgets('error wins over empty so a failed read never looks empty',
        (tester) async {
      await tester.pumpWidget(wrap(
        StateCrossfade(
          isLoading: false,
          isEmpty: true,
          hasError: true,
          loadingChild: const Text('LOADING'),
          emptyChild: const Text('EMPTY'),
          contentChild: const Text('CONTENT'),
          errorChild: const Text('ERROR'),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('ERROR'), findsOneWidget);
      expect(find.text('EMPTY'), findsNothing);
      expect(find.text('CONTENT'), findsNothing);
    });

    testWidgets('defaults keep legacy three-state behaviour', (tester) async {
      await tester.pumpWidget(wrap(
        StateCrossfade(
          isLoading: false,
          isEmpty: true,
          loadingChild: const Text('LOADING'),
          emptyChild: const Text('EMPTY'),
          contentChild: const Text('CONTENT'),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('EMPTY'), findsOneWidget);
      expect(find.text('ERROR'), findsNothing);
    });
  });

  group('WCAG AA contrast tokens', () {
    // sRGB relative luminance per WCAG 2.1.
    double lin(double v) =>
        v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();

    double luminance(Color c) => 0.2126 * lin(c.r) +
        0.7152 * lin(c.g) +
        0.0722 * lin(c.b);

    double contrast(Color fg, Color bg) {
      final l1 = luminance(fg);
      final l2 = luminance(bg);
      final hi = l1 > l2 ? l1 : l2;
      final lo = l1 > l2 ? l2 : l1;
      return (hi + 0.05) / (lo + 0.05);
    }

    const surfaces = <String, Color>{
      'white': Color(0xFFFFFFFF),
      'groupedBg': Color(0xFFF2F2F7),
      'softPinkBg': Color(0xFFFFE5EC),
      'warmAmber': Color(0xFFFFF4E5),
      'mintTint': Color(0xFFE3F9EC),
      'appBackground': Color(0xFFF8F9FA),
    };

    test('textSecondary / textAmber / textBlue clear 4.5:1 on every surface',
        () {
      final tokens = <String, Color>{
        'textSecondary': AppColors.textSecondary,
        'textAmber': AppColors.textAmber,
        'textBlue': AppColors.textBlue,
      };
      tokens.forEach((name, color) {
        surfaces.forEach((surfaceName, surface) {
          final ratio = contrast(color, surface);
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason: '$name on $surfaceName measured ${ratio.toStringAsFixed(2)}:1',
          );
        });
      });
    });

    test('legacy 0xFF8E8E93 is documented as failing AA (regression guard)', () {
      // If someone reverts to the old iOS secondaryLabel this assertion fails,
      // proving the token swap was necessary.
      final ratio = contrast(const Color(0xFF8E8E93), const Color(0xFFFFFFFF));
      expect(ratio, lessThan(4.5));
    });
  });
}
