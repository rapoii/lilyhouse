import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilyhouse/core/theme/app_theme.dart';
import 'package:lilyhouse/features/costumes/domain/accessory.dart';
import 'package:lilyhouse/features/costumes/presentation/widgets/add_accessory_sheet.dart';
import 'package:lilyhouse/features/costumes/presentation/widgets/change_accessory_condition_sheet.dart';

void main() {
  group('AddAccessorySheet UX and validation tests', () {
    testWidgets('Validates empty or whitespace-only name and prevents submit', (tester) async {
      bool saved = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => CupertinoButton(
                child: const Text('Buka'),
                onPressed: () {
                  AddAccessorySheet.show(
                    context: context,
                    costumeId: 'cos-1',
                    onSaveAccessory: (acc) async {
                      saved = true;
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Buka'));
      await tester.pumpAndSettle();

      expect(find.text('Tambah Aksesori'), findsOneWidget);

      // Coba submit saat input kosong
      await tester.tap(find.text('Simpan'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(saved, isFalse);
      expect(find.text('Nama aksesori wajib diisi'), findsOneWidget);

      // Tunggu hingga toast selesai agar tidak ada pending timer
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Masukkan hanya whitespace
      final textField = find.byType(CupertinoTextField);
      await tester.enterText(textField, '   ');
      await tester.tap(find.text('Simpan'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(saved, isFalse);
      expect(find.text('Nama aksesori wajib diisi'), findsOneWidget);

      await tester.pumpAndSettle(const Duration(seconds: 3));
    });

    testWidgets('Prevents duplicate accessory name (case-insensitive & trimmed)', (tester) async {
      bool saved = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => CupertinoButton(
                child: const Text('Buka'),
                onPressed: () {
                  AddAccessorySheet.show(
                    context: context,
                    costumeId: 'cos-1',
                    existingAccessoryNames: ['Wig Silver', 'Sepatu Boot'],
                    onSaveAccessory: (acc) async {
                      saved = true;
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Buka'));
      await tester.pumpAndSettle();

      final textField = find.byType(CupertinoTextField);

      // Coba masukkan duplikat dengan variasi huruf besar/kecil dan whitespace
      await tester.enterText(textField, '  wig silver  ');
      await tester.tap(find.text('Simpan'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(saved, isFalse);
      expect(find.text('Aksesori "wig silver" sudah ada di kostum ini'), findsOneWidget);

      await tester.pumpAndSettle(const Duration(seconds: 3));
    });

    testWidgets('Saves valid trimmed accessory name with condition and min 44pt buttons', (tester) async {
      Accessory? savedAccessory;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => CupertinoButton(
                child: const Text('Buka'),
                onPressed: () {
                  AddAccessorySheet.show(
                    context: context,
                    costumeId: 'cos-10',
                    existingAccessoryNames: ['Wig'],
                    onSaveAccessory: (acc) async {
                      savedAccessory = acc;
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Buka'));
      await tester.pumpAndSettle();

      // Periksa touch target tombol Batal dan Simpan (min 44pt)
      final batalFinder = find.widgetWithText(CupertinoButton, 'Batal');
      final simpanFinder = find.widgetWithText(CupertinoButton, 'Simpan');
      expect(tester.getSize(batalFinder).height, greaterThanOrEqualTo(44.0));
      expect(tester.getSize(batalFinder).width, greaterThanOrEqualTo(44.0));
      expect(tester.getSize(simpanFinder).height, greaterThanOrEqualTo(44.0));
      expect(tester.getSize(simpanFinder).width, greaterThanOrEqualTo(44.0));

      // Pilih kondisi "Rusak Ringan"
      await tester.tap(find.text('Rusak Ringan'));
      await tester.pumpAndSettle();

      // Input nama valid dengan whitespace di awal/akhir
      final textField = find.byType(CupertinoTextField);
      await tester.enterText(textField, '  Tongkat Sihir  ');
      await tester.tap(simpanFinder);
      await tester.pump(const Duration(milliseconds: 100));

      expect(savedAccessory, isNotNull);
      expect(savedAccessory!.name, 'Tongkat Sihir');
      expect(savedAccessory!.conditionStatus, AccessoryCondition.minorDamage);
      expect(savedAccessory!.relatedCostumeId, 'cos-10');
      expect(find.text('Aksesori "Tongkat Sihir" berhasil ditambahkan'), findsOneWidget);

      await tester.pumpAndSettle(const Duration(seconds: 3));
    });
  });

  group('ChangeAccessoryConditionSheet UX tests', () {
    testWidgets('Selects new condition with min 44pt touch target and executes callback', (tester) async {
      AccessoryCondition? selectedCondition;
      const initialAcc = Accessory(
        id: 'acc-1',
        name: 'Sayap Malaikat',
        type: 'Aksesori & Properti',
        conditionStatus: AccessoryCondition.good,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => CupertinoButton(
                child: const Text('Ubah Kondisi'),
                onPressed: () {
                  ChangeAccessoryConditionSheet.show(
                    context: context,
                    accessory: initialAcc,
                    onSelectCondition: (cond) async {
                      selectedCondition = cond;
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Ubah Kondisi'));
      await tester.pumpAndSettle();

      // Verifikasi tombol Tutup min 44pt
      final tutupFinder = find.widgetWithText(CupertinoButton, 'Tutup');
      expect(tester.getSize(tutupFinder).height, greaterThanOrEqualTo(44.0));
      expect(tester.getSize(tutupFinder).width, greaterThanOrEqualTo(44.0));

      // Header and options visible
      expect(find.text('Kondisi Aksesori'), findsOneWidget);
      expect(find.text('Sayap Malaikat'), findsOneWidget);
      expect(find.text('Perlu Servis'), findsOneWidget);

      // Tap 'Perlu Servis'
      await tester.tap(find.text('Perlu Servis'));
      await tester.pumpAndSettle();

      expect(selectedCondition, AccessoryCondition.needsRepair);
    });
  });
}
