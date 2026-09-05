import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTypography {
  // Apple HIG Typography Hierarchy (SF Pro System Standards)

  /// iOS Large Title / Mac Window Header (Tab Utama: Katalog, Kalender, Buku Cicilan, Pengaturan)
  static const TextStyle largeTitle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    color: AppColors.textDark,
  );

  /// Navigation Bar Title (Detail Views)
  static const TextStyle navTitle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    color: AppColors.textDark,
  );

  /// Section Header (CupertinoListSection / Inset Grouped)
  static const TextStyle sectionHeader = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.1,
    color: Color(0xFF6C6C70), // iOS secondaryLabel
  );

  /// Section Footer
  static const TextStyle sectionFooter = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.1,
    color: Color(0xFF8E8E93), // iOS tertiaryLabel
  );

  /// Headline / Card Title
  static const TextStyle headline = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    color: AppColors.textDark,
  );

  /// Body regular
  static const TextStyle body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.2,
    color: AppColors.textDark,
  );

  /// Subhead / Secondary body
  static const TextStyle subhead = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.1,
    color: Color(0xFF8E8E93),
  );

  /// Caption / Metadata
  static const TextStyle caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.0,
    color: Color(0xFF8E8E93),
  );

  /// Action Button Text (Header bar buttons: Smart Paste, Tambah, Ukuran)
  static const TextStyle actionButton = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    color: AppColors.primaryPink,
  );
}
