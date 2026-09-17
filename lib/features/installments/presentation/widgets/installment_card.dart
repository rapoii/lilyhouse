import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/pressable_card.dart';
import '../../domain/installment.dart';

class InstallmentCard extends StatelessWidget {
  final Installment installment;
  final VoidCallback? onTap;

  const InstallmentCard({
    super.key,
    required this.installment,
    this.onTap,
  });

  String _formatCurrency(double amount) {
    final parts = amount.toInt().toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
    return 'Rp $parts';
  }

  @override
  Widget build(BuildContext context) {
    final isDone = installment.isPaidOff;
    final isOverdue = installment.isOverdue;
    final isDueSoon = installment.isDueSoon;
    final showDueBadge = !isDone && (isOverdue || isDueSoon);

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
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Title & Status Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    installment.itemName.replaceAll('_', ' '),
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDone ? const Color(0xFFE3F9EC) : AppColors.softPinkBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDone ? AppColors.successMint : AppColors.pastelPink,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    isDone ? 'Lunas' : 'Cicilan',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDone ? const Color(0xFF1E824C) : AppColors.deepPinkText,
                    ),
                  ),
                ),
              ],
            ),
            if (showDueBadge) ...[
              const SizedBox(height: 10),
              Container(
                key: const Key('installment_due_soon_badge'),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isOverdue
                      ? const Color(0xFFFFEFEF)
                      : const Color(0xFFFFF4E0),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isOverdue
                        ? const Color(0xFFFF3B30)
                        : const Color(0xFFFFAA5A),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isOverdue ? CupertinoIcons.exclamationmark_triangle_fill : CupertinoIcons.clock_fill,
                      size: 13,
                      color: isOverdue ? const Color(0xFFFF3B30) : const Color(0xFFFF9500),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        installment.dueLabel(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isOverdue ? const Color(0xFFC62828) : AppColors.textAmber,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),

            // Key Number: Remaining Balance or Fully Paid with Total Context
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isDone ? 'Lunas Sepenuhnya' : 'Sisa ${_formatCurrency(installment.remainingBalance)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDone ? const Color(0xFF1E824C) : AppColors.deepPinkText,
                  ),
                ),
                Text(
                  'Total ${_formatCurrency(installment.totalCost)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Sleek Progress Bar (6pt)
            Container(
              key: const Key('installment_progress_bar'),
              height: 6,
              decoration: BoxDecoration(
                color: AppColors.softPinkBg,
                borderRadius: BorderRadius.circular(3),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        width: constraints.maxWidth *
                            (installment.progress).clamp(0.0, 1.0),
                        decoration: BoxDecoration(
                          color: isDone
                              ? AppColors.successMint
                              : AppColors.primaryPink,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
