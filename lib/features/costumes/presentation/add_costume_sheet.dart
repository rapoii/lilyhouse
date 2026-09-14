import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/draggable_sheet_container.dart';
import '../../../core/widgets/photo_source_picker_sheet.dart';
import '../../../core/widgets/sheet_picker.dart';
import '../../../core/widgets/squircle_icon.dart';
import '../data/costume_repository.dart';
import '../domain/accessory.dart';
import '../domain/costume.dart';
import 'widgets/add_accessory_sheet.dart';

/// Authentic 10/10 Apple HIG Inset-Grouped Modal Sheet for adding costumes & accessories.
class AddCostumeSheet extends StatefulWidget {
  final ICostumeRepository repository;
  final VoidCallback onSaved;
  final Costume? initialCostume;
  final VoidCallback? onDeleted;

  const AddCostumeSheet({
    super.key,
    required this.repository,
    required this.onSaved,
    this.initialCostume,
    this.onDeleted,
  });

  @override
  State<AddCostumeSheet> createState() => _AddCostumeSheetState();
}

class _AddCostumeSheetState extends State<AddCostumeSheet> {
  bool get _isEditing => widget.initialCostume != null;

  late TextEditingController _nameController;
  late TextEditingController _seriesController;
  late TextEditingController _priceController;
  late TextEditingController _notesController;

  late String _selectedSize;
  late CostumeStatus _selectedStatus;
  String? _selectedImagePath;
  final List<String> _accessories = [];
  bool _isSaving = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final c = widget.initialCostume;
    if (c != null) {
      _nameController = TextEditingController(text: c.name);
      _seriesController = TextEditingController(text: c.animeSeries == '-' ? '' : c.animeSeries);
      _priceController = TextEditingController(
        text: c.rentPrice3Days > 0
            ? (c.rentPrice3Days % 1 == 0 ? c.rentPrice3Days.toInt().toString() : c.rentPrice3Days.toString())
            : '',
      );
      _notesController = TextEditingController(text: c.notes ?? '');
      _selectedSize = c.size;
      _selectedStatus = c.status;
      _selectedImagePath = c.coverPhoto;
    } else {
      _nameController = TextEditingController();
      _seriesController = TextEditingController();
      _priceController = TextEditingController();
      _notesController = TextEditingController();
      _selectedSize = 'M';
      _selectedStatus = CostumeStatus.available;
      _selectedImagePath = null;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _seriesController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _getStatusLabel(CostumeStatus status) {
    switch (status) {
      case CostumeStatus.available:
        return 'Tersedia';
      case CostumeStatus.booked:
        return 'Dibooking';
      case CostumeStatus.rented:
        return 'Disewa';
      case CostumeStatus.laundry:
        return 'Dicuci';
      case CostumeStatus.maintenance:
        return 'Perawatan';
    }
  }

  Color _getStatusColor(CostumeStatus status) {
    switch (status) {
      case CostumeStatus.available:
        return const Color(0xFF1E824C);
      case CostumeStatus.booked:
        return const Color(0xFFD97706);
      case CostumeStatus.rented:
        return AppColors.primaryPink;
      case CostumeStatus.laundry:
        return const Color(0xFF2563EB);
      case CostumeStatus.maintenance:
        return AppColors.dangerRose;
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 85);
      if (picked != null) {
        setState(() => _selectedImagePath = picked.path);
      }
    } catch (_) {}
  }

  void _showImagePickerActionSheet() {
    PhotoSourcePickerSheet.show(
      context: context,
      title: 'Pilih Foto Kostum',
      onCamera: () => _pickImage(ImageSource.camera),
      onGallery: () => _pickImage(ImageSource.gallery),
    );
  }

  void _showAddAccessoryDialog() {
    AddAccessorySheet.show(
      context: context,
      onAddNameOnly: (name) {
        setState(() => _accessories.add(name));
      },
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final price = double.tryParse(_priceController.text.trim()) ?? 0.0;
    if (name.isEmpty) {
      _showAlert('Nama Kostum Wajib Diisi', 'Silakan masukkan nama kostum terlebih dahulu.');
      return;
    }
    if (price <= 0) {
      _showAlert('Harga Sewa Tidak Valid', 'Mohon masukkan harga sewa yang valid (lebih dari 0).');
      return;
    }

    setState(() => _isSaving = true);
    try {
      if (_isEditing) {
        final updatedCostume = widget.initialCostume!.copyWith(
          name: name,
          animeSeries: _seriesController.text.trim().isEmpty ? '-' : _seriesController.text.trim(),
          size: _selectedSize,
          rentPrice3Days: price,
          status: _selectedStatus,
          coverPhoto: _selectedImagePath,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        );
        await widget.repository.updateCostume(updatedCostume);
      } else {
        final costume = Costume(
          id: 'cost_${DateTime.now().millisecondsSinceEpoch}',
          name: name,
          animeSeries: _seriesController.text.trim().isEmpty ? '-' : _seriesController.text.trim(),
          size: _selectedSize,
          rentPrice3Days: price,
          status: _selectedStatus,
          coverPhoto: _selectedImagePath,
          includedAccessories: List<String>.from(_accessories),
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        );
        await widget.repository.insertCostume(costume);
        for (final accName in _accessories) {
          final acc = Accessory(
            id: 'acc_${DateTime.now().millisecondsSinceEpoch}_${accName.hashCode.abs()}',
            name: accName,
            type: 'Aksesori & Properti',
            relatedCostumeId: costume.id,
          );
          await widget.repository.addAccessory(acc);
        }
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      _showAlert('Gagal Menyimpan', 'Terjadi kesalahan: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _confirmDeleteCostume() {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Hapus Kostum?'),
        content: Text('Kostum "${_nameController.text.trim()}" akan dihapus dari katalog beserta seluruh aksesorinya. Tindakan ini tidak dapat dibatalkan.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.primaryPink)),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              await _deleteCostume();
            },
            child: const Text('Hapus', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.dangerRose)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCostume() async {
    if (!_isEditing) return;
    setState(() => _isSaving = true);
    try {
      await widget.repository.deleteCostume(widget.initialCostume!.id);
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onDeleted?.call();
    } catch (e) {
      if (!mounted) return;
      _showAlert('Gagal Menghapus', 'Terjadi kesalahan: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showAlert(String title, String message) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Oke', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.primaryPink)),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoPreview() {
    if (_selectedImagePath == null || _selectedImagePath!.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: const BoxDecoration(
              color: AppColors.background,
              shape: BoxShape.circle,
            ),
            child: const Icon(CupertinoIcons.camera, color: Color(0xFF8E8E93), size: 28),
          ),
          const SizedBox(height: 8),
          const Text(
            'Unggah Foto Kostum',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primaryPink),
          ),
          const SizedBox(height: 2),
          const Text(
            'Format JPG atau PNG (Opsional)',
            style: TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
          ),
        ],
      );
    }

    Widget imageWidget;
    final path = _selectedImagePath!;
    if (path.startsWith('http://') || path.startsWith('https://')) {
      imageWidget = Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const Center(
          child: Icon(CupertinoIcons.sparkles, size: 48, color: AppColors.primaryPink),
        ),
      );
    } else if (path.startsWith('/') || path.startsWith('file:') || File(path).existsSync()) {
      final cleanPath = path.startsWith('file://') ? path.replaceFirst('file://', '') : path;
      imageWidget = Image.file(
        File(cleanPath),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const Center(
          child: Icon(CupertinoIcons.sparkles, size: 48, color: AppColors.primaryPink),
        ),
      );
    } else {
      imageWidget = Image.asset(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const Center(
          child: Icon(CupertinoIcons.sparkles, size: 48, color: AppColors.primaryPink),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          imageWidget,
          Positioned(
            right: 10,
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: CupertinoColors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.camera_fill, color: CupertinoColors.white, size: 14),
                  SizedBox(width: 4),
                  Text('Ubah', style: TextStyle(color: CupertinoColors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return DraggableSheetContainer(
      backgroundColor: AppColors.background,
      onDismissed: () => Navigator.of(context).pop(),
      builder: (context) => DefaultTextStyle(
        style: const TextStyle(
          decoration: TextDecoration.none,
          fontFamily: '.SF Pro Text',
          color: AppColors.textDark,
        ),
        child: CupertinoPageScaffold(
          backgroundColor: AppColors.background,
          navigationBar: CupertinoNavigationBar(
            backgroundColor: AppColors.background,
            border: const Border(bottom: BorderSide(color: Color(0xFFE5E5EA), width: 0.5)),
            leading: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal', style: AppTypography.actionButton),
            ),
            middle: SizedBox(
              width: double.infinity,
              child: Center(
                child: Text(_isEditing ? 'Ubah Kostum' : 'Kostum Baru', style: AppTypography.navTitle),
              ),
            ),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const CupertinoActivityIndicator(radius: 10)
                  : const Text('Simpan', style: AppTypography.actionButton),
            ),
          ),
          child: SafeArea(
            top: false,
            child: ListView(
              padding: EdgeInsets.fromLTRB(0, 8, 0, bottomInset + 80),
              physics: const BouncingScrollPhysics(),
              children: [
                // Photo Uploader Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GestureDetector(
                    onTap: _showImagePickerActionSheet,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      height: 160,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: CupertinoColors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5E5EA), width: 0.5),
                        boxShadow: [
                          BoxShadow(
                            color: CupertinoColors.black.withValues(alpha: 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: _buildPhotoPreview(),
                    ),
                  ),
                ),

                // Section 1: Informasi Dasar Kostum
                CupertinoListSection.insetGrouped(
                  header: const Text(
                    'INFORMASI UTAMA',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF8E8E93)),
                  ),
                  backgroundColor: AppColors.background,
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  children: [
                    CupertinoListTile(
                      leading: const SquircleIcon(icon: CupertinoIcons.sparkles, color: AppColors.primaryPink),
                      title: Row(
                        children: [
                          const SizedBox(
                            width: 100,
                            child: Text('Nama', style: TextStyle(fontSize: 15, color: AppColors.textDark)),
                          ),
                          Expanded(
                            child: CupertinoTextField(
                              controller: _nameController,
                              textAlign: TextAlign.right,
                              placeholder: 'Nama Kostum',
                              placeholderStyle: const TextStyle(color: Color(0xFFC7C7CC), fontSize: 15),
                              style: const TextStyle(fontSize: 15, color: AppColors.textDark),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: null,
                            ),
                          ),
                        ],
                      ),
                    ),
                    CupertinoListTile(
                      leading: const SquircleIcon(icon: CupertinoIcons.tv, color: Color(0xFF5856D6)),
                      title: Row(
                        children: [
                          const SizedBox(
                            width: 100,
                            child: Text('Kategori', style: TextStyle(fontSize: 15, color: AppColors.textDark)),
                          ),
                          Expanded(
                            child: CupertinoTextField(
                              controller: _seriesController,
                              textAlign: TextAlign.right,
                              placeholder: 'cth: Genshin Impact',
                              placeholderStyle: const TextStyle(color: Color(0xFFC7C7CC), fontSize: 15),
                              style: const TextStyle(fontSize: 15, color: AppColors.textDark),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: null,
                            ),
                          ),
                        ],
                      ),
                    ),
                    CupertinoListTile(
                      key: const Key('add_costume_size_row'),
                      leading: const SquircleIcon(
                        icon: CupertinoIcons.tag_fill,
                        color: Color(0xFFFF9500),
                      ),
                      title: const Text(
                        'Ukuran',
                        style: TextStyle(fontSize: 15, color: AppColors.textDark),
                      ),
                      additionalInfo: Text(
                        _selectedSize,
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppColors.textDark,
                        ),
                      ),
                      trailing: const Icon(
                        CupertinoIcons.chevron_right,
                        size: 14,
                        color: Color(0xFFC7C7CC),
                      ),
                      onTap: () async {
                        final hadFocus = FocusScope.of(context).hasFocus;
                        if (hadFocus) {
                          FocusScope.of(context).unfocus();
                          await Future<void>.delayed(const Duration(milliseconds: 150));
                          if (!context.mounted) return;
                        }
                        const items = [
                          SheetPickerItem('S', 'S'),
                          SheetPickerItem('M', 'M'),
                          SheetPickerItem('L', 'L'),
                          SheetPickerItem('XL', 'XL'),
                          SheetPickerItem('All Size', 'All Size'),
                          SheetPickerItem('Custom', 'Custom'),
                        ];
                        final key = await showSheetPicker<String>(
                          context: context,
                          title: 'Ukuran',
                          currentValue: _selectedSize,
                          items: items,
                        );
                        if (key != null) {
                          setState(() => _selectedSize = key);
                        }
                      },
                    ),
                    CupertinoListTile(
                      leading: const SquircleIcon(icon: CupertinoIcons.money_dollar_circle_fill, color: Color(0xFF34C759)),
                      title: Row(
                        children: [
                          const SizedBox(
                            width: 100,
                            child: Text('Tarif 3 Hari', style: TextStyle(fontSize: 15, color: AppColors.textDark)),
                          ),
                          Expanded(
                            child: CupertinoTextField(
                              controller: _priceController,
                              textAlign: TextAlign.right,
                              placeholder: '150000',
                              placeholderStyle: const TextStyle(color: Color(0xFFC7C7CC), fontSize: 15),
                              style: const TextStyle(fontSize: 15, color: AppColors.textDark),
                              keyboardType: TextInputType.number,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: null,
                            ),
                          ),
                        ],
                      ),
                    ),
                    CupertinoListTile(
                      key: const Key('add_costume_status_row'),
                      leading: SquircleIcon(
                        icon: CupertinoIcons.arrow_2_circlepath_circle_fill,
                        color: _getStatusColor(_selectedStatus),
                      ),
                      title: const Text(
                        'Status Kostum',
                        style: TextStyle(fontSize: 15, color: AppColors.textDark),
                      ),
                      additionalInfo: Text(
                        _getStatusLabel(_selectedStatus),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _getStatusColor(_selectedStatus),
                        ),
                      ),
                      trailing: const Icon(
                        CupertinoIcons.chevron_right,
                        size: 14,
                        color: Color(0xFFC7C7CC),
                      ),
                      onTap: () async {
                        final hadFocus = FocusScope.of(context).hasFocus;
                        if (hadFocus) {
                          FocusScope.of(context).unfocus();
                          await Future<void>.delayed(const Duration(milliseconds: 150));
                          if (!context.mounted) return;
                        }
                        const items = [
                          SheetPickerItem('available', 'Tersedia'),
                          SheetPickerItem('booked', 'Dibooking'),
                          SheetPickerItem('rented', 'Disewa'),
                          SheetPickerItem('laundry', 'Dicuci'),
                          SheetPickerItem('maintenance', 'Perawatan'),
                        ];
                        final key = await showSheetPicker<String>(
                          context: context,
                          title: 'Status Kostum',
                          currentValue: _selectedStatus.name,
                          items: items,
                        );
                        if (key != null) {
                          setState(() => _selectedStatus = CostumeStatus.fromString(key));
                        }
                      },
                    ),
                  ],
                ),

                if (!_isEditing) ...[
                  // Section 2: Daftar Aksesori Termasuk (Saat tambah baru)
                  CupertinoListSection.insetGrouped(
                    header: const Text(
                      'AKSESORI & KELENGKAPAN',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF8E8E93)),
                    ),
                    backgroundColor: AppColors.background,
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    children: _accessories.isEmpty
                        ? [
                            CupertinoListTile(
                              leading: const SquircleIcon(icon: CupertinoIcons.cube_box, color: Color(0xFF8E8E93)),
                              title: const Text(
                                'Belum ada aksesori terdaftar',
                                style: TextStyle(fontSize: 14, color: Color(0xFF8E8E93), fontStyle: FontStyle.italic),
                              ),
                              trailing: CupertinoButton(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                onPressed: _showAddAccessoryDialog,
                                child: const Icon(CupertinoIcons.plus_circle_fill, color: AppColors.primaryPink, size: 22),
                              ),
                              onTap: _showAddAccessoryDialog,
                            ),
                          ]
                        : [
                            ..._accessories.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final acc = entry.value;
                              return CupertinoListTile(
                                leading: const SquircleIcon(icon: CupertinoIcons.check_mark_circled_solid, color: Color(0xFF34C759)),
                                title: Text(acc, style: const TextStyle(fontSize: 15, color: AppColors.textDark, fontWeight: FontWeight.w500)),
                                trailing: CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  onPressed: () {
                                    setState(() => _accessories.removeAt(idx));
                                  },
                                  child: const Icon(CupertinoIcons.minus_circle_fill, color: Color(0xFFFF3B30), size: 20),
                                ),
                              );
                            }),
                            CupertinoListTile(
                              leading: const SquircleIcon(icon: CupertinoIcons.add, color: AppColors.primaryPink),
                              title: const Text(
                                'Tambah Aksesori',
                                style: TextStyle(fontSize: 15, color: AppColors.primaryPink, fontWeight: FontWeight.w500),
                              ),
                              onTap: _showAddAccessoryDialog,
                            ),
                          ],
                  ),
                ],

                // Section 3: Catatan Khusus
                CupertinoListSection.insetGrouped(
                  header: const Text(
                    'CATATAN TAMBAHAN',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF8E8E93)),
                  ),
                  backgroundColor: AppColors.background,
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: CupertinoTextField(
                        controller: _notesController,
                        placeholder: 'Catatan perawatan, deposit, atau instruksi khusus...',
                        placeholderStyle: const TextStyle(color: Color(0xFFC7C7CC), fontSize: 14),
                        style: const TextStyle(fontSize: 14, color: AppColors.textDark),
                        maxLines: 3,
                        decoration: null,
                      ),
                    ),
                  ],
                ),

                if (_isEditing) ...[
                  // Section: Zona Bahaya (Hapus Kostum)
                  CupertinoListSection.insetGrouped(
                    header: const Text(
                      'ZONA BAHAYA',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF8E8E93)),
                    ),
                    backgroundColor: AppColors.background,
                    margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    children: [
                      CupertinoListTile(
                        leading: const SquircleIcon(
                          icon: CupertinoIcons.trash_fill,
                          color: AppColors.dangerRose,
                        ),
                        title: const Text(
                          'Hapus Kostum',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.dangerRose,
                          ),
                        ),
                        onTap: _confirmDeleteCostume,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
