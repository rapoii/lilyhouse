import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/ios_toast.dart';
import '../../../../core/widgets/sheet_picker.dart';
import '../../data/installment_repository.dart';
import '../../domain/installment.dart';
import '../../domain/installment_log.dart';

class AddPaymentSheet extends StatefulWidget {
  final Installment installment;
  final IInstallmentRepository repository;
  final VoidCallback onSaved;

  const AddPaymentSheet({
    super.key,
    required this.installment,
    required this.repository,
    required this.onSaved,
  });

  @override
  State<AddPaymentSheet> createState() => _AddPaymentSheetState();
}

class _AddPaymentSheetState extends State<AddPaymentSheet> {
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _amountFocusNode = FocusNode();
  final _notesFocusNode = FocusNode();

  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;
  String? _errorMessage;

  List<InstallmentLog> _logs = const [];
  bool _isLoadingLogs = true;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_onAmountChanged);
    _loadPaymentHistory();
  }

  Future<void> _loadPaymentHistory() async {
    try {
      final logs = await widget.repository.getLogsForInstallment(widget.installment.id);
      if (mounted) {
        setState(() {
          _logs = logs..sort((a, b) => b.paymentDate.compareTo(a.paymentDate));
          _isLoadingLogs = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingLogs = false);
      }
    }
  }

  @override
  void dispose() {
    _amountController.removeListener(_onAmountChanged);
    _amountController.dispose();
    _notesController.dispose();
    _amountFocusNode.dispose();
    _notesFocusNode.dispose();
    super.dispose();
  }

  void _onAmountChanged() {
    if (_errorMessage != null) {
      setState(() {
        _errorMessage = null;
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
    final now = DateTime.now();
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final formatted = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    if (isToday) {
      return '$formatted (Hari ini)';
    }
    return formatted;
  }

  Widget _buildSummaryRow(String label, String value, IconData icon, Color color, {Key? key}) {
    return Row(
      key: key,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    FocusScope.of(context).unfocus();
    final picked = await showSheetDatePicker(
      context: context,
      title: 'Pilih Tanggal Bayar',
      initialDate: _selectedDate,
      minimumDate: DateTime(2020, 1, 1),
      maximumDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _applyPayInFull() {
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}
    FocusScope.of(context).unfocus();

    final remaining = widget.installment.remainingBalance;
    final intRemaining = remaining.toInt();
    final parts = intRemaining.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );

    setState(() {
      _amountController.text = parts;
      _errorMessage = null;
    });
  }

  Future<void> _savePayment() async {
    final rawAmountText = _amountController.text.trim().replaceAll('.', '').replaceAll(',', '');
    final amount = double.tryParse(rawAmountText);

    if (amount == null || amount <= 0) {
      setState(() {
        _errorMessage = 'Nominal pembayaran tidak valid';
      });
      return;
    }

    // Pencegahan overpayment: nominal bayar tidak boleh melebihi sisa utang
    final remaining = widget.installment.remainingBalance;
    if (amount > (remaining + 0.01)) {
      setState(() {
        _errorMessage = 'Nominal melebihi sisa utang (${_formatCurrency(remaining)})';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final log = InstallmentLog(
        id: 'log_${DateTime.now().millisecondsSinceEpoch}',
        installmentId: widget.installment.id,
        paymentDate: _selectedDate,
        amountPaid: amount,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      await widget.repository.addPaymentLog(log);

      if (mounted) {
        widget.onSaved();
        Navigator.of(context).pop();
        IosToast.show(context, 'Pembayaran berhasil dicatat', icon: CupertinoIcons.checkmark_alt);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal menyimpan: $e';
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final remaining = widget.installment.remainingBalance;
    final isOverdue = widget.installment.isOverdue;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header bar
              Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.borderSubtle,
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(44, 44),
                      onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                      child: const Text(
                        'Batal',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const Text(
                      'Catat Pembayaran Cicilan',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(44, 44),
                      onPressed: _isSaving ? null : _savePayment,
                      child: _isSaving
                          ? const CupertinoActivityIndicator(radius: 10)
                          : const Text(
                              'Simpan',
                              style: TextStyle(
                                color: AppColors.primaryPink,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ],
                ),
              ),

              // Body content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Item Name & Remaining summary badge
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isOverdue
                                ? const Color(0xFFFF3B30).withValues(alpha: 0.5)
                                : AppColors.borderSubtle,
                            width: isOverdue ? 1.2 : 0.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.installment.itemName,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Sisa Utang Saat Ini',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                                Text(
                                  _formatCurrency(remaining),
                                  key: const Key('add_payment_remaining_text'),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: isOverdue ? const Color(0xFFFF3B30) : AppColors.primaryPink,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Progress bar pembayaran berjalan
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                key: const Key('add_payment_progress_bar'),
                                value: widget.installment.progress.clamp(0.0, 1.0),
                                minHeight: 6,
                                backgroundColor: AppColors.softPinkBg,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  widget.installment.isPaidOff
                                      ? AppColors.successMint
                                      : AppColors.primaryPink,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Sudah dibayar ${(widget.installment.progress * 100).clamp(0, 100).round()}% dari total',
                                  key: const Key('add_payment_progress_label'),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                                Text(
                                  '${_logs.length}x pembayaran',
                                  key: const Key('add_payment_log_count'),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),

                            // Peringatan keterlambatan
                            if (widget.installment.isOverdue) ...[
                              const SizedBox(height: 12),
                              Container(
                                key: const Key('add_payment_overdue_warning'),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFEFEF),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFFF3B30), width: 1),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      CupertinoIcons.exclamationmark_triangle_fill,
                                      size: 15,
                                      color: Color(0xFFFF3B30),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Terlambat ${widget.installment.daysUntilDue()?.abs() ?? 0} hari',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFFC62828),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          const Text(
                                            'Tanggal jatuh tempo telah terlewati. Segera catat pembayaran untuk menghindari denda.',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFFC62828),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // Ringkasan pembayaran berjalan
                            if (_isLoadingLogs)
                              const Padding(
                                padding: EdgeInsets.only(top: 12),
                                child: Center(
                                  child: CupertinoActivityIndicator(radius: 10),
                                ),
                              )
                            else if (_logs.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              const Divider(height: 1, color: AppColors.borderSubtle),
                              const SizedBox(height: 10),
                              _buildSummaryRow(
                                'Pembayaran Terakhir',
                                '${_formatCurrency(_logs.first.amountPaid)} \u00b7 ${_formatDate(_logs.first.paymentDate)}',
                                CupertinoIcons.checkmark_alt,
                                AppColors.primaryPink,
                                key: const Key('add_payment_last_payment'),
                              ),
                              const SizedBox(height: 8),
                              _buildSummaryRow(
                                'Rata-rata / Bayar',
                                _formatCurrency(widget.installment.averagePayment(_logs)),
                                CupertinoIcons.equal_circle,
                                const Color(0xFF5856D6),
                                key: const Key('add_payment_average'),
                              ),
                              const SizedBox(height: 8),
                              _buildSummaryRow(
                                'Estimasi Sisa Cicilan',
                                widget.installment.estimatedRemainingPayments(_logs) != null
                                    ? '${widget.installment.estimatedRemainingPayments(_logs)}x lagi'
                                    : '-',
                                CupertinoIcons.number_circle,
                                const Color(0xFFFF9500),
                                key: const Key('add_payment_estimated_remaining'),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Input section
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.borderSubtle,
                            width: 0.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Nominal input with "Bayar Lunas" shortcut button
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Nominal Pembayaran',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                      if (remaining > 0)
                                        CupertinoButton(
                                          key: const Key('shortcut_pay_in_full_button'),
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          minimumSize: const Size(32, 28),
                                          color: AppColors.primaryPink.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(16),
                                          onPressed: _applyPayInFull,
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                CupertinoIcons.checkmark_seal_fill,
                                                size: 13,
                                                color: AppColors.primaryPink,
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                'Bayar Lunas',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.primaryPink,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  CupertinoTextField(
                                    key: const Key('payment_amount_input'),
                                    controller: _amountController,
                                    focusNode: _amountFocusNode,
                                    placeholder: 'Contoh: 100.000',
                                    prefix: const Padding(
                                      padding: EdgeInsets.only(left: 12),
                                      child: Text(
                                        'Rp ',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textDark,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textDark,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.background,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              height: 0.5,
                              color: AppColors.borderSubtle,
                            ),

                            // Tanggal Pembayaran Row (Tappable for Date Picker)
                            CupertinoButton(
                              key: const Key('payment_date_picker_button'),
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(44, 44),
                              onPressed: _pickDate,
                              child: Container(
                                constraints: const BoxConstraints(minHeight: 48),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(
                                          CupertinoIcons.calendar,
                                          size: 18,
                                          color: AppColors.textMuted,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Tanggal Bayar',
                                          style: TextStyle(
                                            fontSize: 15,
                                            color: AppColors.textDark,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          _formatDate(_selectedDate),
                                          key: const Key('payment_date_value_text'),
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.primaryPink,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(
                                          CupertinoIcons.chevron_right,
                                          size: 14,
                                          color: AppColors.textMuted,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Container(
                              height: 0.5,
                              color: AppColors.borderSubtle,
                            ),

                            // Catatan Input
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Catatan (Opsional)',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  CupertinoTextField(
                                    key: const Key('payment_notes_input'),
                                    controller: _notesController,
                                    focusNode: _notesFocusNode,
                                    placeholder: 'Contoh: Cicilan ke-2, transfer BCA',
                                    maxLines: 2,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      color: AppColors.textDark,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.background,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (_errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Row(
                            children: [
                              const Icon(
                                CupertinoIcons.exclamationmark_circle_fill,
                                size: 14,
                                color: CupertinoColors.systemRed,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  key: const Key('payment_error_message'),
                                  style: const TextStyle(
                                    color: CupertinoColors.systemRed,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
