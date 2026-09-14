import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../data/costume_repository.dart';
import '../domain/costume.dart';
import '../domain/accessory.dart';
import '../../../core/theme/app_typography.dart';
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
    final statusData = _getStatusBadgeData(_costume.status);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          _costume.name,
          style: const TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.maybePop(context),
          child: const Icon(CupertinoIcons.chevron_back, color: AppColors.textDark, size: 24),
        ),
        actions: [
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            onPressed: _showEditCostumeSheet,
            child: const Text(
              'Ubah',
              style: AppTypography.actionButton,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Preview Header Card
            Container(
              width: double.infinity,
              height: 220,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28.0),
                border: Border.all(color: AppColors.borderSubtle, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.pastelPink.withValues(alpha: 0.12),
                    blurRadius: 16.0,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28.0),
                child: _costume.coverPhoto != null && _costume.coverPhoto!.isNotEmpty
                    ? _buildCoverPhoto(_costume.coverPhoto!)
                    : const Center(
                        child: Icon(CupertinoIcons.sparkles, size: 48, color: AppColors.primaryPink),
                      ),
              ),
            ),
            const SizedBox(height: 20),

            // Info Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24.0),
                border: Border.all(color: AppColors.borderSubtle, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _costume.name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _costume.animeSeries,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusData.$1,
                          borderRadius: BorderRadius.circular(20),
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
                  const SizedBox(height: 16),
                  const Divider(color: AppColors.borderSubtle),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildPillAttribute('Ukuran', _costume.size),
                      _buildPillAttribute(
                        'Tarif Sewa',
                        '${_formatCurrency(_costume.rentPrice3Days)} / 3 hari',
                        highlight: true,
                      ),
                    ],
                  ),
                  if (_costume.notes != null && _costume.notes!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Catatan',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _costume.notes!,
                      style: const TextStyle(fontSize: 14, color: AppColors.textDark),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Accessories Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Aksesori & Properti',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  onPressed: _showAddAccessoryDialog,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CupertinoIcons.plus_circle_fill, color: AppColors.primaryPink, size: 20),
                      SizedBox(width: 4),
                      Text(
                        'Tambah',
                        style: TextStyle(
                          color: AppColors.primaryPink,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (_isLoading)
              const Center(child: CupertinoActivityIndicator(radius: 14))
            else
              CupertinoListSection.insetGrouped(
                margin: EdgeInsets.zero,
                backgroundColor: Colors.transparent,
                children: [
                  if (_accessories.isEmpty && _costume.includedAccessories.isEmpty)
                    const CupertinoListTile(
                      title: Text(
                        'Belum ada aksesori yang dicatat untuk kostum ini.',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                      ),
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
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPillAttribute(String label, String value, {bool highlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: highlight ? AppColors.softPinkBg : AppColors.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: highlight ? AppColors.primaryPink.withValues(alpha: 0.3) : AppColors.borderSubtle,
            ),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: highlight ? AppColors.primaryPink : AppColors.textDark,
            ),
          ),
        ),
      ],
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
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: colors.text),
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
              minimumSize: const Size(28, 28),
              onPressed: () => _confirmDeleteAccessory(accessory.id, name),
              child: const Icon(CupertinoIcons.trash, color: Color(0xFFFF3B30), size: 16),
            )
          : null,
    );
  }
}
