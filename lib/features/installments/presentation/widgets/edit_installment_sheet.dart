import 'package:flutter/cupertino.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/draggable_sheet_container.dart';
import '../../../../core/widgets/ios_toast.dart';
import '../../../../core/widgets/sheet_picker.dart';
import '../../../../core/widgets/squircle_icon.dart';
import '../../../../core/widgets/unsaved_changes_guard.dart';
import '../../data/installment_repository.dart';
import '../../domain/installment.dart';

/// Modal sheet to edit installment details (item name, store, due date)
/// adhering strictly to Apple HIG Inset-Grouped styling.
class EditInstallmentSheet extends StatefulWidget {
  final Installment installment;
  final IInstallmentRepository repository;
  final VoidCallback onSaved;

  const EditInstallmentSheet({
    super.key,
    required this.installment,
    required this.repository,
    required this.onSaved,
  });

  @override
  State<EditInstallmentSheet> createState() => _EditInstallmentSheetState();
}

class _EditInstallmentSheetState extends State<EditInstallmentSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _storeController;
  DateTime? _selectedDueDate;
  bool _isSaving = false;
  bool _userEdited = false;

  /// True when the user made at least one manual edit that is not yet saved.
  bool get _hasUnsavedChanges => _userEdited && !_isSaving;

  /// Confirms discarding edits before the sheet closes. Returns `true` when
  /// the sheet should be allowed to close.
  Future<bool> _confirmClose() async {
    if (!_hasUnsavedChanges) return true;
    return confirmDiscardChanges(context);
  }

  void _markEdited() {
    if (!_userEdited) setState(() => _userEdited = true);
  }

  static const _months = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
  ];

  String _monthName(int month) => (month >= 1 && month <= 12) ? _months[month] : '$month';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.installment.itemName.replaceAll('_', ' '));
    _storeController = TextEditingController(text: widget.installment.storeName?.replaceAll('_', ' ') ?? '');
    _selectedDueDate = widget.installment.dueDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _storeController.dispose();
    super.dispose();
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

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final store = _storeController.text.trim();

    if (name.isEmpty) {
      _showAlert('Nama Wajib Diisi', 'Mohon masukkan nama barang atau kostum.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final updated = widget.installment.copyWith(
        itemName: name,
        storeName: store.isEmpty ? null : store,
        dueDate: _selectedDueDate,
        clearDueDate: _selectedDueDate == null,
      );

      await widget.repository.updateInstallment(updated);

      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onSaved();
      IosToast.show(context, 'Perubahan cicilan berhasil disimpan');
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        _showAlert('Gagal Menyimpan', 'Terjadi kesalahan saat menyimpan perubahan: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
        backgroundColor: AppColors.background,
        initialHeightFraction: 0.50,
        maxHeightFraction: 0.85,
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
              onPressed: () async {
                final navigator = Navigator.of(context);
                if (await _confirmClose()) {
                  if (mounted) navigator.pop();
                }
              },
              child: const Text('Batal', style: AppTypography.actionButton),
            ),
            middle: const Text('Ubah Cicilan', style: AppTypography.navTitle),
            trailing: CupertinoButton(
              key: const Key('save_edit_installment_button'),
              padding: EdgeInsets.zero,
              onPressed: _isSaving ? null : _submit,
              child: _isSaving
                  ? const CupertinoActivityIndicator()
                  : const Text('Simpan', style: AppTypography.actionButton),
            ),
          ),
          child: SafeArea(
            top: false,
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(0, 8, 0, bottomInset + 24),
              physics: const BouncingScrollPhysics(),
              children: [
                CupertinoListSection.insetGrouped(
                  backgroundColor: AppColors.background,
                  header: const Text('INFORMASI BARANG'),
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  children: [
                    CupertinoListTile(
                      leading: const SquircleIcon(
                        icon: CupertinoIcons.sparkles,
                        color: AppColors.primaryPink,
                      ),
                      title: Row(
                        children: [
                          const SizedBox(
                            width: 90,
                            child: Text('Nama', style: TextStyle(fontSize: 15, color: AppColors.textDark)),
                          ),
                          Expanded(
                            child: CupertinoTextField(
                              key: const Key('edit_installment_name_input'),
                              controller: _nameController,
                              textAlign: TextAlign.right,
                              placeholder: 'Nama barang / kostum',
                              placeholderStyle: const TextStyle(color: Color(0xFFC7C7CC), fontSize: 15),
                              style: const TextStyle(fontSize: 15, color: AppColors.textDark),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: null,
                              textInputAction: TextInputAction.next,
                              onChanged: (_) => _markEdited(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    CupertinoListTile(
                      leading: const SquircleIcon(
                        icon: CupertinoIcons.bag_fill,
                        color: Color(0xFF5856D6),
                      ),
                      title: Row(
                        children: [
                          const SizedBox(
                            width: 90,
                            child: Text('Toko', style: TextStyle(fontSize: 15, color: AppColors.textDark)),
                          ),
                          Expanded(
                            child: CupertinoTextField(
                              key: const Key('edit_installment_store_input'),
                              controller: _storeController,
                              textAlign: TextAlign.right,
                              placeholder: 'Nama toko / seller',
                              placeholderStyle: const TextStyle(color: Color(0xFFC7C7CC), fontSize: 15),
                              style: const TextStyle(fontSize: 15, color: AppColors.textDark),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: null,
                              onChanged: (_) => _markEdited(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                CupertinoListSection.insetGrouped(
                  backgroundColor: AppColors.background,
                  header: const Text('JATUH TEMPO'),
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  children: [
                    CupertinoListTile(
                      key: const Key('edit_installment_due_date_row'),
                      leading: const SquircleIcon(
                        icon: CupertinoIcons.calendar,
                        color: Color(0xFFFF3B30),
                      ),
                      title: const Text(
                        'Jatuh tempo',
                        style: TextStyle(fontSize: 15, color: AppColors.textDark),
                      ),
                      additionalInfo: Text(
                        _selectedDueDate == null
                            ? 'Opsional'
                            : '${_selectedDueDate!.day} ${_monthName(_selectedDueDate!.month)} ${_selectedDueDate!.year}',
                        style: TextStyle(
                          fontSize: 15,
                          color: _selectedDueDate == null
                              ? const Color(0xFF8E8E93)
                              : AppColors.textDark,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_selectedDueDate != null)
                            CupertinoButton(
                              key: const Key('clear_due_date_button'),
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(28, 28),
                              onPressed: () {
                                _markEdited();
                                setState(() => _selectedDueDate = null);
                              },
                              child: const Icon(
                                CupertinoIcons.clear_circled_solid,
                                size: 18,
                                color: Color(0xFF8E8E93),
                              ),
                            ),
                          const SizedBox(width: 4),
                          const Icon(
                            CupertinoIcons.chevron_right,
                            size: 14,
                            color: Color(0xFFC7C7CC),
                          ),
                        ],
                      ),
                      onTap: () async {
                        final hadFocus = FocusScope.of(context).hasFocus;
                        if (hadFocus) {
                          FocusScope.of(context).unfocus();
                          await Future<void>.delayed(const Duration(milliseconds: 150));
                          if (!mounted) return;
                        }
                        if (!context.mounted) return;
                        final d = await showSheetDatePicker(
                          context: context,
                          title: 'Jatuh Tempo',
                          initialDate: _selectedDueDate ??
                              DateTime.now().add(const Duration(days: 30)),
                        );
                        if (d != null) {
                          _markEdited();
                          setState(() => _selectedDueDate = d);
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }
}
