import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/sync/sync_manager.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/draggable_sheet_container.dart';
import '../../../core/widgets/header_action_button.dart';
import '../../../core/widgets/ios_toast.dart';
import '../../../core/widgets/sheet_picker.dart';
import '../../../core/widgets/squircle_icon.dart';
import '../../../core/widgets/animated_list_item.dart';
import '../../../core/widgets/state_crossfade.dart';
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
  UniqueKey _listKey = UniqueKey();

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
        _listKey = UniqueKey();
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
      minimumSize: const Size(44, 44),
      onPressed: _showFilterSheet,
      child: Container(
        height: 38,
        width: 38,
        decoration: BoxDecoration(
          color: hasActiveFilter ? AppColors.softPinkBg : AppColors.background,
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
    final hadFocus = FocusScope.of(context).hasFocus;
    if (hadFocus) {
      FocusScope.of(context).unfocus();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      if (!mounted) return;
    }
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
        bool isSaving = false;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return DraggableSheetContainer(
              backgroundColor: AppColors.background,
              initialHeightFraction: 0.52,
              maxHeightFraction: 0.88,
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
                      onPressed: isSaving ? null : () async {
                        final name = nameController.text.trim();
                        final rawCost = costController.text.trim().replaceAll('.', '').replaceAll(',', '');
                        final rawDp = dpController.text.trim().replaceAll('.', '').replaceAll(',', '');
                        final cost = double.tryParse(rawCost) ?? 0.0;
                        final dp = double.tryParse(rawDp) ?? 0.0;
                        if (name.isEmpty) {
                          _showFormAlert(ctx, 'Nama Wajib Diisi', 'Mohon masukkan nama barang atau kostum.');
                          return;
                        }
                        if (cost <= 0) {
                          _showFormAlert(ctx, 'Total Harga Tidak Valid', 'Mohon masukkan total harga yang valid (lebih dari 0).');
                          return;
                        }
                        if (dp < 0) {
                          _showFormAlert(ctx, 'DP Tidak Valid', 'Jumlah DP awal tidak boleh kurang dari Rp 0.');
                          return;
                        }
                        if (dp > cost) {
                          _showFormAlert(ctx, 'DP Melebihi Total', 'Jumlah DP awal tidak boleh melebihi total harga.');
                          return;
                        }

                        setSheetState(() => isSaving = true);

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
                      child: isSaving
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
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) {
        return _PaymentHistorySheet(
          installmentId: installment.id,
          repository: widget.repository,
          onDataChanged: () => _loadInstallments(),
          onOpenDetail: () {
            Navigator.pop(ctx);
            Navigator.push(
              context,
              CupertinoPageRoute(
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

  String _formatCurrency(double amount) {
    final parts = amount.toInt().toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
    return 'Rp $parts';
  }

  Widget _buildSummaryCard() {
    double totalRemainingDebt = 0.0;
    int activeCount = 0;

    for (final inst in _installments) {
      if (!inst.isPaidOff) {
        totalRemainingDebt += inst.remainingBalance;
        activeCount++;
      }
    }

    return Container(
      key: const Key('installment_summary_card'),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: const Color(0xFFE5E5EA),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8.0,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SquircleIcon(
                icon: CupertinoIcons.chart_pie_fill,
                color: AppColors.primaryPink,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'RINGKASAN FINANSIAL CICILAN',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: Color(0xFF8E8E93),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: activeCount > 0 ? AppColors.softPinkBg : const Color(0xFFE3F9EC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  activeCount > 0 ? '$activeCount Aktif' : 'Semua Lunas',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: activeCount > 0 ? AppColors.deepPinkText : const Color(0xFF1E824C),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text(
                'Total Sisa Hutang',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textDark,
                ),
              ),
              Text(
                _formatCurrency(totalRemainingDebt),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: totalRemainingDebt > 0 ? AppColors.deepPinkText : const Color(0xFF1E824C),
                ),
              ),
            ],
          ),
        ],
      ),
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
                      child: CupertinoSearchTextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        placeholder: 'Cari cicilan atau nama toko',
                        style: const TextStyle(fontSize: 15, color: Colors.black87),
                        placeholderStyle: const TextStyle(color: Color(0xFF8E8E93), fontSize: 15),
                        onSuffixTap: () {
                          try {
                            HapticFeedback.lightImpact();
                          } catch (_) {}
                          _searchController.clear();
                          _loadInstallments();
                        },
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
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    setState(() => _selectedStatus = null);
                                    _loadInstallments();
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(4, 2, 2, 2),
                                    child: Icon(
                                      CupertinoIcons.clear_circled_solid,
                                      size: 14,
                                      color: _selectedStatus == InstallmentStatus.paidOff ? const Color(0xFF1E824C) : const Color(0xFFD97706),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (_selectedSortBy != 'due_date_asc')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.background,
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
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    setState(() => _selectedSortBy = 'due_date_asc');
                                    _loadInstallments();
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.fromLTRB(4, 2, 2, 2),
                                    child: Icon(CupertinoIcons.clear_circled_solid, size: 14, color: Color(0xFF8E8E93)),
                                  ),
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
            child: StateCrossfade(
              isLoading: _isLoading,
              isEmpty: _installments.isEmpty,
              loadingChild: const Center(child: CupertinoActivityIndicator(radius: 14)),
              emptyChild: Column(
                children: [
                  const Spacer(flex: 5),
                  Center(
                    child: Builder(
                      builder: (context) {
                        final hasFilterOrQuery = _searchController.text.trim().isNotEmpty ||
                            _selectedStatus != null ||
                            _selectedSortBy != 'due_date_asc';
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: AppColors.primaryPink.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                hasFilterOrQuery ? CupertinoIcons.search : CupertinoIcons.creditcard,
                                size: 36,
                                color: AppColors.primaryPink,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              hasFilterOrQuery ? 'Tidak ada cicilan yang cocok' : 'Belum ada daftar cicilan',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              hasFilterOrQuery
                                  ? 'Coba sesuaikan filter atau kata kunci pencarian'
                                  : 'Catat cicilan kostum baru untuk memantau jatuh tempo',
                              style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 14),
                            if (hasFilterOrQuery)
                              CupertinoButton(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                color: AppColors.softPinkBg,
                                borderRadius: BorderRadius.circular(20),
                                onPressed: () {
                                  try {
                                    HapticFeedback.lightImpact();
                                  } catch (_) {}
                                  _searchController.clear();
                                  setState(() {
                                    _selectedStatus = null;
                                    _selectedSortBy = 'due_date_asc';
                                  });
                                  _loadInstallments();
                                },
                                child: const Text(
                                  'Atur Ulang Filter',
                                  style: TextStyle(color: AppColors.deepPinkText, fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              )
                            else
                              CupertinoButton(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                color: AppColors.softPinkBg,
                                borderRadius: BorderRadius.circular(20),
                                onPressed: () {
                                  try {
                                    HapticFeedback.lightImpact();
                                  } catch (_) {}
                                  _showAddInstallmentDialog();
                                },
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(CupertinoIcons.plus, size: 14, color: AppColors.deepPinkText),
                                    SizedBox(width: 6),
                                    Text(
                                      'Tambah Cicilan',
                                      style: TextStyle(color: AppColors.deepPinkText, fontSize: 13, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                  const Spacer(flex: 8),
                ],
              ),
              contentChild: CustomScrollView(
                key: _listKey,
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                slivers: [
                  CupertinoSliverRefreshControl(
                    onRefresh: _loadInstallments,
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 8.0),
                      child: _buildSummaryCard(),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16.0, 6.0, 16.0, 160.0),
                    sliver: SliverList.separated(
                      itemCount: _installments.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final item = _installments[index];
                        return AnimatedListItem(
                          index: index,
                          child: InstallmentCard(
                            installment: item,
                            onTap: () => _showLedgerDetailSheet(item),
                          ),
                        );
                      },
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
    final updated = await widget.repository.recalculateInstallment(widget.installmentId);
    final inst = updated ?? await widget.repository.getInstallmentById(widget.installmentId);
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

  void _confirmDeleteLog(InstallmentLog log) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Hapus Catatan Pembayaran?'),
        content: Text('Apakah Anda yakin ingin menghapus catatan pembayaran sebesar ${_formatCurrency(log.amountPaid)}?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: AppColors.textDark)),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              await widget.repository.deletePaymentLog(log.id, widget.installmentId);
              widget.onDataChanged();
              _fetchDetails();
              if (mounted) {
                IosToast.show(context, 'Catatan pembayaran berhasil dihapus', icon: CupertinoIcons.trash);
              }
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return DraggableSheetContainer(
        backgroundColor: AppColors.background,
        onDismissed: () => Navigator.of(context).pop(),
        builder: (ctx) => const SizedBox(
          height: 300,
          child: Center(child: CupertinoActivityIndicator(radius: 14)),
        ),
      );
    }

    final inst = _installment;
    if (inst == null) {
      return DraggableSheetContainer(
        backgroundColor: AppColors.background,
        onDismissed: () => Navigator.of(context).pop(),
        builder: (ctx) => const SizedBox(
          height: 200,
          child: Center(
            child: Text('Data cicilan tidak ditemukan', style: TextStyle(color: AppColors.textMuted)),
          ),
        ),
      );
    }

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return DraggableSheetContainer(
      backgroundColor: AppColors.background,
      onDismissed: () => Navigator.of(context).pop(),
      builder: (ctx) => DefaultTextStyle(
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
              child: const Text('Tutup', style: AppTypography.actionButton),
            ),
            middle: const Text('Detail Cicilan', style: AppTypography.navTitle),
            trailing: widget.onOpenDetail != null
                ? CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: widget.onOpenDetail,
                    child: const Text('Detail Lengkap', style: AppTypography.actionButton),
                  )
                : null,
          ),
          child: SafeArea(
            top: false,
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(0, 8, 0, bottomInset + 80),
              children: [
                // Section 1: INFORMASI BARANG
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
                      title: const Text('Nama Barang', style: TextStyle(fontSize: 15, color: AppColors.textDark)),
                      additionalInfo: Text(
                        inst.itemName.replaceAll('_', ' '),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textDark),
                      ),
                    ),
                    if (inst.storeName != null && inst.storeName!.trim().isNotEmpty)
                      CupertinoListTile(
                        leading: const SquircleIcon(
                          icon: CupertinoIcons.bag_fill,
                          color: Color(0xFFFF9500),
                        ),
                        title: const Text('Toko / Vendor', style: TextStyle(fontSize: 15, color: AppColors.textDark)),
                        additionalInfo: Text(
                          inst.storeName!.replaceAll('_', ' '),
                          style: const TextStyle(fontSize: 15, color: AppColors.textDark),
                        ),
                      ),
                    CupertinoListTile(
                      leading: SquircleIcon(
                        icon: inst.isPaidOff ? CupertinoIcons.checkmark_seal_fill : CupertinoIcons.clock_fill,
                        color: inst.isPaidOff ? const Color(0xFF34C759) : AppColors.primaryPink,
                      ),
                      title: const Text('Status Pelunasan', style: TextStyle(fontSize: 15, color: AppColors.textDark)),
                      trailing: Container(
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
                            color: inst.isPaidOff ? const Color(0xFF1E824C) : AppColors.deepPinkText,
                          ),
                        ),
                      ),
                    ),
                    if (inst.dueDate != null)
                      CupertinoListTile(
                        leading: const SquircleIcon(
                          icon: CupertinoIcons.calendar,
                          color: Color(0xFF5856D6),
                        ),
                        title: const Text('Jatuh Tempo', style: TextStyle(fontSize: 15, color: AppColors.textDark)),
                        additionalInfo: Text(
                          _formatDate(inst.dueDate!),
                          style: const TextStyle(fontSize: 15, color: AppColors.textDark),
                        ),
                      ),
                  ],
                ),

                // Section 2: RINGKASAN PEMBAYARAN
                CupertinoListSection.insetGrouped(
                  backgroundColor: AppColors.background,
                  header: const Text('RINGKASAN PEMBAYARAN'),
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  children: [
                    CupertinoListTile(
                      leading: const SquircleIcon(
                        icon: CupertinoIcons.tag_fill,
                        color: Color(0xFF007AFF),
                      ),
                      title: const Text('Total Harga', style: TextStyle(fontSize: 15, color: AppColors.textDark)),
                      additionalInfo: Text(
                        _formatCurrency(inst.totalCost),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textDark),
                      ),
                    ),
                    CupertinoListTile(
                      leading: const SquircleIcon(
                        icon: CupertinoIcons.arrow_down_circle_fill,
                        color: AppColors.primaryPink,
                      ),
                      title: const Text('Sudah Terbayar', style: TextStyle(fontSize: 15, color: AppColors.textDark)),
                      additionalInfo: Text(
                        _formatCurrency(inst.totalPaid),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryPink,
                        ),
                      ),
                    ),
                    CupertinoListTile(
                      leading: SquircleIcon(
                        icon: CupertinoIcons.money_dollar_circle_fill,
                        color: inst.isPaidOff ? const Color(0xFF34C759) : const Color(0xFFFF3B30),
                      ),
                      title: const Text('Sisa Tagihan', style: TextStyle(fontSize: 15, color: AppColors.textDark)),
                      additionalInfo: Text(
                        _formatCurrency(inst.remainingBalance),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: inst.isPaidOff ? const Color(0xFF34C759) : const Color(0xFFFF3B30),
                        ),
                      ),
                    ),
                  ],
                ),

                // Action button: + Catat Pembayaran
                if (!inst.isPaidOff)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: SizedBox(
                      width: double.infinity,
                      child: CupertinoButton(
                        color: AppColors.primaryPink,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        borderRadius: BorderRadius.circular(12),
                        onPressed: _showAddPaymentSheet,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(CupertinoIcons.creditcard_fill, color: CupertinoColors.white, size: 18),
                            SizedBox(width: 8),
                            Text(
                              '+ Catat Pembayaran',
                              style: TextStyle(
                                color: CupertinoColors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Section 3: RIWAYAT CICILAN
                CupertinoListSection.insetGrouped(
                  backgroundColor: AppColors.background,
                  header: const Text('RIWAYAT CICILAN'),
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  children: [
                    if (_logs.isEmpty)
                      const CupertinoListTile(
                        title: Text(
                          'Belum ada catatan pembayaran cicilan.',
                          style: TextStyle(fontSize: 14, color: Color(0xFF8E8E93)),
                        ),
                      )
                    else
                      ..._logs.map((log) {
                        final hasNote = log.notes != null && log.notes!.trim().isNotEmpty;
                        return CupertinoListTile(
                          leading: const SquircleIcon(
                            icon: CupertinoIcons.checkmark_alt,
                            color: AppColors.primaryPink,
                          ),
                          title: Text(
                            _formatCurrency(log.amountPaid),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                          ),
                          subtitle: hasNote
                              ? Text(
                                  log.notes!.trim(),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF8E8E93),
                                    fontWeight: FontWeight.w500,
                                  ),
                                )
                              : null,
                          additionalInfo: Text(
                            _formatDate(log.paymentDate),
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF8E8E93),
                            ),
                          ),
                          trailing: CupertinoButton(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(44, 44),
                            onPressed: () => _confirmDeleteLog(log),
                            child: const Icon(
                              CupertinoIcons.trash,
                              size: 16,
                              color: AppColors.dangerRose,
                            ),
                          ),
                        );
                      }),
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
