import 'package:intl/intl.dart';

/// Utilities for human-readable contextual date & time formatting in Indonesian
class DateTimeUtils {
  DateTimeUtils._();

  /// Format human-readable relative/contextual sync time in Indonesian
  /// Examples:
  /// - null -> 'Belum pernah'
  /// - < 45 seconds -> 'Baru saja'
  /// - < 60 minutes -> '5 menit lalu'
  /// - Today -> 'Hari ini pukul 14:30'
  /// - Yesterday -> 'Kemarin pukul 09:15'
  /// - < 7 days -> 'Senin pukul 10:00'
  /// - Same year -> '12 Sep, 15:45'
  /// - Different year -> '12 Sep 2025, 15:45'
  static String formatSyncRelative(DateTime? timestamp, {DateTime? now}) {
    if (timestamp == null) return 'Belum pernah';
    final currentTime = now ?? DateTime.now();
    final difference = currentTime.difference(timestamp);

    // Negative or virtually same moment (< 45 seconds)
    if (difference.isNegative || difference.inSeconds < 45) {
      return 'Baru saja';
    }

    final minutes = difference.inMinutes;
    if (minutes < 60) {
      return '$minutes menit lalu';
    }

    final timeStr = DateFormat('HH:mm').format(timestamp);

    // Check if same calendar day
    final isSameDay = timestamp.year == currentTime.year &&
        timestamp.month == currentTime.month &&
        timestamp.day == currentTime.day;

    if (isSameDay) {
      return 'Hari ini pukul $timeStr';
    }

    final yesterday = currentTime.subtract(const Duration(days: 1));
    final isYesterday = timestamp.year == yesterday.year &&
        timestamp.month == yesterday.month &&
        timestamp.day == yesterday.day;

    if (isYesterday) {
      return 'Kemarin pukul $timeStr';
    }

    if (difference.inDays < 7) {
      final dayName = DateFormat('EEEE', 'id_ID').format(timestamp);
      return '$dayName pukul $timeStr';
    }

    if (timestamp.year == currentTime.year) {
      return DateFormat('d MMM, HH:mm', 'id_ID').format(timestamp);
    }

    return DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(timestamp);
  }
}
