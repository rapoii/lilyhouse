import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/draggable_sheet_container.dart';
import '../../../core/widgets/squircle_icon.dart';
import '../data/costume_repository.dart';
import '../domain/costume.dart';

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
  final CostumeStatus _selectedStatus = CostumeStatus.available;
  String? _selectedImagePath;
  final List<String> _accessories = [];
  bool _isSizePickerExpanded = false;
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
    final controller = TextEditingController();
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Aksesori Baru'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            placeholder: 'Contoh: Wig Stylist, Tiara, dll',
            autofocus: true,
            decoration: BoxDecoration(
              color: const Color(0xFFF2F2F7),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(10),
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
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) {
                setState(() => _accessories.add(value));
              }
              Navigator.pop(ctx);
            },
            child: const Text('Tambah', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.primaryPink)),
          ),
        ],
      ),
    );
  }

  void _showSizePicker() {
    setState(() {
      _isSizePickerExpanded = !_isSizePickerExpanded;
    });
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

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return DraggableSheetContainer(
      backgroundColor: const Color(0xFFF2F2F7),
      onDismissed: () => Navigator.of(context).pop(),
      builder: (context) => DefaultTextStyle(
        style: const TextStyle(
          decoration: TextDecoration.none,
          fontFamily: '.SF Pro Text',
          color: AppColors.textDark,
        ),
        child: CupertinoPageScaffold(
          backgroundColor: const Color(0xFFF2F2F7),
          navigationBar: CupertinoNavigationBar(
            backgroundColor: const Color(0xFFF2F2F7),
            border: const Border(bottom: BorderSide(color: Color(0xFFE5E5EA), width: 0.5)),
            leading: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal', style: AppTypography.actionButton),
            ),
            middle: const SizedBox(
              width: double.infinity,
              child: Center(
                child: Text('Kostum Baru', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textDark)),
              ),
            ),
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

                // Section 1: Informasi Dasar Kostum
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
                    // Ukuran row: Apple HIG collapsible picker (same pattern
                    // as Jatuh tempo on Cicilan sheet). Tapping the row
                    // toggles the inline CupertinoPicker — no separate
                    // modal popup, consistent with the rest of the form.
                    // Use leadingSize: 29 to match the SquircleIcon size
                    // used by CupertinoTextFormFieldRow siblings so the
                    // title text starts at the same x-coordinate.
                    CupertinoListTile(
                      padding: const EdgeInsetsDirectional.fromSTEB(20.0, 0, 14.0, 0),
                      leadingSize: 29.0,
                      leadingToTitle: 0.0,
                      leading: const SquircleIcon(icon: CupertinoIcons.tag_fill, color: Color(0xFFFF9500)),
                      title: Text(
                        _selectedSize,
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.textDark,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      subtitle: const Text(
                        'Pilih ukuran',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF8E8E93),
                        ),
                      ),
                      trailing: AnimatedRotation(
                        turns: _isSizePickerExpanded ? 0.25 : 0.0,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOutCubic,
                        child: const Icon(
                          CupertinoIcons.chevron_right,
                          size: 14,
                          color: Color(0xFFC7C7CC),
                        ),
                      ),
                      onTap: _showSizePicker,
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOutCubic,
                      alignment: Alignment.topCenter,
                      child: _isSizePickerExpanded
                          ? Container(
                              decoration: const BoxDecoration(
                                color: CupertinoColors.white,
                                border: Border(
                                  top: BorderSide(color: Color(0xFFE5E5EA), width: 0.5),
                                ),
                              ),
                              padding: const EdgeInsets.only(top: 8, bottom: 12),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    height: 180,
                                    child: CupertinoPicker(
                                      itemExtent: 36,
                                      scrollController: FixedExtentScrollController(
                                        initialItem: ['S', 'M', 'L', 'XL', 'All Size', 'Custom']
                                            .indexOf(_selectedSize)
                                            .clamp(0, 5),
                                      ),
                                      onSelectedItemChanged: (idx) {
                                        const sizes = ['S', 'M', 'L', 'XL', 'All Size', 'Custom'];
                                        setState(() => _selectedSize = sizes[idx]);
                                      },
                                      children: const ['S', 'M', 'L', 'XL', 'All Size', 'Custom']
                                          .map((s) => Center(
                                                child: Text(
                                                  s,
                                                  style: const TextStyle(
                                                    fontSize: 18,
                                                    color: AppColors.textDark,
                                                  ),
                                                ),
                                              ))
                                          .toList(),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        CupertinoButton(
                                          padding: EdgeInsets.zero,
                                          minimumSize: Size.zero,
                                          onPressed: () {
                                            setState(() => _isSizePickerExpanded = false);
                                          },
                                          child: const Text(
                                            'Selesai',
                                            style: TextStyle(
                                              color: AppColors.primaryPink,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : const SizedBox.shrink(),
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

                // Section 2: Daftar Aksesori Termasuk
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

                // Section 3: Catatan Khusus
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
