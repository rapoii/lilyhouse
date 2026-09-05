import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
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

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final percent = (installment.progress * 100).toInt();
    final isDone = installment.isPaidOff;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.0),
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
              // Header Row: Item Name, Store, and Status Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          installment.itemName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (installment.storeName != null && installment.storeName!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.storefront_rounded,
                                size: 14,
                                color: AppColors.textMuted,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  installment.storeName!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textMuted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                        fontWeight: FontWeight.w700,
                        color: isDone ? const Color(0xFF1E824C) : AppColors.primaryPink,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Cute Rounded Pill Progress Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Progress Pembayaran',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted.withValues(alpha: 0.9),
                    ),
                  ),
                  Text(
                    '$percent%',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isDone ? AppColors.successMint : AppColors.primaryPink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                key: const Key('installment_progress_bar'),
                height: 12,
                decoration: BoxDecoration(
                  color: AppColors.softPinkBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: installment.progress,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isDone ? AppColors.successMint : AppColors.primaryPink,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Financial Breakdown: Terbayar vs Total
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Terbayar',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatCurrency(installment.totalPaid),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Total Harga',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatCurrency(installment.totalCost),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(color: AppColors.softPinkBg, height: 1),
              const SizedBox(height: 10),

              // Footer: Sisa & Due Date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Sisa: ${_formatCurrency(installment.remainingBalance)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDone ? AppColors.successMint : AppColors.dangerRose,
                    ),
                  ),
                  if (installment.dueDate != null)
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 13,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Jatuh tempo: ${_formatDate(installment.dueDate!)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
