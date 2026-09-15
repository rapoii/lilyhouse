import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/sync/sync_manager.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/animated_list_item.dart';
import '../../../core/widgets/header_action_button.dart';
import '../../../core/widgets/state_crossfade.dart';
import '../data/costume_repository.dart';
import '../domain/costume.dart';
import 'widgets/costume_card.dart';
import 'costume_detail_screen.dart';
import 'add_costume_sheet.dart';
import 'costume_filter_sheet.dart';

class CostumeListScreen extends StatefulWidget {
  final ICostumeRepository? repository;

  const CostumeListScreen({
    super.key,
    this.repository,
  });

  @override
  State<CostumeListScreen> createState() => _CostumeListScreenState();
}

class _CostumeListScreenState extends State<CostumeListScreen> {
  late ICostumeRepository _repository;
  final TextEditingController _searchController = TextEditingController();

  List<Costume> _costumes = [];
  bool _isLoading = true;
  UniqueKey _listKey = UniqueKey();
  CostumeStatus? _selectedStatus;
  String? _selectedSize;
  String? _selectedSeries;
  String _selectedSortBy = 'name_asc';

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? CostumeRepository();
    _fetchCostumes();
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
      _fetchCostumes();
    }
  }

  Future<void> _fetchCostumes() async {
    setState(() => _isLoading = true);
    final results = await _repository.searchCostumes(
      query: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
      status: _selectedStatus,
      size: (_selectedSize == null || _selectedSize == 'All') ? null : _selectedSize,
      series: _selectedSeries,
      sortBy: _selectedSortBy,
    );
    if (mounted) {
      setState(() {
        _costumes = results;
        _isLoading = false;
        _listKey = UniqueKey();
      });
    }
  }

  void _onSearchChanged(String _) {
    _fetchCostumes();
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
      builder: (BuildContext sheetCtx) {
        return CostumeFilterSheet(
          repository: _repository,
          initialSeries: _selectedSeries,
          initialStatus: _selectedStatus,
          initialSize: _selectedSize,
          initialSortBy: _selectedSortBy,
          onApply: ({
            required String? series,
            required CostumeStatus? status,
            required String? size,
            required String sortBy,
          }) {
            setState(() {
              _selectedSeries = series;
              _selectedStatus = status;
              _selectedSize = size;
              _selectedSortBy = sortBy;
            });
            _fetchCostumes();
          },
        );
      },
    );
  }

  String _getSortLabel(String sort) {
    switch (sort) {
      case 'name_desc':
        return 'Nama (Z-A)';
      case 'price_asc':
        return 'Harga Termurah';
      case 'price_desc':
        return 'Harga Termahal';
      default:
        return 'Nama (A-Z)';
    }
  }

  String _getStatusLabel(CostumeStatus status) {
    switch (status) {
      case CostumeStatus.available:
        return 'Tersedia';
      case CostumeStatus.booked:
        return 'Dibooking';
      case CostumeStatus.rented:
        return 'Disewa';
      case CostumeStatus.laundry:
        return 'Dicuci';
      case CostumeStatus.maintenance:
        return 'Perawatan';
    }
  }

  Widget _buildFilterButton() {
    final bool hasActiveFilter = _selectedSeries != null ||
        _selectedStatus != null ||
        _selectedSize != null ||
        _selectedSortBy != 'name_asc';
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
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

  // iOS Modal Presentation Sheet for adding a new costume
  // Uses showCupertinoModalPopup (Apple HIG: modal sheet wrapping content perfectly)
  Future<void> _showAddCostumeSheet() async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext sheetCtx) {
        return AddCostumeSheet(
          repository: _repository,
          onSaved: _fetchCostumes,
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
        title: const Text(
          'Katalog Kostum',
          style: AppTypography.largeTitle,
        ),
        centerTitle: false,
        actions: [
          HeaderActionButton(
            label: 'Tambah',
            icon: CupertinoIcons.add,
            onPressed: _showAddCostumeSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter header container
          Container(
            color: AppColors.background,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Column(
              children: [
                // True iOS HIG Search Field + Filter Button
                Row(
                  children: [
                    Expanded(
                      child: CupertinoSearchTextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        placeholder: 'Cari kostum atau seri anime',
                        style: const TextStyle(fontSize: 15, color: Colors.black87),
                        placeholderStyle: const TextStyle(color: Color(0xFF8E8E93), fontSize: 15),
                        onSuffixTap: () {
                          try {
                            HapticFeedback.lightImpact();
                          } catch (_) {}
                          _searchController.clear();
                          _fetchCostumes();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterButton(),
                  ],
                ),
                if (_selectedSeries != null ||
                    _selectedStatus != null ||
                    _selectedSize != null ||
                    _selectedSortBy != 'name_asc') ...[
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        if (_selectedSeries != null)
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.softPinkBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.pastelPink),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(CupertinoIcons.tv, size: 12, color: AppColors.primaryPink),
                                const SizedBox(width: 5),
                                Text(
                                  _selectedSeries!,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryPink),
                                ),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () {
                                    setState(() => _selectedSeries = null);
                                    _fetchCostumes();
                                  },
                                  child: const Icon(CupertinoIcons.clear_circled_solid, size: 14, color: AppColors.primaryPink),
                                ),
                              ],
                            ),
                          ),
                        if (_selectedStatus != null)
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F8F0),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFA3E6C4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(CupertinoIcons.check_mark_circled_solid, size: 12, color: Color(0xFF1E824C)),
                                const SizedBox(width: 5),
                                Text(
                                  _getStatusLabel(_selectedStatus!),
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E824C)),
                                ),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () {
                                    setState(() => _selectedStatus = null);
                                    _fetchCostumes();
                                  },
                                  child: const Icon(CupertinoIcons.clear_circled_solid, size: 14, color: Color(0xFF1E824C)),
                                ),
                              ],
                            ),
                          ),
                        if (_selectedSize != null)
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF4E5),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFFFD199)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(CupertinoIcons.tag_fill, size: 12, color: Color(0xFFD97706)),
                                const SizedBox(width: 5),
                                Text(
                                  'Size ${_selectedSize!}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFD97706)),
                                ),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () {
                                    setState(() => _selectedSize = null);
                                    _fetchCostumes();
                                  },
                                  child: const Icon(CupertinoIcons.clear_circled_solid, size: 14, color: Color(0xFFD97706)),
                                ),
                              ],
                            ),
                          ),
                        if (_selectedSortBy != 'name_asc')
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
                                  onTap: () {
                                    setState(() => _selectedSortBy = 'name_asc');
                                    _fetchCostumes();
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

          // Costume List Content
          Expanded(
            child: StateCrossfade(
              isLoading: _isLoading,
              isEmpty: _costumes.isEmpty,
              loadingChild: const Center(
                child: CupertinoActivityIndicator(radius: 14),
              ),
              emptyChild: Column(
                // Flex-based optical centering: content at 1/3 from
                // top of available area (Apple HIG empty-state
                // position). Same device-agnostic pattern as Cicilan
                // for visual consistency across empty states.
                children: [
                  const Spacer(flex: 5),
                  Center(
                    child: Builder(
                      builder: (context) {
                        final hasFilterOrQuery = _searchController.text.trim().isNotEmpty ||
                            _selectedSeries != null ||
                            _selectedStatus != null ||
                            _selectedSize != null ||
                            _selectedSortBy != 'name_asc';
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
                                hasFilterOrQuery ? CupertinoIcons.search : CupertinoIcons.sparkles,
                                size: 36,
                                color: AppColors.primaryPink,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              hasFilterOrQuery ? 'Tidak ada hasil yang cocok' : 'Belum ada kostum',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              hasFilterOrQuery
                                  ? 'Coba sesuaikan kata kunci atau filter pencarian'
                                  : 'Tambahkan kostum pertama ke katalog LilyHouse',
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
                                    _selectedSeries = null;
                                    _selectedStatus = null;
                                    _selectedSize = null;
                                    _selectedSortBy = 'name_asc';
                                  });
                                  _fetchCostumes();
                                },
                                child: const Text(
                                  'Atur Ulang Pencarian',
                                  style: TextStyle(color: AppColors.primaryPink, fontSize: 13, fontWeight: FontWeight.w600),
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
                                  _showAddCostumeSheet();
                                },
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(CupertinoIcons.plus, size: 14, color: AppColors.primaryPink),
                                    SizedBox(width: 6),
                                    Text(
                                      'Tambah Kostum',
                                      style: TextStyle(color: AppColors.primaryPink, fontSize: 13, fontWeight: FontWeight.w600),
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
              contentChild: ListView.separated(
                key: _listKey,
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 160),
                itemCount: _costumes.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final costume = _costumes[index];
                  return AnimatedListItem(
                    index: index,
                    child: CostumeCard(
                      costume: costume,
                      onTap: () {
                        Navigator.push(
                          context,
                          CupertinoPageRoute(
                            builder: (_) => CostumeDetailScreen(
                              costume: costume,
                              repository: _repository,
                            ),
                          ),
                        ).then((_) => _fetchCostumes());
                      },
                    ),
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
