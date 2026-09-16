import 'package:flutter/cupertino.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/ios_toast.dart';
import '../../../../core/widgets/squircle_icon.dart';
import '../data/installment_repository.dart';
import '../domain/installment.dart';
import '../domain/installment_log.dart';
import 'widgets/add_payment_sheet.dart';
import 'widgets/edit_installment_sheet.dart';

class InstallmentDetailScreen extends StatefulWidget {
  final String installmentId;
  final IInstallmentRepository repository;

  const InstallmentDetailScreen({
    super.key,
    required this.installmentId,
    required this.repository,
  });

  @override
  State<InstallmentDetailScreen> createState() => _InstallmentDetailScreenState();
}

class _InstallmentDetailScreenState extends State<InstallmentDetailScreen> {
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
        onSaved: _fetchDetails,
      ),
    );
  }

  Future<void> _showEditInstallmentSheet() async {
    final inst = _installment;
    if (inst == null) return;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => EditInstallmentSheet(
        installment: inst,
        repository: widget.repository,
        onSaved: _fetchDetails,
      ),
    );
  }

  void _confirmDeleteInstallment(Installment inst) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Hapus Cicilan?'),
        content: Text('Apakah Anda yakin ingin menghapus data cicilan "${inst.itemName}" beserta riwayat pembayarannya?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: AppColors.textDark)),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              await widget.repository.deleteInstallment(inst.id);
              if (!mounted) return;
              IosToast.show(context, 'Cicilan "${inst.itemName}" berhasil dihapus', icon: CupertinoIcons.trash);
              Navigator.pop(context);
            },
            child: const Text('Hapus'),
          ),
        ],
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
      return const CupertinoPageScaffold(
        backgroundColor: AppColors.background,
        child: Center(child: CupertinoActivityIndicator(radius: 14)),
      );
    }

    final inst = _installment;
    if (inst == null) {
      return CupertinoPageScaffold(
        backgroundColor: AppColors.background,
        navigationBar: CupertinoNavigationBar(
          backgroundColor: AppColors.background,
          middle: const Text('Detail Cicilan', style: AppTypography.navTitle),
          leading: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => Navigator.maybePop(context),
            child: const Icon(CupertinoIcons.chevron_back, color: AppColors.textDark, size: 24),
          ),
        ),
        child: const Center(child: Text('Data cicilan tidak ditemukan')),
      );
    }

    final percent = (inst.progress * 100).toInt();

    return DefaultTextStyle(
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
            onPressed: () => Navigator.maybePop(context),
            child: const Icon(CupertinoIcons.chevron_back, color: AppColors.textDark, size: 24),
          ),
          middle: const Text('Detail Cicilan', style: AppTypography.navTitle),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoButton(
                key: const Key('edit_installment_button'),
                padding: EdgeInsets.zero,
                onPressed: _showEditInstallmentSheet,
                child: const Text('Ubah', style: AppTypography.actionButton),
              ),
              const SizedBox(width: 8),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => _confirmDeleteInstallment(inst),
                child: const Icon(CupertinoIcons.trash, color: AppColors.dangerRose, size: 20),
              ),
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 180),
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
                      decoration: TextDecoration.none,
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
              CupertinoListTile(
                leading: const SquircleIcon(
                  icon: CupertinoIcons.chart_bar_alt_fill,
                  color: Color(0xFF34C759),
                ),
                title: const Text('Progress Pelunasan', style: TextStyle(fontSize: 15, color: AppColors.textDark)),
                additionalInfo: Text(
                  '$percent%',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: inst.isPaidOff ? const Color(0xFF34C759) : AppColors.primaryPink,
                  ),
                ),
              ),
            ],
          ),

          // Action button: + Catat Pembayaran / Lunas
          if (inst.isPaidOff)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F9EC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF34C759).withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.checkmark_seal_fill, color: Color(0xFF1E824C), size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Cicilan Sudah Lunas',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.none,
                        color: Color(0xFF1E824C),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
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

          // Section 3: RIWAYAT PEMBAYARAN
          CupertinoListSection.insetGrouped(
            backgroundColor: AppColors.background,
            header: Text('RIWAYAT PEMBAYARAN (${_logs.length})'),
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            children: [
              if (_logs.isEmpty)
                const CupertinoListTile(
                  title: Text(
                    'Belum ada riwayat pembayaran.',
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
    );
  }
}
