import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/draggable_sheet_container.dart';
import '../../../core/widgets/squircle_icon.dart';
import '../data/costume_repository.dart';
import '../domain/costume.dart';

/// Authentic Apple HIG Inset-Grouped Modal Sheet for filtering and sorting costumes.
class CostumeFilterSheet extends StatefulWidget {
  final ICostumeRepository repository;
  final String? initialSeries;
  final CostumeStatus? initialStatus;
  final String? initialSize;
  final String initialSortBy;
  final void Function({
    required String? series,
    required CostumeStatus? status,
    required String? size,
    required String sortBy,
  }) onApply;

  const CostumeFilterSheet({
    super.key,
    required this.repository,
    this.initialSeries,
    this.initialStatus,
    this.initialSize,
    this.initialSortBy = 'name_asc',
    required this.onApply,
  });

  @override
  State<CostumeFilterSheet> createState() => _CostumeFilterSheetState();
}

class _CostumeFilterSheetState extends State<CostumeFilterSheet> {
  String? _selectedSeries;
  CostumeStatus? _selectedStatus;
  String? _selectedSize;
  late String _selectedSortBy;

  List<String> _availableSeries = [];
  bool _isLoadingSeries = true;

  @override
  void initState() {
    super.initState();
    _selectedSeries = widget.initialSeries;
    _selectedStatus = widget.initialStatus;
    _selectedSize = widget.initialSize;
    _selectedSortBy = widget.initialSortBy;
    _loadSeries();
  }

  Future<void> _loadSeries() async {
    try {
      final list = await widget.repository.getDistinctAnimeSeries();
      if (mounted) {
        setState(() {
          _availableSeries = list;
          _isLoadingSeries = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingSeries = false);
      }
    }
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
      _selectedSeries = null;
      _selectedStatus = null;
      _selectedSize = null;
      _selectedSortBy = 'name_asc';
    });
  }

  void _apply() {
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}
    widget.onApply(
      series: _selectedSeries,
      status: _selectedStatus,
      size: _selectedSize,
      sortBy: _selectedSortBy,
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
                // Section 1: Kategori / Seri Anime
                CupertinoListSection.insetGrouped(
                  header: const Text(
                    'KATEGORI / SERI ANIME',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                  ),
                  backgroundColor: AppColors.background,
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  children: [
                    CupertinoListTile(
                      leading: const SquircleIcon(icon: CupertinoIcons.sparkles, color: AppColors.primaryPink),
                      title: const Text('Semua Kategori', style: TextStyle(fontSize: 15, color: AppColors.textDark)),
                      trailing: _buildCheckmark(_selectedSeries == null),
                      onTap: () => _select(() => _selectedSeries = null),
                    ),
                    if (_isLoadingSeries)
                      const CupertinoListTile(
                        title: Center(
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: CupertinoActivityIndicator(radius: 8),
                          ),
                        ),
                      )
                    else
                      ..._availableSeries.map((series) {
                        final isSelected = _selectedSeries == series;
                        return CupertinoListTile(
                          leading: const SquircleIcon(icon: CupertinoIcons.tv, color: Color(0xFF5856D6)),
                          title: Text(
                            series,
                            style: TextStyle(
                              fontSize: 15,
                              color: isSelected ? AppColors.deepPinkText : AppColors.textDark,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                          trailing: _buildCheckmark(isSelected),
                          onTap: () => _select(() => _selectedSeries = series),
                        );
                      }),
                  ],
                ),

                // Section 2: Status Ketersediaan
                CupertinoListSection.insetGrouped(
                  header: const Text(
                    'STATUS KETERSEDIAAN',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                  ),
                  backgroundColor: AppColors.background,
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  children: [
                    CupertinoListTile(
                      leading: const SquircleIcon(icon: CupertinoIcons.layers_alt_fill, color: Color(0xFF8E8E93)),
                      title: const Text('Semua Status', style: TextStyle(fontSize: 15, color: AppColors.textDark)),
                      trailing: _buildCheckmark(_selectedStatus == null),
                      onTap: () => _select(() => _selectedStatus = null),
                    ),
                    CupertinoListTile(
                      leading: const SquircleIcon(icon: CupertinoIcons.checkmark_circle_fill, color: AppColors.badgeSuccessText),
                      title: const Text('Tersedia', style: TextStyle(fontSize: 15, color: AppColors.textDark)),
                      trailing: _buildCheckmark(_selectedStatus == CostumeStatus.available),
                      onTap: () => _select(() => _selectedStatus = CostumeStatus.available),
                    ),
                    CupertinoListTile(
                      leading: const SquircleIcon(icon: CupertinoIcons.bookmark_fill, color: AppColors.textAmber),
                      title: const Text('Dipesan', style: TextStyle(fontSize: 15, color: AppColors.textDark)),
                      trailing: _buildCheckmark(_selectedStatus == CostumeStatus.booked),
                      onTap: () => _select(() => _selectedStatus = CostumeStatus.booked),
                    ),
                    CupertinoListTile(
                      leading: const SquircleIcon(icon: CupertinoIcons.arrow_right_circle_fill, color: AppColors.primaryPink),
                      title: const Text('Sedang Disewa', style: TextStyle(fontSize: 15, color: AppColors.textDark)),
                      subtitle: const Text(
                        'Kostum sedang dalam masa sewa aktif',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      trailing: _buildCheckmark(_selectedStatus == CostumeStatus.rented),
                      onTap: () => _select(() => _selectedStatus = CostumeStatus.rented),
                    ),
                    CupertinoListTile(
                      leading: const SquircleIcon(icon: CupertinoIcons.drop_fill, color: Color(0xFF2563EB)),
                      title: const Text('Dicuci', style: TextStyle(fontSize: 15, color: AppColors.textDark)),
                      trailing: _buildCheckmark(_selectedStatus == CostumeStatus.laundry),
                      onTap: () => _select(() => _selectedStatus = CostumeStatus.laundry),
                    ),
                    CupertinoListTile(
                      leading: const SquircleIcon(icon: CupertinoIcons.wrench_fill, color: AppColors.dangerRose),
                      title: const Text('Perawatan', style: TextStyle(fontSize: 15, color: AppColors.textDark)),
                      trailing: _buildCheckmark(_selectedStatus == CostumeStatus.maintenance),
                      onTap: () => _select(() => _selectedStatus = CostumeStatus.maintenance),
                    ),
                  ],
                ),

                // Section 3: Ukuran Kostum
                CupertinoListSection.insetGrouped(
                  header: const Text(
                    'UKURAN KOSTUM',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                  ),
                  backgroundColor: AppColors.background,
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  children: [
                    CupertinoListTile(
                      leading: const SquircleIcon(icon: CupertinoIcons.tag_fill, color: Color(0xFFFF9500)),
                      title: const Text('Semua Ukuran', style: TextStyle(fontSize: 15, color: AppColors.textDark)),
                      trailing: _buildCheckmark(_selectedSize == null || _selectedSize == 'All'),
                      onTap: () => _select(() => _selectedSize = null),
                    ),
                    ...['S', 'M', 'L', 'XL', 'All Size', 'Custom'].map((sz) {
                      final isSelected = _selectedSize == sz;
                      return CupertinoListTile(
                        leading: const SquircleIcon(icon: CupertinoIcons.tag, color: Color(0xFF8E8E93)),
                        title: Text(
                          sz,
                          style: TextStyle(
                            fontSize: 15,
                            color: isSelected ? AppColors.deepPinkText : AppColors.textDark,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                        trailing: _buildCheckmark(isSelected),
                        onTap: () => _select(() => _selectedSize = sz),
                      );
                    }),
                  ],
                ),

                // Section 4: Urutkan
                CupertinoListSection.insetGrouped(
                  header: const Text(
                    'URUTKAN BERDASARKAN',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                  ),
                  backgroundColor: AppColors.background,
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  children: [
                    CupertinoListTile(
                      leading: const SquircleIcon(icon: CupertinoIcons.sort_down, color: Color(0xFF007AFF)),
                      title: const Text('Nama Kostum (A - Z)', style: TextStyle(fontSize: 15, color: AppColors.textDark)),
                      trailing: _buildCheckmark(_selectedSortBy == 'name_asc'),
                      onTap: () => _select(() => _selectedSortBy = 'name_asc'),
                    ),
                    CupertinoListTile(
                      leading: const SquircleIcon(icon: CupertinoIcons.sort_up, color: Color(0xFF007AFF)),
                      title: const Text('Nama Kostum (Z - A)', style: TextStyle(fontSize: 15, color: AppColors.textDark)),
                      trailing: _buildCheckmark(_selectedSortBy == 'name_desc'),
                      onTap: () => _select(() => _selectedSortBy = 'name_desc'),
                    ),
                    CupertinoListTile(
                      leading: const SquircleIcon(icon: CupertinoIcons.money_dollar_circle_fill, color: Color(0xFF34C759)),
                      title: const Text('Tarif Sewa (Termurah)', style: TextStyle(fontSize: 15, color: AppColors.textDark)),
                      trailing: _buildCheckmark(_selectedSortBy == 'price_asc'),
                      onTap: () => _select(() => _selectedSortBy = 'price_asc'),
                    ),
                    CupertinoListTile(
                      leading: const SquircleIcon(icon: CupertinoIcons.money_dollar_circle, color: Color(0xFFFF9500)),
                      title: const Text('Tarif Sewa (Termahal)', style: TextStyle(fontSize: 15, color: AppColors.textDark)),
                      trailing: _buildCheckmark(_selectedSortBy == 'price_desc'),
                      onTap: () => _select(() => _selectedSortBy = 'price_desc'),
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
