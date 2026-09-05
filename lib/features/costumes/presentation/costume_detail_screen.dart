import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../data/costume_repository.dart';
import '../domain/costume.dart';
import '../domain/accessory.dart';

class CostumeDetailScreen extends StatefulWidget {
  final Costume costume;
  final ICostumeRepository? repository;

  const CostumeDetailScreen({
    super.key,
    required this.costume,
    this.repository,
  });

  @override
  State<CostumeDetailScreen> createState() => _CostumeDetailScreenState();
}

class _CostumeDetailScreenState extends State<CostumeDetailScreen> {
  late ICostumeRepository _repository;
  List<Accessory> _accessories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? CostumeRepository();
    _loadAccessories();
  }

  Future<void> _loadAccessories() async {
    final list = await _repository.getAccessoriesByCostumeId(widget.costume.id);
    if (mounted) {
      setState(() {
        _accessories = list;
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

  (Color bg, Color text, String label) _getStatusBadgeData(CostumeStatus status) {
    switch (status) {
      case CostumeStatus.available:
        return (const Color(0xFFE3F9EC), const Color(0xFF1E824C), 'Available');
      case CostumeStatus.booked:
        return (const Color(0xFFFFF4E5), const Color(0xFFD97706), 'Booked');
      case CostumeStatus.rented:
        return (const Color(0xFFFFEBF0), AppColors.primaryPink, 'Rented');
      case CostumeStatus.laundry:
        return (const Color(0xFFE8F1FF), const Color(0xFF2563EB), 'Laundry');
      case CostumeStatus.maintenance:
        return (const Color(0xFFFDE8E8), AppColors.dangerRose, 'Maintenance');
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusData = _getStatusBadgeData(widget.costume.status);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.costume.name,
          style: const TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.maybePop(context),
          child: const Icon(CupertinoIcons.chevron_back, color: AppColors.textDark, size: 24),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Preview Header Card
            Container(
              width: double.infinity,
              height: 220,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28.0),
                border: Border.all(color: AppColors.borderSubtle, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.pastelPink.withValues(alpha: 0.12),
                    blurRadius: 16.0,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28.0),
                child: widget.costume.coverPhoto != null && widget.costume.coverPhoto!.isNotEmpty
                    ? Image.asset(
                        widget.costume.coverPhoto!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Center(
                          child: Icon(CupertinoIcons.sparkles, size: 48, color: AppColors.primaryPink),
                        ),
                      )
                    : const Center(
                        child: Icon(CupertinoIcons.sparkles, size: 48, color: AppColors.primaryPink),
                      ),
              ),
            ),
            const SizedBox(height: 20),

            // Info Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24.0),
                border: Border.all(color: AppColors.borderSubtle, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.costume.name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.costume.animeSeries,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusData.$1,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          statusData.$3,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: statusData.$2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: AppColors.borderSubtle),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildPillAttribute('Size', widget.costume.size),
                      _buildPillAttribute(
                        'Rental Rate',
                        '${_formatCurrency(widget.costume.rentPrice3Days)} / 3d',
                        highlight: true,
                      ),
                    ],
                  ),
                  if (widget.costume.notes != null && widget.costume.notes!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Notes',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.costume.notes!,
                      style: const TextStyle(fontSize: 14, color: AppColors.textDark),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Accessories Section
            const Text(
              'Included Accessories & Props',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 12),

            if (_isLoading)
              const Center(child: CupertinoActivityIndicator(radius: 14))
            else if (_accessories.isEmpty && widget.costume.includedAccessories.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: const Text(
                  'No specific accessories recorded for this costume.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              )
            else ...[
              // Registered Accessory objects from DB
              ..._accessories.map((acc) => _buildAccessoryRow(acc.name, acc.type, acc.conditionStatus.name)),
              // Legacy strings list in includedAccessories
              ...widget.costume.includedAccessories
                  .where((accStr) => !_accessories.any((a) => a.name.toLowerCase() == accStr.toLowerCase()))
                  .map((accStr) => _buildAccessoryRow(accStr, 'Set Piece', 'good')),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPillAttribute(String label, String value, {bool highlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: highlight ? AppColors.softPinkBg : AppColors.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: highlight ? AppColors.primaryPink.withValues(alpha: 0.3) : AppColors.borderSubtle,
            ),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: highlight ? AppColors.primaryPink : AppColors.textDark,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAccessoryRow(String name, String type, String condition) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.softPinkBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(CupertinoIcons.star_fill, color: AppColors.primaryPink, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textDark),
                ),
                Text(
                  type,
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Text(
              condition.toUpperCase(),
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}
