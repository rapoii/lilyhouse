import 'package:flutter/cupertino.dart';
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
      builder: (context, child) {
        if (isTestMode) return child ?? const SizedBox.shrink();
        return Stack(
          children: [
            if (child != null) child,
            const _CupertinoPickerPrewarmer(),
          ],
        );
      },
      home: MainScaffold(isTestMode: isTestMode),
    );
  }
}

/// Pre-warms Cupertino picker shaders, text layout cache, and localizations
/// at app launch behind the opaque MainScaffold.
/// Automatically unmounts after warm-up completes (1.5 seconds).
class _CupertinoPickerPrewarmer extends StatefulWidget {
  const _CupertinoPickerPrewarmer();

  @override
  State<_CupertinoPickerPrewarmer> createState() =>
      _CupertinoPickerPrewarmerState();
}

class _CupertinoPickerPrewarmerState extends State<_CupertinoPickerPrewarmer> {
  bool _warmed = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() => _warmed = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_warmed) return const SizedBox.shrink();

    return Positioned(
      left: 0,
      bottom: 0,
      child: IgnorePointer(
        ignoring: true,
        child: ExcludeSemantics(
          excluding: true,
          child: Opacity(
            opacity: 0.005,
            child: SizedBox(
              width: 320,
              height: 216,
              child: Stack(
                children: [
                  RepaintBoundary(
                    child: CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.date,
                      initialDateTime: DateTime.now(),
                      onDateTimeChanged: (_) {},
                    ),
                  ),
                  RepaintBoundary(
                    child: CupertinoPicker(
                      itemExtent: 36,
                      scrollController: FixedExtentScrollController(),
                      onSelectedItemChanged: (_) {},
                      children: const [Text('Prewarm')],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
