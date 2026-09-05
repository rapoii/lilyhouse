import 'package:flutter_test/flutter_test.dart';
import 'package:lilyhouse/core/theme/app_colors.dart';
import 'package:lilyhouse/core/theme/app_theme.dart';

void main() {
  test('AppTheme light theme defines signature soft pink pill colors', () {
    final theme = AppTheme.lightTheme;
    expect(theme.scaffoldBackgroundColor, equals(AppColors.background));
    expect(theme.primaryColor, equals(AppColors.primaryPink));
  });
}
