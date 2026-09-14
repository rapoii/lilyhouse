import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/draggable_sheet_container.dart';
import '../../../../core/widgets/ios_toast.dart';
import '../../../../core/widgets/sheet_picker.dart';
import '../../../../core/widgets/squircle_icon.dart';
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
  DateTime _selectedDate = DateTime.now();

  static const _months = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
  ];

  String _formatDate(DateTime dt) => '${dt.day} ${_months[dt.month]} ${dt.year}';

  String _formatCurrency(double amount) {
    final parts = amount.toInt().toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
    return 'Rp $parts';
  }

  void _showAlert(String title, String message) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Oke', style: TextStyle(color: AppColors.primaryPink, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (amount <= 0) {
      _showAlert('Nominal Tidak Valid', 'Masukkan jumlah pembayaran yang valid lebih dari Rp 0.');
      return;
    }

    final log = InstallmentLog(
      id: 'log_${DateTime.now().millisecondsSinceEpoch}',
      installmentId: widget.installment.id,
      paymentDate: _selectedDate,
      amountPaid: amount,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );

    await widget.repository.addPaymentLog(log);
    if (!mounted) return;
    Navigator.of(context).pop();
    widget.onSaved();
    IosToast.show(context, 'Pembayaran ${_formatCurrency(amount)} berhasil dicatat');
  }

  @override
  Widget build(BuildContext context) {
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
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal', style: TextStyle(fontSize: 15, color: AppColors.primaryPink)),
            ),
            middle: const Text('Catat Pembayaran Cicilan', style: AppTypography.navTitle),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _submit,
              child: const Text('Simpan', style: AppTypography.actionButton),
            ),
          ),
          child: SafeArea(
            top: false,
            child: ListView(
              padding: EdgeInsets.fromLTRB(0, 12, 0, bottomInset + 32),
              physics: const BouncingScrollPhysics(),
              children: [
                // Info Summary Card (target cicilan)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Container(
                    padding: const EdgeInsets.all(14.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.installment.itemName,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark),
                              ),
                              if (widget.installment.storeName != null)
                                Text(
                                  widget.installment.storeName!,
                                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                                ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Sisa Tagihan', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                            Text(
                              _formatCurrency(widget.installment.remainingBalance),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primaryPink),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Quick Pay Remaining Button
                if (widget.installment.remainingBalance > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        setState(() {
                          _amountController.text = widget.installment.remainingBalance.toInt().toString();
                          if (_notesController.text.isEmpty) {
                            _notesController.text = 'Pelunasan Akhir';
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.softPinkBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.pastelPink),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(CupertinoIcons.sparkles, size: 14, color: AppColors.primaryPink),
                            const SizedBox(width: 6),
                            Text(
                              'Isi Nominal Sisa Tagihan (${_formatCurrency(widget.installment.remainingBalance)})',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryPink),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Form Section
                CupertinoListSection.insetGrouped(
                  backgroundColor: AppColors.background,
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  children: [
                    CupertinoListTile(
                      leading: const SquircleIcon(
                        icon: CupertinoIcons.money_dollar,
                        color: AppColors.primaryPink,
                      ),
                      title: Row(
                        children: [
                          const SizedBox(
                            width: 100,
                            child: Text('Jumlah Bayar', style: TextStyle(fontSize: 15, color: AppColors.textDark)),
                          ),
                          Expanded(
                            child: CupertinoTextField(
                              key: const Key('payment_amount_input'),
                              controller: _amountController,
                              textAlign: TextAlign.right,
                              placeholder: '0 (Rp)',
                              placeholderStyle: const TextStyle(color: Color(0xFFC7C7CC), fontSize: 15),
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textDark),
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
                      leading: const SquircleIcon(
                        icon: CupertinoIcons.calendar,
                        color: Color(0xFF007AFF),
                      ),
                      title: const Text('Tanggal Bayar', style: TextStyle(fontSize: 15, color: AppColors.textDark)),
                      additionalInfo: Text(
                        _formatDate(_selectedDate),
                        style: const TextStyle(fontSize: 15, color: AppColors.textDark),
                      ),
                      trailing: const Icon(CupertinoIcons.chevron_right, size: 14, color: Color(0xFFC7C7CC)),
                      onTap: () async {
                        final picked = await showSheetDatePicker(
                          context: context,
                          title: 'Pilih Tanggal Bayar',
                          initialDate: _selectedDate,
                          maximumDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setState(() => _selectedDate = picked);
                        }
                      },
                    ),
                    CupertinoListTile(
                      leading: const SquircleIcon(
                        icon: CupertinoIcons.doc_text,
                        color: Color(0xFF8E8E93),
                      ),
                      title: Row(
                        children: [
                          const SizedBox(
                            width: 100,
                            child: Text('Catatan', style: TextStyle(fontSize: 15, color: AppColors.textDark)),
                          ),
                          Expanded(
                            child: CupertinoTextField(
                              key: const Key('payment_notes_input'),
                              controller: _notesController,
                              textAlign: TextAlign.right,
                              placeholder: 'Misal: Cicilan ke-2',
                              placeholderStyle: const TextStyle(color: Color(0xFFC7C7CC), fontSize: 15),
                              style: const TextStyle(fontSize: 15, color: AppColors.textDark),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: null,
                            ),
                          ),
                        ],
                      ),
                    ),
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
