import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/database/db_helper.dart';
import 'core/presentation/main_scaffold.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SQLite database instance
  await DatabaseHelper.instance.database;

  runApp(
    const ProviderScope(
      child: LilyHouseApp(),
    ),
  );
}

class LilyHouseApp extends StatelessWidget {
  final bool isTestMode;

  const LilyHouseApp({super.key, this.isTestMode = false});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LilyHouse Rent',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: MainScaffold(isTestMode: isTestMode),
    );
  }
}
