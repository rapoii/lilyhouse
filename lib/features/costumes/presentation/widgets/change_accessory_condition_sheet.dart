import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/draggable_sheet_container.dart';
import '../../../../core/widgets/squircle_icon.dart';
import '../../domain/accessory.dart';

class ChangeAccessoryConditionSheet extends StatelessWidget {
  final Accessory accessory;
  final Future<void> Function(AccessoryCondition newCondition) onSelectCondition;

  const ChangeAccessoryConditionSheet({
    super.key,
    required this.accessory,
    required this.onSelectCondition,
  });

  static Future<void> show({
    required BuildContext context,
    required Accessory accessory,
    required Future<void> Function(AccessoryCondition newCondition) onSelectCondition,
  }) {
    return showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => ChangeAccessoryConditionSheet(
        accessory: accessory,
        onSelectCondition: onSelectCondition,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableSheetContainer(
      initialHeightFraction: 0.58,
      maxHeightFraction: 0.68,
      backgroundColor: AppColors.background,
      onDismissed: () => Navigator.of(context).pop(),
      builder: (ctx) => DefaultTextStyle(
        style: const TextStyle(
          decoration: TextDecoration.none,
          fontFamily: '.SF Pro Text',
          color: AppColors.textDark,
        ),
        child: CupertinoPageScaffold(
          backgroundColor: AppColors.background,
          navigationBar: CupertinoNavigationBar(
            automaticallyImplyLeading: false,
            backgroundColor: AppColors.background,
            border: const Border(bottom: BorderSide(color: Color(0xFFE5E5EA), width: 0.5)),
            middle: const Text('Kondisi Aksesori', style: AppTypography.navTitle),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(44, 44),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Tutup', style: TextStyle(color: AppColors.deepPinkText, fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
          child: SafeArea(
            top: false,
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(0, 16, 0, 180),
              children: [
                // Hero card for accessory
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderSubtle, width: 0.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.softPinkBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Icon(CupertinoIcons.sparkles, color: AppColors.primaryPink, size: 24),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                accessory.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textDark,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                accessory.type,
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        _buildStatusPill(accessory.conditionStatus),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                CupertinoListSection.insetGrouped(
                  header: const Text(
                    'PILIH STATUS KONDISI SAAT INI',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  backgroundColor: Colors.transparent,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _buildOption(
                      context: context,
                      condition: AccessoryCondition.good,
                      title: 'Baik',
                      subtitle: 'Kondisi utuh & layak sewa tanpa kerusakan',
                      icon: CupertinoIcons.checkmark_seal_fill,
                      color: const Color(0xFF34C759),
                    ),
                    _buildOption(
                      context: context,
                      condition: AccessoryCondition.minorDamage,
                      title: 'Rusak Ringan',
                      subtitle: 'Kusut, noda ringan, atau jahitan minor terlepas',
                      icon: CupertinoIcons.exclamationmark_triangle_fill,
                      color: const Color(0xFFFF9500),
                    ),
                    _buildOption(
                      context: context,
                      condition: AccessoryCondition.needsRepair,
                      title: 'Perlu Servis',
                      subtitle: 'Butuh reparasi prop, re-styling wig, atau jahit',
                      icon: CupertinoIcons.wrench_fill,
                      color: AppColors.dangerRose,
                    ),
                    _buildOption(
                      context: context,
                      condition: AccessoryCondition.lost,
                      title: 'Hilang',
                      subtitle: 'Aksesori hilang atau tidak dikembalikan penyewa',
                      icon: CupertinoIcons.xmark_circle_fill,
                      color: const Color(0xFF8E8E93),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusPill(AccessoryCondition condition) {
    Color bg;
    Color fg;

    switch (condition) {
      case AccessoryCondition.good:
        bg = const Color(0xFFE3F9EC);
        fg = const Color(0xFF1E824C);
        break;
      case AccessoryCondition.minorDamage:
        bg = const Color(0xFFFFF4E5);
        fg = AppColors.textAmber;
        break;
      case AccessoryCondition.needsRepair:
        bg = const Color(0xFFFFEBF0);
        fg = AppColors.dangerRose;
        break;
      case AccessoryCondition.lost:
        bg = const Color(0xFFF3F4F6);
        fg = const Color(0xFF6B7280);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(
        condition.displayName,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildOption({
    required BuildContext context,
    required AccessoryCondition condition,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = accessory.conditionStatus == condition;

    return CupertinoListTile(
      leading: SquircleIcon(icon: icon, color: color),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: isSelected ? color : AppColors.textDark,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
      trailing: isSelected
          ? Icon(CupertinoIcons.checkmark_alt, size: 20, color: color)
          : null,
      onTap: () async {
        HapticFeedback.selectionClick();
        Navigator.of(context).pop();
        try {
          await onSelectCondition(condition);
        } catch (_) {}
      },
    );
  }
}
