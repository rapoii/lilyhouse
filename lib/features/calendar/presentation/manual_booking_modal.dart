import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../costumes/data/costume_repository.dart';
import '../../costumes/domain/costume.dart';
import '../../rentals/data/rental_repository.dart';
import '../../rentals/domain/customer.dart';
import '../../rentals/domain/rental.dart';
import '../domain/booking_conflict_engine.dart';

/// Modal untuk input booking manual (di luar Smart Paste form).
///
/// Fields:
/// - Nama Penyewa
/// - No HP
/// - Kostum (dropdown picker dari katalog)
/// - Tanggal Mulai (DatePicker)
/// - Tanggal Selesai (DatePicker, default = mulai + 3 hari)
/// - Keperluan (opsional, default 'homecos')
/// - Total Harga (opsional, default 0)
///
/// Otomatis insert Customer + Rental ke repository, dan cek konflik.
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
  String? _nameError;
  String? _phoneError;
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
    final picked = await showCupertinoModalPopup<DateTime>(
      context: context,
      builder: (ctx) => Container(
        height: 280,
        color: Colors.white,
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
                  const Text('Pilih Tanggal Mulai', style: AppTypography.navTitle),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.of(ctx).pop(_startDate),
                    child: const Text('Selesai', style: AppTypography.actionButton),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: _startDate,
                minimumYear: 2020,
                maximumYear: 2035,
                onDateTimeChanged: (dt) {
                  // Update temp value for completion
                  _startDate = dt;
                },
              ),
            ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate.add(const Duration(days: 3));
        }
      });
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showCupertinoModalPopup<DateTime>(
      context: context,
      builder: (ctx) => Container(
        height: 280,
        color: Colors.white,
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
                  const Text('Pilih Tanggal Selesai', style: AppTypography.navTitle),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.of(ctx).pop(_endDate),
                    child: const Text('Selesai', style: AppTypography.actionButton),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: _endDate,
                minimumYear: 2020,
                maximumYear: 2035,
                minimumDate: _startDate,
                onDateTimeChanged: (dt) {
                  _endDate = dt;
                },
              ),
            ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  Future<void> _pickCostume() async {
    if (_costumes.isEmpty) return;
    final selected = await showCupertinoModalPopup<Costume>(
      context: context,
      builder: (ctx) => Container(
        height: 280,
        color: Colors.white,
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
                    onPressed: () => Navigator.of(ctx).pop(_selectedCostume),
                    child: const Text('Selesai', style: AppTypography.actionButton),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoPicker(
                itemExtent: 36,
                scrollController: FixedExtentScrollController(
                  initialItem: _selectedCostume != null
                      ? _costumes.indexWhere((c) => c.id == _selectedCostume!.id)
                      : 0,
                ),
                onSelectedItemChanged: (idx) {
                  _selectedCostume = _costumes[idx];
                },
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
    if (selected != null && mounted) {
      setState(() {
        _selectedCostume = selected;
      });
    }
  }

  Future<void> _pickPurpose() async {
    final options = ['homecos', 'event', 'photoshoot', 'lainnya'];
    final labels = {
      'homecos': 'Homecos (Pakai Sendiri)',
      'event': 'Event Cosplay',
      'photoshoot': 'Photoshoot',
      'lainnya': 'Lainnya',
    };
    final selected = await showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => Container(
        height: 280,
        color: Colors.white,
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
                    onPressed: () => Navigator.of(ctx).pop(_purpose),
                    child: const Text('Selesai', style: AppTypography.actionButton),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoPicker(
                itemExtent: 36,
                scrollController: FixedExtentScrollController(
                  initialItem: options.indexOf(_purpose),
                ),
                onSelectedItemChanged: (idx) {
                  _purpose = options[idx];
                },
                children: options
                    .map((p) => Center(
                          child: Text(
                            labels[p]!,
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
    if (selected != null && mounted) {
      setState(() {
        _purpose = selected;
      });
    }
  }

  bool _validate() {
    setState(() {
      _nameError = _nameController.text.trim().isEmpty ? 'Nama wajib diisi' : null;
      _phoneError = _phoneController.text.trim().isEmpty ? 'No HP wajib diisi' : null;
      _costumeError = _selectedCostume == null ? 'Pilih kostum dulu' : null;
      _dateError = _endDate.isBefore(_startDate) ? 'Tanggal selesai harus setelah mulai' : null;
    });
    return _nameError == null &&
        _phoneError == null &&
        _costumeError == null &&
        _dateError == null;
  }

  Future<void> _save() async {
    if (!_validate()) return;
    setState(() => _isSaving = true);

    try {
      // Cek konflik
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

      // Insert customer
      final custId = 'cust_${DateTime.now().millisecondsSinceEpoch}';
      final customer = Customer(
        id: custId,
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        address: '-',
      );
      await widget.rentalRepository.insertCustomer(customer);

      // Insert rental
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
    // Outer scaffold's snack
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final dateFormat = DateFormat('EEEE, d MMMM yyyy', 'id_ID');

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFD1D1D6),
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Booking Manual', style: AppTypography.headline),
                      SizedBox(height: 2),
                      Text(
                        'Isi data booking kostum untuk pelanggan',
                        style: AppTypography.subhead,
                      ),
                    ],
                  ),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Batal', style: AppTypography.actionButton),
                ),
              ],
            ),
          ),
          // Form
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Section 1: Data Penyewa
                  _buildSectionHeader('DATA PENYEWA'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    label: 'Nama Penyewa',
                    icon: CupertinoIcons.person_fill,
                    iconColor: AppColors.primaryPink,
                    controller: _nameController,
                    placeholder: 'cth: Andi Setiawan',
                    errorText: _nameError,
                  ),
                  const SizedBox(height: 10),
                  _buildTextField(
                    label: 'No HP / WhatsApp',
                    icon: CupertinoIcons.phone_fill,
                    iconColor: const Color(0xFF5856D6),
                    controller: _phoneController,
                    placeholder: 'cth: 081234567890',
                    keyboardType: TextInputType.phone,
                    errorText: _phoneError,
                  ),

                  const SizedBox(height: 18),
                  // Section 2: Kostum & Tanggal
                  _buildSectionHeader('KOSTUM & JADWAL'),
                  const SizedBox(height: 8),
                  _buildPickerRow(
                    label: 'Kostum',
                    icon: CupertinoIcons.bag_fill,
                    iconColor: const Color(0xFFFF85A1),
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
                  const SizedBox(height: 10),
                  _buildPickerRow(
                    label: 'Tanggal Mulai',
                    icon: CupertinoIcons.calendar,
                    iconColor: const Color(0xFFFF9500),
                    value: dateFormat.format(_startDate),
                    valueColor: AppColors.textDark,
                    onTap: _pickStartDate,
                  ),
                  const SizedBox(height: 10),
                  _buildPickerRow(
                    label: 'Tanggal Selesai',
                    icon: CupertinoIcons.calendar_badge_minus,
                    iconColor: const Color(0xFFFF3B30),
                    value: dateFormat.format(_endDate),
                    valueColor: AppColors.textDark,
                    onTap: _pickEndDate,
                    errorText: _dateError,
                  ),
                  const SizedBox(height: 10),
                  _buildPickerRow(
                    label: 'Keperluan',
                    icon: CupertinoIcons.tag_fill,
                    iconColor: const Color(0xFF5856D6),
                    value: _purpose == 'homecos'
                        ? 'Homecos (Pakai Sendiri)'
                        : _purpose == 'event'
                            ? 'Event Cosplay'
                            : _purpose == 'photoshoot'
                                ? 'Photoshoot'
                                : 'Lainnya',
                    valueColor: AppColors.textDark,
                    onTap: _pickPurpose,
                  ),

                  const SizedBox(height: 18),
                  // Section 3: Pembayaran
                  _buildSectionHeader('PEMBAYARAN'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    label: 'Total Harga (opsional)',
                    icon: CupertinoIcons.money_dollar_circle_fill,
                    iconColor: const Color(0xFF34C759),
                    controller: _totalPriceController,
                    placeholder: 'cth: 150000',
                    keyboardType: TextInputType.number,
                    prefix: 'Rp ',
                  ),

                  const SizedBox(height: 24),
                  // Save button
                  CupertinoButton(
                    onPressed: _isSaving ? null : _save,
                    color: AppColors.primaryPink,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    borderRadius: BorderRadius.circular(12),
                    child: _isSaving
                        ? const CupertinoActivityIndicator(color: Colors.white)
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(CupertinoIcons.checkmark_circle_fill, color: Colors.white, size: 18),
                              SizedBox(width: 6),
                              Text(
                                'Simpan Booking',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Color(0xFF6C6C70),
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required IconData icon,
    required Color iconColor,
    required TextEditingController controller,
    required String placeholder,
    TextInputType? keyboardType,
    String? errorText,
    String? prefix,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: errorText != null ? AppColors.dangerRose : const Color(0xFFE5E5EA),
          width: 0.5,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 29,
            height: 29,
            decoration: BoxDecoration(
              color: iconColor,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8E8E93),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                CupertinoTextField(
                  controller: controller,
                  placeholder: placeholder,
                  keyboardType: keyboardType,
                  decoration: const BoxDecoration(),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  style: const TextStyle(fontSize: 15, color: AppColors.textDark),
                  placeholderStyle: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF8E8E93),
                  ),
                  prefix: prefix != null
                      ? Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(
                            prefix,
                            style: const TextStyle(
                              fontSize: 15,
                              color: Color(0xFF8E8E93),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )
                      : null,
                ),
                if (errorText != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      errorText,
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
        ],
      ),
    );
  }

  Widget _buildPickerRow({
    required String label,
    required IconData icon,
    required Color iconColor,
    required String value,
    required Color valueColor,
    required VoidCallback? onTap,
    String? errorText,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: errorText != null ? AppColors.dangerRose : const Color(0xFFE5E5EA),
            width: 0.5,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 29,
              height: 29,
              decoration: BoxDecoration(
                color: iconColor,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(icon, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF8E8E93),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 15,
                      color: valueColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (errorText != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        errorText,
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
              size: 16,
              color: Color(0xFFC7C7CC),
            ),
          ],
        ),
      ),
    );
  }
}
