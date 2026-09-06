import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/apple_sliding_segmented_control.dart';
import '../../../core/widgets/draggable_sheet_container.dart';
import '../../../core/widgets/squircle_icon.dart';
import '../data/installment_repository.dart';
import '../domain/installment.dart';
import '../domain/installment_log.dart';
import 'widgets/installment_card.dart';
import 'installment_detail_screen.dart';

class InstallmentListScreen extends StatefulWidget {
  final IInstallmentRepository repository;

  const InstallmentListScreen({
    super.key,
    required this.repository,
  });

  @override
  State<InstallmentListScreen> createState() => _InstallmentListScreenState();
}

class _InstallmentListScreenState extends State<InstallmentListScreen> {
  List<Installment> _installments = [];
  bool _isLoading = true;
  String _selectedFilter = 'all'; // all, ongoing, paidOff

  static const _months = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
  ];

  String _monthName(int month) => (month >= 1 && month <= 12) ? _months[month] : '$month';

  @override
  void initState() {
    super.initState();
    _loadInstallments();
  }

  Future<void> _loadInstallments() async {
    setState(() => _isLoading = true);
    List<Installment> items;
    if (_selectedFilter == 'ongoing') {
      items = await widget.repository.getInstallmentsByStatus(InstallmentStatus.ongoing);
    } else if (_selectedFilter == 'paidOff') {
      items = await widget.repository.getInstallmentsByStatus(InstallmentStatus.paidOff);
    } else {
      items = await widget.repository.getAllInstallments();
    }
    if (mounted) {
      setState(() {
        _installments = items;
        _isLoading = false;
      });
    }
  }

  void _showAddInstallmentDialog() {
    final nameController = TextEditingController();
    final storeController = TextEditingController();
    final costController = TextEditingController();
    final dpController = TextEditingController();
    DateTime? selectedDueDate;
    bool isDatePickerExpanded = false;

    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) {
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return DraggableSheetContainer(
              backgroundColor: const Color(0xFFF2F2F7),
              onDismissed: () => Navigator.of(ctx).pop(),
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
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Batal', style: AppTypography.actionButton),
                    ),
                    middle: const SizedBox(
                      width: double.infinity,
                      child: Center(
                        child: Text('Cicilan Baru', style: AppTypography.navTitle),
                      ),
                    ),
                    trailing: CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () async {
                        final name = nameController.text.trim();
                        final cost = double.tryParse(costController.text.trim()) ?? 0.0;
                        final dp = double.tryParse(dpController.text.trim()) ?? 0.0;
                        if (name.isEmpty || cost <= 0) return;

                        final id = 'inst_${DateTime.now().millisecondsSinceEpoch}';
                        final remaining = (cost - dp).clamp(0.0, cost);
                        final status = remaining <= 0 ? InstallmentStatus.paidOff : InstallmentStatus.ongoing;

                        final newInst = Installment(
                          id: id,
                          itemName: name,
                          storeName: storeController.text.trim().isEmpty ? null : storeController.text.trim(),
                          totalCost: cost,
                          totalPaid: dp,
                          remainingBalance: remaining,
                          dueDate: selectedDueDate,
                          status: status,
                        );

                        await widget.repository.insertInstallment(newInst);
                        if (dp > 0) {
                          await widget.repository.addPaymentLog(InstallmentLog(
                            id: 'log_${DateTime.now().millisecondsSinceEpoch}',
                            installmentId: id,
                            paymentDate: DateTime.now(),
                            amountPaid: dp,
                            notes: 'DP Awal',
                          ));
                        }
                        if (!ctx.mounted) return;
                        Navigator.of(ctx).pop();
                        _loadInstallments();
                      },
                      child: const Text('Simpan', style: AppTypography.actionButton),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(0, 8, 0, bottomInset + 24),
                      physics: const BouncingScrollPhysics(),
                      children: [
                        CupertinoFormSection.insetGrouped(
                          backgroundColor: AppColors.background,
                          header: const Text('INFORMASI BARANG'),
                          children: [
                            CupertinoTextFormFieldRow(
                              key: const Key('installment_name_input'),
                              controller: nameController,
                              prefix: const SquircleIcon(icon: CupertinoIcons.sparkles, color: AppColors.primaryPink),
                              placeholder: 'Nama barang / kostum',
                              textInputAction: TextInputAction.next,
                            ),
                            CupertinoTextFormFieldRow(
                              key: const Key('installment_store_input'),
                              controller: storeController,
                              prefix: const SquircleIcon(icon: CupertinoIcons.bag_fill, color: Color(0xFF5856D6)),
                              placeholder: 'Nama toko / seller',
                              textInputAction: TextInputAction.next,
                            ),
                          ],
                        ),
                        CupertinoFormSection.insetGrouped(
                          backgroundColor: AppColors.background,
                          header: const Text('PEMBAYARAN'),
                          children: [
                            CupertinoTextFormFieldRow(
                              key: const Key('installment_cost_input'),
                              controller: costController,
                              prefix: const SquircleIcon(icon: CupertinoIcons.money_dollar_circle_fill, color: Color(0xFFFF9500)),
                              placeholder: 'Total harga (Rp)',
                              keyboardType: TextInputType.number,
                            ),
                            CupertinoTextFormFieldRow(
                              key: const Key('installment_dp_input'),
                              controller: dpController,
                              prefix: const SquircleIcon(icon: CupertinoIcons.creditcard_fill, color: Color(0xFF34C759)),
                              placeholder: 'DP awal (Rp)',
                              keyboardType: TextInputType.number,
                            ),
                            // Jatuh tempo row: Apple HIG style.
                            // Use leadingSize: 29 to match the SquircleIcon
                            // size used by CupertinoTextFormFieldRow siblings
                            // (DP awal, Total harga) so the title text starts
                            // at the same x-coordinate. Default CupertinoListTile
                            // uses leadingSize 28 + leadingToTitle 16, which
                            // pushes this row's text ~3-4px to the right of
                            // the other rows in the section.
                            CupertinoListTile(
                              leadingSize: 29.0,
                              leadingToTitle: 13.0,
                              leading: const SquircleIcon(icon: CupertinoIcons.calendar, color: Color(0xFFFF3B30)),
                              title: Transform.translate(
                                offset: const Offset(-16.0, 0),
                                child: Text(
                                  selectedDueDate == null
                                      ? 'Pilih jatuh tempo (opsional)'
                                      : '${selectedDueDate!.day} ${_monthName(selectedDueDate!.month)} ${selectedDueDate!.year}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: selectedDueDate == null
                                        ? const Color(0xFFC7C7CC)
                                        : AppColors.textDark,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                              trailing: AnimatedRotation(
                                turns: isDatePickerExpanded ? 0.25 : 0.0,
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeInOutCubic,
                                child: const Icon(CupertinoIcons.chevron_right, size: 14, color: Color(0xFFC7C7CC)),
                              ),
                              onTap: () {
                                setSheetState(() {
                                  isDatePickerExpanded = !isDatePickerExpanded;
                                  if (isDatePickerExpanded && selectedDueDate == null) {
                                    selectedDueDate = DateTime.now().add(const Duration(days: 30));
                                  }
                                });
                              },
                            ),
                            AnimatedSize(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOutCubic,
                              alignment: Alignment.topCenter,
                              child: isDatePickerExpanded
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
                                            child: CupertinoDatePicker(
                                              mode: CupertinoDatePickerMode.date,
                                              initialDateTime: selectedDueDate ?? DateTime.now().add(const Duration(days: 30)),
                                              minimumDate: DateTime(2020),
                                              maximumDate: DateTime(2035),
                                              onDateTimeChanged: (d) {
                                                setSheetState(() => selectedDueDate = d);
                                              },
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                CupertinoButton(
                                                  padding: EdgeInsets.zero,
                                                  minimumSize: Size.zero,
                                                  onPressed: () {
                                                    setSheetState(() {
                                                      selectedDueDate = null;
                                                      isDatePickerExpanded = false;
                                                    });
                                                  },
                                                  child: const Text(
                                                    'Hapus Tanggal',
                                                    style: TextStyle(
                                                      color: AppColors.primaryPink,
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                                CupertinoButton(
                                                  padding: EdgeInsets.zero,
                                                  minimumSize: Size.zero,
                                                  onPressed: () {
                                                    setSheetState(() => isDatePickerExpanded = false);
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
      },
    );
  }

  void _showLedgerDetailSheet(Installment installment) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _PaymentHistorySheet(
          installmentId: installment.id,
          repository: widget.repository,
          onDataChanged: () => _loadInstallments(),
          onOpenDetail: () {
            Navigator.pop(ctx);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => InstallmentDetailScreen(
                  installmentId: installment.id,
                  repository: widget.repository,
                ),
              ),
            ).then((_) => _loadInstallments());
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Buku Cicilan',
          style: AppTypography.largeTitle,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              key: const Key('add_installment_button'),
              onPressed: _showAddInstallmentDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.add, size: 15, color: AppColors.primaryPink),
                    SizedBox(width: 5),
                    Text(
                      'Tambah',
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
      body: Column(
        children: [
          // iOS Apple Sliding Segmented Control (Draggable + Tap)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
            child: AppleSlidingSegmentedControl<String>(
              groupValue: _selectedFilter,
              height: 36.0,
              fontSize: 13.0,
              items: const [
                SegmentItem(value: 'all', label: 'Semua'),
                SegmentItem(value: 'ongoing', label: 'Berjalan'),
                SegmentItem(value: 'paidOff', label: 'Lunas'),
              ],
              onValueChanged: (val) {
                setState(() => _selectedFilter = val);
                _loadInstallments();
              },
            ),
          ),
          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CupertinoActivityIndicator(radius: 14))
                : _installments.isEmpty
                    ? Column(
                        // Flex-based optical centering: 1 part above content,
                        // 1 part the content, 2 parts below = content sits at
                        // 25% from the top of the available area (Apple HIG
                        // empty-state position). Scales to any screen — no
                        // magic pixels, no MediaQuery dance. The bottom Spacer
                        // is naturally larger to leave breathing room above
                        // the floating nav.
                        children: [
                          const Spacer(flex: 5),
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFE5E5EA), // iOS systemGray5
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    CupertinoIcons.creditcard,
                                    size: 36,
                                    color: Color(0xFF8E8E93), // iOS secondaryLabel
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Belum ada daftar cicilan',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(flex: 8),
                        ],
                      )
                    : RefreshIndicator(
                        color: AppColors.primaryPink,
                        onRefresh: _loadInstallments,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 112.0),
                          itemCount: _installments.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 14),
                          itemBuilder: (context, index) {
                            final item = _installments[index];
                            return InstallmentCard(
                              installment: item,
                              onTap: () => _showLedgerDetailSheet(item),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _PaymentHistorySheet extends StatefulWidget {
  final String installmentId;
  final IInstallmentRepository repository;
  final VoidCallback onDataChanged;
  final VoidCallback? onOpenDetail;

  const _PaymentHistorySheet({
    required this.installmentId,
    required this.repository,
    required this.onDataChanged,
    this.onOpenDetail,
  });

  @override
  State<_PaymentHistorySheet> createState() => _PaymentHistorySheetState();
}

class _PaymentHistorySheetState extends State<_PaymentHistorySheet> {
  Installment? _installment;
  List<InstallmentLog> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    final inst = await widget.repository.getInstallmentById(widget.installmentId);
    final logs = await widget.repository.getLogsForInstallment(widget.installmentId);
    if (mounted) {
      setState(() {
        _installment = inst;
        _logs = logs;
        _isLoading = false;
      });
    }
  }

  String _formatCurrency(double amount) {
    final parts = amount.toInt().toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
    return 'Rp $parts';
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  void _showAddPaymentDialog() {
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showCupertinoDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return CupertinoAlertDialog(
              title: const Text('Catat Pembayaran Cicilan'),
              content: Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CupertinoTextField(
                      key: const Key('payment_amount_input'),
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      placeholder: 'Jumlah Bayar (Rp) *',
                      prefix: const Padding(
                        padding: EdgeInsets.only(left: 8.0),
                        child: Text('Rp ', style: TextStyle(color: CupertinoColors.secondaryLabel)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F2F7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 10),
                    CupertinoTextField(
                      key: const Key('payment_notes_input'),
                      controller: notesController,
                      placeholder: 'Catatan (misal: Cicilan ke-2)',
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F2F7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ],
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
                  onPressed: () => Navigator.pop(dialogCtx),
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
                  onPressed: () async {
                    final amount = double.tryParse(amountController.text.trim()) ?? 0.0;
                    if (amount <= 0) return;

                    final log = InstallmentLog(
                      id: 'log_${DateTime.now().millisecondsSinceEpoch}',
                      installmentId: widget.installmentId,
                      paymentDate: selectedDate,
                      amountPaid: amount,
                      notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                    );

                    await widget.repository.addPaymentLog(log);
                    widget.onDataChanged();
                    if (!dialogCtx.mounted) return;
                    Navigator.pop(dialogCtx);
                    _fetchDetails();
                  },
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 300,
        decoration: const BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: const Center(child: CupertinoActivityIndicator(radius: 14)),
      );
    }

    final inst = _installment;
    if (inst == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: const Text('Data cicilan tidak ditemukan'),
      );
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: ListView(
            controller: scrollController,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.pastelPink.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title and Subtitle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          inst.itemName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                        ),
                        if (inst.storeName != null)
                          Text(
                            inst.storeName!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: inst.isPaidOff ? const Color(0xFFE3F9EC) : AppColors.softPinkBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      inst.isPaidOff ? 'Lunas' : 'Belum Lunas',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: inst.isPaidOff ? const Color(0xFF1E824C) : AppColors.primaryPink,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Summary Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Harga:', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                        Text(_formatCurrency(inst.totalCost), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Sudah Terbayar:', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                        Text(
                          _formatCurrency(inst.totalPaid),
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.primaryPink),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Sisa Tagihan:', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                        Text(
                          _formatCurrency(inst.remainingBalance),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: inst.isPaidOff ? AppColors.successMint : AppColors.dangerRose,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Action button: Catat Pembayaran
              SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  borderRadius: BorderRadius.circular(10),
                  onPressed: _showAddPaymentDialog,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.creditcard_fill, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text(
                        '+ Catat Pembayaran',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Payment Logs Ledger Header
              const Text(
                'Riwayat Cicilan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 10),

              if (_logs.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  alignment: Alignment.center,
                  child: const Text(
                    'Belum ada catatan pembayaran cicilan.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                )
              else
                ..._logs.map((log) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF2F2F7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(CupertinoIcons.checkmark_circle_fill, color: AppColors.primaryPink, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _formatCurrency(log.amountPaid),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textDark,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  log.notes ?? _formatDate(log.paymentDate),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textMuted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Text(
                              _formatDate(log.paymentDate),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(CupertinoIcons.trash, size: 16, color: AppColors.dangerRose),
                              onPressed: () async {
                                await widget.repository.deletePaymentLog(log.id, widget.installmentId);
                                widget.onDataChanged();
                                _fetchDetails();
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              const SizedBox(height: 30),
            ],
          ),
        );
      },
    );
  }
}
