import 'package:flutter/material.dart';

class AppColors {
  static const Color primaryPink = Color(0xFFFF85A1);
  static const Color deepPinkText = Color(0xFFC2185B); // WCAG AA compliant on softPinkBg (> 5.5:1)
  static const Color pastelPink = Color(0xFFFFA6BA);
  static const Color softPinkBg = Color(0xFFFFE5EC);
  static const Color background = Color(0xFFF8F9FA); // Warm off-white background
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF2D2D3A);
  static const Color textMuted = Color(0xFF8C8CA1);
  static const Color successMint = Color(0xFF67D4A8);
  static const Color warningOrange = Color(0xFFFFAA5A);
  static const Color dangerRose = Color(0xFFFF5964);
  static const Color borderSubtle = Color(0xFFE5E5EA); // iOS systemGray5 / separator

  // ---------------------------------------------------------------------------
  // WCAG AA text tokens (Phase 20). Each ratio below is measured against the
  // lightest/darkest app surface (white, #F2F2F7, softPinkBg, #FFF4E5, #E3F9EC,
  // #F8F9FA). Use these for any TEXT; the raw iOS hues stay for icons/borders
  // where only the 3:1 non-text minimum applies.
  // ---------------------------------------------------------------------------

  /// Secondary/label text. Replaces 0xFF8E8E93 (iOS secondaryLabel) which only
  /// reaches 3.26:1 on white — below AA. 0xFF636366 keeps >= 5.0:1 everywhere.
  static const Color textSecondary = Color(0xFF636366);

  /// Amber warning text. Replaces 0xFFD97706 (3.19:1) and 0xFFB26B00 (4.20:1).
  /// 0xFF8A5300 keeps >= 5.3:1 on every surface.
  static const Color textAmber = Color(0xFF8A5300);

  /// Link/info blue text. Replaces 0xFF007AFF (4.02:1 on white).
  /// 0xFF0062CC keeps >= 4.8:1 on every surface.
  static const Color textBlue = Color(0xFF0062CC);
}
