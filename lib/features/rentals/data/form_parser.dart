import '../domain/parsed_rental_data.dart';

/// Parser that extracts customer and rental information from raw Indonesian rent forms.
class SmartFormParser {
  static const Map<String, int> _monthMap = {
    'jan': 1, 'januari': 1, 'january': 1,
    'feb': 2, 'februari': 2, 'february': 2,
    'mar': 3, 'maret': 3, 'march': 3,
    'apr': 4, 'april': 4,
    'mei': 5, 'may': 5,
    'jun': 6, 'juni': 6, 'june': 6,
    'jul': 7, 'juli': 7, 'july': 7,
    'agu': 8, 'agus': 8, 'agustus': 8, 'aug': 8, 'august': 8,
    'sep': 9, 'sept': 9, 'september': 9,
    'okt': 10, 'oktober': 10, 'oct': 10, 'october': 10,
    'nov': 11, 'november': 11,
    'des': 12, 'desember': 12, 'dec': 12, 'december': 12,
  };

  /// Parses raw Indonesian WhatsApp rental form into [ParsedRentalData].
  static ParsedRentalData parse(String rawText) {
    if (rawText.trim().isEmpty) {
      return const ParsedRentalData();
    }

    final fullName = _extractField(
      rawText,
      patterns: [
        RegExp(r'(?:1\.\s*)?Nama\s*(?:asli|lengkap)?(?:\s*/\s*nama\s*di\s*paket)?\s*:\s*([^\n\r]+)', caseSensitive: false),
        RegExp(r'Nama\s*:\s*([^\n\r]+)', caseSensitive: false),
      ],
    );

    final phone = _extractField(
      rawText,
      patterns: [
        RegExp(r'(?:2\.\s*)?No\s*(?:HP|WA|WhatsApp|Telepon)\s*:\s*([^\n\r]+)', caseSensitive: false),
        RegExp(r'HP\s*:\s*([^\n\r]+)', caseSensitive: false),
      ],
    );

    final address = _extractMultilineField(
      rawText,
      startPattern: RegExp(r'(?:3\.\s*)?Alamat(?:\s*lengkap)?\s*:\s*', caseSensitive: false),
      nextPattern: RegExp(r'(?:\n\r?|\r\n?)(?:(?:4\.\s*)?No\s*hp\s*ortu|4\.)', caseSensitive: false),
    );

    final parentPhone = _extractField(
      rawText,
      patterns: [
        RegExp(r'(?:4\.\s*)?No\s*hp\s*ortu(?:/org\s*terdekat\s*yg\s*bisa\s*dihubungi|/orang\s*terdekat)?\s*:\s*([^\n\r]+)', caseSensitive: false),
        RegExp(r'No\s*hp\s*ortu[^\n\r:]*:\s*([^\n\r]+)', caseSensitive: false),
      ],
    );

    final socialMedia = _extractField(
      rawText,
      patterns: [
        RegExp(r'(?:5\.\s*)?Akun\s*sosmed(?:\s*\([^)]*\))?\s*:\s*([^\n\r]+)', caseSensitive: false),
        RegExp(r'Sosmed\s*:\s*([^\n\r]+)', caseSensitive: false),
      ],
    );

    final costumeName = _extractField(
      rawText,
      patterns: [
        RegExp(r'(?:6\.\s*)?Kostum\s*(?:yg|yang)?\s*di\s*rental\s*:\s*([^\n\r]+)', caseSensitive: false),
        RegExp(r'Kostum\s*:\s*([^\n\r]+)', caseSensitive: false),
      ],
    );

    final datesRaw = _extractField(
      rawText,
      patterns: [
        RegExp(r'(?:7\.\s*)?Tanggal\s*(?:di\s*pakai|dipakai)(?:\s*\([^)]*\))?\s*:\s*([^\n\r]+)', caseSensitive: false),
        RegExp(r'Tanggal(?:\s*sewa|\s*rental)?\s*:\s*([^\n\r]+)', caseSensitive: false),
      ],
    );

    final purpose = _extractField(
      rawText,
      patterns: [
        RegExp(r'(?:8\.\s*)?Untuk\s*keperluan(?:\s*\([^)]*\))?\s*:\s*([^\n\r]+)', caseSensitive: false),
        RegExp(r'Keperluan\s*:\s*([^\n\r]+)', caseSensitive: false),
      ],
    );

    DateTime? startDate;
    DateTime? endDate;
    int? rentalDurationDays;

    if (datesRaw != null) {
      final dateResult = _parseDates(datesRaw);
      startDate = dateResult.startDate;
      endDate = dateResult.endDate;
      rentalDurationDays = dateResult.durationDays;
    }

    return ParsedRentalData(
      fullName: fullName?.trim(),
      phone: phone?.trim(),
      address: address?.trim(),
      parentPhone: parentPhone?.trim(),
      socialMedia: socialMedia?.trim(),
      costumeName: costumeName?.trim(),
      datesRaw: datesRaw?.trim(),
      purpose: purpose?.trim(),
      startDate: startDate,
      endDate: endDate,
      rentalDurationDays: rentalDurationDays,
      rawText: rawText,
    );
  }

  static String? _extractField(String text, {required List<RegExp> patterns}) {
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null && match.groupCount >= 1) {
        final val = match.group(1)?.trim();
        if (val != null && val.isNotEmpty) {
          return val;
        }
      }
    }
    return null;
  }

  static String? _extractMultilineField(
    String text, {
    required RegExp startPattern,
    required RegExp nextPattern,
  }) {
    final startMatch = startPattern.firstMatch(text);
    if (startMatch == null) return null;

    final startIndex = startMatch.end;
    final remainingText = text.substring(startIndex);
    final nextMatch = nextPattern.firstMatch(remainingText);

    final rawVal = nextMatch != null
        ? remainingText.substring(0, nextMatch.start)
        : remainingText.split(RegExp(r'\n\r?|\r\n?')).first;

    final cleaned = rawVal.replaceAll(RegExp(r'[\r\n]+'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleaned.isNotEmpty ? cleaned : null;
  }

  static ({DateTime? startDate, DateTime? endDate, int? durationDays}) _parseDates(String text) {
    final clean = text.trim();

    // Pattern 1: DD/MM/YYYY - DD/MM/YYYY or DD-MM-YYYY to DD-MM-YYYY
    final slashRange = RegExp(r'(\d{1,2})[/-](\d{1,2})[/-](\d{4})\s*(?:-|sd|s/d|sampai|to)\s*(\d{1,2})[/-](\d{1,2})[/-](\d{4})', caseSensitive: false);
    final slashMatch = slashRange.firstMatch(clean);
    if (slashMatch != null) {
      final startDay = int.parse(slashMatch.group(1)!);
      final startMonth = int.parse(slashMatch.group(2)!);
      final startYear = int.parse(slashMatch.group(3)!);

      final endDay = int.parse(slashMatch.group(4)!);
      final endMonth = int.parse(slashMatch.group(5)!);
      final endYear = int.parse(slashMatch.group(6)!);

      final start = DateTime(startYear, startMonth, startDay);
      final end = DateTime(endYear, endMonth, endDay);
      final days = end.difference(start).inDays + 1;
      return (startDate: start, endDate: end, durationDays: days);
    }

    // Pattern 2: D1 - D2 Month YYYY (e.g., 5-6 sept 2026, 10 - 12 Oktober 2026)
    final dayRangeMonthYear = RegExp(r'(\d{1,2})\s*(?:-|sd|s/d|sampai|to)\s*(\d{1,2})\s+([a-zA-Z]+)\s+(\d{4})', caseSensitive: false);
    final dayRangeMatch = dayRangeMonthYear.firstMatch(clean);
    if (dayRangeMatch != null) {
      final startDay = int.parse(dayRangeMatch.group(1)!);
      final endDay = int.parse(dayRangeMatch.group(2)!);
      final monthStr = dayRangeMatch.group(3)!.toLowerCase();
      final year = int.parse(dayRangeMatch.group(4)!);
      final month = _monthMap[monthStr];

      if (month != null) {
        final start = DateTime(year, month, startDay);
        final end = DateTime(year, month, endDay);
        final days = end.difference(start).inDays + 1;
        return (startDate: start, endDate: end, durationDays: days);
      }
    }

    // Pattern 3: Single date D Month YYYY (e.g., 15 September 2026)
    final singleDateMonthYear = RegExp(r'(\d{1,2})\s+([a-zA-Z]+)\s+(\d{4})', caseSensitive: false);
    final singleMatch = singleDateMonthYear.firstMatch(clean);
    if (singleMatch != null) {
      final day = int.parse(singleMatch.group(1)!);
      final monthStr = singleMatch.group(2)!.toLowerCase();
      final year = int.parse(singleMatch.group(3)!);
      final month = _monthMap[monthStr];

      if (month != null) {
        final date = DateTime(year, month, day);
        return (startDate: date, endDate: date, durationDays: 1);
      }
    }

    // Pattern 4: Single date DD/MM/YYYY
    final singleSlash = RegExp(r'(\d{1,2})[/-](\d{1,2})[/-](\d{4})');
    final singleSlashMatch = singleSlash.firstMatch(clean);
    if (singleSlashMatch != null) {
      final day = int.parse(singleSlashMatch.group(1)!);
      final month = int.parse(singleSlashMatch.group(2)!);
      final year = int.parse(singleSlashMatch.group(3)!);
      final date = DateTime(year, month, day);
      return (startDate: date, endDate: date, durationDays: 1);
    }

    return (startDate: null, endDate: null, durationDays: null);
  }
}

/// Alias for task brief compatibility
typedef RentFormParser = SmartFormParser;
