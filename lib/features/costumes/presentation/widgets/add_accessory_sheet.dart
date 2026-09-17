import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/draggable_sheet_container.dart';
import '../../../../core/widgets/ios_toast.dart';
import '../../../../core/widgets/squircle_icon.dart';
import '../../../../core/widgets/unsaved_changes_guard.dart';
import '../../domain/accessory.dart';

class AddAccessorySheet extends StatefulWidget {
  final String? costumeId;
  final List<String> existingAccessoryNames;
  final Future<void> Function(Accessory accessory)? onSaveAccessory;
  final void Function(String name)? onAddNameOnly;

  const AddAccessorySheet({
    super.key,
    this.costumeId,
    this.existingAccessoryNames = const [],
    this.onSaveAccessory,
    this.onAddNameOnly,
  });

  static Future<void> show({
    required BuildContext context,
    String? costumeId,
    List<String> existingAccessoryNames = const [],
    Future<void> Function(Accessory accessory)? onSaveAccessory,
    void Function(String name)? onAddNameOnly,
  }) {
    return showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => AddAccessorySheet(
        costumeId: costumeId,
        existingAccessoryNames: existingAccessoryNames,
        onSaveAccessory: onSaveAccessory,
        onAddNameOnly: onAddNameOnly,
      ),
    );
  }

  @override
  State<AddAccessorySheet> createState() => _AddAccessorySheetState();
}

class _AddAccessorySheetState extends State<AddAccessorySheet> {
  final _nameController = TextEditingController();
  AccessoryCondition _selectedCondition = AccessoryCondition.good;
  bool _isSubmitting = false;

  bool get _hasUnsavedChanges =>
      _nameController.text.trim().isNotEmpty && !_isSubmitting;

  Future<bool> _confirmClose() async {
    if (!_hasUnsavedChanges) return true;
    return confirmDiscardChanges(context);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      HapticFeedback.lightImpact();
      IosToast.show(
        context,
        'Nama aksesori wajib diisi',
        icon: CupertinoIcons.exclamationmark_circle_fill,
        iconColor: AppColors.warningOrange,
      );
      return;
    }

    final isDuplicate = widget.existingAccessoryNames.any(
      (existing) => existing.trim().toLowerCase() == name.toLowerCase(),
    );
    if (isDuplicate) {
      HapticFeedback.lightImpact();
      IosToast.show(
        context,
        'Aksesori "$name" sudah ada di kostum ini',
        icon: CupertinoIcons.exclamationmark_circle_fill,
        iconColor: AppColors.warningOrange,
      );
      return;
    }

    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      if (widget.onSaveAccessory != null) {
        final acc = Accessory(
          id: 'acc_${DateTime.now().millisecondsSinceEpoch}',
          name: name,
          type: 'Aksesori & Properti',
          conditionStatus: _selectedCondition,
          relatedCostumeId: widget.costumeId,
        );
        await widget.onSaveAccessory!(acc);
      } else if (widget.onAddNameOnly != null) {
        widget.onAddNameOnly!(name);
      }

      if (mounted) {
        HapticFeedback.mediumImpact();
        Navigator.of(context).pop();
        IosToast.show(
          context,
          'Aksesori "$name" berhasil ditambahkan',
          icon: CupertinoIcons.checkmark_circle_fill,
          iconColor: const Color(0xFF34C759),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        IosToast.show(
          context,
          'Gagal menyimpan aksesori',
          icon: CupertinoIcons.exclamationmark_circle_fill,
          iconColor: AppColors.dangerRose,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final showCondition = widget.onSaveAccessory != null;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmClose()) {
          if (mounted) navigator.pop();
        }
      },
      child: DraggableSheetContainer(
        initialHeightFraction: 0.60,
        maxHeightFraction: 0.75,
        backgroundColor: AppColors.background,
        onDismissed: () => Navigator.of(context).pop(),
        confirmDismiss: _confirmClose,
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
              leading: CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(44, 44),
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  if (await _confirmClose()) {
                    if (mounted) navigator.pop();
                  }
                },
                child: const Text('Batal', style: TextStyle(fontSize: 15, color: AppColors.deepPinkText)),
              ),
              middle: const Text('Tambah Aksesori', style: AppTypography.navTitle),
              trailing: CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(44, 44),
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const CupertinoActivityIndicator(radius: 10)
                    : const Text('Simpan', style: AppTypography.actionButton),
              ),
            ),
          child: SafeArea(
            top: false,
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(0, 16, 0, bottomInset + 180),
              children: [
                CupertinoListSection.insetGrouped(
                  header: const Text(
                    'NAMA AKSESORI',
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
                    CupertinoListTile(
                      leading: const SquircleIcon(
                        icon: CupertinoIcons.sparkles,
                        color: AppColors.primaryPink,
                      ),
                      title: CupertinoTextField(
                        controller: _nameController,
                        placeholder: 'Contoh: Wig Stylist, Prop Senjata, Tiara',
                        autofocus: true,
                        decoration: null,
                        style: const TextStyle(fontSize: 15, color: AppColors.textDark),
                        placeholderStyle: const TextStyle(fontSize: 15, color: AppColors.placeholderText),
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                      ),
                      subtitle: const Text(
                        'Nama item atau perlengkapan kostum',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
                if (showCondition) ...[
                  const SizedBox(height: 12),
                  CupertinoListSection.insetGrouped(
                    header: const Text(
                      'KONDISI AWAL',
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
                      _buildConditionTile(
                        condition: AccessoryCondition.good,
                        title: 'Baik',
                        subtitle: 'Kondisi sempurna tanpa cacat atau noda',
                        icon: CupertinoIcons.checkmark_seal_fill,
                        color: const Color(0xFF34C759),
                      ),
                      _buildConditionTile(
                        condition: AccessoryCondition.minorDamage,
                        title: 'Rusak Ringan',
                        subtitle: 'Kusut, noda ringan, atau jahitan minor lepas',
                        icon: CupertinoIcons.exclamationmark_triangle_fill,
                        color: const Color(0xFFFF9500),
                      ),
                      _buildConditionTile(
                        condition: AccessoryCondition.needsRepair,
                        title: 'Perlu Servis',
                        subtitle: 'Perlu styling ulang, reparasi prop, atau jahit',
                        icon: CupertinoIcons.wrench_fill,
                        color: AppColors.dangerRose,
                      ),
                      _buildConditionTile(
                        condition: AccessoryCondition.lost,
                        title: 'Hilang',
                        subtitle: 'Item belum lengkap atau tidak ada di set',
                        icon: CupertinoIcons.xmark_circle_fill,
                        color: const Color(0xFF8E8E93),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildConditionTile({
    required AccessoryCondition condition,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _selectedCondition == condition;

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
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedCondition = condition);
      },
    );
  }
}
