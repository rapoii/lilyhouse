import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../core/sync/sync_manager.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/draggable_sheet_container.dart';
import '../../../core/widgets/header_action_button.dart';
import '../../../core/widgets/squircle_icon.dart';
import '../../costumes/data/costume_repository.dart';
import '../../costumes/domain/costume.dart';
import '../../rentals/data/form_parser.dart';
import '../../rentals/data/rental_repository.dart';
import '../../rentals/domain/customer.dart';
import '../../rentals/domain/parsed_rental_data.dart';
import '../../rentals/domain/rental.dart';
import '../domain/booking_conflict_engine.dart';
import 'manual_booking_modal.dart';
import 'rental_detail_sheet.dart';

class CalendarScreen extends StatefulWidget {
  final IRentalRepository? rentalRepository;
  final ICostumeRepository? costumeRepository;
  final DateTime? initialFocusedDay;

  const CalendarScreen({
    super.key,
    this.rentalRepository,
    this.costumeRepository,
    this.initialFocusedDay,
  });

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late IRentalRepository _repository;
  late ICostumeRepository _costumeRepository;
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  final CalendarFormat _calendarFormat = CalendarFormat.month;

  List<Rental> _allRentals = [];
  Map<String, Customer> _customerCache = {};
  Map<String, Costume> _costumeCache = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null);
    _repository = widget.rentalRepository ?? RentalRepository();
    _costumeRepository = widget.costumeRepository ?? CostumeRepository();
    final initial = widget.initialFocusedDay ?? DateTime.now();
    _focusedDay = DateTime(initial.year, initial.month, initial.day);
    _selectedDay = _focusedDay;
    _loadData();
    SyncManager.instance.dataVersion.addListener(_onDataVersionChanged);
  }

  @override
  void dispose() {
    SyncManager.instance.dataVersion.removeListener(_onDataVersionChanged);
    super.dispose();
  }

  void _onDataVersionChanged() {
    if (mounted) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final rentals = await _repository.getAllRentals();
    final customers = await _repository.getAllCustomers();
    final costumes = await _costumeRepository.getAllCostumes();

    final cache = <String, Customer>{};
    for (final c in customers) {
      cache[c.id] = c;
    }

    final costCache = <String, Costume>{};
    for (final c in costumes) {
      costCache[c.id] = c;
    }

    if (mounted) {
      setState(() {
        _allRentals = rentals;
        _customerCache = cache;
        _costumeCache = costCache;
        _isLoading = false;
      });
    }
  }

  List<Rental> _getRentalsForDay(DateTime day) {
    final target = DateTime(day.year, day.month, day.day);
    return _allRentals.where((r) {
      if (r.itemStatus == RentalItemStatus.cancelled) return false;
      final start = DateTime(r.startDate.year, r.startDate.month, r.startDate.day);
      final end = DateTime(r.endDate.year, r.endDate.month, r.endDate.day);
      return !target.isBefore(start) && !target.isAfter(end);
    }).toList();
  }

  void _openBookingEntrySheet() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) {
        return DraggableSheetContainer(
          initialHeightFraction: 0.28,
          maxHeightFraction: 0.34,
          backgroundColor: AppColors.background,
          onDismissed: () => Navigator.of(ctx).pop(),
          builder: (sheetCtx) => DefaultTextStyle(
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
                middle: const Text('Tambah Pesanan', style: AppTypography.navTitle),
                trailing: CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => Navigator.of(sheetCtx).pop(),
                  child: const Text('Tutup', style: TextStyle(color: AppColors.primaryPink, fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
              child: SafeArea(
                top: false,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(0, 12, 0, 140),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    CupertinoListSection.insetGrouped(
                      header: const Text(
                        'PILIH METODE INPUT',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF8E8E93),
                        ),
                      ),
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      backgroundColor: Colors.transparent,
                      children: [
                        CupertinoListTile(
                          key: const Key('entry_smart_paste'),
                          leading: const SquircleIcon(
                            icon: CupertinoIcons.sparkles,
                            color: AppColors.primaryPink,
                          ),
                          title: const Text('Smart Paste', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                          subtitle: const Text(
                            'Parsing otomatis form booking WhatsApp',
                            style: TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
                          ),
                          trailing: const Icon(CupertinoIcons.chevron_right, size: 14, color: Color(0xFFC7C7CC)),
                          onTap: () {
                            Navigator.of(ctx).pop();
                            _openSmartPasteDialog();
                          },
                        ),
                        CupertinoListTile(
                          key: const Key('entry_manual'),
                          leading: const SquircleIcon(
                            icon: CupertinoIcons.square_pencil,
                            color: Color(0xFF5856D6),
                          ),
                          title: const Text('Input Manual', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                          subtitle: const Text(
                            'Ketik data pesanan satu per satu lewat form',
                            style: TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
                          ),
                          trailing: const Icon(CupertinoIcons.chevron_right, size: 14, color: Color(0xFFC7C7CC)),
                          onTap: () {
                            Navigator.of(ctx).pop();
                            _openManualBookingDialog();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _openSmartPasteDialog() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => _SmartPasteModal(
        repository: _repository,
        costumeRepository: _costumeRepository,
        parentContext: context,
        onBookingAdded: () {
          _loadData();
        },
      ),
    );
  }

  void _openManualBookingDialog() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => ManualBookingModal(
        rentalRepository: _repository,
        costumeRepository: _costumeRepository,
        initialDate: _selectedDay,
        onBookingAdded: () {
          _loadData();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedDayRentals = _getRentalsForDay(_selectedDay);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          'Kalender Rental',
          style: AppTypography.largeTitle,
        ),
        centerTitle: false,
        actions: [
          // Single Tambah button — opens entry method chooser (Smart Paste / Manual)
          HeaderActionButton(
            buttonKey: const Key('add_booking_button'),
            label: 'Tambah',
            icon: CupertinoIcons.add,
            onPressed: _openBookingEntrySheet,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CupertinoActivityIndicator(radius: 14),
            )
          : SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Calendar Card
                  Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E5EA), width: 0.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    child: TableCalendar<Rental>(
                      locale: 'id_ID',
                      firstDay: DateTime(2020, 1, 1),
                      lastDay: DateTime(2035, 12, 31),
                      focusedDay: _focusedDay,
                      currentDay: DateTime.now(),
                      calendarFormat: _calendarFormat,
                      startingDayOfWeek: StartingDayOfWeek.monday,
                      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                      eventLoader: _getRentalsForDay,
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _selectedDay = selectedDay;
                          _focusedDay = focusedDay;
                        });
                      },
                      onPageChanged: (focusedDay) {
                        _focusedDay = focusedDay;
                      },
                      headerStyle: const HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                        titleTextStyle: TextStyle(
                          color: AppColors.textDark,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        leftChevronIcon: Icon(
                          CupertinoIcons.chevron_left,
                          color: AppColors.primaryPink,
                          size: 18,
                        ),
                        rightChevronIcon: Icon(
                          CupertinoIcons.chevron_right,
                          color: AppColors.primaryPink,
                          size: 18,
                        ),
                      ),
                      calendarStyle: CalendarStyle(
                        outsideDaysVisible: false,
                        weekendTextStyle: const TextStyle(color: AppColors.primaryPink),
                        defaultTextStyle: const TextStyle(color: AppColors.textDark),
                        selectedDecoration: const BoxDecoration(
                          color: AppColors.primaryPink,
                          shape: BoxShape.circle,
                        ),
                        todayDecoration: BoxDecoration(
                          color: AppColors.softPinkBg,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.primaryPink, width: 1.5),
                        ),
                        todayTextStyle: const TextStyle(
                          color: AppColors.primaryPink,
                          fontWeight: FontWeight.bold,
                        ),
                        markerDecoration: const BoxDecoration(
                          color: AppColors.primaryPink,
                          shape: BoxShape.circle,
                        ),
                        markersMaxCount: 3,
                        markerSize: 6.0,
                        markersAlignment: Alignment.bottomCenter,
                        markerMargin: const EdgeInsets.symmetric(horizontal: 1.0),
                      ),
                    ),
                  ),

                  // Selected Day Schedule Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: AppColors.primaryPink,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(_selectedDay),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.softPinkBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${selectedDayRentals.length} Pesanan',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryPink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Rentals for day
                  if (selectedDayRentals.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: AppColors.primaryPink.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                CupertinoIcons.calendar,
                                size: 36,
                                color: AppColors.primaryPink,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Tidak ada booking',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      itemCount: selectedDayRentals.length,
                      itemBuilder: (context, index) {
                        final rental = selectedDayRentals[index];
                        final customer = _customerCache[rental.customerId];
                        final costume = _costumeCache[rental.costumeId];
                        return _RentalSlotCard(
                          rental: rental,
                          customer: customer,
                          costume: costume,
                          allRentals: _allRentals,
                          repository: _repository,
                          onRentalUpdated: _loadData,
                        );
                      },
                    ),

                  const SizedBox(height: 112),
                ],
              ),
            ),
    );
  }
}

class _RentalSlotCard extends StatelessWidget {
  final Rental rental;
  final Customer? customer;
  final Costume? costume;
  final List<Rental> allRentals;
  final IRentalRepository? repository;
  final VoidCallback? onRentalUpdated;

  const _RentalSlotCard({
    required this.rental,
    required this.customer,
    this.costume,
    required this.allRentals,
    this.repository,
    this.onRentalUpdated,
  });

  void _showRentalDetailSheet(BuildContext context, bool hasConflict) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => RentalDetailSheet(
        rental: rental,
        customer: customer,
        costume: costume,
        hasConflict: hasConflict,
        repository: repository,
        onRentalUpdated: onRentalUpdated,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d MMM');
    final dateRangeText =
        '${dateFormat.format(rental.startDate)} - ${dateFormat.format(rental.endDate)} (${rental.durationDays} hari)';

    // Check if this rental has any conflict with other rentals
    final hasConflict = BookingConflictEngine.hasConflict(allRentals, rental);

    return GestureDetector(
      onTap: () => _showRentalDetailSheet(context, hasConflict),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasConflict ? AppColors.dangerRose : AppColors.borderSubtle,
            width: hasConflict ? 1.5 : 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasConflict)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.dangerRose.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.exclamationmark_triangle_fill, size: 14, color: AppColors.dangerRose),
                    SizedBox(width: 4),
                    Text(
                      'Konflik Terdeteksi!',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.dangerRose,
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    costume?.name ?? rental.costumeId,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                _buildPaymentStatusPill(rental.paymentStatus),
              ],
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(CupertinoIcons.person, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text(
                customer?.fullName ?? rental.customerId,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(width: 12),
              const Icon(CupertinoIcons.calendar, size: 12, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text(
                dateRangeText,
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildItemStatusPill(rental.itemStatus),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  rental.purpose,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'Rp ${rental.totalPrice.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryPink,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

  Widget _buildPaymentStatusPill(RentalPaymentStatus status) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case RentalPaymentStatus.paid:
        bg = AppColors.successMint.withValues(alpha: 0.15);
        fg = const Color(0xFF289868);
        label = 'Lunas';
        break;
      case RentalPaymentStatus.dpPaid:
        bg = AppColors.warningOrange.withValues(alpha: 0.15);
        fg = const Color(0xFFD67710);
        label = 'DP Terbayar';
        break;
      case RentalPaymentStatus.unpaid:
        bg = AppColors.dangerRose.withValues(alpha: 0.12);
        fg = AppColors.dangerRose;
        label = 'Belum Bayar';
        break;
      case RentalPaymentStatus.refunded:
        bg = AppColors.textMuted.withValues(alpha: 0.15);
        fg = AppColors.textDark;
        label = 'Dikembalikan';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildItemStatusPill(RentalItemStatus status) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case RentalItemStatus.booked:
        bg = AppColors.softPinkBg;
        fg = AppColors.primaryPink;
        label = 'Dibooking';
        break;
      case RentalItemStatus.rented:
        bg = AppColors.successMint.withValues(alpha: 0.15);
        fg = const Color(0xFF289868);
        label = 'Disewa';
        break;
      case RentalItemStatus.shipped:
        bg = AppColors.pastelPink.withValues(alpha: 0.2);
        fg = AppColors.primaryPink;
        label = 'Dikirim';
        break;
      case RentalItemStatus.returned:
        bg = AppColors.softPinkBg.withValues(alpha: 0.5);
        fg = const Color(0xFF3A3A3C);
        label = 'Dikembalikan';
        break;
      case RentalItemStatus.laundry:
        bg = AppColors.pastelPink.withValues(alpha: 0.15);
        fg = const Color(0xFFC44D7B);
        label = 'Dicuci';
        break;
      case RentalItemStatus.completed:
        bg = AppColors.successMint.withValues(alpha: 0.2);
        fg = const Color(0xFF1B7A4E);
        label = 'Selesai';
        break;
      case RentalItemStatus.cancelled:
        bg = AppColors.dangerRose.withValues(alpha: 0.12);
        fg = AppColors.dangerRose;
        label = 'Dibatalkan';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SmartPasteModal extends StatefulWidget {
  final IRentalRepository repository;
  final ICostumeRepository costumeRepository;
  final BuildContext parentContext;
  final VoidCallback onBookingAdded;

  const _SmartPasteModal({
    required this.repository,
    required this.costumeRepository,
    required this.parentContext,
    required this.onBookingAdded,
  });

  @override
  State<_SmartPasteModal> createState() => _SmartPasteModalState();
}
class _SmartPasteModalState extends State<_SmartPasteModal> {
  final TextEditingController _textController = TextEditingController();
  ParsedRentalData? _parsedData;
  bool _hasConflict = false;
  List<Rental> _conflictingRentals = [];

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _handleParse() async {
    final rawText = _textController.text;
    final parsed = SmartFormParser.parse(rawText);

    bool conflict = false;
    List<Rental> conflicts = [];

    if (parsed.costumeName != null && parsed.startDate != null && parsed.endDate != null) {
      final candidate = Rental(
        id: 'temp_candidate',
        costumeId: parsed.costumeName!,
        customerId: 'temp_customer',
        startDate: parsed.startDate!,
        endDate: parsed.endDate!,
        durationDays: parsed.rentalDurationDays ?? 3,
        purpose: parsed.purpose ?? 'rent',
        totalPrice: 0,
      );

      final allRentals = await widget.repository.getAllRentals();
      conflicts = BookingConflictEngine.findConflicts(allRentals, candidate);
      conflict = conflicts.isNotEmpty;
    }

    setState(() {
      _parsedData = parsed;
      _hasConflict = conflict;
      _conflictingRentals = conflicts;
    });
  }

  Future<void> _continueToManual() async {
    if (_parsedData == null) return;
    final parsed = _parsedData!;
    // Capture outer context (CalendarScreen) so Manual modal survives this
    // Smart Paste modal being popped. Defer Manual modal open with post-frame
    // callback so it lands on the navigator after this route is gone.
    final outerCtx = widget.parentContext;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!outerCtx.mounted) return;
      showCupertinoModalPopup<void>(
        context: outerCtx,
        builder: (ctx) => ManualBookingModal(
          rentalRepository: widget.repository,
          costumeRepository: widget.costumeRepository,
          initialParsedData: parsed,
          onBookingAdded: () {
            widget.onBookingAdded();
          },
        ),
      );
    });
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
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
              onPressed: () => Navigator.of(sheetCtx).pop(),
              child: const Text('Batal', style: AppTypography.actionButton),
            ),
            middle: const Text('Smart Rent Form Parser', style: AppTypography.navTitle),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                const Text(
                  'Paste pesan WhatsApp format sewa di bawah untuk otomatisasi data booking & cek tabrakan jadwal.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93), height: 1.3),
                ),
                const SizedBox(height: 12),
                // Input field
                Container(
                  height: 110,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE5E5EA), width: 0.5),
                  ),
                  child: CupertinoTextField(
                    key: const Key('smart_paste_input'),
                    controller: _textController,
                    maxLines: null,
                    expands: true,
                    style: const TextStyle(fontSize: 13, color: AppColors.textDark),
                    placeholder: 'Paste pesan form rent WhatsApp di sini...',
                    placeholderStyle: const TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                    padding: const EdgeInsets.all(12),
                    decoration: null,
                  ),
                ),
                const SizedBox(height: 12),
                CupertinoButton(
                  key: const Key('smart_paste_parse_btn'),
                  color: AppColors.primaryPink,
                  onPressed: _handleParse,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  borderRadius: BorderRadius.circular(12),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.search, size: 16, color: Colors.white),
                      SizedBox(width: 6),
                      Text(
                        'Periksa & Deteksi Konflik',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ],
                  ),
                ),

                // Parsed preview card
                if (_parsedData != null) ...[
                  const SizedBox(height: 14),
                  // Conflict status banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _hasConflict
                          ? AppColors.dangerRose.withValues(alpha: 0.12)
                          : AppColors.successMint.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _hasConflict ? AppColors.dangerRose : AppColors.successMint,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _hasConflict ? CupertinoIcons.exclamationmark_circle_fill : CupertinoIcons.checkmark_circle_fill,
                          color: _hasConflict ? AppColors.dangerRose : const Color(0xFF289868),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _hasConflict
                                ? 'Konflik Terdeteksi! (${_conflictingRentals.length} jadwal tabrakan)'
                                : 'Bebas Konflik! Kostum tersedia.',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: _hasConflict ? AppColors.dangerRose : const Color(0xFF289868),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Summary card as Apple HIG Inset Grouped section
                  CupertinoListSection.insetGrouped(
                    header: const Text(
                      'DATA HASIL DETEKSI',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF8E8E93)),
                    ),
                    margin: EdgeInsets.zero,
                    backgroundColor: Colors.transparent,
                    children: [
                      CupertinoListTile(
                        leading: const SquircleIcon(icon: CupertinoIcons.person_fill, color: AppColors.primaryPink),
                        title: const Text('Nama Penyewa', style: TextStyle(fontSize: 14, color: AppColors.textDark)),
                        additionalInfo: Text(_parsedData!.fullName ?? '-', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                      ),
                      CupertinoListTile(
                        leading: const SquircleIcon(icon: CupertinoIcons.phone_fill, color: Color(0xFF34C759)),
                        title: const Text('No. WhatsApp', style: TextStyle(fontSize: 14, color: AppColors.textDark)),
                        additionalInfo: Text(_parsedData!.normalizedPhone ?? _parsedData!.phone ?? '-', style: const TextStyle(fontSize: 14, color: AppColors.textDark)),
                      ),
                      if (_parsedData!.address != null && _parsedData!.address!.isNotEmpty)
                        CupertinoListTile(
                          leading: const SquircleIcon(icon: CupertinoIcons.location_fill, color: Color(0xFFFF9500)),
                          title: const Text('Alamat', style: TextStyle(fontSize: 14, color: AppColors.textDark)),
                          additionalInfo: Text(_parsedData!.address!, style: const TextStyle(fontSize: 14, color: AppColors.textDark)),
                        ),
                      CupertinoListTile(
                        leading: const SquircleIcon(icon: CupertinoIcons.sparkles, color: Color(0xFF5856D6)),
                        title: const Text('Kostum', style: TextStyle(fontSize: 14, color: AppColors.textDark)),
                        additionalInfo: Text(_parsedData!.costumeName ?? '-', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                      ),
                      CupertinoListTile(
                        leading: const SquircleIcon(icon: CupertinoIcons.calendar, color: Color(0xFF007AFF)),
                        title: const Text('Tanggal Sewa', style: TextStyle(fontSize: 14, color: AppColors.textDark)),
                        additionalInfo: Text(
                          _parsedData!.startDate != null
                              ? '${DateFormat('d MMM').format(_parsedData!.startDate!)} - ${DateFormat('d MMM yyyy').format(_parsedData!.endDate!)} (${_parsedData!.rentalDurationDays ?? 3} hari)'
                              : (_parsedData!.datesRaw ?? '-'),
                          style: const TextStyle(fontSize: 14, color: AppColors.textDark),
                        ),
                      ),
                      if (_parsedData!.purpose != null && _parsedData!.purpose!.isNotEmpty)
                        CupertinoListTile(
                          leading: const SquircleIcon(icon: CupertinoIcons.doc_text_fill, color: Color(0xFF8E8E93)),
                          title: const Text('Keperluan', style: TextStyle(fontSize: 14, color: AppColors.textDark)),
                          additionalInfo: Text(_parsedData!.purpose!, style: const TextStyle(fontSize: 14, color: AppColors.textDark)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFF9500).withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      children: [
                        Icon(CupertinoIcons.camera_fill, size: 14, color: Color(0xFFFF9500)),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Foto KTP & Selfie+KTP belum bisa di-paste. Akan diinput di langkah berikutnya.',
                            style: TextStyle(fontSize: 11, color: Color(0xFF8E5A00)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  CupertinoButton(
                    color: AppColors.primaryPink,
                    onPressed: _continueToManual,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    borderRadius: BorderRadius.circular(12),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(CupertinoIcons.arrow_right_circle_fill, size: 16, color: Colors.white),
                        SizedBox(width: 6),
                        Text(
                          'Lanjut Input Manual (Lengkapi Foto)',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
