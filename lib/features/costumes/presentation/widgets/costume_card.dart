import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/pressable_card.dart';
import '../../domain/costume.dart';

class CostumeCard extends StatelessWidget {
  final Costume costume;
  final VoidCallback? onTap;

  const CostumeCard({
    super.key,
    required this.costume,
    this.onTap,
  });

  String _formatCurrency(double amount) {
    // Format 150000 -> Rp 150.000
    final parts = amount.toInt().toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
    return 'Rp $parts';
  }

  Widget _buildCoverPhoto(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        width: 56,
        height: 56,
        cacheWidth: 400,
        cacheHeight: 400,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const Icon(
          CupertinoIcons.sparkles,
          color: AppColors.primaryPink,
          size: 28,
        ),
      );
    }
    // Check if path looks like a local filesystem path (POSIX, Windows drive letter, or file:// URI)
    final isLocalFile = path.startsWith('/') ||
        path.startsWith('file:') ||
        (path.length >= 2 && path[1] == ':');
    if (isLocalFile) {
      final cleanPath = path.startsWith('file://') ? path.replaceFirst('file://', '') : path;
      return Image.file(
        File(cleanPath),
        width: 56,
        height: 56,
        cacheWidth: 400,
        cacheHeight: 400,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const Icon(
          CupertinoIcons.sparkles,
          color: AppColors.primaryPink,
          size: 28,
        ),
      );
    }
    return Image.asset(
      path,
      width: 56,
      height: 56,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => const Icon(
        CupertinoIcons.sparkles,
        color: AppColors.primaryPink,
        size: 28,
      ),
    );
  }

  (Color bg, Color text, String label) _getStatusBadgeData(CostumeStatus status) {
    switch (status) {
      case CostumeStatus.available:
        return (const Color(0xFFE3F9EC), AppColors.badgeSuccessText, 'Tersedia');
      case CostumeStatus.booked:
        return (const Color(0xFFFFF4E5), AppColors.textAmber, 'Dibooking');
      case CostumeStatus.rented:
        return (const Color(0xFFFFEBF0), AppColors.deepPinkText, 'Disewa');
      case CostumeStatus.laundry:
        return (const Color(0xFFE8F1FF), const Color(0xFF2563EB), 'Dicuci');
      case CostumeStatus.maintenance:
        return (const Color(0xFFFDE8E8), AppColors.dangerRose, 'Perawatan');
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusData = _getStatusBadgeData(costume.status);

    return PressableCard(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(
            color: const Color(0xFFE5E5EA),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8.0,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Costume Thumbnail or Placeholder Avatar
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: Center(
                  child: costume.coverPhoto != null && costume.coverPhoto!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10.0),
                          child: _buildCoverPhoto(costume.coverPhoto!),
                        )
                      : const Icon(
                          CupertinoIcons.sparkles,
                          color: AppColors.primaryPink,
                          size: 28,
                        ),
                ),
              ),
              const SizedBox(width: 14),
              // Details: 3 Essential Elements
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        // Element 1: Judul
                        Expanded(
                          child: Text(
                            costume.name.replaceAll('_', ' '),
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1C1C1E),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Element 2: Status Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusData.$1,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            statusData.$3,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: statusData.$2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Element 3: Angka Kunci (Harga sewa per 3 hari)
                    Text(
                      '${_formatCurrency(costume.rentPrice3Days)} / 3d',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.deepPinkText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
