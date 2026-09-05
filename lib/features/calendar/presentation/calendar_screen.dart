import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../rentals/data/form_parser.dart';
import '../../rentals/data/rental_repository.dart';
import '../../rentals/domain/customer.dart';
import '../../rentals/domain/parsed_rental_data.dart';
import '../../rentals/domain/rental.dart';
import '../domain/booking_conflict_engine.dart';

class CalendarScreen extends StatefulWidget {
  final IRentalRepository? rentalRepository;
  final DateTime? initialFocusedDay;

  const CalendarScreen({
    super.key,
    this.rentalRepository,
    this.initialFocusedDay,
  });

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late IRentalRepository _repository;
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  final CalendarFormat _calendarFormat = CalendarFormat.month;

  List<Rental> _allRentals = [];
  Map<String, Customer> _customerCache = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null);
    _repository = widget.rentalRepository ?? RentalRepository();
    final initial = widget.initialFocusedDay ?? DateTime.now();
    _focusedDay = DateTime(initial.year, initial.month, initial.day);
    _selectedDay = _focusedDay;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final rentals = await _repository.getAllRentals();
    final customers = await _repository.getAllCustomers();

    final cache = <String, Customer>{};
    for (final c in customers) {
      cache[c.id] = c;
    }

    if (mounted) {
      setState(() {
        _allRentals = rentals;
        _customerCache = cache;
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

  void _openSmartPasteDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SmartPasteModal(
        repository: _repository,
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
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              key: const Key('smart_paste_button'),
              onPressed: _openSmartPasteDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F4), // very light pink fill (Apple tertiary fill)
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.sparkles,
                      size: 15,
                      color: AppColors.primaryPink,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Smart Paste',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryPink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
                          Icons.chevron_left_rounded,
                          color: AppColors.primaryPink,
                        ),
                        rightChevronIcon: Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.primaryPink,
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
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      padding: const EdgeInsets.all(24),
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
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.check_mark_circled,
                            size: 36,
                            color: AppColors.primaryPink,
                          ),
                          SizedBox(height: 10),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'Tidak ada booking di tanggal ini',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              SizedBox(width: 5),
                              Icon(
                                CupertinoIcons.sparkles,
                                size: 14,
                                color: AppColors.primaryPink,
                              ),
                            ],
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Kostum tersedia untuk disewa.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
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
                        return _RentalSlotCard(
                          rental: rental,
                          customer: customer,
                          allRentals: _allRentals,
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
  final List<Rental> allRentals;

  const _RentalSlotCard({
    required this.rental,
    required this.customer,
    required this.allRentals,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d MMM');
    final dateRangeText =
        '${dateFormat.format(rental.startDate)} - ${dateFormat.format(rental.endDate)} (${rental.durationDays} hari)';

    // Check if this rental has any conflict with other rentals
    final hasConflict = BookingConflictEngine.hasConflict(allRentals, rental);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasConflict ? AppColors.dangerRose : AppColors.borderSubtle,
          width: hasConflict ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
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
                  Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.dangerRose),
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
                  rental.costumeId,
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
              const Icon(Icons.person_outline_rounded, size: 14, color: AppColors.textMuted),
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
              const Icon(Icons.calendar_today_rounded, size: 12, color: AppColors.textMuted),
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
        label = 'Paid';
        break;
      case RentalPaymentStatus.dpPaid:
        bg = AppColors.warningOrange.withValues(alpha: 0.15);
        fg = const Color(0xFFD67710);
        label = 'DP Paid';
        break;
      case RentalPaymentStatus.unpaid:
        bg = AppColors.dangerRose.withValues(alpha: 0.12);
        fg = AppColors.dangerRose;
        label = 'Unpaid';
        break;
      case RentalPaymentStatus.refunded:
        bg = AppColors.textMuted.withValues(alpha: 0.15);
        fg = AppColors.textDark;
        label = 'Refunded';
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
        label = 'Booked';
        break;
      case RentalItemStatus.rented:
        bg = AppColors.successMint.withValues(alpha: 0.15);
        fg = const Color(0xFF289868);
        label = 'Rented';
        break;
      case RentalItemStatus.shipped:
        bg = AppColors.pastelPink.withValues(alpha: 0.2);
        fg = AppColors.primaryPink;
        label = 'Shipped';
        break;
      case RentalItemStatus.returned:
        bg = Colors.grey.shade200;
        fg = Colors.black54;
        label = 'Returned';
        break;
      case RentalItemStatus.laundry:
        bg = AppColors.pastelPink.withValues(alpha: 0.15);
        fg = const Color(0xFFC44D7B);
        label = 'Laundry';
        break;
      case RentalItemStatus.completed:
        bg = AppColors.successMint.withValues(alpha: 0.2);
        fg = const Color(0xFF1B7A4E);
        label = 'Completed';
        break;
      case RentalItemStatus.cancelled:
        bg = AppColors.dangerRose.withValues(alpha: 0.12);
        fg = AppColors.dangerRose;
        label = 'Cancelled';
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
  final VoidCallback onBookingAdded;

  const _SmartPasteModal({
    required this.repository,
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
  bool _isSaving = false;

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

  Future<void> _saveBooking() async {
    if (_parsedData == null) return;
    setState(() => _isSaving = true);

    final custId = 'cust_${DateTime.now().millisecondsSinceEpoch}';
    final customer = Customer(
      id: custId,
      fullName: _parsedData!.fullName ?? 'Pelanggan Baru',
      phone: _parsedData!.normalizedPhone ?? _parsedData!.phone ?? '-',
      parentPhone: _parsedData!.parentPhone,
      address: _parsedData!.address ?? '-',
      socialMedia: _parsedData!.socialMedia,
    );
    await widget.repository.insertCustomer(customer);

    final rentalId = 'rent_${DateTime.now().millisecondsSinceEpoch}';
    final rental = Rental(
      id: rentalId,
      costumeId: _parsedData!.costumeName ?? 'Kostum',
      customerId: custId,
      startDate: _parsedData!.startDate ?? DateTime.now(),
      endDate: _parsedData!.endDate ?? DateTime.now().add(const Duration(days: 3)),
      durationDays: _parsedData!.rentalDurationDays ?? 3,
      purpose: _parsedData!.purpose ?? 'homecos',
      totalPrice: 150000.0,
      itemStatus: RentalItemStatus.booked,
      paymentStatus: RentalPaymentStatus.dpPaid,
    );
    await widget.repository.insertRental(rental);

    if (mounted) {
      setState(() => _isSaving = false);
      widget.onBookingAdded();
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFD1D1D6),
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Row(
            children: [
              Icon(CupertinoIcons.sparkles, size: 20, color: AppColors.primaryPink),
              SizedBox(width: 8),
              Text(
                'Smart Rent Form Parser',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Paste teks chat/format WhatsApp sewa di bawah untuk otomatisasi data booking & cek tabrakan jadwal.',
            style: TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
          ),
          const SizedBox(height: 12),
          // Input field
          Container(
            height: 110,
            decoration: BoxDecoration(
              color: const Color(0xFFF2F2F7),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5E5EA), width: 0.5),
            ),
            child: TextField(
              key: const Key('smart_paste_input'),
              controller: _textController,
              maxLines: null,
              expands: true,
              style: const TextStyle(fontSize: 13, color: AppColors.textDark),
              decoration: const InputDecoration(
                hintText: 'Paste pesan form rent WhatsApp di sini...',
                hintStyle: TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
                contentPadding: EdgeInsets.all(12),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          CupertinoButton.filled(
            key: const Key('smart_paste_parse_btn'),
            onPressed: _handleParse,
            padding: const EdgeInsets.symmetric(vertical: 12),
            borderRadius: BorderRadius.circular(10),
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
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Conflict status banner
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: _hasConflict
                            ? AppColors.dangerRose.withValues(alpha: 0.12)
                            : AppColors.successMint.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
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
                    const SizedBox(height: 10),
                    // Summary card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow('Nama Penyewa', _parsedData!.fullName ?? '-'),
                          _buildDetailRow('No HP', _parsedData!.normalizedPhone ?? _parsedData!.phone ?? '-'),
                          _buildDetailRow('Kostum', _parsedData!.costumeName ?? '-'),
                          _buildDetailRow(
                            'Tanggal',
                            _parsedData!.startDate != null
                                ? '${DateFormat('d MMM yyyy').format(_parsedData!.startDate!)} - ${DateFormat('d MMM yyyy').format(_parsedData!.endDate!)} (${_parsedData!.rentalDurationDays ?? 3} hari)'
                                : (_parsedData!.datesRaw ?? '-'),
                          ),
                          _buildDetailRow('Keperluan', _parsedData!.purpose ?? '-'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    CupertinoButton.filled(
                      onPressed: _isSaving ? null : _saveBooking,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      borderRadius: BorderRadius.circular(10),
                      child: _isSaving
                          ? const CupertinoActivityIndicator(color: Colors.white)
                          : Text(
                              _hasConflict ? 'Tetap Simpan Booking' : 'Simpan Booking',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 95,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ),
          const Text(': ', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
