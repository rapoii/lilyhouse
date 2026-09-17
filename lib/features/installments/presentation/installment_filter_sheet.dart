import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/draggable_sheet_container.dart';
import '../../../core/widgets/squircle_icon.dart';
import '../domain/installment.dart';

/// Authentic Apple HIG Inset-Grouped Modal Sheet for filtering and sorting installments.
class InstallmentFilterSheet extends StatefulWidget {
  final InstallmentStatus? initialStatus;
  final String initialSortBy;
  final bool initialDueSoon;
  final void Function({
    required InstallmentStatus? status,
    required String sortBy,
    required bool dueSoon,
  }) onApply;

  const InstallmentFilterSheet({
    super.key,
    this.initialStatus,
    this.initialSortBy = 'due_date_asc',
    this.initialDueSoon = false,
    required this.onApply,
  });

  @override
  State<InstallmentFilterSheet> createState() => _InstallmentFilterSheetState();
}

class _InstallmentFilterSheetState extends State<InstallmentFilterSheet> {
  InstallmentStatus? _selectedStatus;
  late String _selectedSortBy;
  late bool _dueSoon;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.initialStatus;
    _selectedSortBy = widget.initialSortBy;
    _dueSoon = widget.initialDueSoon;
  }

  void _select(VoidCallback fn) {
    try {
      HapticFeedback.selectionClick();
    } catch (_) {}
    setState(fn);
  }

  void _resetFilters() {
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}
    setState(() {
      _selectedStatus = null;
      _selectedSortBy = 'due_date_asc';
      _dueSoon = false;
    });
  }

  void _apply() {
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}
    widget.onApply(
      status: _selectedStatus,
      sortBy: _selectedSortBy,
      dueSoon: _dueSoon,
    );
    Navigator.of(context).pop();
  }

  Widget _buildCheckmark(bool selected) {
    if (!selected) return const SizedBox.shrink();
    return const Icon(
      CupertinoIcons.checkmark,
      color: AppColors.primaryPink,
      size: 18,
      weight: 700,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return DraggableSheetContainer(
      backgroundColor: AppColors.background,
      onDismissed: () => Navigator.of(context).pop(),
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
              minimumSize: const Size(44, 44),
              onPressed: _resetFilters,
              child: const Text('Atur Ulang', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.deepPinkText)),
            ),
            middle: const SizedBox(
              width: double.infinity,
              child: Center(
                child: Text('Filter & Urutkan', style: AppTypography.navTitle),
              ),
            ),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(44, 44),
              onPressed: _apply,
              child: const Text('Terapkan', style: AppTypography.actionButton),
            ),
          ),
          child: SafeArea(
            top: false,
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(0, 8, 0, bottomInset + 40),
              physics: const BouncingScrollPhysics(),
              children: [
                // Section 1: Status Cicilan
                CupertinoListSection.insetGrouped(
                  header: const Text(
                    'STATUS CICILAN',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                  ),
                  backgroundColor: AppColors.background,
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  children: [
                    CupertinoListTile(
                      leading: const SquircleIcon(icon: CupertinoIcons.layers_alt_fill, color: Color(0xFF8E8E93)),
                      title: const Text('Semua Status', style: TextStyle(fontSize: 15, color: AppColors.textDark)),
                      trailing: _buildCheckmark(_selectedStatus == null),
                      onTap: () => _select(() => _selectedStatus = null),
                    ),
                    CupertinoListTile(
                      leading: const SquircleIcon(icon: CupertinoIcons.clock_fill, color: Color(0xFFFF9500)),
                      title: const Text('Sedang Berjalan', style: TextStyle(fontSize: 15, color: AppColors.textDark)),
                      trailing: _buildCheckmark(_selectedStatus == InstallmentStatus.ongoing),
                      onTap: () => _select(() => _selectedStatus = InstallmentStatus.ongoing),
                    ),
                    CupertinoListTile(
                      leading: const SquircleIcon(icon: CupertinoIcons.checkmark_seal_fill, color: Color(0xFF34C759)),
                      title: const Text('Sudah Lunas', style: TextStyle(fontSize: 15, color: AppColors.textDark)),
                      trailing: _buildCheckmark(_selectedStatus == InstallmentStatus.paidOff),
                      onTap: () => _select(() => _selectedStatus = InstallmentStatus.paidOff),
                    ),
                  ],
                ),

                // Section 2: Prioritas - Jatuh Tempo Dekat
                CupertinoListSection.insetGrouped(
                  header: const Text(
                    'PRIORITAS',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                  ),
                  backgroundColor: AppColors.background,
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  children: [
                    CupertinoListTile(
                      leading: const SquircleIcon(
                        icon: CupertinoIcons.exclamationmark_bubble_fill,
                        color: Color(0xFFFF9500),
                      ),
                      title: const Text(
                        'Jatuh Tempo Dekat',
                        style: TextStyle(fontSize: 15, color: AppColors.textDark),
                      ),
                      additionalInfo: Text(
                        '<= 7 hari',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: _dueSoon ? AppColors.deepPinkText : AppColors.textSecondary,
                        ),
                      ),
                      trailing: CupertinoSwitch(
                        key: const Key('filter_due_soon_switch'),
                        value: _dueSoon,
                        activeTrackColor: AppColors.primaryPink,
                        onChanged: (value) => _select(() => _dueSoon = value),
                      ),
                    ),
                  ],
                ),

                // Section 3: Urutkan Berdasarkan
                CupertinoListSection.insetGrouped(
                  header: const Text(
                    'URUTKAN BERDASARKAN',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                  ),
                  backgroundColor: AppColors.background,
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  children: [
                    CupertinoListTile(
                      leading: const SquircleIcon(icon: CupertinoIcons.calendar_today, color: AppColors.primaryPink),
                      title: const Text('Jatuh Tempo Terdekat (Bawaan)', style: TextStyle(fontSize: 15, color: AppColors.textDark)),
                      trailing: _buildCheckmark(_selectedSortBy == 'due_date_asc'),
                      onTap: () => _select(() => _selectedSortBy = 'due_date_asc'),
                    ),
                    CupertinoListTile(
                      leading: const SquircleIcon(icon: CupertinoIcons.creditcard_fill, color: Color(0xFFFF3B30)),
                      title: const Text('Sisa Tagihan Terbanyak', style: TextStyle(fontSize: 15, color: AppColors.textDark)),
                      trailing: _buildCheckmark(_selectedSortBy == 'balance_desc'),
                      onTap: () => _select(() => _selectedSortBy = 'balance_desc'),
                    ),
                    CupertinoListTile(
                      leading: const SquircleIcon(icon: CupertinoIcons.arrow_up_right_circle_fill, color: Color(0xFF5856D6)),
                      title: const Text('Total Biaya Tertinggi', style: TextStyle(fontSize: 15, color: AppColors.textDark)),
                      trailing: _buildCheckmark(_selectedSortBy == 'cost_desc'),
                      onTap: () => _select(() => _selectedSortBy = 'cost_desc'),
                    ),
                    CupertinoListTile(
                      leading: const SquircleIcon(icon: CupertinoIcons.textformat_abc, color: Color(0xFF007AFF)),
                      title: const Text('Nama Barang (A-Z)', style: TextStyle(fontSize: 15, color: AppColors.textDark)),
                      trailing: _buildCheckmark(_selectedSortBy == 'name_asc'),
                      onTap: () => _select(() => _selectedSortBy = 'name_asc'),
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
