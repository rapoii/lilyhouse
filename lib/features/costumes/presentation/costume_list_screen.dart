import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/apple_sliding_segmented_control.dart';
import '../data/costume_repository.dart';
import '../domain/costume.dart';
import 'widgets/costume_card.dart';
import 'costume_detail_screen.dart';
import 'add_costume_sheet.dart';

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
  CostumeStatus? _selectedStatus;
  String? _selectedSize;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? CostumeRepository();
    _fetchCostumes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchCostumes() async {
    setState(() => _isLoading = true);
    final results = await _repository.searchCostumes(
      query: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
      status: _selectedStatus,
      size: (_selectedSize == null || _selectedSize == 'All') ? null : _selectedSize,
    );
    if (mounted) {
      setState(() {
        _costumes = results;
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String _) {
    _fetchCostumes();
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
          Padding(
            padding: const EdgeInsets.only(right: 14.0),
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              onPressed: _showAddCostumeSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.add,
                      size: 15,
                      color: AppColors.primaryPink,
                    ),
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
          // Search & Filter header container
          Container(
            color: AppColors.background,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Column(
              children: [
                // True iOS HIG Search Field
                Container(
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
                      hintText: 'Cari kostum atau seri anime',
                      hintStyle: const TextStyle(color: Color(0xFF8E8E93), fontSize: 15),
                      prefixIcon: const Icon(CupertinoIcons.search, color: Color(0xFF8E8E93), size: 18),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                _searchController.clear();
                                _fetchCostumes();
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
                const SizedBox(height: 12),
                // Filter status - Full width iOS draggable segmented control
                AppleSlidingSegmentedControl<String>(
                  groupValue: _selectedStatus?.name ?? 'all',
                  height: 36.0,
                  fontSize: 12.5,
                  items: const [
                    SegmentItem(value: 'all', label: 'Semua'),
                    SegmentItem(value: 'available', label: 'Tersedia'),
                    SegmentItem(value: 'booked', label: 'Dibooking'),
                    SegmentItem(value: 'rented', label: 'Disewa'),
                  ],
                  onValueChanged: (val) {
                    setState(() {
                      if (val == 'all') {
                        _selectedStatus = null;
                      } else {
                        _selectedStatus = CostumeStatus.values.firstWhere((e) => e.name == val);
                      }
                    });
                    _fetchCostumes();
                  },
                ),
                const SizedBox(height: 8),
                // Filter ukuran - Full width iOS draggable segmented control
                AppleSlidingSegmentedControl<String>(
                  groupValue: _selectedSize ?? 'All',
                  height: 32.0,
                  fontSize: 12.0,
                  items: const [
                    SegmentItem(value: 'All', label: 'Semua'),
                    SegmentItem(value: 'S', label: 'S'),
                    SegmentItem(value: 'M', label: 'M'),
                    SegmentItem(value: 'L', label: 'L'),
                    SegmentItem(value: 'XL', label: 'XL'),
                  ],
                  onValueChanged: (val) {
                    setState(() {
                      _selectedSize = val == 'All' ? null : val;
                    });
                    _fetchCostumes();
                  },
                ),
              ],
            ),
          ),

          // Costume List Content
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CupertinoActivityIndicator(radius: 14),
                  )
                : _costumes.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: const BoxDecoration(
                                color: Color(0xFFE5E5EA), // iOS systemGray5
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                CupertinoIcons.sparkles,
                                size: 36,
                                color: Color(0xFF8E8E93), // iOS secondaryLabel
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Belum ada kostum',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Sesuaikan kata kunci pencarian atau filter status',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
                        itemCount: _costumes.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final costume = _costumes[index];
                          return CostumeCard(
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
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
