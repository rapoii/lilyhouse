import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/squircle_icon.dart';
import '../data/costume_repository.dart';
import '../domain/costume.dart';
import '../domain/accessory.dart';

/// Authentic 10/10 Apple HIG Inset-Grouped Modal Sheet for adding costumes & accessories.
class AddCostumeSheet extends StatefulWidget {
  final ICostumeRepository repository;
  final VoidCallback onSaved;

  const AddCostumeSheet({
    super.key,
    required this.repository,
    required this.onSaved,
  });

  @override
  State<AddCostumeSheet> createState() => _AddCostumeSheetState();
}

class _AddCostumeSheetState extends State<AddCostumeSheet> {
  final _nameController = TextEditingController();
  final _seriesController = TextEditingController();
  final _priceController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedSize = 'M';
  CostumeStatus _selectedStatus = CostumeStatus.available;
  String? _selectedImagePath;
  final List<String> _accessories = [];
  bool _isSaving = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _nameController.dispose();
    _seriesController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
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
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Pilih Foto Kostum'),
        message: const Text('Ambil foto langsung atau pilih dari galeri'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _pickImage(ImageSource.camera);
            },
            child: const Text('Ambil dari Kamera'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _pickImage(ImageSource.gallery);
            },
            child: const Text('Pilih dari Galeri Foto'),
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
    final accController = TextEditingController();
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Tambah Aksesori'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: accController,
            placeholder: 'Contoh: Wig Stylist, Tiara, Sarung Tangan',
            autofocus: true,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F2F7),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            textStyle: const TextStyle(
              inherit: false,
              fontFamily: '.SF Pro Text',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryPink,
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          CupertinoDialogAction(
            textStyle: const TextStyle(
              inherit: false,
              fontFamily: '.SF Pro Text',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryPink,
            ),
            onPressed: () {
              final text = accController.text.trim();
              if (text.isNotEmpty) {
                setState(() => _accessories.add(text));
              }
              Navigator.pop(ctx);
            },
            child: const Text('Tambah'),
          ),
        ],
      ),
    );
  }

  void _showSizePicker() {
    final sizes = ['S', 'M', 'L', 'XL', 'All Size', 'Custom'];
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => Container(
        height: 250,
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: DefaultTextStyle(
          style: const TextStyle(
            decoration: TextDecoration.none,
            fontFamily: '.SF Pro Text',
            color: AppColors.textDark,
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFE5E5EA), width: 0.5)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Batal', style: AppTypography.actionButton),
                    ),
                    const Text('Pilih Ukuran', style: AppTypography.navTitle),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Selesai', style: AppTypography.actionButton),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoPicker(
                  itemExtent: 36,
                  scrollController: FixedExtentScrollController(
                    initialItem: sizes.indexOf(_selectedSize).clamp(0, sizes.length - 1),
                  ),
                  onSelectedItemChanged: (idx) {
                    setState(() => _selectedSize = sizes[idx]);
                  },
                  children: sizes.map((s) => Center(child: Text(s, style: const TextStyle(fontSize: 18, color: AppColors.textDark)))).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showAlert('Nama kostum wajib diisi');
      return;
    }
    final priceDigits = _priceController.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
    if (priceDigits.isEmpty) {
      _showAlert('Harga rental 3 hari wajib diisi');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final costumeId = 'cos_${DateTime.now().millisecondsSinceEpoch}';
      final costume = Costume(
        id: costumeId,
        name: name,
        animeSeries: _seriesController.text.trim().isEmpty ? 'Original / Lainnya' : _seriesController.text.trim(),
        size: _selectedSize,
        rentPrice3Days: double.parse(priceDigits),
        status: _selectedStatus,
        coverPhoto: _selectedImagePath,
        includedAccessories: List.from(_accessories),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      await widget.repository.insertCostume(costume);

      // Insert accessories into accessories table for complete sub-ledger tracking
      for (final accName in _accessories) {
        final accessory = Accessory(
          id: 'acc_${DateTime.now().millisecondsSinceEpoch}_${accName.hashCode}',
          relatedCostumeId: costumeId,
          name: accName,
          type: 'Set Piece',
          conditionStatus: AccessoryCondition.good,
        );
        await widget.repository.addAccessory(accessory);
      }

      if (!mounted) return;
      widget.onSaved();
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showAlert('Gagal menyimpan: $e');
    }
  }

  void _showAlert(String message) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Perhatian'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(message),
        ),
        actions: [
          CupertinoDialogAction(
            textStyle: const TextStyle(
              inherit: false,
              fontFamily: '.SF Pro Text',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryPink,
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Oke'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: screenHeight * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFFF2F2F7),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      clipBehavior: Clip.antiAlias,
      child: DefaultTextStyle(
        style: const TextStyle(
          decoration: TextDecoration.none,
          fontFamily: '.SF Pro Text',
          color: AppColors.textDark,
        ),
        child: CupertinoPageScaffold(
          backgroundColor: const Color(0xFFF2F2F7), // iOS systemGroupedBackground
          navigationBar: CupertinoNavigationBar(
            backgroundColor: const Color(0xFFF2F2F7),
            border: const Border(bottom: BorderSide(color: Color(0xFFE5E5EA), width: 0.5)),
            leading: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal', style: AppTypography.actionButton),
            ),
            middle: const Text('Kostum Baru', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textDark)),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const CupertinoActivityIndicator(radius: 10)
                  : const Text('Simpan', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.primaryPink)),
            ),
          ),
          child: SafeArea(
            top: false,
            child: ListView(
              padding: EdgeInsets.fromLTRB(0, 8, 0, bottomInset + 24),
              physics: const BouncingScrollPhysics(),
              children: [
                // iOS Modal Sheet Drag Handle
                Center(
                  child: Container(
                    width: 36,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1D1D6),
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),

            // Photo Uploader Card (Apple HIG rounded 16px with hairline border)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: _showImagePickerActionSheet,
                child: Container(
                  height: 160,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: CupertinoColors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E5EA), width: 0.5),
                    boxShadow: [
                      BoxShadow(
                        color: CupertinoColors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: _selectedImagePath != null && File(_selectedImagePath!).existsSync()
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.file(File(_selectedImagePath!), fit: BoxFit.cover),
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
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 54,
                              height: 54,
                              decoration: const BoxDecoration(
                                color: Color(0xFFF2F2F7),
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
                        ),
                ),
              ),
            ),

            // Section 1: Informasi Dasar Kostum (Inset Grouped Section)
            CupertinoListSection.insetGrouped(
              header: const Text('INFORMASI UTAMA'),
              backgroundColor: const Color(0xFFF2F2F7),
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              children: [
                CupertinoListTile(
                  leading: const SquircleIcon(icon: CupertinoIcons.sparkles, color: AppColors.primaryPink),
                  title: CupertinoTextField(
                    controller: _nameController,
                    placeholder: 'Nama Kostum (cth: Furina Archon)',
                    placeholderStyle: const TextStyle(color: Color(0xFFC7C7CC), fontSize: 15),
                    style: const TextStyle(fontSize: 15, color: AppColors.textDark),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: null,
                  ),
                ),
                CupertinoListTile(
                  leading: const SquircleIcon(icon: CupertinoIcons.tv, color: Color(0xFF5856D6)),
                  title: CupertinoTextField(
                    controller: _seriesController,
                    placeholder: 'Seri Anime / Game (cth: Genshin Impact)',
                    placeholderStyle: const TextStyle(color: Color(0xFFC7C7CC), fontSize: 15),
                    style: const TextStyle(fontSize: 15, color: AppColors.textDark),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: null,
                  ),
                ),
                CupertinoListTile(
                  leading: const SquircleIcon(icon: CupertinoIcons.tag_fill, color: Color(0xFFFF9500)),
                  title: const Text('Ukuran', style: TextStyle(fontSize: 15, color: AppColors.textDark)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_selectedSize, style: const TextStyle(fontSize: 15, color: Color(0xFF8E8E93), fontWeight: FontWeight.w500)),
                      const SizedBox(width: 4),
                      const Icon(CupertinoIcons.chevron_right, size: 14, color: Color(0xFFC7C7CC)),
                    ],
                  ),
                  onTap: _showSizePicker,
                ),
                CupertinoListTile(
                  leading: const SquircleIcon(icon: CupertinoIcons.money_dollar_circle_fill, color: Color(0xFF34C759)),
                  title: CupertinoTextField(
                    controller: _priceController,
                    placeholder: 'Harga Sewa 3 Hari (cth: 150000)',
                    placeholderStyle: const TextStyle(color: Color(0xFFC7C7CC), fontSize: 15),
                    style: const TextStyle(fontSize: 15, color: AppColors.textDark),
                    keyboardType: TextInputType.number,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: null,
                  ),
                ),
              ],
            ),

            // Section 2: Daftar Aksesori Termasuk (Inset Grouped Section)
            CupertinoListSection.insetGrouped(
              header: const Text('AKSESORI & KELENGKAPAN'),
              backgroundColor: const Color(0xFFF2F2F7),
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

            // Section 3: Catatan Khusus (Inset Grouped Section)
            CupertinoListSection.insetGrouped(
              header: const Text('CATATAN TAMBAHAN'),
              backgroundColor: const Color(0xFFF2F2F7),
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
          ],
        ),
      ),
    ),
  ),
);
}
}
