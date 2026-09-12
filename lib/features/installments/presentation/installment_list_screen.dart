import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/sync/sync_manager.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/draggable_sheet_container.dart';
import '../../../core/widgets/header_action_button.dart';
import '../../../core/widgets/ios_toast.dart';
import '../../../core/widgets/sheet_picker.dart';
import '../../../core/widgets/squircle_icon.dart';
import '../data/installment_repository.dart';
import '../domain/installment.dart';
import '../domain/installment_log.dart';
import 'widgets/installment_card.dart';
import 'installment_detail_screen.dart';
import 'installment_filter_sheet.dart';
import 'widgets/add_payment_sheet.dart';

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
  final TextEditingController _searchController = TextEditingController();
  List<Installment> _installments = [];
  bool _isLoading = true;
  InstallmentStatus? _selectedStatus;
  String _selectedSortBy = 'due_date_asc';

  static const _months = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
  ];

  String _monthName(int month) => (month >= 1 && month <= 12) ? _months[month] : '$month';

  @override
  void initState() {
    super.initState();
    _loadInstallments();
    SyncManager.instance.dataVersion.addListener(_onDataVersionChanged);
  }

  @override
  void dispose() {
    SyncManager.instance.dataVersion.removeListener(_onDataVersionChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onDataVersionChanged() {
    if (mounted) {
      _loadInstallments();
    }
  }

  Future<void> _loadInstallments() async {
    setState(() => _isLoading = true);
    final items = await widget.repository.searchInstallments(
      query: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
      status: _selectedStatus,
      sortBy: _selectedSortBy,
    );
    if (mounted) {
      setState(() {
        _installments = items;
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String _) {
    _loadInstallments();
  }

  String _getSortLabel(String sortBy) {
    switch (sortBy) {
      case 'due_date_desc':
        return 'Jatuh Tempo Terjauh';
      case 'balance_desc':
        return 'Sisa Terbanyak';
      case 'cost_desc':
        return 'Total Biaya Tertinggi';
      case 'name_asc':
        return 'Nama (A-Z)';
      case 'due_date_asc':
      default:
        return 'Jatuh Tempo Terdekat';
    }
  }

  Widget _buildFilterButton() {
    final bool hasActiveFilter = _selectedStatus != null || _selectedSortBy != 'due_date_asc';
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: _showFilterSheet,
      child: Container(
        height: 38,
        width: 38,
        decoration: BoxDecoration(
          color: hasActiveFilter ? AppColors.softPinkBg : const Color(0xFFE3E3E8),
          borderRadius: BorderRadius.circular(10.0),
          border: hasActiveFilter ? Border.all(color: AppColors.primaryPink.withValues(alpha: 0.5), width: 1.2) : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              CupertinoIcons.slider_horizontal_3,
              size: 19,
              color: hasActiveFilter ? AppColors.primaryPink : const Color(0xFF555558),
            ),
            if (hasActiveFilter)
              Positioned(
                top: 7,
                right: 7,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryPink,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showFilterSheet() async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) {
        return InstallmentFilterSheet(
          initialStatus: _selectedStatus,
          initialSortBy: _selectedSortBy,
          onApply: ({required status, required sortBy}) {
            setState(() {
              _selectedStatus = status;
              _selectedSortBy = sortBy;
            });
            _loadInstallments();
          },
        );
      },
    );
  }

  void _showFormAlert(BuildContext ctx, String title, String message) {
    showCupertinoDialog<void>(
      context: ctx,
      builder: (alertCtx) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(alertCtx),
            child: const Text('Oke', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.primaryPink)),
          ),
        ],
      ),
    );
  }

  void _showAddInstallmentDialog() {
    final nameController = TextEditingController();
    final storeController = TextEditingController();
    final costController = TextEditingController();
    final dpController = TextEditingController();
    DateTime? selectedDueDate;

    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) {
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return DraggableSheetContainer(
              backgroundColor: AppColors.background,
              onDismissed: () => Navigator.of(ctx).pop(),
              builder: (context) => DefaultTextStyle(
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
                        if (name.isEmpty) {
                          _showFormAlert(ctx, 'Nama Wajib Diisi', 'Mohon masukkan nama barang atau kostum.');
                          return;
                        }
                        if (cost <= 0) {
                          _showFormAlert(ctx, 'Total Harga Tidak Valid', 'Mohon masukkan total harga yang valid (lebih dari 0).');
                          return;
                        }
                        if (dp > cost) {
                          _showFormAlert(ctx, 'DP Melebihi Total', 'Jumlah DP awal tidak boleh melebihi total harga.');
                          return;
                        }

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
                        IosToast.show(context, 'Cicilan "$name" berhasil ditambahkan');
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
                        CupertinoListSection.insetGrouped(
                          backgroundColor: AppColors.background,
                          header: const Text('INFORMASI BARANG'),
                          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          children: [
                            CupertinoListTile(
                              leading: const SquircleIcon(icon: CupertinoIcons.sparkles, color: AppColors.primaryPink),
                              title: Row(
                                children: [
                                  const SizedBox(
                                    width: 90,
                                    child: Text('Nama', style: TextStyle(fontSize: 15, color: AppColors.textDark)),
                                  ),
                                  Expanded(
                                    child: CupertinoTextField(
                                      key: const Key('installment_name_input'),
                                      controller: nameController,
                                      textAlign: TextAlign.right,
                                      placeholder: 'Nama barang / kostum',
                                      placeholderStyle: const TextStyle(color: Color(0xFFC7C7CC), fontSize: 15),
                                      style: const TextStyle(fontSize: 15, color: AppColors.textDark),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: null,
                                      textInputAction: TextInputAction.next,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            CupertinoListTile(
                              leading: const SquircleIcon(icon: CupertinoIcons.bag_fill, color: Color(0xFF5856D6)),
                              title: Row(
                                children: [
                                  const SizedBox(
                                    width: 90,
                                    child: Text('Toko', style: TextStyle(fontSize: 15, color: AppColors.textDark)),
                                  ),
                                  Expanded(
                                    child: CupertinoTextField(
                                      key: const Key('installment_store_input'),
                                      controller: storeController,
                                      textAlign: TextAlign.right,
                                      placeholder: 'Nama toko / seller',
                                      placeholderStyle: const TextStyle(color: Color(0xFFC7C7CC), fontSize: 15),
                                      style: const TextStyle(fontSize: 15, color: AppColors.textDark),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: null,
                                      textInputAction: TextInputAction.next,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        CupertinoListSection.insetGrouped(
                          backgroundColor: AppColors.background,
                          header: const Text('PEMBAYARAN'),
                          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          children: [
                            CupertinoListTile(
                              leading: const SquircleIcon(icon: CupertinoIcons.money_dollar_circle_fill, color: Color(0xFFFF9500)),
                              title: Row(
                                children: [
                                  const SizedBox(
                                    width: 90,
                                    child: Text('Total', style: TextStyle(fontSize: 15, color: AppColors.textDark)),
                                  ),
                                  Expanded(
                                    child: CupertinoTextField(
                                      key: const Key('installment_cost_input'),
                                      controller: costController,
                                      textAlign: TextAlign.right,
                                      placeholder: 'Total harga (Rp)',
                                      placeholderStyle: const TextStyle(color: Color(0xFFC7C7CC), fontSize: 15),
                                      style: const TextStyle(fontSize: 15, color: AppColors.textDark),
                                      keyboardType: TextInputType.number,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: null,
                                      textInputAction: TextInputAction.next,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            CupertinoListTile(
                              leading: const SquircleIcon(icon: CupertinoIcons.creditcard_fill, color: Color(0xFF34C759)),
                              title: Row(
                                children: [
                                  const SizedBox(
                                    width: 90,
                                    child: Text('DP Awal', style: TextStyle(fontSize: 15, color: AppColors.textDark)),
                                  ),
                                  Expanded(
                                    child: CupertinoTextField(
                                      key: const Key('installment_dp_input'),
                                      controller: dpController,
                                      textAlign: TextAlign.right,
                                      placeholder: 'DP awal (Rp)',
                                      placeholderStyle: const TextStyle(color: Color(0xFFC7C7CC), fontSize: 15),
                                      style: const TextStyle(fontSize: 15, color: AppColors.textDark),
                                      keyboardType: TextInputType.number,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: null,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            CupertinoListTile(
                              key: const Key('installment_due_date_row'),
                              leading: const SquircleIcon(
                                icon: CupertinoIcons.calendar,
                                color: Color(0xFFFF3B30),
                              ),
                              title: const Text(
                                'Jatuh tempo',
                                style: TextStyle(fontSize: 15, color: AppColors.textDark),
                              ),
                              additionalInfo: Text(
                                selectedDueDate == null
                                    ? 'Opsional'
                                    : '${selectedDueDate!.day} ${_monthName(selectedDueDate!.month)} ${selectedDueDate!.year}',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: selectedDueDate == null
                                      ? const Color(0xFF8E8E93)
                                      : AppColors.textDark,
                                ),
                              ),
                              trailing: const Icon(
                                CupertinoIcons.chevron_right,
                                size: 14,
                                color: Color(0xFFC7C7CC),
                              ),
                              onTap: () async {
                                final d = await showSheetDatePicker(
                                  context: ctx,
                                  title: 'Jatuh Tempo',
                                  initialDate: selectedDueDate ??
                                      DateTime.now().add(const Duration(days: 30)),
                                );
                                if (d != null) {
                                  setSheetState(() => selectedDueDate = d);
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
          HeaderActionButton(
            buttonKey: const Key('add_installment_button'),
            label: 'Tambah',
            icon: CupertinoIcons.add,
            onPressed: _showAddInstallmentDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // True iOS HIG Search Field + Filter Button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3E3E8), // iOS systemGray5/6
                          borderRadius: BorderRadius.circular(10.0), // Standard Apple iOS search field radius
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          style: const TextStyle(fontSize: 15, color: Colors.black87),
                          decoration: InputDecoration(
                            hintText: 'Cari cicilan atau nama toko',
                            hintStyle: const TextStyle(color: Color(0xFF8E8E93), fontSize: 15),
                            prefixIcon: const Icon(CupertinoIcons.search, color: Color(0xFF8E8E93), size: 18),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? CupertinoButton(
                                    padding: EdgeInsets.zero,
                                    onPressed: () {
                                      _searchController.clear();
                                      _loadInstallments();
                                    },
                                    child: const Icon(CupertinoIcons.clear_circled_solid, color: Color(0xFF8E8E93), size: 18),
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 9),
                            isDense: true,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterButton(),
                  ],
                ),
                if (_selectedStatus != null || _selectedSortBy != 'due_date_asc') ...[
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        if (_selectedStatus != null)
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _selectedStatus == InstallmentStatus.paidOff ? const Color(0xFFE8F8F0) : const Color(0xFFFFF4E5),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _selectedStatus == InstallmentStatus.paidOff ? const Color(0xFFA3E6C4) : const Color(0xFFFFD199),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _selectedStatus == InstallmentStatus.paidOff ? CupertinoIcons.checkmark_seal_fill : CupertinoIcons.clock_fill,
                                  size: 12,
                                  color: _selectedStatus == InstallmentStatus.paidOff ? const Color(0xFF1E824C) : const Color(0xFFD97706),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _selectedStatus == InstallmentStatus.paidOff ? 'Sudah Lunas' : 'Sedang Berjalan',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _selectedStatus == InstallmentStatus.paidOff ? const Color(0xFF1E824C) : const Color(0xFFD97706),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () {
                                    setState(() => _selectedStatus = null);
                                    _loadInstallments();
                                  },
                                  child: Icon(
                                    CupertinoIcons.clear_circled_solid,
                                    size: 14,
                                    color: _selectedStatus == InstallmentStatus.paidOff ? const Color(0xFF1E824C) : const Color(0xFFD97706),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (_selectedSortBy != 'due_date_asc')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF2F2F7),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFD1D1D6)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(CupertinoIcons.sort_down, size: 12, color: Color(0xFF555558)),
                                const SizedBox(width: 5),
                                Text(
                                  _getSortLabel(_selectedSortBy),
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF555558)),
                                ),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () {
                                    setState(() => _selectedSortBy = 'due_date_asc');
                                    _loadInstallments();
                                  },
                                  child: const Icon(CupertinoIcons.clear_circled_solid, size: 14, color: Color(0xFF8E8E93)),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
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
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryPink.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    CupertinoIcons.creditcard,
                                    size: 36,
                                    color: AppColors.primaryPink,
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

  Future<void> _showAddPaymentSheet() async {
    final inst = _installment;
    if (inst == null) return;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => AddPaymentSheet(
        installment: inst,
        repository: widget.repository,
        onSaved: () {
          widget.onDataChanged();
          _fetchDetails();
        },
      ),
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
                  onPressed: _showAddPaymentSheet,
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
                                color: AppColors.background,
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
