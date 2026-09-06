import 'package:flutter/cupertino.dart';
import '../../../core/theme/app_colors.dart';

/// Card-style entry point for picking how to add a new booking.
/// Mirrors the visual language used by modal Tambah Katalog & modal Cicilan
/// (white card, 16 radius, 0.5px border, subtle shadow, chevron trailing).
class EntryMethodCard extends StatelessWidget {
  final IconData leadingIcon;
  final Color leadingBg;
  final Color leadingFg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const EntryMethodCard({
    super.key,
    required this.leadingIcon,
    required this.leadingBg,
    required this.leadingFg,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 14, 16),
        decoration: BoxDecoration(
          color: CupertinoColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E5EA), width: 0.5),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            // Squircle leading icon
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: leadingBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(leadingIcon, size: 20, color: leadingFg),
            ),
            const SizedBox(width: 14),
            // Title + subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              CupertinoIcons.chevron_right,
              size: 16,
              color: Color(0xFFC7C7CC),
            ),
          ],
        ),
      ),
    );
  }
}
