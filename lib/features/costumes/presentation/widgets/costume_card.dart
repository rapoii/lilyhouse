import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
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

  (Color bg, Color text, String label) _getStatusBadgeData(CostumeStatus status) {
    switch (status) {
      case CostumeStatus.available:
        return (const Color(0xFFE3F9EC), const Color(0xFF1E824C), 'Tersedia');
      case CostumeStatus.booked:
        return (const Color(0xFFFFF4E5), const Color(0xFFD97706), 'Dibooking');
      case CostumeStatus.rented:
        return (const Color(0xFFFFEBF0), AppColors.primaryPink, 'Disewa');
      case CostumeStatus.laundry:
        return (const Color(0xFFE8F1FF), const Color(0xFF2563EB), 'Dicuci');
      case CostumeStatus.maintenance:
        return (const Color(0xFFFDE8E8), AppColors.dangerRose, 'Perawatan');
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusData = _getStatusBadgeData(costume.status);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
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
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F2F7),
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: Center(
                    child: costume.coverPhoto != null && costume.coverPhoto!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12.0),
                            child: Image.asset(
                              costume.coverPhoto!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => const Icon(
                                CupertinoIcons.sparkles,
                                color: AppColors.primaryPink,
                                size: 32,
                              ),
                            ),
                          )
                        : const Icon(
                            CupertinoIcons.sparkles,
                            color: AppColors.primaryPink,
                            size: 32,
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              costume.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Status Pill Badge
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
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: statusData.$2,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        costume.animeSeries,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          // Size pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.borderSubtle,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              'Size ${costume.size}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark,
                              ),
                            ),
                          ),
                          const Spacer(),
                          // 3-day Price
                          Text(
                            '${_formatCurrency(costume.rentPrice3Days)} / 3d',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryPink,
                            ),
                          ),
                        ],
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
