import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/draggable_sheet_container.dart';
import '../../../core/widgets/squircle_icon.dart';
import '../../costumes/data/costume_repository.dart';
import '../../costumes/domain/costume.dart';
import '../../rentals/data/rental_repository.dart';
import '../../rentals/domain/customer.dart';
import '../../rentals/domain/rental.dart';
import '../domain/booking_conflict_engine.dart';

/// Modal for adding a booking manually (entry chosen from the "Tambah" sheet
/// in the Kalender tab). Style mirrors the "Tambah Kostum" and "Cicilan Baru"
/// sheets: DraggableSheetContainer + CupertinoPageScaffold +
/// CupertinoNavigationBar, body composed of CupertinoFormSection.insetGrouped
/// sections — iOS Settings-style form.
class ManualBookingModal extends StatefulWidget {
  final IRentalRepository rentalRepository;
  final ICostumeRepository costumeRepository;
  final DateTime? initialDate;
  final VoidCallback onBookingAdded;

  const ManualBookingModal({
    super.key,
    required this.rentalRepository,
    required this.costumeRepository,
    this.initialDate,
    required this.onBookingAdded,
  });

  @override
  State<ManualBookingModal> createState() => _ManualBookingModalState();
}

class _ManualBookingModalState extends State<ManualBookingModal> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _totalPriceController = TextEditingController();

  List<Costume> _costumes = [];
  Costume? _selectedCostume;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 3));
  String _purpose = 'homecos';
  bool _isLoadingCostumes = true;
  bool _isSaving = false;
  String? _costumeError;
  String? _dateError;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null);
    if (widget.initialDate != null) {
      _startDate = DateTime(
        widget.initialDate!.year,
        widget.initialDate!.month,
        widget.initialDate!.day,
      );
      _endDate = _startDate.add(const Duration(days: 3));
    }
    _loadCostumes();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _totalPriceController.dispose();
    super.dispose();
  }

  Future<void> _loadCostumes() async {
    final list = await widget.costumeRepository.getAllCostumes();
    if (mounted) {
      setState(() {
        _costumes = list;
        _isLoadingCostumes = false;
      });
    }
  }

  Future<void> _pickStartDate() async {
    final picked = await _showDatePickerSheet(
      title: 'Pilih Tanggal Mulai',
      initial: _startDate,
    );
    if (picked != null && mounted) {
      setState(() {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate.add(const Duration(days: 3));
        }
        _dateError = null;
      });
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await _showDatePickerSheet(
      title: 'Pilih Tanggal Selesai',
      initial: _endDate,
      minimumDate: _startDate,
    );
    if (picked != null && mounted) {
      setState(() {
        _endDate = picked;
        _dateError = null;
      });
    }
  }

  Future<DateTime?> _showDatePickerSheet({
    required String title,
    required DateTime initial,
    DateTime? minimumDate,
  }) async {
    DateTime temp = initial;
    return showCupertinoModalPopup<DateTime>(
      context: context,
      builder: (ctx) => Container(
        height: 280,
        color: CupertinoColors.white,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              // Navigation bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFE5E5EA), width: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Batal', style: AppTypography.actionButton),
                    ),
                    Text(title, style: AppTypography.navTitle),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.of(ctx).pop(temp),
                      child: const Text('Selesai', style: AppTypography.actionButton),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: initial,
                  minimumYear: 2020,
                  maximumYear: 2035,
                  minimumDate: minimumDate,
                  onDateTimeChanged: (dt) => temp = dt,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickCostume() async {
    if (_costumes.isEmpty) return;
    int initialIdx = _selectedCostume != null
        ? _costumes.indexWhere((c) => c.id == _selectedCostume!.id)
        : 0;
    if (initialIdx < 0) initialIdx = 0;
    final selected = await showCupertinoModalPopup<Costume>(
      context: context,
      builder: (ctx) {
        int current = initialIdx;
        return Container(
          height: 280,
          color: CupertinoColors.white,
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFE5E5EA), width: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Batal', style: AppTypography.actionButton),
                      ),
                      const Text('Pilih Kostum', style: AppTypography.navTitle),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.of(ctx).pop(_costumes[current]),
                        child: const Text('Selesai', style: AppTypography.actionButton),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: CupertinoPicker(
                    itemExtent: 36,
                    scrollController: FixedExtentScrollController(initialItem: initialIdx),
                    onSelectedItemChanged: (idx) => current = idx,
                    children: _costumes
                        .map((c) => Center(
                              child: Text(
                                '${c.name} (${c.size})',
                                style: const TextStyle(fontSize: 15),
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (selected != null && mounted) {
      setState(() {
        _selectedCostume = selected;
        _costumeError = null;
      });
    }
  }

  Future<void> _pickPurpose() async {
    const List<String> options = ['homecos', 'event', 'photoshoot', 'lainnya'];
    const Map<String, String> labels = {
      'homecos': 'Homecos (Pakai Sendiri)',
      'event': 'Event Cosplay',
      'photoshoot': 'Photoshoot',
      'lainnya': 'Lainnya',
    };
    int initialIdx = options.indexOf(_purpose);
    if (initialIdx < 0) initialIdx = 0;
    final selected = await showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) {
        int current = initialIdx;
        return Container(
          height: 280,
          color: CupertinoColors.white,
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFE5E5EA), width: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Batal', style: AppTypography.actionButton),
                      ),
                      const Text('Keperluan', style: AppTypography.navTitle),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.of(ctx).pop(options[current]),
                        child: const Text('Selesai', style: AppTypography.actionButton),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: CupertinoPicker(
                    itemExtent: 36,
                    scrollController: FixedExtentScrollController(initialItem: initialIdx),
                    onSelectedItemChanged: (idx) => current = idx,
                    children: options
                        .map((v) => Center(
                              child: Text(labels[v] ?? v, style: const TextStyle(fontSize: 15)),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (selected != null && mounted) {
      setState(() => _purpose = selected);
    }
  }

  String get _purposeLabel {
    switch (_purpose) {
      case 'event':
        return 'Event Cosplay';
      case 'photoshoot':
        return 'Photoshoot';
      case 'lainnya':
        return 'Lainnya';
      case 'homecos':
      default:
        return 'Homecos (Pakai Sendiri)';
    }
  }

  bool _validate() {
    final okName = _nameController.text.trim().isNotEmpty;
    final okPhone = _phoneController.text.trim().isNotEmpty;
    final okCostume = _selectedCostume != null;
    final okDate = !_endDate.isBefore(_startDate);
    setState(() {
      _costumeError = okCostume ? null : 'Pilih kostum dulu';
      _dateError = okDate ? null : 'Tanggal selesai harus setelah mulai';
    });
    return okName && okPhone && okCostume && okDate;
  }

  Future<void> _save() async {
    if (!_validate()) return;
    setState(() => _isSaving = true);

    try {
      final candidate = Rental(
        id: 'temp_candidate',
        costumeId: _selectedCostume!.id,
        customerId: 'temp_customer',
        startDate: _startDate,
        endDate: _endDate,
        durationDays: _endDate.difference(_startDate).inDays + 1,
        purpose: _purpose,
        totalPrice: double.tryParse(_totalPriceController.text.replaceAll('.', '').replaceAll(',', '')) ?? 0,
      );

      final allRentals = await widget.rentalRepository.getAllRentals();
      final conflicts = BookingConflictEngine.findConflicts(allRentals, candidate);

      if (conflicts.isNotEmpty) {
        final proceed = await _showConflictDialog(conflicts);
        if (proceed != true) {
          setState(() => _isSaving = false);
          return;
        }
      }

      final custId = 'cust_${DateTime.now().millisecondsSinceEpoch}';
      final customer = Customer(
        id: custId,
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        address: '-',
      );
      await widget.rentalRepository.insertCustomer(customer);

      final rentalId = 'rent_${DateTime.now().millisecondsSinceEpoch}';
      final rental = Rental(
        id: rentalId,
        costumeId: _selectedCostume!.id,
        customerId: custId,
        startDate: _startDate,
        endDate: _endDate,
        durationDays: _endDate.difference(_startDate).inDays + 1,
        purpose: _purpose,
        totalPrice: double.tryParse(_totalPriceController.text.replaceAll('.', '').replaceAll(',', '')) ?? 0,
        itemStatus: RentalItemStatus.booked,
        paymentStatus: RentalPaymentStatus.unpaid,
      );
      await widget.rentalRepository.insertRental(rental);

      if (mounted) {
        setState(() => _isSaving = false);
        widget.onBookingAdded();
        Navigator.of(context).pop();
        _showSuccessSnack();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        _showErrorSnack('Gagal menyimpan: $e');
      }
    }
  }

  Future<bool?> _showConflictDialog(List<Rental> conflicts) async {
    return showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Konflik Jadwal'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'Kostum ini sudah dipesan ${conflicts.length} kali pada rentang tanggal tersebut. Tetap simpan?',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Tetap Simpan'),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Booking ${_selectedCostume!.name} tersimpan'),
        backgroundColor: AppColors.successMint,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.dangerRose,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEEE, d MMMM yyyy', 'id_ID');
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return DraggableSheetContainer(
      backgroundColor: AppColors.background,
      onDismissed: () => Navigator.of(context).pop(),
      builder: (sheetCtx) => DefaultTextStyle(
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
              onPressed: _isSaving ? null : () => Navigator.of(sheetCtx).pop(),
              child: const Text('Batal', style: AppTypography.actionButton),
            ),
            middle: const SizedBox(
              width: double.infinity,
              child: Center(
                child: Text('Booking Manual', style: AppTypography.navTitle),
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
              padding: EdgeInsets.fromLTRB(0, 8, 0, bottomInset + 24),
              physics: const BouncingScrollPhysics(),
              children: [
                // ====== Section 1: DATA PENYEWA ======
                CupertinoFormSection.insetGrouped(
                  backgroundColor: AppColors.background,
                  header: const Text('DATA PENYEWA'),
                  children: [
                    CupertinoTextFormFieldRow(
                      key: const Key('manual_name_input'),
                      controller: _nameController,
                      prefix: const SquircleIcon(
                        icon: CupertinoIcons.person_fill,
                        color: AppColors.primaryPink,
                      ),
                      placeholder: 'Nama Penyewa',
                      textInputAction: TextInputAction.next,
                    ),
                    CupertinoTextFormFieldRow(
                      key: const Key('manual_phone_input'),
                      controller: _phoneController,
                      prefix: const SquircleIcon(
                        icon: CupertinoIcons.phone_fill,
                        color: Color(0xFF5856D6),
                      ),
                      placeholder: 'No HP / WhatsApp',
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                    ),
                  ],
                ),

                // ====== Section 2: KOSTUM & JADWAL ======
                CupertinoFormSection.insetGrouped(
                  backgroundColor: AppColors.background,
                  header: const Text('KOSTUM & JADWAL'),
                  children: [
                    // Kostum — picker row
                    _PickerFormRow(
                      key: const Key('manual_costume_row'),
                      leadingIcon: CupertinoIcons.bag_fill,
                      leadingColor: const Color(0xFFFF85A1),
                      value: _isLoadingCostumes
                          ? 'Memuat...'
                          : (_selectedCostume != null
                              ? '${_selectedCostume!.name} (${_selectedCostume!.size})'
                              : 'Pilih kostum'),
                      valueColor: _selectedCostume != null
                          ? AppColors.textDark
                          : const Color(0xFF8E8E93),
                      onTap: _isLoadingCostumes ? null : _pickCostume,
                      errorText: _costumeError,
                    ),
                    // Tanggal Mulai
                    _PickerFormRow(
                      key: const Key('manual_start_date_row'),
                      leadingIcon: CupertinoIcons.calendar,
                      leadingColor: const Color(0xFFFF9500),
                      value: dateFormat.format(_startDate),
                      valueColor: AppColors.textDark,
                      onTap: _pickStartDate,
                    ),
                    // Tanggal Selesai
                    _PickerFormRow(
                      key: const Key('manual_end_date_row'),
                      leadingIcon: CupertinoIcons.calendar_badge_minus,
                      leadingColor: const Color(0xFFFF3B30),
                      value: dateFormat.format(_endDate),
                      valueColor: AppColors.textDark,
                      onTap: _pickEndDate,
                      errorText: _dateError,
                    ),
                    // Keperluan
                    _PickerFormRow(
                      key: const Key('manual_purpose_row'),
                      leadingIcon: CupertinoIcons.tag_fill,
                      leadingColor: const Color(0xFF5856D6),
                      value: _purposeLabel,
                      valueColor: AppColors.textDark,
                      onTap: _pickPurpose,
                    ),
                  ],
                ),

                // ====== Section 3: PEMBAYARAN ======
                CupertinoFormSection.insetGrouped(
                  backgroundColor: AppColors.background,
                  header: const Text('PEMBAYARAN'),
                  children: [
                    CupertinoTextFormFieldRow(
                      key: const Key('manual_price_input'),
                      controller: _totalPriceController,
                      prefix: const SquircleIcon(
                        icon: CupertinoIcons.money_dollar_circle_fill,
                        color: Color(0xFF34C759),
                      ),
                      placeholder: 'Total harga (opsional)',
                      keyboardType: TextInputType.number,
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

/// iOS form-row style picker (mirrors the inline Jatuh tempo row in the
/// Cicilan sheet). Tap target is the full row, leading SquircleIcon +
/// placeholder value, trailing chevron. Custom Container used here (not
/// CupertinoListTile) so the leading area exactly matches sibling
/// CupertinoTextFormFieldRow icons.
class _PickerFormRow extends StatelessWidget {
  final IconData leadingIcon;
  final Color leadingColor;
  final String value;
  final Color valueColor;
  final VoidCallback? onTap;
  final String? errorText;

  const _PickerFormRow({
    super.key,
    required this.leadingIcon,
    required this.leadingColor,
    required this.value,
    required this.valueColor,
    required this.onTap,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        // No opaque color — the parent CupertinoFormSection.insetGrouped
        // already paints the rounded card background. Adding a flat
        // white fill here would paint over the section's bottom rounded
        // corners, making the picker row appear to break out of the card.
        padding: const EdgeInsetsDirectional.fromSTEB(20.0, 14.0, 14.0, 14.0),
        child: Row(
          children: [
            SquircleIcon(icon: leadingIcon, color: leadingColor),
            const SizedBox(width: 7.0),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      color: valueColor,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  if (errorText != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        errorText!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.dangerRose,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_right,
              size: 14,
              color: Color(0xFFC7C7CC),
            ),
          ],
        ),
      ),
    );
  }
}
