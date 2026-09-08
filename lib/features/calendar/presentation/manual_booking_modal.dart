import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/draggable_sheet_container.dart';
import '../../../core/widgets/sheet_picker.dart';
import '../../../core/widgets/squircle_icon.dart';
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

  final ImagePicker _picker = ImagePicker();
  String? _ktpPhotoPath;
  String? _selfieKtpPath;

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
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _parentPhoneController.dispose();
    _socialMediaController.dispose();
    _totalPriceController.dispose();
    super.dispose();
  }

  Future<void> _loadCostumes() async {
    final list = await widget.costumeRepository.getAllCostumes();
    if (mounted) {
      setState(() {
        _costumes = list;
        _isLoadingCostumes = false;

        // Try to match parsed costume name to a Costume in the catalogue.
        final wanted = widget.initialParsedData?.costumeName;
        if (wanted != null && wanted.isNotEmpty && _selectedCostume == null) {
          final needle = wanted.toLowerCase().trim();
          Costume? match;
          for (final c in _costumes) {
            final n = c.name.toLowerCase().trim();
            if (n == needle || n.contains(needle) || needle.contains(n)) {
              match = c;
              break;
            }
          }
          _selectedCostume = match;
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
        setState(() {
          if (isKtp) {
            _ktpPhotoPath = picked.path;
          } else {
            _selfieKtpPath = picked.path;
          }
        });
      }
    } catch (_) {}
  }

  void _showImagePickerActionSheet(bool isKtp) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(isKtp ? 'Pilih Foto KTP / KIA' : 'Pilih Foto Selfie + KTP'),
        message: Text(
          isKtp
              ? 'Ambil foto langsung atau pilih dari galeri'
              : 'Selfie sambil pegang kartu identitas',
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _pickImage(ImageSource.camera, isKtp);
            },
            child: const Text('Ambil dari Kamera'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _pickImage(ImageSource.gallery, isKtp);
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
        address: _addressController.text.trim().isEmpty
            ? '-'
            : _addressController.text.trim(),
        parentPhone: _parentPhoneController.text.trim().isEmpty
            ? null
            : _parentPhoneController.text.trim(),
        socialMedia: _socialMediaController.text.trim().isEmpty
            ? null
            : _socialMediaController.text.trim(),
        ktpPhotoUrl: _ktpPhotoPath,
        selfieKtpUrl: _selfieKtpPath,
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
    final dateFormat = DateFormat('d MMM y', 'id_ID');
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
            child: RepaintBoundary(
              child: ListView(
                padding: EdgeInsets.fromLTRB(0, 8, 0, bottomInset + 24),
                physics: const BouncingScrollPhysics(),
              children: [
                // ====== Section 1: DATA PENYEWA ======
                CupertinoListSection.insetGrouped(
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
                        placeholderStyle: const TextStyle(color: Color(0xFFC7C7CC), fontSize: 15),
                        style: const TextStyle(fontSize: 15, color: AppColors.textDark),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: null,
                        textInputAction: TextInputAction.next,
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
                        placeholder: 'No HP / WhatsApp',
                        placeholderStyle: const TextStyle(color: Color(0xFFC7C7CC), fontSize: 15),
                        style: const TextStyle(fontSize: 15, color: AppColors.textDark),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: null,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
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
                        placeholderStyle: const TextStyle(color: Color(0xFFC7C7CC), fontSize: 15),
                        style: const TextStyle(fontSize: 15, color: AppColors.textDark),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: null,
                        maxLines: 3,
                        minLines: 1,
                        textInputAction: TextInputAction.next,
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
                        placeholderStyle: const TextStyle(color: Color(0xFFC7C7CC), fontSize: 15),
                        style: const TextStyle(fontSize: 15, color: AppColors.textDark),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: null,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
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
                        placeholder: 'Akun sosmed (TikTok / IG)',
                        placeholderStyle: const TextStyle(color: Color(0xFFC7C7CC), fontSize: 15),
                        style: const TextStyle(fontSize: 15, color: AppColors.textDark),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: null,
                        textInputAction: TextInputAction.done,
                      ),
                    ),
                  ],
                ),

                // ====== Section 2: DOKUMEN IDENTITAS ======
                CupertinoListSection.insetGrouped(
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
                              ? AppColors.primaryPink
                              : const Color(0xFF8E8E93),
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
                              ),
                            )
                          : const Icon(
                              CupertinoIcons.chevron_right,
                              size: 14,
                              color: Color(0xFFC7C7CC),
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
                              ? AppColors.primaryPink
                              : const Color(0xFF8E8E93),
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
                              ),
                            )
                          : const Icon(
                              CupertinoIcons.chevron_right,
                              size: 14,
                              color: Color(0xFFC7C7CC),
                            ),
                      onTap: () => _showImagePickerActionSheet(false),
                    ),
                  ],
                ),

                // ====== Section 3: KOSTUM & JADWAL ======
                CupertinoListSection.insetGrouped(
                  header: const Text('KOSTUM & JADWAL'),
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
                                ? '${_selectedCostume!.name} (${_selectedCostume!.size})'
                                : 'Pilih kostum'),
                        style: TextStyle(
                          fontSize: 15,
                          color: _selectedCostume != null
                              ? AppColors.textDark
                              : const Color(0xFF8E8E93),
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
                        color: Color(0xFFC7C7CC),
                      ),
                      onTap: _isLoadingCostumes || _costumes.isEmpty
                          ? null
                          : () async {
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
                                setState(() {
                                  _selectedCostume = c;
                                  _costumeError = null;
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
                        color: Color(0xFFC7C7CC),
                      ),
                      onTap: () async {
                        final d = await showSheetDatePicker(
                          context: context,
                          title: 'Tanggal Mulai',
                          initialDate: _startDate,
                          minimumDate: DateTime(2020),
                        );
                        if (d != null) {
                          setState(() {
                            _startDate = d;
                            if (_endDate.isBefore(_startDate)) {
                              _endDate = _startDate.add(const Duration(days: 3));
                            }
                            _dateError = null;
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
                        color: Color(0xFFC7C7CC),
                      ),
                      onTap: () async {
                        final d = await showSheetDatePicker(
                          context: context,
                          title: 'Tanggal Selesai',
                          initialDate: _endDate,
                          minimumDate: _startDate,
                        );
                        if (d != null) {
                          setState(() {
                            _endDate = d;
                            _dateError = null;
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
                        color: Color(0xFFC7C7CC),
                      ),
                      onTap: () async {
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
                          setState(() => _purpose = key);
                        }
                      },
                    ),
                  ],
                ),

                // ====== Section 4: PEMBAYARAN ======
                CupertinoListSection.insetGrouped(
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
                        controller: _totalPriceController,
                        placeholder: 'Total harga (opsional)',
                        placeholderStyle: const TextStyle(color: Color(0xFFC7C7CC), fontSize: 15),
                        style: const TextStyle(fontSize: 15, color: AppColors.textDark),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: null,
                        keyboardType: TextInputType.number,
                      ),
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
