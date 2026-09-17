import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/apple_sliding_segmented_control.dart';
import '../../../core/widgets/draggable_sheet_container.dart';
import '../../../core/widgets/ios_toast.dart';
import '../../../core/widgets/photo_source_picker_sheet.dart';
import '../../../core/widgets/sheet_picker.dart';
import '../../../core/widgets/squircle_icon.dart';
import '../../../core/widgets/unsaved_changes_guard.dart';
import '../../costumes/data/costume_repository.dart';
import '../../costumes/domain/costume.dart';
import '../../rentals/data/rental_repository.dart';
import '../../rentals/domain/customer.dart';
import '../../rentals/domain/parsed_rental_data.dart';
import '../../rentals/domain/rental.dart';
import '../domain/booking_conflict_engine.dart';

/// Modal for adding a booking manually (entry chosen from the "Tambah" sheet
/// in the Kalender tab). Style mirrors the "Tambah Kostum" and "Cicilan Baru"
/// sheets: DraggableSheetContainer + CupertinoPageScaffold +
/// CupertinoNavigationBar, body composed of CupertinoListSection.insetGrouped
/// sections — iOS Settings-style form. Picker rows (Kostum, Tanggal Mulai,
/// Tanggal Selesai, Keperluan) expand inline with AnimatedRotation chevron +
/// AnimatedSize + CupertinoPicker/CupertinoDatePicker (Apple HIG pattern).
class ManualBookingModal extends StatefulWidget {
  final IRentalRepository rentalRepository;
  final ICostumeRepository costumeRepository;
  final DateTime? initialDate;
  final ParsedRentalData? initialParsedData;
  final VoidCallback onBookingAdded;

  const ManualBookingModal({
    super.key,
    required this.rentalRepository,
    required this.costumeRepository,
    this.initialDate,
    this.initialParsedData,
    required this.onBookingAdded,
  });

  @override
  State<ManualBookingModal> createState() => _ManualBookingModalState();
}

class _ManualBookingModalState extends State<ManualBookingModal> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _parentPhoneController = TextEditingController();
  final _socialMediaController = TextEditingController();
  final _totalPriceController = TextEditingController();
  final _dpAmountController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  String? _ktpPhotoPath;
  String? _selfieKtpPath;

  List<Costume> _costumes = [];
  List<Customer> _existingCustomers = [];
  Costume? _selectedCostume;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 3));
  String _purpose = 'homecos';
  bool _isLoadingCostumes = true;
  bool _isSaving = false;
  bool _isPriceManuallyEdited = false;
  RentalPaymentStatus _paymentStatus = RentalPaymentStatus.unpaid;
  String? _costumeError;
  String? _dateError;
  String? _dpError;
  bool _userEdited = false;

  /// True when the user made at least one manual edit that is not yet saved.
  ///
  /// Auto-filled values (Smart Paste pre-fill, customer auto-match, auto-price)
  /// are deliberately excluded: only genuine user input flips this flag.
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

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null);
    _phoneController.addListener(_onPhoneChanged);

    final prefill = widget.initialParsedData;
    if (prefill != null) {
      // Pre-fill text fields from Smart Paste parse result.
      if (prefill.fullName != null) {
        _nameController.text = prefill.fullName!;
      }
      final parsedPhone = prefill.normalizedPhone ?? prefill.phone;
      if (parsedPhone != null) {
        _phoneController.text = parsedPhone;
      }
      if (prefill.address != null) {
        _addressController.text = prefill.address!;
      }
      if (prefill.parentPhone != null) {
        _parentPhoneController.text = prefill.parentPhone!;
      }
      if (prefill.socialMedia != null) {
        _socialMediaController.text = prefill.socialMedia!;
      }
      if (prefill.startDate != null) {
        _startDate = prefill.startDate!;
      }
      if (prefill.endDate != null) {
        _endDate = prefill.endDate!;
      } else if (prefill.startDate != null) {
        _endDate = _startDate.add(const Duration(days: 2));
      }
      if (prefill.purpose != null) {
        final p = prefill.purpose!.toLowerCase();
        if (p.contains('homecos') ||
            p.contains('home') ||
            p.contains('pakai sendiri')) {
          _purpose = 'homecos';
        } else if (p.contains('photo') || p.contains('ses')) {
          _purpose = 'photoshoot';
        } else if (p.contains('event') || p.contains('acar')) {
          _purpose = 'event';
        } else {
          _purpose = 'lainnya';
        }
      }
    } else if (widget.initialDate != null) {
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
    _phoneController.removeListener(_onPhoneChanged);
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _parentPhoneController.dispose();
    _socialMediaController.dispose();
    _totalPriceController.dispose();
    _dpAmountController.dispose();
    super.dispose();
  }

  static String sanitizePhone(String input) {
    var cleaned = input.trim().replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.startsWith('+62')) {
      cleaned = '0${cleaned.substring(3)}';
    } else if (cleaned.startsWith('62')) {
      cleaned = '0${cleaned.substring(2)}';
    } else if (cleaned.startsWith('+')) {
      cleaned = cleaned.substring(1);
    }
    return cleaned.replaceAll('+', '');
  }

  void _onPhoneChanged() {
    _matchExistingCustomer();
  }

  void _matchExistingCustomer() {
    final rawPhone = sanitizePhone(_phoneController.text).replaceAll(RegExp(r'\D'), '');
    if (rawPhone.length < 8) return;

    Customer? match;
    for (final c in _existingCustomers) {
      final cDigits = c.phone.replaceAll(RegExp(r'\D'), '');
      if (cDigits.isNotEmpty && (cDigits == rawPhone || cDigits.endsWith(rawPhone) || rawPhone.endsWith(cDigits))) {
        match = c;
        break;
      }
    }

    if (match != null) {
      if (_nameController.text.trim().isEmpty && match.fullName.isNotEmpty) {
        _nameController.text = match.fullName;
      }
      if (_addressController.text.trim().isEmpty && match.address.isNotEmpty && match.address != '-') {
        _addressController.text = match.address;
      }
      if (_parentPhoneController.text.trim().isEmpty && match.parentPhone != null && match.parentPhone!.isNotEmpty) {
        _parentPhoneController.text = match.parentPhone!;
      }
      if (_socialMediaController.text.trim().isEmpty && match.socialMedia != null && match.socialMedia!.isNotEmpty) {
        _socialMediaController.text = match.socialMedia!;
      }
      if (_ktpPhotoPath == null && match.ktpPhotoUrl != null && match.ktpPhotoUrl!.isNotEmpty) {
        setState(() => _ktpPhotoPath = match!.ktpPhotoUrl);
      }
      if (_selfieKtpPath == null && match.selfieKtpUrl != null && match.selfieKtpUrl!.isNotEmpty) {
        setState(() => _selfieKtpPath = match!.selfieKtpUrl);
      }
    }
  }

  Future<void> _loadCostumes() async {
    final list = await widget.costumeRepository.getAllCostumes();
    final customers = await widget.rentalRepository.getAllCustomers();
    if (mounted) {
      setState(() {
        _costumes = list;
        _existingCustomers = customers;
        _isLoadingCostumes = false;

        _matchExistingCustomer();

        // Try to match parsed costume name to a Costume in the catalogue.
        final wanted = widget.initialParsedData?.costumeName;
        if (wanted != null && wanted.isNotEmpty && _selectedCostume == null) {
          final needle = wanted.toLowerCase().replaceAll('_', ' ').replaceAll('-', ' ').trim();
          Costume? match;
          for (final c in _costumes) {
            final n = c.name.toLowerCase().replaceAll('_', ' ').replaceAll('-', ' ').trim();
            if (n == needle || n.contains(needle) || needle.contains(n)) {
              match = c;
              break;
            }
          }
          _selectedCostume = match;
          if (_selectedCostume != null) {
            _syncPriceWithDates();
          }
        }
      });
    }
  }

  Future<void> _pickImage(ImageSource source, bool isKtp) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (picked != null && mounted) {
        _markEdited();
        setState(() {
          if (isKtp) {
            _ktpPhotoPath = picked.path;
          } else {
            _selfieKtpPath = picked.path;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        IosToast.show(
          context,
          'Gagal mengambil foto. Periksa izin perangkat.',
          icon: CupertinoIcons.exclamationmark_circle_fill,
          iconColor: AppColors.warningOrange,
        );
      }
    }
  }

  void _showImagePickerActionSheet(bool isKtp) {
    PhotoSourcePickerSheet.show(
      context: context,
      title: isKtp ? 'Foto KTP / KIA' : 'Foto Selfie + KTP',
      onCamera: () => _pickImage(ImageSource.camera, isKtp),
      onGallery: () => _pickImage(ImageSource.gallery, isKtp),
    );
  }

  double get _totalPrice {
    final raw = _totalPriceController.text.replaceAll('.', '').replaceAll(',', '').trim();
    return double.tryParse(raw) ?? 0.0;
  }

  double get _dpAmount {
    final raw = _dpAmountController.text.replaceAll('.', '').replaceAll(',', '').trim();
    return double.tryParse(raw) ?? 0.0;
  }

  double get _remainingBalance => (_totalPrice - _dpAmount).clamp(0.0, double.infinity);

  int get _durationDays => _endDate.difference(_startDate).inDays + 1;

  double? get _recommendedPrice {
    if (_selectedCostume == null || _selectedCostume!.rentPrice3Days <= 0) {
      return null;
    }
    final basePrice = _selectedCostume!.rentPrice3Days;
    if (_durationDays <= 3) {
      return basePrice;
    }
    final extraDays = _durationDays - 3;
    final dailyRate = basePrice / 3.0;
    return basePrice + (extraDays * dailyRate);
  }

  void _syncPriceWithDates({bool force = false}) {
    if (_selectedCostume == null || _selectedCostume!.rentPrice3Days <= 0) return;
    if (force || !_isPriceManuallyEdited || _totalPriceController.text.isEmpty || _totalPriceController.text == '0') {
      final rec = _recommendedPrice;
      if (rec != null) {
        _totalPriceController.text = rec.round().toString();
      }
    }
  }

  String _formatCurrency(double amount) {
    final parts = amount.round().toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
    return 'Rp $parts';
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

  // Picker callbacks. These still call setState on the parent so the
  // date/costume/purpose value can be re-read by the rest of the form,
  // but the heavy work (CupertinoPicker / CupertinoDatePicker scroll
  // controllers, picker child widgets) is owned by the InlinePickerRow
  // State, which is preserved across rebuilds.
  bool _validate() {
    final okName = _nameController.text.trim().isNotEmpty;
    final rawPhone = sanitizePhone(_phoneController.text);
    final okPhone = rawPhone.length >= 8 && rawPhone.length <= 15;
    final okCostume = _selectedCostume != null;
    final okDate = !_endDate.isBefore(_startDate);
    final rawPrice = _totalPriceController.text.replaceAll('.', '').replaceAll(',', '').trim();
    final parsedPrice = double.tryParse(rawPrice);
    final okPrice = parsedPrice != null && parsedPrice > 0;

    String? dpErr;
    if (_paymentStatus == RentalPaymentStatus.dpPaid) {
      final rawDp = _dpAmountController.text.replaceAll('.', '').replaceAll(',', '').trim();
      final parsedDp = double.tryParse(rawDp);
      if (parsedDp == null || parsedDp <= 0) {
        dpErr = 'Nominal DP wajib diisi (minimal Rp 1.000)';
      } else if (okPrice && parsedDp >= parsedPrice) {
        dpErr = 'Nominal DP harus lebih kecil dari total harga (gunakan status Lunas)';
      }
    }

    setState(() {
      _costumeError = okCostume ? null : 'Pilih kostum terlebih dahulu';
      _dateError = okDate ? null : 'Tanggal selesai harus setelah tanggal mulai';
      _dpError = dpErr;
    });
    if (!okName) {
      _showErrorSnack('Nama penyewa wajib diisi');
      return false;
    }
    if (_phoneController.text.trim().isEmpty) {
      _showErrorSnack('Nomor telepon wajib diisi');
      return false;
    }
    if (!okPhone) {
      _showErrorSnack('Nomor telepon tidak valid (minimal 8 digit)');
      return false;
    }
    if (_parentPhoneController.text.trim().isNotEmpty) {
      final parentDigits = sanitizePhone(_parentPhoneController.text);
      if (parentDigits.length < 8 || parentDigits.length > 15) {
        _showErrorSnack('Nomor HP orang tua tidak valid (minimal 8 digit)');
        return false;
      }
    }
    if (!okCostume) {
      _showErrorSnack('Pilih kostum yang akan disewa');
      return false;
    }
    if (!okDate) {
      _showErrorSnack('Tanggal selesai harus setelah tanggal mulai');
      return false;
    }
    if (!okPrice) {
      _showErrorSnack('Total harga sewa wajib diisi (minimal Rp 1.000)');
      return false;
    }
    if (dpErr != null) {
      _showErrorSnack(dpErr);
      return false;
    }
    return true;
  }

  Future<void> _save() async {
    if (!_validate()) return;
    setState(() => _isSaving = true);

    try {
      final parsedCandidateTotal = double.tryParse(_totalPriceController.text.replaceAll('.', '').replaceAll(',', '')) ?? 0.0;
      final candidate = Rental(
        id: 'temp_candidate',
        costumeId: _selectedCostume!.id,
        customerId: 'temp_customer',
        startDate: _startDate,
        endDate: _endDate,
        durationDays: _endDate.difference(_startDate).inDays + 1,
        purpose: _purpose,
        totalPrice: parsedCandidateTotal,
        dpAmount: _paymentStatus == RentalPaymentStatus.dpPaid
            ? (double.tryParse(_dpAmountController.text.replaceAll('.', '').replaceAll(',', '')) ?? 0.0)
            : (_paymentStatus == RentalPaymentStatus.paid ? parsedCandidateTotal : 0.0),
        paymentStatus: _paymentStatus,
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

      final rawPhone = sanitizePhone(_phoneController.text.trim());
      Customer? existingCustomer;
      for (final c in _existingCustomers) {
        final cDigits = sanitizePhone(c.phone).replaceAll(RegExp(r'\D'), '');
        if (cDigits.isNotEmpty && (cDigits == rawPhone || cDigits.endsWith(rawPhone) || rawPhone.endsWith(cDigits))) {
          existingCustomer = c;
          break;
        }
      }

      final custId = existingCustomer?.id ?? 'cust_${DateTime.now().millisecondsSinceEpoch}';
      final cleanPhone = sanitizePhone(_phoneController.text.trim());
      final cleanParentPhone = _parentPhoneController.text.trim().isEmpty
          ? existingCustomer?.parentPhone
          : sanitizePhone(_parentPhoneController.text.trim());
      final rawSocial = _socialMediaController.text.replaceAll('@', '').trim();
      final customer = Customer(
        id: custId,
        fullName: _nameController.text.trim(),
        phone: cleanPhone,
        address: _addressController.text.trim().isEmpty
            ? (existingCustomer?.address.isNotEmpty == true ? existingCustomer!.address : '-')
            : _addressController.text.trim(),
        parentPhone: cleanParentPhone,
        socialMedia: rawSocial.isEmpty
            ? existingCustomer?.socialMedia
            : rawSocial,
        ktpPhotoUrl: _ktpPhotoPath ?? existingCustomer?.ktpPhotoUrl,
        selfieKtpUrl: _selfieKtpPath ?? existingCustomer?.selfieKtpUrl,
      );

      if (existingCustomer != null) {
        await widget.rentalRepository.updateCustomer(customer);
      } else {
        await widget.rentalRepository.insertCustomer(customer);
      }

      final cleanTotalPrice = double.tryParse(_totalPriceController.text.replaceAll('.', '').replaceAll(',', '')) ?? 0.0;
      final cleanDpAmount = _paymentStatus == RentalPaymentStatus.dpPaid
          ? (double.tryParse(_dpAmountController.text.replaceAll('.', '').replaceAll(',', '')) ?? 0.0)
          : (_paymentStatus == RentalPaymentStatus.paid ? cleanTotalPrice : 0.0);

      final rentalId = 'rent_${DateTime.now().millisecondsSinceEpoch}';
      final rental = Rental(
        id: rentalId,
        costumeId: _selectedCostume!.id,
        customerId: custId,
        startDate: _startDate,
        endDate: _endDate,
        durationDays: _endDate.difference(_startDate).inDays + 1,
        purpose: _purpose,
        totalPrice: cleanTotalPrice,
        dpAmount: cleanDpAmount,
        itemStatus: RentalItemStatus.booked,
        paymentStatus: _paymentStatus,
      );
      await widget.rentalRepository.insertRental(rental);

      if (mounted) {
        setState(() => _isSaving = false);
        _showSuccessSnack();
        widget.onBookingAdded();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        _showErrorSnack('Gagal menyimpan: $e');
      }
    }
  }

  Future<bool?> _showConflictDialog(List<Rental> conflicts) async {
    final conflictDetails = conflicts.map((c) {
      String name = 'Penyewa';
      for (final cust in _existingCustomers) {
        if (cust.id == c.customerId) {
          name = cust.fullName;
          break;
        }
      }
      if (name == 'Penyewa') {
        name = c.customerId.replaceAll('_', ' ');
      } else {
        name = name.replaceAll('_', ' ');
      }
      final start = '${c.startDate.day}/${c.startDate.month}';
      final end = '${c.endDate.day}/${c.endDate.month}';
      return '• $name ($start - $end)';
    }).join('\n');

    return showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Konflik Jadwal Sewa'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'Kostum ini sudah memiliki jadwal sewa pada rentang tanggal yang sama:\n\n$conflictDetails\n\nTetap simpan booking ini?',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
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
    IosToast.show(
      context,
      'Booking ${_selectedCostume!.name} tersimpan',
      icon: CupertinoIcons.checkmark_circle_fill,
      iconColor: AppColors.successMint,
    );
  }

  void _showErrorSnack(String msg) {
    IosToast.show(
      context,
      msg,
      icon: CupertinoIcons.exclamationmark_circle_fill,
      iconColor: AppColors.dangerRose,
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d MMM y', 'id_ID');
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
        onDismissed: () => Navigator.of(context).pop(),
        confirmDismiss: _confirmClose,
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
              onPressed: _isSaving
                  ? null
                  : () async {
                      final navigator = Navigator.of(sheetCtx);
                      if (await _confirmClose()) {
                        if (mounted) navigator.pop();
                      }
                    },
              child: const Text('Batal', style: AppTypography.actionButton),
            ),
            middle: const SizedBox(
              width: double.infinity,
              child: Center(
                child: Text('Booking Manual', style: AppTypography.navTitle),
              ),
            ),
            trailing: CupertinoButton(
              key: const Key('manual_save_booking_button'),
              padding: EdgeInsets.zero,
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const CupertinoActivityIndicator(radius: 10)
                  : const Text('Simpan', style: AppTypography.actionButton),
            ),
          ),
          child: SafeArea(
            top: false,
            child: RepaintBoundary(
              child: ListView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(0, 8, 0, bottomInset + 24),
                physics: const BouncingScrollPhysics(),
                addRepaintBoundaries: false,
              children: [
                // ====== Section 1: DATA PENYEWA ======
                RepaintBoundary(
                  child: CupertinoListSection.insetGrouped(
                  header: const Text('DATA PENYEWA'),
                  backgroundColor: AppColors.background,
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  children: [
                    CupertinoListTile(
                      leading: const SquircleIcon(
                        icon: CupertinoIcons.person_fill,
                        color: AppColors.primaryPink,
                      ),
                      title: CupertinoTextField(
                        key: const Key('manual_name_input'),
                        controller: _nameController,
                        placeholder: 'Nama asli / nama di paket',
                        placeholderStyle: const TextStyle(color: AppColors.placeholderText, fontSize: 15),
                        style: const TextStyle(fontSize: 15, color: AppColors.textDark),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: null,
                        textInputAction: TextInputAction.next,
                        onChanged: (_) => _markEdited(),
                      ),
                    ),
                    CupertinoListTile(
                      leading: const SquircleIcon(
                        icon: CupertinoIcons.phone_fill,
                        color: Color(0xFF5856D6),
                      ),
                      title: CupertinoTextField(
                        key: const Key('manual_phone_input'),
                        controller: _phoneController,
                        placeholder: 'Nomor Telepon / HP (cth: 081234567890)',
                        placeholderStyle: const TextStyle(color: AppColors.placeholderText, fontSize: 15),
                        style: const TextStyle(fontSize: 15, color: AppColors.textDark),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: null,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[\d+\-\s]')),
                        ],
                        textInputAction: TextInputAction.next,
                        onChanged: (_) => _markEdited(),
                      ),
                    ),
                    CupertinoListTile(
                      leading: const SquircleIcon(
                        icon: CupertinoIcons.location_solid,
                        color: Color(0xFFFF9500),
                      ),
                      title: CupertinoTextField(
                        key: const Key('manual_address_input'),
                        controller: _addressController,
                        placeholder: 'Alamat lengkap',
                        placeholderStyle: const TextStyle(color: AppColors.placeholderText, fontSize: 15),
                        style: const TextStyle(fontSize: 15, color: AppColors.textDark),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: null,
                        maxLines: 3,
                        minLines: 1,
                        textInputAction: TextInputAction.next,
                        onChanged: (_) => _markEdited(),
                      ),
                    ),
                    CupertinoListTile(
                      leading: const SquircleIcon(
                        icon: CupertinoIcons.person_2_fill,
                        color: Color(0xFF34C759),
                      ),
                      title: CupertinoTextField(
                        key: const Key('manual_parent_phone_input'),
                        controller: _parentPhoneController,
                        placeholder: 'No HP ortu / keluarga terdekat',
                        placeholderStyle: const TextStyle(color: AppColors.placeholderText, fontSize: 15),
                        style: const TextStyle(fontSize: 15, color: AppColors.textDark),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: null,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[\d+\-\s]')),
                        ],
                        textInputAction: TextInputAction.next,
                        onChanged: (_) => _markEdited(),
                      ),
                    ),
                    CupertinoListTile(
                      leading: const SquircleIcon(
                        icon: CupertinoIcons.link,
                        color: Color(0xFFFF2D55),
                      ),
                      title: CupertinoTextField(
                        key: const Key('manual_social_input'),
                        controller: _socialMediaController,
                        placeholder: 'Akun Instagram (cth: @username)',
                        placeholderStyle: const TextStyle(color: AppColors.placeholderText, fontSize: 15),
                        style: const TextStyle(fontSize: 15, color: AppColors.textDark),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: null,
                        textInputAction: TextInputAction.done,
                        onChanged: (_) => _markEdited(),
                      ),
                    ),
                  ],
                ),
                ),

                // ====== Section 2: DOKUMEN IDENTITAS ======
                RepaintBoundary(
                  child: CupertinoListSection.insetGrouped(
                  header: const Text('DOKUMEN IDENTITAS'),
                  backgroundColor: AppColors.background,
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  children: [
                    CupertinoListTile(
                      key: const Key('manual_ktp_photo_row'),
                      leading: const SquircleIcon(
                        icon: CupertinoIcons.creditcard_fill,
                        color: Color(0xFFFF3B30),
                      ),
                      title: const Text(
                        'Foto KTP / KIA',
                        style: TextStyle(fontSize: 15, color: AppColors.textDark),
                      ),
                      additionalInfo: Text(
                        _ktpPhotoPath != null && File(_ktpPhotoPath!).existsSync()
                            ? 'Terlampir'
                            : 'Pilih foto',
                        style: TextStyle(
                          fontSize: 15,
                          color: _ktpPhotoPath != null && File(_ktpPhotoPath!).existsSync()
                              ? AppColors.deepPinkText
                              : AppColors.textSecondary,
                        ),
                      ),
                      trailing: _ktpPhotoPath != null && File(_ktpPhotoPath!).existsSync()
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.file(
                                File(_ktpPhotoPath!),
                                width: 24,
                                height: 24,
                                fit: BoxFit.cover,
                                cacheWidth: 400,
                                cacheHeight: 400,
                              ),
                            )
                          : const Icon(
                              CupertinoIcons.chevron_right,
                              size: 14,
                              color: AppColors.placeholderText,
                            ),
                      onTap: () => _showImagePickerActionSheet(true),
                    ),
                    CupertinoListTile(
                      key: const Key('manual_selfie_ktp_row'),
                      leading: const SquircleIcon(
                        icon: CupertinoIcons.camera_viewfinder,
                        color: Color(0xFF5856D6),
                      ),
                      title: const Text(
                        'Selfie memegang KTP',
                        style: TextStyle(fontSize: 15, color: AppColors.textDark),
                      ),
                      additionalInfo: Text(
                        _selfieKtpPath != null && File(_selfieKtpPath!).existsSync()
                            ? 'Terlampir'
                            : 'Pilih foto',
                        style: TextStyle(
                          fontSize: 15,
                          color: _selfieKtpPath != null && File(_selfieKtpPath!).existsSync()
                              ? AppColors.deepPinkText
                              : AppColors.textSecondary,
                        ),
                      ),
                      trailing: _selfieKtpPath != null && File(_selfieKtpPath!).existsSync()
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.file(
                                File(_selfieKtpPath!),
                                width: 24,
                                height: 24,
                                fit: BoxFit.cover,
                                cacheWidth: 400,
                                cacheHeight: 400,
                              ),
                            )
                          : const Icon(
                              CupertinoIcons.chevron_right,
                              size: 14,
                              color: AppColors.placeholderText,
                            ),
                      onTap: () => _showImagePickerActionSheet(false),
                    ),
                  ],
                ),
                ),

                // ====== Section 3: KOSTUM & JADWAL ======
                RepaintBoundary(
                  child: CupertinoListSection.insetGrouped(
                  header: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('KOSTUM & JADWAL'),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _durationDays > 3 ? const Color(0xFFFFF3E0) : AppColors.softPinkBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _durationDays > 3
                              ? '$_durationDays hari sewa (+${_durationDays - 3} hari)'
                              : '$_durationDays hari sewa',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _durationDays > 3 ? AppColors.warningOrange : AppColors.deepPinkText,
                          ),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: AppColors.background,
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  children: [
                    CupertinoListTile(
                      key: const Key('manual_costume_row'),
                      leading: const SquircleIcon(
                        icon: CupertinoIcons.bag_fill,
                        color: Color(0xFFFF85A1),
                      ),
                      title: const Text(
                        'Kostum',
                        style: TextStyle(fontSize: 15, color: AppColors.textDark),
                      ),
                      additionalInfo: Text(
                        _isLoadingCostumes
                            ? 'Memuat...'
                            : (_selectedCostume != null
                                ? '${_selectedCostume!.name.replaceAll('_', ' ')} (${_selectedCostume!.size})'
                                : 'Pilih kostum'),
                        style: TextStyle(
                          fontSize: 15,
                          color: _selectedCostume != null
                              ? AppColors.textDark
                              : AppColors.textSecondary,
                        ),
                      ),
                      subtitle: _costumeError == null
                          ? null
                          : Text(_costumeError!,
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.dangerRose)),
                      trailing: const Icon(
                        CupertinoIcons.chevron_right,
                        size: 14,
                        color: AppColors.placeholderText,
                      ),
                      onTap: _isLoadingCostumes || _costumes.isEmpty
                          ? null
                          : () async {
                              final hadFocus = FocusScope.of(context).hasFocus;
                              if (hadFocus) {
                                FocusScope.of(context).unfocus();
                                await Future<void>.delayed(const Duration(milliseconds: 150));
                              }
                              if (!mounted || !context.mounted) return;
                              final id = await showSheetPicker<String>(
                                context: context,
                                title: 'Pilih Kostum',
                                currentValue: _selectedCostume?.id ?? '',
                                items: _costumes
                                    .map((c) => SheetPickerItem<String>(
                                          c.id,
                                          '${c.name} (${c.size})',
                                        ))
                                    .toList(growable: false),
                              );
                              if (id != null) {
                                final c = _costumes.firstWhere(
                                  (x) => x.id == id,
                                  orElse: () => _costumes.first,
                                );
                                _markEdited();
                                setState(() {
                                  _selectedCostume = c;
                                  _costumeError = null;
                                  _syncPriceWithDates();
                                });
                              }
                            },
                    ),
                    CupertinoListTile(
                      key: const Key('manual_start_date_row'),
                      leading: const SquircleIcon(
                        icon: CupertinoIcons.calendar,
                        color: Color(0xFFFF9500),
                      ),
                      title: const Text(
                        'Tanggal Mulai',
                        style: TextStyle(fontSize: 15, color: AppColors.textDark),
                      ),
                      additionalInfo: Text(
                        dateFormat.format(_startDate),
                        style: const TextStyle(fontSize: 15, color: AppColors.textDark),
                      ),
                      trailing: const Icon(
                        CupertinoIcons.chevron_right,
                        size: 14,
                        color: AppColors.placeholderText,
                      ),
                      onTap: () async {
                        final hadFocus = FocusScope.of(context).hasFocus;
                        if (hadFocus) {
                          FocusScope.of(context).unfocus();
                          await Future<void>.delayed(const Duration(milliseconds: 150));
                        }
                        if (!mounted || !context.mounted) return;
                        final d = await showSheetDatePicker(
                          context: context,
                          title: 'Tanggal Mulai',
                          initialDate: _startDate,
                          minimumDate: DateTime(2020),
                        );
                        if (d != null) {
                          _markEdited();
                          setState(() {
                            _startDate = d;
                            if (_endDate.isBefore(_startDate)) {
                              _endDate = _startDate.add(const Duration(days: 3));
                            }
                            _dateError = null;
                            _syncPriceWithDates();
                          });
                        }
                      },
                    ),
                    CupertinoListTile(
                      key: const Key('manual_end_date_row'),
                      leading: const SquircleIcon(
                        icon: CupertinoIcons.calendar_badge_minus,
                        color: Color(0xFFFF3B30),
                      ),
                      title: const Text(
                        'Tanggal Selesai',
                        style: TextStyle(fontSize: 15, color: AppColors.textDark),
                      ),
                      additionalInfo: Text(
                        dateFormat.format(_endDate),
                        style: TextStyle(
                          fontSize: 15,
                          color: _dateError != null
                              ? AppColors.dangerRose
                              : AppColors.textDark,
                        ),
                      ),
                      subtitle: _dateError == null
                          ? null
                          : Text(_dateError!,
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.dangerRose)),
                      trailing: const Icon(
                        CupertinoIcons.chevron_right,
                        size: 14,
                        color: AppColors.placeholderText,
                      ),
                      onTap: () async {
                        final hadFocus = FocusScope.of(context).hasFocus;
                        if (hadFocus) {
                          FocusScope.of(context).unfocus();
                          await Future<void>.delayed(const Duration(milliseconds: 150));
                        }
                        if (!mounted || !context.mounted) return;
                        final d = await showSheetDatePicker(
                          context: context,
                          title: 'Tanggal Selesai',
                          initialDate: _endDate,
                          minimumDate: _startDate,
                        );
                        if (d != null) {
                          _markEdited();
                          setState(() {
                            _endDate = d;
                            _dateError = null;
                            _syncPriceWithDates();
                          });
                        }
                      },
                    ),
                    CupertinoListTile(
                      key: const Key('manual_purpose_row'),
                      leading: const SquircleIcon(
                        icon: CupertinoIcons.tag_fill,
                        color: Color(0xFF5856D6),
                      ),
                      title: const Text(
                        'Keperluan',
                        style: TextStyle(fontSize: 15, color: AppColors.textDark),
                      ),
                      additionalInfo: Text(
                        _purposeLabel,
                        style: const TextStyle(fontSize: 15, color: AppColors.textDark),
                      ),
                      trailing: const Icon(
                        CupertinoIcons.chevron_right,
                        size: 14,
                        color: AppColors.placeholderText,
                      ),
                      onTap: () async {
                        final hadFocus = FocusScope.of(context).hasFocus;
                        if (hadFocus) {
                          FocusScope.of(context).unfocus();
                          await Future<void>.delayed(const Duration(milliseconds: 150));
                        }
                        if (!mounted || !context.mounted) return;
                        const items = [
                          SheetPickerItem('homecos', 'Homecos (Pakai Sendiri)'),
                          SheetPickerItem('event', 'Event Cosplay'),
                          SheetPickerItem('photoshoot', 'Photoshoot'),
                          SheetPickerItem('lainnya', 'Lainnya'),
                        ];
                        final key = await showSheetPicker<String>(
                          context: context,
                          title: 'Keperluan',
                          currentValue: _purpose,
                          items: items,
                        );
                        if (key != null) {
                          _markEdited();
                          setState(() => _purpose = key);
                        }
                      },
                    ),
                  ],
                ),
                ),

                // ====== Section 4: PEMBAYARAN ======
                RepaintBoundary(
                  child: CupertinoListSection.insetGrouped(
                  header: const Text('PEMBAYARAN'),
                  backgroundColor: AppColors.background,
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  children: [
                    CupertinoListTile(
                      key: const Key('manual_price_input'),
                      leading: const SquircleIcon(
                        icon: CupertinoIcons.money_dollar_circle_fill,
                        color: Color(0xFF34C759),
                      ),
                      title: CupertinoTextField(
                        key: const Key('manual_total_price_field'),
                        controller: _totalPriceController,
                        placeholder: 'Total harga sewa',
                        placeholderStyle: const TextStyle(color: AppColors.placeholderText, fontSize: 15),
                        style: const TextStyle(fontSize: 15, color: AppColors.textDark),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: null,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        onChanged: (_) {
                          _isPriceManuallyEdited = true;
                          _markEdited();
                          setState(() {});
                        },
                      ),
                    ),
                    CupertinoListTile(
                      key: const Key('manual_payment_status_row'),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: const SquircleIcon(
                        icon: CupertinoIcons.creditcard_fill,
                        color: Color(0xFF5856D6),
                      ),
                      title: AppleSlidingSegmentedControl<RentalPaymentStatus>(
                        key: const Key('manual_payment_status_control'),
                        groupValue: _paymentStatus,
                        height: 36,
                        items: const [
                          SegmentItem(
                            key: Key('payment_status_unpaid'),
                            value: RentalPaymentStatus.unpaid,
                            label: 'Belum Bayar',
                          ),
                          SegmentItem(
                            key: Key('payment_status_dp'),
                            value: RentalPaymentStatus.dpPaid,
                            label: 'DP',
                          ),
                          SegmentItem(
                            key: Key('payment_status_paid'),
                            value: RentalPaymentStatus.paid,
                            label: 'Lunas',
                          ),
                        ],
                        onValueChanged: (val) {
                          HapticFeedback.selectionClick();
                          _markEdited();
                          setState(() {
                            _paymentStatus = val;
                            if (val != RentalPaymentStatus.dpPaid) {
                              _dpError = null;
                            }
                          });
                        },
                      ),
                    ),
                    if (_paymentStatus == RentalPaymentStatus.dpPaid) ...[
                      CupertinoListTile(
                        key: const Key('manual_dp_input'),
                        leading: const SquircleIcon(
                          icon: CupertinoIcons.arrow_down_circle_fill,
                          color: Color(0xFFFF9500),
                        ),
                        title: CupertinoTextField(
                          key: const Key('manual_dp_amount_field'),
                          controller: _dpAmountController,
                          placeholder: 'Nominal DP (Rp)',
                          placeholderStyle: const TextStyle(color: AppColors.placeholderText, fontSize: 15),
                          style: const TextStyle(fontSize: 15, color: AppColors.textDark),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: null,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          onChanged: (_) {
                            _markEdited();
                            setState(() {
                              _dpError = null;
                            });
                          },
                        ),
                        subtitle: _dpError == null
                            ? null
                            : Text(
                                _dpError!,
                                style: const TextStyle(fontSize: 12, color: AppColors.dangerRose),
                              ),
                      ),
                      CupertinoListTile(
                        key: const Key('manual_remaining_balance_tile'),
                        leading: const SquircleIcon(
                          icon: CupertinoIcons.hourglass,
                          color: AppColors.dangerRose,
                        ),
                        title: const Text(
                          'Sisa Tagihan Pelunasan',
                          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15, color: AppColors.textDark),
                        ),
                        subtitle: const Text(
                          'Perlu dilunasi saat serah terima kostum',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        trailing: Text(
                          _formatCurrency(_remainingBalance),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: AppColors.dangerRose,
                          ),
                        ),
                      ),
                    ],
                    if (_selectedCostume != null && _selectedCostume!.rentPrice3Days > 0) ...[
                      if (_durationDays > 3)
                        CupertinoListTile(
                          key: const Key('manual_extended_duration_hint'),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          leading: const SquircleIcon(
                            icon: CupertinoIcons.info_circle_fill,
                            color: AppColors.warningOrange,
                          ),
                          title: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Durasi $_durationDays Hari (+${_durationDays - 3} hari tambahan)',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textDark,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Tarif dasar 3 hari: ${_formatCurrency(_selectedCostume!.rentPrice3Days)} • Hari tambahan (+${_durationDays - 3} hari): ${_formatCurrency((_selectedCostume!.rentPrice3Days / 3.0) * (_durationDays - 3))} (${_formatCurrency(_selectedCostume!.rentPrice3Days / 3.0)}/hari)',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  height: 1.25,
                                ),
                              ),
                              if (_recommendedPrice != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Text(
                                      'Rekomendasi Total: ',
                                      style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                                    ),
                                    Text(
                                      _formatCurrency(_recommendedPrice!),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.deepPinkText,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                          trailing: _isPriceManuallyEdited
                              ? CupertinoButton(
                                  key: const Key('manual_apply_recommended_price_btn'),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  minimumSize: const Size(44, 32),
                                  color: AppColors.softPinkBg,
                                  borderRadius: BorderRadius.circular(8),
                                  onPressed: () {
                                    HapticFeedback.selectionClick();
                                    setState(() {
                                      _isPriceManuallyEdited = false;
                                      _syncPriceWithDates(force: true);
                                    });
                                  },
                                  child: const Text(
                                    'Pakai',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.deepPinkText,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                    ],
                  ],
                ),
                ),
              ],
            ),
            ),
          ),
        ),
      ),
    ),
    );
  }
}
