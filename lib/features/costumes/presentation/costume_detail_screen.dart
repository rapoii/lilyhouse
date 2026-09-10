import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../data/costume_repository.dart';
import '../domain/costume.dart';
import '../domain/accessory.dart';

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
  List<Accessory> _accessories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? CostumeRepository();
    _loadAccessories();
  }

  Future<void> _loadAccessories() async {
    final list = await _repository.getAccessoriesByCostumeId(widget.costume.id);
    if (mounted) {
      setState(() {
        _accessories = list;
        _isLoading = false;
      });
    }
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
    final statusData = _getStatusBadgeData(widget.costume.status);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.costume.name,
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
                child: widget.costume.coverPhoto != null && widget.costume.coverPhoto!.isNotEmpty
                    ? _buildCoverPhoto(widget.costume.coverPhoto!)
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
                              widget.costume.name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.costume.animeSeries,
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
                      _buildPillAttribute('Ukuran', widget.costume.size),
                      _buildPillAttribute(
                        'Tarif Sewa',
                        '${_formatCurrency(widget.costume.rentPrice3Days)} / 3 hari',
                        highlight: true,
                      ),
                    ],
                  ),
                  if (widget.costume.notes != null && widget.costume.notes!.isNotEmpty) ...[
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
                      widget.costume.notes!,
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
                  'Aksesori & Properti Termasuk',
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
            const SizedBox(height: 12),

            if (_isLoading)
              const Center(child: CupertinoActivityIndicator(radius: 14))
            else if (_accessories.isEmpty && widget.costume.includedAccessories.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: const Text(
                  'Belum ada aksesori yang dicatat untuk kostum ini.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              )
            else ...[
              // Registered Accessory objects from DB
              ..._accessories.map((acc) => _buildAccessoryRow(
                    acc.name,
                    acc.type,
                    acc.conditionStatus,
                    accessory: acc,
                  )),
              // Legacy strings list in includedAccessories
              ...widget.costume.includedAccessories
                  .where((accStr) => !_accessories.any((a) => a.name.toLowerCase() == accStr.toLowerCase()))
                  .map((accStr) => _buildAccessoryRow(
                        accStr,
                        'Kelengkapan Set',
                        AccessoryCondition.good,
                      )),
            ],
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
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text('Kondisi Aksesori: ${acc.name}'),
        message: const Text('Pilih status kondisi aksesori saat ini:'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(ctx);
              await _repository.updateAccessory(acc.copyWith(conditionStatus: AccessoryCondition.good));
              await _loadAccessories();
            },
            child: const Text('Baik', style: TextStyle(color: Color(0xFF1E824C), fontWeight: FontWeight.w600)),
          ),
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(ctx);
              await _repository.updateAccessory(acc.copyWith(conditionStatus: AccessoryCondition.minorDamage));
              await _loadAccessories();
            },
            child: const Text('Rusak Ringan', style: TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.w600)),
          ),
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(ctx);
              await _repository.updateAccessory(acc.copyWith(conditionStatus: AccessoryCondition.needsRepair));
              await _loadAccessories();
            },
            child: const Text('Perlu Servis', style: TextStyle(color: AppColors.dangerRose, fontWeight: FontWeight.w600)),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              await _repository.updateAccessory(acc.copyWith(conditionStatus: AccessoryCondition.lost));
              await _loadAccessories();
            },
            child: const Text('Hilang'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Batal'),
        ),
      ),
    );
  }

  void _showAddAccessoryDialog() {
    final controller = TextEditingController();
    AccessoryCondition selectedCondition = AccessoryCondition.good;

    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => CupertinoAlertDialog(
          title: const Text('Tambah Aksesori'),
          content: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CupertinoTextField(
                  controller: controller,
                  placeholder: 'Contoh: Wig Stylist, Senjata Prop, Tiara',
                  autofocus: true,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(10),
                ),
                const SizedBox(height: 12),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Kondisi Aksesori:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                  ),
                ),
                const SizedBox(height: 6),
                CupertinoSlidingSegmentedControl<AccessoryCondition>(
                  groupValue: selectedCondition,
                  children: const {
                    AccessoryCondition.good: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: Text('Baik', style: TextStyle(fontSize: 11)),
                    ),
                    AccessoryCondition.minorDamage: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: Text('Ringan', style: TextStyle(fontSize: 11)),
                    ),
                    AccessoryCondition.needsRepair: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: Text('Servis', style: TextStyle(fontSize: 11)),
                    ),
                    AccessoryCondition.lost: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: Text('Hilang', style: TextStyle(fontSize: 11)),
                    ),
                  },
                  onValueChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedCondition = val);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx),
              isDestructiveAction: true,
              child: const Text('Batal', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.primaryPink)),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () async {
                final value = controller.text.trim();
                if (value.isNotEmpty) {
                  final acc = Accessory(
                    id: 'acc_${DateTime.now().millisecondsSinceEpoch}',
                    name: value,
                    type: 'Aksesori & Properti',
                    conditionStatus: selectedCondition,
                    relatedCostumeId: widget.costume.id,
                  );
                  await _repository.addAccessory(acc);
                  await _loadAccessories();
                }
                if (mounted && Navigator.canPop(ctx)) {
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Tambah', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.primaryPink)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteAccessory(String id, String name) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text('Hapus Aksesori "$name"?'),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              await _repository.deleteAccessory(id);
              await _loadAccessories();
            },
            child: const Text('Hapus Aksesori'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Batal'),
        ),
      ),
    );
  }

  Widget _buildAccessoryRow(
    String name,
    String type,
    AccessoryCondition condition, {
    Accessory? accessory,
  }) {
    final colors = _getConditionColors(condition);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.softPinkBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(CupertinoIcons.star_fill, color: AppColors.primaryPink, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textDark),
                ),
                Text(
                  type,
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          GestureDetector(
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
          if (accessory != null) ...[
            const SizedBox(width: 8),
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              onPressed: () => _confirmDeleteAccessory(accessory.id, name),
              child: const Icon(CupertinoIcons.trash, color: Color(0xFFFF3B30), size: 18),
            ),
          ],
        ],
      ),
    );
  }
}
