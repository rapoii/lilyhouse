import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../data/costume_repository.dart';
import '../domain/costume.dart';
import '../domain/accessory.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/draggable_sheet_container.dart';
import '../../../core/widgets/ios_toast.dart';
import '../../../core/widgets/squircle_icon.dart';
import 'add_costume_sheet.dart';
import 'widgets/add_accessory_sheet.dart';
import 'widgets/change_accessory_condition_sheet.dart';

class CostumeDetailScreen extends StatefulWidget {
  final Costume costume;
  final ICostumeRepository? repository;

  const CostumeDetailScreen({
    super.key,
    required this.costume,
    this.repository,
  });

  @override
  State<CostumeDetailScreen> createState() => _CostumeDetailScreenState();
}

class _CostumeDetailScreenState extends State<CostumeDetailScreen> {
  late ICostumeRepository _repository;
  late Costume _costume;
  List<Accessory> _accessories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _costume = widget.costume;
    _repository = widget.repository ?? CostumeRepository();
    _loadAccessories();
  }

  Future<void> _loadAccessories() async {
    final list = await _repository.getAccessoriesByCostumeId(_costume.id);
    if (mounted) {
      setState(() {
        _accessories = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _reloadCostume() async {
    final updated = await _repository.getCostumeById(_costume.id);
    if (updated != null && mounted) {
      setState(() {
        _costume = updated;
      });
    }
  }

  Future<void> _showEditCostumeSheet() async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext sheetCtx) {
        return AddCostumeSheet(
          repository: _repository,
          initialCostume: _costume,
          onSaved: () async {
            await _reloadCostume();
          },
          onDeleted: () {
            if (mounted) {
              Navigator.of(context).pop();
            }
          },
        );
      },
    );
  }

  String _formatCurrency(double amount) {
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
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Icon(CupertinoIcons.sparkles, size: 48, color: AppColors.primaryPink),
        ),
      );
    }
    if (path.startsWith('/') || path.startsWith('file:') || File(path).existsSync()) {
      final cleanPath = path.startsWith('file://') ? path.replaceFirst('file://', '') : path;
      return Image.file(
        File(cleanPath),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Icon(CupertinoIcons.sparkles, size: 48, color: AppColors.primaryPink),
        ),
      );
    }
    return Image.asset(
      path,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => const Center(
        child: Icon(CupertinoIcons.sparkles, size: 48, color: AppColors.primaryPink),
      ),
    );
  }

  void _showPhotoPreviewModal(
    BuildContext context, {
    required String title,
    required String photoPath,
  }) {
    HapticFeedback.selectionClick();
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => DraggableSheetContainer(
        initialHeightFraction: 0.88,
        maxHeightFraction: 0.96,
        backgroundColor: const Color(0xFF1C1C1E),
        onDismissed: () => Navigator.of(ctx).pop(),
        builder: (sheetCtx) => CupertinoPageScaffold(
          backgroundColor: const Color(0xFF1C1C1E),
          navigationBar: CupertinoNavigationBar(
            automaticallyImplyLeading: false,
            backgroundColor: const Color(0xFF2C2C2E),
            border: const Border(bottom: BorderSide(color: Color(0xFF38383A), width: 0.5)),
            middle: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(
                'Tutup',
                style: TextStyle(
                  color: AppColors.primaryPink,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: InteractiveViewer(
                      minScale: 0.8,
                      maxScale: 5.0,
                      child: _buildCoverPhoto(photoPath),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: const Color(0xFF2C2C2E),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.zoom_in, size: 14, color: Color(0xFF8E8E93)),
                      SizedBox(width: 6),
                      Text(
                        'Cubit layar untuk zoom & geser foto',
                        style: TextStyle(
                          color: Color(0xFF8E8E93),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  (Color bg, Color text, String label) _getStatusBadgeData(CostumeStatus status) {
    switch (status) {
      case CostumeStatus.available:
        return (const Color(0xFFE3F9EC), const Color(0xFF1E824C), 'Tersedia');
      case CostumeStatus.booked:
        return (const Color(0xFFFFF4E5), const Color(0xFFD97706), 'Dibooking');
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
    final statusData = _getStatusBadgeData(_costume.status);

    return DefaultTextStyle(
      style: const TextStyle(
        decoration: TextDecoration.none,
        fontFamily: '.SF Pro Text',
        color: AppColors.textDark,
      ),
      child: CupertinoPageScaffold(
        backgroundColor: AppColors.background,
        navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.background,
        border: const Border(
          bottom: BorderSide(color: Color(0xFFE5E5EA), width: 0.5),
        ),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.maybePop(context),
          child: const Icon(
            CupertinoIcons.chevron_back,
            color: AppColors.textDark,
            size: 24,
          ),
        ),
        middle: Text(
          _costume.name.replaceAll('_', ' '),
          style: AppTypography.navTitle,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _showEditCostumeSheet,
          child: const Text('Ubah', style: AppTypography.actionButton),
        ),
      ),
      child: SafeArea(
        top: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 180),
          children: [
            // Hero cover photo — Apple card spec: radius 12, hairline 0.5, subtle shadow
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Container(
                width: double.infinity,
                height: 220,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFE5E5EA),
                    width: 0.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _costume.coverPhoto != null && _costume.coverPhoto!.isNotEmpty
                      ? GestureDetector(
                          onTap: () => _showPhotoPreviewModal(
                            context,
                            title: _costume.name.replaceAll('_', ' '),
                            photoPath: _costume.coverPhoto!,
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              _buildCoverPhoto(_costume.coverPhoto!),
                              Positioned(
                                right: 10,
                                bottom: 10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: CupertinoColors.black.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(CupertinoIcons.zoom_in, color: CupertinoColors.white, size: 12),
                                      SizedBox(width: 4),
                                      Text(
                                        'Perbesar',
                                        style: TextStyle(
                                          color: CupertinoColors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : const Center(
                          child: Icon(CupertinoIcons.sparkles, size: 48, color: AppColors.primaryPink),
                        ),
                ),
              ),
            ),

            // Section 1: INFORMASI KOSTUM (seiras INFORMASI BARANG di Detail Cicilan)
            CupertinoListSection.insetGrouped(
              backgroundColor: AppColors.background,
              header: const Text('INFORMASI KOSTUM'),
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              children: [
                CupertinoListTile(
                  leading: const SquircleIcon(
                    icon: CupertinoIcons.sparkles,
                    color: AppColors.primaryPink,
                  ),
                  title: const Text('Nama Kostum', style: TextStyle(fontSize: 15, color: AppColors.textDark)),
                  additionalInfo: Text(
                    _costume.name.replaceAll('_', ' '),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textDark),
                  ),
                ),
                CupertinoListTile(
                  leading: const SquircleIcon(
                    icon: CupertinoIcons.tv,
                    color: Color(0xFF5856D6),
                  ),
                  title: const Text('Serial Anime', style: TextStyle(fontSize: 15, color: AppColors.textDark)),
                  additionalInfo: Text(
                    _costume.animeSeries.replaceAll('_', ' '),
                    style: const TextStyle(fontSize: 15, color: AppColors.textDark),
                  ),
                ),
                CupertinoListTile(
                  leading: SquircleIcon(
                    icon: _costume.status == CostumeStatus.available
                        ? CupertinoIcons.checkmark_seal_fill
                        : CupertinoIcons.clock_fill,
                    color: _costume.status == CostumeStatus.available
                        ? const Color(0xFF34C759)
                        : AppColors.primaryPink,
                  ),
                  title: const Text('Status', style: TextStyle(fontSize: 15, color: AppColors.textDark)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusData.$1,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      statusData.$3,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.none,
                        color: statusData.$2,
                      ),
                    ),
                  ),
                ),
                CupertinoListTile(
                  leading: const SquircleIcon(
                    icon: CupertinoIcons.textformat,
                    color: Color(0xFF8E8E93),
                  ),
                  title: const Text('Ukuran', style: TextStyle(fontSize: 15, color: AppColors.textDark)),
                  additionalInfo: Text(
                    _costume.size,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textDark),
                  ),
                ),
              ],
            ),

            // Section 2: TARIF & DETAIL (seiras RINGKASAN PEMBAYARAN di Detail Cicilan)
            CupertinoListSection.insetGrouped(
              backgroundColor: AppColors.background,
              header: const Text('TARIF & DETAIL'),
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              children: [
                CupertinoListTile(
                  leading: const SquircleIcon(
                    icon: CupertinoIcons.tag_fill,
                    color: Color(0xFFFF9500),
                  ),
                  title: const Text('Tarif Sewa', style: TextStyle(fontSize: 15, color: AppColors.textDark)),
                  additionalInfo: Text(
                    '${_formatCurrency(_costume.rentPrice3Days)} / 3 hari',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryPink,
                    ),
                  ),
                ),
                if (_costume.notes != null && _costume.notes!.isNotEmpty)
                  CupertinoListTile(
                    leading: const SquircleIcon(
                      icon: CupertinoIcons.doc_text,
                      color: Color(0xFF8E8E93),
                    ),
                    title: const Text('Catatan', style: TextStyle(fontSize: 15, color: AppColors.textDark)),
                    subtitle: Text(
                      _costume.notes!,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                    ),
                  ),
              ],
            ),

            // Section 3: AKSESORI & PROPERTI
            CupertinoListSection.insetGrouped(
              backgroundColor: AppColors.background,
              header: const Text('AKSESORI & PROPERTI'),
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              children: [
                if (_isLoading)
                  const CupertinoListTile(
                    title: Center(child: CupertinoActivityIndicator(radius: 12)),
                  )
                else if (_accessories.isEmpty && _costume.includedAccessories.isEmpty)
                  CupertinoListTile(
                    title: const Text(
                      'Belum ada aksesori yang dicatat untuk kostum ini.',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                    ),
                    trailing: const Icon(
                      CupertinoIcons.plus_circle_fill,
                      color: AppColors.primaryPink,
                      size: 22,
                    ),
                    onTap: _showAddAccessoryDialog,
                  )
                else ...[
                  // Registered Accessory objects from DB
                  ..._accessories.map((acc) => _buildAccessoryTile(
                        acc.name,
                        acc.type,
                        acc.conditionStatus,
                        accessory: acc,
                      )),
                  // Legacy strings list in includedAccessories
                  ..._costume.includedAccessories
                      .where((accStr) => !_accessories.any((a) => a.name.toLowerCase() == accStr.toLowerCase()))
                      .map((accStr) => _buildAccessoryTile(
                            accStr,
                            'Kelengkapan Set',
                            AccessoryCondition.good,
                          )),
                  CupertinoListTile(
                    leading: const SquircleIcon(
                      icon: CupertinoIcons.add,
                      color: AppColors.primaryPink,
                    ),
                    title: const Text(
                      'Tambah Aksesori',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryPink,
                      ),
                    ),
                    onTap: _showAddAccessoryDialog,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    ),
    );
  }

  ({Color bg, Color text}) _getConditionColors(AccessoryCondition condition) {
    switch (condition) {
      case AccessoryCondition.good:
        return (bg: const Color(0xFFE3F9EC), text: const Color(0xFF1E824C));
      case AccessoryCondition.minorDamage:
        return (bg: const Color(0xFFFFF4E5), text: const Color(0xFFD97706));
      case AccessoryCondition.needsRepair:
        return (bg: const Color(0xFFFFEBF0), text: AppColors.dangerRose);
      case AccessoryCondition.lost:
        return (bg: const Color(0xFFFEE2E2), text: const Color(0xFFDC2626));
    }
  }

  void _showChangeConditionSheet(Accessory acc) {
    ChangeAccessoryConditionSheet.show(
      context: context,
      accessory: acc,
      onSelectCondition: (newCondition) async {
        await _repository.updateAccessory(acc.copyWith(conditionStatus: newCondition));
        await _loadAccessories();
        if (mounted) {
          IosToast.show(context, 'Kondisi diubah ke "${newCondition.displayName}"');
        }
      },
    );
  }

  void _showAddAccessoryDialog() {
    AddAccessorySheet.show(
      context: context,
      costumeId: _costume.id,
      onSaveAccessory: (acc) async {
        await _repository.addAccessory(acc);
        await _loadAccessories();
      },
    );
  }

  void _confirmDeleteAccessory(String id, String name) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Hapus Aksesori?'),
        content: Text('Apakah kamu yakin ingin menghapus "$name" dari kostum ini?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              await _repository.deleteAccessory(id);
              await _loadAccessories();
              if (mounted) {
                IosToast.show(context, 'Aksesori berhasil dihapus');
              }
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessoryTile(
    String name,
    String type,
    AccessoryCondition condition, {
    Accessory? accessory,
  }) {
    final colors = _getConditionColors(condition);

    return CupertinoListTile(
      leading: const SquircleIcon(
        icon: CupertinoIcons.star_fill,
        color: AppColors.primaryPink,
      ),
      title: Text(
        name,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.textDark),
      ),
      subtitle: Text(
        type,
        style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
      ),
      additionalInfo: GestureDetector(
        onTap: accessory != null ? () => _showChangeConditionSheet(accessory) : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: colors.bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.text.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                condition.displayName.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.none,
                  color: colors.text,
                ),
              ),
              if (accessory != null) ...[
                const SizedBox(width: 4),
                Icon(CupertinoIcons.chevron_down, size: 10, color: colors.text),
              ],
            ],
          ),
        ),
      ),
      trailing: accessory != null
          ? CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(44, 44),
              onPressed: () => _confirmDeleteAccessory(accessory.id, name),
              child: const Icon(CupertinoIcons.trash, color: Color(0xFFFF3B30), size: 16),
            )
          : null,
    );
  }
}
