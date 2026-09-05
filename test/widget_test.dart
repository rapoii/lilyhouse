import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilyhouse/core/database/db_helper.dart';
import 'package:lilyhouse/core/database/tables.dart';
import 'package:lilyhouse/core/presentation/main_scaffold.dart';
import 'package:lilyhouse/main.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    final testDb = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute(AppTables.createCostumes);
          await db.execute(AppTables.createAccessories);
          await db.execute(AppTables.createCustomers);
          await db.execute(AppTables.createRentals);
          await db.execute(AppTables.createInstallments);
          await db.execute(AppTables.createInstallmentLogs);
          await db.execute(AppTables.createSyncQueue);
        },
      ),
    );
    DatabaseHelper.instance.setDatabaseForTesting(testDb);
  });

  testWidgets('LilyHouseApp smoke test builds MaterialApp with MainScaffold', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: LilyHouseApp(isTestMode: true),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify MainScaffold is rendered
    expect(find.byType(MainScaffold), findsOneWidget);
    expect(find.text('Katalog'), findsOneWidget);
    expect(find.text('Kalender'), findsOneWidget);
    expect(find.text('Cicilan'), findsOneWidget);
    expect(find.text('Pengaturan'), findsOneWidget);
  });
}
