import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/database/db_helper.dart';
import '../../../core/sync/sync_state_notifier.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/draggable_sheet_container.dart';
import '../../../core/widgets/ios_toast.dart';
import '../../../core/widgets/squircle_icon.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _cacheSizeText = '';

  @override
  void initState() {
    super.initState();
    _calculateCacheSize();
  }

  String _formatBytes(int totalBytes) {
    if (totalBytes <= 0) return '0 B';
    if (totalBytes < 1024) {
      return '$totalBytes B';
    } else if (totalBytes < 1024 * 1024) {
      return '${(totalBytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  Future<void> _calculateCacheSize() async {
    try {
      final tempDir = await getTemporaryDirectory();
      if (!tempDir.existsSync()) {
        if (mounted) setState(() => _cacheSizeText = '0 B');
        return;
      }
      int totalBytes = 0;
      final entities = tempDir.listSync(recursive: true);
      for (final entity in entities) {
        if (entity is File) {
          totalBytes += entity.lengthSync();
        }
      }
      if (mounted) {
        setState(() {
          _cacheSizeText = _formatBytes(totalBytes);
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cacheSizeText = '0 B');
    }
  }

  void _showIosToast(String message, {IconData icon = CupertinoIcons.checkmark_circle_fill}) {
    IosToast.show(context, message, icon: icon);
  }

  Future<void> _handleSync() async {
    HapticFeedback.selectionClick();
    final result = await ref.read(syncStateProvider.notifier).syncNow();
    if (!mounted) return;
    if (result.isSuccess) {
      _showIosToast(
        result.syncedCount > 0
            ? 'Sinkronisasi berhasil: ${result.syncedCount} item terkirim'
            : 'Data sudah mutakhir dengan cloud',
      );
    } else {
      _showIosToast(
        result.errorMessage ?? 'Gagal melakukan sinkronisasi',
        icon: CupertinoIcons.exclamationmark_circle_fill,
      );
    }
  }

  Future<void> _handleRestore() async {
    HapticFeedback.selectionClick();
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Pulihkan dari Cloud?'),
        content: const Text(
          'Seluruh data lokal akan diganti dengan data dari cloud. '
          'Data offline yang belum disinkronkan akan hilang. '
          'Gunakan ini setelah install ulang aplikasi.',
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Pulihkan Data'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    HapticFeedback.mediumImpact();
    final result = await ref.read(syncStateProvider.notifier).restoreNow();
    if (!mounted) return;
    if (result.isSuccess) {
      _showIosToast('Pemulihan berhasil: ${result.totalCount} data dari cloud');
    } else {
      _showIosToast(
        result.errorMessage ?? 'Gagal memulihkan dari cloud',
        icon: CupertinoIcons.exclamationmark_circle_fill,
      );
    }
  }



  void _showPendingQueueSheet() {
    HapticFeedback.selectionClick();
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => DraggableSheetContainer(
        backgroundColor: AppColors.background,
        onDismissed: () => Navigator.of(ctx).pop(),
        initialHeightFraction: 0.75,
        maxHeightFraction: 0.9,
        builder: (sheetCtx) => DefaultTextStyle(
          style: const TextStyle(
            decoration: TextDecoration.none,
            fontFamily: '.SF Pro Text',
            color: AppColors.textDark,
          ),
          child: CupertinoPageScaffold(
            backgroundColor: AppColors.background,
            navigationBar: CupertinoNavigationBar(
              automaticallyImplyLeading: false,
              backgroundColor: AppColors.background,
              border: const Border(bottom: BorderSide(color: Color(0xFFE5E5EA), width: 0.5)),
              middle: const Text('Antrean Offline', style: AppTypography.navTitle),
              trailing: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.pop(sheetCtx),
                child: const Text('Tutup', style: AppTypography.actionButton),
              ),
            ),
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: DatabaseHelper.instance.getPendingSyncItems(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CupertinoActivityIndicator());
                }
                final items = snapshot.data ?? [];
                if (items.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: const Color(0xFF34C759).withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              CupertinoIcons.checkmark_seal_fill,
                              color: Color(0xFF34C759),
                              size: 36,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Semua Data Tersinkron',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Tidak ada antrean tertunda. Seluruh perubahan lokal telah aman tersimpan di cloud Google Apps Script.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF8E8E93),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    CupertinoListSection.insetGrouped(
                      header: Text('${items.length} ITEM MENUNGGU SINKRONISASI'),
                      backgroundColor: Colors.transparent,
                      margin: EdgeInsets.zero,
                      children: items.map((item) {
                        final table = item['table_name'] as String? ?? 'Data';
                        final action = item['action'] as String? ?? 'update';
                        final createdAt = item['created_at'] as String?;
                        final formattedTime = createdAt != null
                            ? DateFormat('d MMM, HH:mm').format(DateTime.tryParse(createdAt) ?? DateTime.now())
                            : '-';

                        return CupertinoListTile(
                          leading: const SquircleIcon(
                            icon: CupertinoIcons.tray_arrow_up_fill,
                            color: Color(0xFFFF9500),
                          ),
                          title: Text(
                            '$table ($action)',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                          subtitle: Text(
                            'ID: ${item['record_id'] ?? '-'}',
                            style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                          ),
                          additionalInfo: Text(
                            formattedTime,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    CupertinoButton.filled(
                      onPressed: () {
                        Navigator.pop(sheetCtx);
                        _handleSync();
                      },
                      child: const Text('Sinkronkan Sekarang', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }



  void _showDatabaseStatsSheet() {
    HapticFeedback.selectionClick();
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => DraggableSheetContainer(
        backgroundColor: AppColors.background,
        onDismissed: () => Navigator.of(ctx).pop(),
        initialHeightFraction: 0.65,
        maxHeightFraction: 0.8,
        builder: (sheetCtx) => DefaultTextStyle(
          style: const TextStyle(
            decoration: TextDecoration.none,
            fontFamily: '.SF Pro Text',
            color: AppColors.textDark,
          ),
          child: CupertinoPageScaffold(
            backgroundColor: AppColors.background,
            navigationBar: CupertinoNavigationBar(
              automaticallyImplyLeading: false,
              backgroundColor: AppColors.background,
              border: const Border(bottom: BorderSide(color: Color(0xFFE5E5EA), width: 0.5)),
              middle: const Text('Statistik Database', style: AppTypography.navTitle),
              trailing: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.pop(sheetCtx),
                child: const Text('Tutup', style: AppTypography.actionButton),
              ),
            ),
            child: FutureBuilder<Map<String, dynamic>>(
              future: () async {
                final counts = await DatabaseHelper.instance.getTableCounts();
                final dbBytes = await DatabaseHelper.instance.getDatabaseFileSize();
                return {
                  'counts': counts,
                  'dbBytes': dbBytes,
                };
              }(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CupertinoActivityIndicator());
                }
                final data = snapshot.data ?? {};
                final counts = (data['counts'] as Map<String, int>?) ?? {};
                final dbBytes = (data['dbBytes'] as int?) ?? 0;
                return ListView(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  children: [
                    CupertinoListSection.insetGrouped(
                      header: const Text('RINGKASAN DATA LOKAL (SQLITE)'),
                      backgroundColor: Colors.transparent,
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      children: [
                        CupertinoListTile(
                          leading: const SquircleIcon(
                            icon: CupertinoIcons.tag_fill,
                            color: Color(0xFFFF9500),
                          ),
                          title: const Text('Katalog Kostum', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                          additionalInfo: Text(
                            '${counts['costumes'] ?? 0} item',
                            style: const TextStyle(fontSize: 15, color: Color(0xFF8E8E93)),
                          ),
                        ),
                        CupertinoListTile(
                          leading: const SquircleIcon(
                            icon: CupertinoIcons.calendar,
                            color: AppColors.primaryPink,
                          ),
                          title: const Text('Pesanan Rental', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                          additionalInfo: Text(
                            '${counts['rentals'] ?? 0} pesanan',
                            style: const TextStyle(fontSize: 15, color: Color(0xFF8E8E93)),
                          ),
                        ),
                        CupertinoListTile(
                          leading: const SquircleIcon(
                            icon: CupertinoIcons.person_2_fill,
                            color: Color(0xFF007AFF),
                          ),
                          title: const Text('Pelanggan Terdaftar', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                          additionalInfo: Text(
                            '${counts['customers'] ?? 0} orang',
                            style: const TextStyle(fontSize: 15, color: Color(0xFF8E8E93)),
                          ),
                        ),
                        CupertinoListTile(
                          leading: const SquircleIcon(
                            icon: CupertinoIcons.creditcard_fill,
                            color: Color(0xFF34C759),
                          ),
                          title: const Text('Transaksi Cicilan', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                          additionalInfo: Text(
                            '${counts['installments'] ?? 0} tagihan',
                            style: const TextStyle(fontSize: 15, color: Color(0xFF8E8E93)),
                          ),
                        ),
                      ],
                    ),
                    CupertinoListSection.insetGrouped(
                      header: const Text('INFORMASI FILE STORAGE'),
                      backgroundColor: Colors.transparent,
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      children: [
                        const CupertinoListTile(
                          leading: SquircleIcon(
                            icon: CupertinoIcons.circle_grid_hex_fill,
                            color: Color(0xFF5856D6),
                          ),
                          title: Text('Database Engine', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                          additionalInfo: Text('SQLite v3.x', style: TextStyle(fontSize: 15, color: Color(0xFF8E8E93))),
                        ),
                        const CupertinoListTile(
                          leading: SquircleIcon(
                            icon: CupertinoIcons.folder_fill,
                            color: Color(0xFF8E8E93),
                          ),
                          title: Text('Nama Berkas', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                          additionalInfo: Text('lilyhouse.db', style: TextStyle(fontSize: 15, color: Color(0xFF8E8E93))),
                        ),
                        CupertinoListTile(
                          leading: const SquircleIcon(
                            icon: CupertinoIcons.tray_full_fill,
                            color: Color(0xFF34C759),
                          ),
                          title: const Text('Ukuran Berkas', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                          additionalInfo: Text(_formatBytes(dbBytes), style: const TextStyle(fontSize: 15, color: Color(0xFF8E8E93))),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _showClearCacheDialog() {
    HapticFeedback.selectionClick();
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Bersihkan Cache Gambar?'),
        content: const Text(
          'File cache thumbnail dan memori sementara akan dibersihkan. '
          'Data kostum, foto tersimpan, dan catatan booking tidak akan terhapus.',
        ),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final tempDir = await getTemporaryDirectory();
                if (tempDir.existsSync()) {
                  final entities = tempDir.listSync();
                  for (final entity in entities) {
                    try {
                      entity.deleteSync(recursive: true);
                    } catch (_) {}
                  }
                }
                await _calculateCacheSize();
                _showIosToast('Cache gambar berhasil dibersihkan');
              } catch (_) {
                _showIosToast('Gagal membersihkan cache', icon: CupertinoIcons.exclamationmark_circle_fill);
              }
            },
            child: const Text('Bersihkan Cache'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
        ],
      ),
    );
  }

  void _showAboutSheet() {
    HapticFeedback.selectionClick();
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => DraggableSheetContainer(
        backgroundColor: AppColors.background,
        onDismissed: () => Navigator.of(ctx).pop(),
        initialHeightFraction: 0.65,
        maxHeightFraction: 0.8,
        builder: (sheetCtx) => DefaultTextStyle(
          style: const TextStyle(
            decoration: TextDecoration.none,
            fontFamily: '.SF Pro Text',
            color: AppColors.textDark,
          ),
          child: CupertinoPageScaffold(
            backgroundColor: AppColors.background,
            navigationBar: CupertinoNavigationBar(
              automaticallyImplyLeading: false,
              backgroundColor: AppColors.background,
              border: const Border(bottom: BorderSide(color: Color(0xFFE5E5EA), width: 0.5)),
              middle: const Text('Tentang Aplikasi', style: AppTypography.navTitle),
              trailing: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.pop(sheetCtx),
                child: const Text('Tutup', style: AppTypography.actionButton),
              ),
            ),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              children: [
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.primaryPink,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33FF85A1),
                          blurRadius: 16,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(CupertinoIcons.heart_fill, color: Colors.white, size: 36),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Center(
                  child: Text(
                    'LilyHouse Rent',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Center(
                  child: Text(
                    'Versi 1.0.84',
                    style: TextStyle(fontSize: 14, color: Color(0xFF8E8E93)),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'Aplikasi manajemen rental kostum cosplay premium. '
                    'Mendukung pencatatan pesanan cerdas, kalender ketersediaan, '
                    'pelacakan cicilan pelanggan, serta sinkronisasi serverless '
                    'langsung ke Google Sheets.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: AppColors.textDark, height: 1.45),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: const [
                      SquircleIcon(
                        icon: CupertinoIcons.person_fill,
                        color: Color(0xFF007AFF),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Pemilik & Developer',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textDark),
                        ),
                      ),
                      Text(
                        'Rafi Permana',
                        style: TextStyle(fontSize: 15, color: Color(0xFF8E8E93), fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDesignSystemSheet() {
    HapticFeedback.selectionClick();
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => DraggableSheetContainer(
        backgroundColor: AppColors.background,
        onDismissed: () => Navigator.of(ctx).pop(),
        initialHeightFraction: 0.7,
        maxHeightFraction: 0.85,
        builder: (sheetCtx) => DefaultTextStyle(
          style: const TextStyle(
            decoration: TextDecoration.none,
            fontFamily: '.SF Pro Text',
            color: AppColors.textDark,
          ),
          child: CupertinoPageScaffold(
            backgroundColor: AppColors.background,
            navigationBar: CupertinoNavigationBar(
              automaticallyImplyLeading: false,
              backgroundColor: AppColors.background,
              border: const Border(bottom: BorderSide(color: Color(0xFFE5E5EA), width: 0.5)),
              middle: const Text('Apple HIG Specs', style: AppTypography.navTitle),
              trailing: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.pop(sheetCtx),
                child: const Text('Tutup', style: AppTypography.actionButton),
              ),
            ),
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                CupertinoListSection.insetGrouped(
                  header: Text('PRINSIP DESAIN APPLE HIG'),
                  backgroundColor: Colors.transparent,
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  children: [
                    CupertinoListTile(
                      leading: SquircleIcon(
                        icon: CupertinoIcons.textformat,
                        color: Color(0xFF5856D6),
                      ),
                      title: Text('Tipografi Native', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                      subtitle: Text('.SF Pro Text & Display dengan dynamic leading', style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93))),
                    ),
                    CupertinoListTile(
                      leading: SquircleIcon(
                        icon: CupertinoIcons.sparkles,
                        color: AppColors.primaryPink,
                      ),
                      title: Text('Warna Utama', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                      subtitle: Text('Primary Pink (#FF85A1) dengan iOS Vibrant accents', style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93))),
                    ),
                    CupertinoListTile(
                      leading: SquircleIcon(
                        icon: CupertinoIcons.square_fill_line_vertical_square,
                        color: Color(0xFF34C759),
                      ),
                      title: Text('Komponen Cupertino', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                      subtitle: Text('Modal popup, inset grouped list, squircle 6.5px', style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93))),
                    ),
                    CupertinoListTile(
                      leading: SquircleIcon(
                        icon: CupertinoIcons.speedometer,
                        color: Color(0xFFFF9500),
                      ),
                      title: Text('60 FPS Transitions', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                      subtitle: Text('Deferred wheel slider dengan HarfBuzz pre-warming', style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93))),
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

  void _showChangelogSheet() {
    HapticFeedback.selectionClick();
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => DraggableSheetContainer(
        backgroundColor: AppColors.background,
        onDismissed: () => Navigator.of(ctx).pop(),
        initialHeightFraction: 0.75,
        maxHeightFraction: 0.9,
        builder: (sheetCtx) => DefaultTextStyle(
          style: const TextStyle(
            decoration: TextDecoration.none,
            fontFamily: '.SF Pro Text',
            color: AppColors.textDark,
          ),
          child: CupertinoPageScaffold(
            backgroundColor: AppColors.background,
            navigationBar: CupertinoNavigationBar(
              automaticallyImplyLeading: false,
              backgroundColor: AppColors.background,
              border: const Border(bottom: BorderSide(color: Color(0xFFE5E5EA), width: 0.5)),
              middle: const Text('Catatan Rilis', style: AppTypography.navTitle),
              trailing: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.pop(sheetCtx),
                child: const Text('Tutup', style: AppTypography.actionButton),
              ),
            ),
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                CupertinoListSection.insetGrouped(
                  header: const Text('VERSI 1.0.84 (BUILD 119) - TERBARU'),
                  backgroundColor: Colors.transparent,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  children: const [
                    CupertinoListTile(
                      leading: SquircleIcon(
                        icon: CupertinoIcons.exclamationmark_triangle_fill,
                        color: AppColors.warningOrange,
                      ),
                      title: Text('Deteksi Konflik Sewa & Rincian Jadwal', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                      subtitle: Text(
                        'Dialog peringatan tabrakan booking kini mencantumkan nama penyewa yang bertabrakan dan rentang tanggal sewa secara langsung.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                      ),
                    ),
                    CupertinoListTile(
                      leading: SquircleIcon(
                        icon: CupertinoIcons.money_dollar,
                        color: Color(0xFF34C759),
                      ),
                      title: Text('Aksesibilitas Kontras WCAG AA & Input Form', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                      subtitle: Text(
                        'Peningkatan kontras teks status Disewa/Belum Lunas ke Deep Pink (5.8:1), prefix mata uang pada tarif kostum, tinggi modal bayar cicilan lebih ringkas, dan sanitasi string menyeluruh.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                      ),
                    ),
                  ],
                ),
                CupertinoListSection.insetGrouped(
                  header: const Text('VERSI 1.0.83 (BUILD 118)'),
                  backgroundColor: Colors.transparent,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  children: const [
                    CupertinoListTile(
                      leading: SquircleIcon(
                        icon: CupertinoIcons.sparkles,
                        color: AppColors.primaryPink,
                      ),
                      title: Text('Booking Smarter & Validasi Harga', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                      subtitle: Text(
                        'Pencocokan nama kostum otomatis menoleransi spasi/garis bawah, auto-fill tarif sewa, validasi wajib harga sewa minimal, dan pencegahan booking Rp 0.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                      ),
                    ),
                    CupertinoListTile(
                      leading: SquircleIcon(
                        icon: CupertinoIcons.slider_horizontal_3,
                        color: Color(0xFF34C759),
                      ),
                      title: Text('Penyempurnaan Modal & Diagnostik SQLite', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                      subtitle: Text(
                        'Eliminasi tombol navigasi ganda di semua modal settings, pemisahan zona bahaya pada lembar rental, diagnostik ukuran file database aktual, dan tinggi modal cicilan ergonomis.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                      ),
                    ),
                  ],
                ),
                CupertinoListSection.insetGrouped(
                  header: const Text('VERSI 1.0.82 (BUILD 117)'),
                  backgroundColor: Colors.transparent,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  children: const [
                    CupertinoListTile(
                      leading: SquircleIcon(
                        icon: CupertinoIcons.sparkles,
                        color: AppColors.primaryPink,
                      ),
                      title: Text('Sanitasi String & Filter Kategori', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                      subtitle: Text(
                        'Pembersihan format teks snake_case pada katalog dan cicilan, serta normalisasi filter seri anime agar pencarian lebih akurat.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                      ),
                    ),
                    CupertinoListTile(
                      leading: SquircleIcon(
                        icon: CupertinoIcons.money_dollar_circle_fill,
                        color: Color(0xFF34C759),
                      ),
                      title: Text('Konteks Finansial & Aksesibilitas WCAG', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                      subtitle: Text(
                        'Kartu cicilan kini menampilkan total harga barang, sinkronisasi live kalkulasi log pembayaran, indikator ukuran cache disk, dan peningkatan kontras tombol.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                      ),
                    ),
                  ],
                ),
                CupertinoListSection.insetGrouped(
                  header: const Text('VERSI 1.0.81 (BUILD 116)'),
                  backgroundColor: Colors.transparent,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  children: const [
                    CupertinoListTile(
                      leading: SquircleIcon(
                        icon: CupertinoIcons.calendar_badge_plus,
                        color: AppColors.primaryPink,
                      ),
                      title: Text('Kalender & Smart Paste Cepat', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                      subtitle: Text(
                        'Kartu booking kini menampilkan rentang tanggal sewa & durasi lengkap, indikator hari sewa berjalan, dan tombol cepat Tempel Klip untuk form WhatsApp otomatis.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                      ),
                    ),
                    CupertinoListTile(
                      leading: SquircleIcon(
                        icon: CupertinoIcons.sparkles,
                        color: Color(0xFF34C759),
                      ),
                      title: Text('Penyempurnaan UX Apple HIG', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                      subtitle: Text(
                        'Peningkatan kontras teks status cicilan, eliminasi checkmark ganda pada aksi rental, scroll margin bawah 180pt, dan perbaikan hierarki dialog iOS.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                      ),
                    ),
                  ],
                ),
                CupertinoListSection.insetGrouped(
                  header: const Text('VERSI 1.0.80 (BUILD 115)'),
                  backgroundColor: Colors.transparent,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  children: const [
                    CupertinoListTile(
                      leading: SquircleIcon(
                        icon: CupertinoIcons.calendar_today,
                        color: AppColors.primaryPink,
                      ),
                      title: Text('Booking Conflict Exemption', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                      subtitle: Text(
                        'Kostum yang sudah berstatus kembali atau selesai tidak lagi memicu bentrok jadwal sewa baru di kalender.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                      ),
                    ),
                    CupertinoListTile(
                      leading: SquircleIcon(
                        icon: CupertinoIcons.check_mark_circled_solid,
                        color: Color(0xFF34C759),
                      ),
                      title: Text('Presisi Pelunasan & Proteksi Data', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                      subtitle: Text(
                        'Toleransi floating point pada buku cicilan agar pelunasan 100% akurat, proteksi hapus pelanggan aktif, dan kueri rentang kalender langsung pada database.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                      ),
                    ),
                  ],
                ),
                CupertinoListSection.insetGrouped(
                  header: const Text('VERSI 1.0.79 (BUILD 114)'),
                  backgroundColor: Colors.transparent,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  children: const [
                    CupertinoListTile(
                      leading: SquircleIcon(
                        icon: CupertinoIcons.shield_lefthalf_fill,
                        color: AppColors.primaryPink,
                      ),
                      title: Text('Integritas Data & Proteksi Rental Aktif', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                      subtitle: Text(
                        'Pencegahan penghapusan kostum yang sedang memiliki jadwal sewa aktif atau booking kalender guna menjaga keutuhan relasi data.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                      ),
                    ),
                    CupertinoListTile(
                      leading: SquircleIcon(
                        icon: CupertinoIcons.bolt_fill,
                        color: Color(0xFFFF9500),
                      ),
                      title: Text('Performa Database & Navigasi Cepat', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                      subtitle: Text(
                        'Indeks pencarian SQLite untuk kalender dan katalog, navigasi langsung dari detail sewa ke kostum, serta eliminasi stutter rendering gambar.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                      ),
                    ),
                  ],
                ),
                CupertinoListSection.insetGrouped(
                  header: const Text('VERSI 1.0.78 (BUILD 113)'),
                  backgroundColor: Colors.transparent,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  children: const [
                    CupertinoListTile(
                      leading: SquircleIcon(
                        icon: CupertinoIcons.money_dollar_circle_fill,
                        color: AppColors.primaryPink,
                      ),
                      title: Text('Sanitasi Pemisah Ribuan & Guard Overpayment', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                      subtitle: Text(
                        'Format titik dan koma nominal rupiah (Rp) kini diproses sempurna tanpa terpotong desimal. Perlindungan kelebihan bayar cicilan dengan dialog konfirmasi.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                      ),
                    ),
                    CupertinoListTile(
                      leading: SquircleIcon(
                        icon: CupertinoIcons.calendar_today,
                        color: Color(0xFF007AFF),
                      ),
                      title: Text('Konteks Operasional Jadwal Kalender', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                      subtitle: Text(
                        'Lencana dinamis Apple HIG memperjelas status jadwal hari ini: Hari Ambil / Mulai Sewa vs Jatuh Tempo Pengembalian kostum.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                      ),
                    ),
                  ],
                ),
                CupertinoListSection.insetGrouped(
                  header: const Text('VERSI 1.0.77 (BUILD 112)'),
                  backgroundColor: Colors.transparent,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  children: const [
                    CupertinoListTile(
                      leading: SquircleIcon(
                        icon: CupertinoIcons.shield_fill,
                        color: AppColors.primaryPink,
                      ),
                      title: Text('Proteksi Data Finansial & Konfirmasi', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                      subtitle: Text(
                        'Pencegahan dobel simpan pembayaran cicilan, proteksi modal overlay settings, dan dialog konfirmasi untuk pelunasan serta pengembalian sewa.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                      ),
                    ),
                    CupertinoListTile(
                      leading: SquircleIcon(
                        icon: CupertinoIcons.hand_draw_fill,
                        color: Color(0xFF5856D6),
                      ),
                      title: Text('Penyempurnaan Taktil & Touch Target', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                      subtitle: Text(
                        'Touch target tombol hapus dan chip filter diperluas hingga 44pt Apple HIG, kurva animasi ProMotion 240fps, dan penanganan ramah izin kamera.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                      ),
                    ),
                  ],
                ),
                CupertinoListSection.insetGrouped(
                  header: const Text('VERSI 1.0.76 (BUILD 111)'),
                  backgroundColor: Colors.transparent,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  children: const [
                    CupertinoListTile(
                      leading: SquircleIcon(
                        icon: CupertinoIcons.person_crop_circle_badge_checkmark,
                        color: AppColors.primaryPink,
                      ),
                      title: Text('Deteksi Pelanggan Berulang Cerdas', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                      subtitle: Text(
                        'Saat memasukkan nomor WhatsApp pelanggan lama, sistem otomatis mengisi identitas, alamat, akun sosmed, dan menghubungkan KTP terverifikasi tanpa duplikasi data.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                      ),
                    ),
                    CupertinoListTile(
                      leading: SquircleIcon(
                        icon: CupertinoIcons.arrow_up_left_arrow_down_right,
                        color: Color(0xFF5856D6),
                      ),
                      title: Text('Penyelarasan Scroll Margin Detail', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                      subtitle: Text(
                        'Layar Detail Kostum dan Detail Cicilan kini memiliki bottom padding lapang 96pt agar nyaman dibaca dan tidak mepet dengan bilah gestur sistem Android.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                      ),
                    ),
                  ],
                ),
                CupertinoListSection.insetGrouped(
                  header: const Text('VERSI 1.0.75 (BUILD 110)'),
                  backgroundColor: Colors.transparent,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  children: const [
                    CupertinoListTile(
                      leading: SquircleIcon(
                        icon: CupertinoIcons.doc_on_doc_fill,
                        color: AppColors.primaryPink,
                      ),
                      title: Text('Alur Kerja Cepat Pemilik Rental', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                      subtitle: Text(
                        'Tombol salin satu ketukan untuk alamat pengiriman dan akun media sosial penyewa memudahkan pemesanan kurir (GoSend/JNE) tanpa ketik ulang.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                      ),
                    ),
                    CupertinoListTile(
                      leading: SquircleIcon(
                        icon: CupertinoIcons.money_dollar_circle_fill,
                        color: Color(0xFF34C759),
                      ),
                      title: Text('Auto-Fill Tarif Sewa & Notifikasi Presisi', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                      subtitle: Text(
                        'Memilih kostum pada booking kini otomatis mengisi total tarif sewa, serta konfirmasi perubahan status dan pelunasan sewa muncul tepat waktu.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                      ),
                    ),
                  ],
                ),
                CupertinoListSection.insetGrouped(
                  header: const Text('VERSI 1.0.74 (BUILD 109)'),
                  backgroundColor: Colors.transparent,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  children: const [
                    CupertinoListTile(
                      leading: SquircleIcon(
                        icon: CupertinoIcons.sparkles,
                        color: AppColors.primaryPink,
                      ),
                      title: Text('Empty State Cerdas & Interaktif', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                      subtitle: Text(
                        'Layar kosong pada Katalog, Cicilan, dan Kalender kini kontekstual dengan tombol aksi instan untuk menambah data atau mengatur ulang filter pencarian.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                      ),
                    ),
                    CupertinoListTile(
                      leading: SquircleIcon(
                        icon: CupertinoIcons.arrow_down_doc_fill,
                        color: Color(0xFF5856D6),
                      ),
                      title: Text('Keyboard Dismiss on Drag & Smart Paste Polish', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                      subtitle: Text(
                        'Keyboard otomatis tertutup saat menggulir form dan daftar sesuai standar iOS, serta form Smart Paste kini dilengkapi validasi input dan auto-unfocus.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                      ),
                    ),
                  ],
                ),
                CupertinoListSection.insetGrouped(
                  header: const Text('VERSI 1.0.73 (BUILD 108)'),
                  backgroundColor: Colors.transparent,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  children: const [
                    CupertinoListTile(
                      leading: SquircleIcon(
                        icon: CupertinoIcons.hand_draw_fill,
                        color: AppColors.primaryPink,
                      ),
                      title: Text('Umpan Balik Taktil & Haptik Lintas Fitur', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                      subtitle: Text(
                        'Pilihan filter, pemilihan tanggal kalender, aksi batal/selesai picker wheel, dan tombol hapus pencarian kini memberikan sensasi haptik iOS yang presisi.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                      ),
                    ),
                    CupertinoListTile(
                      leading: SquircleIcon(
                        icon: CupertinoIcons.keyboard_chevron_compact_down,
                        color: Color(0xFF5856D6),
                      ),
                      title: Text('Pencegahan Glitch Keyboard & Toast Robust', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                      subtitle: Text(
                        'Keyboard otomatis ditutup sebelum modal picker terbuka untuk mencegah benturan tampilan, dan notifikasi toast kini bertahan mulus melintasi penutupan sheet.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                      ),
                    ),
                  ],
                ),
                CupertinoListSection.insetGrouped(
                  header: const Text('VERSI 1.0.72 (BUILD 107)'),
                  backgroundColor: Colors.transparent,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  children: const [
                    CupertinoListTile(
                      leading: SquircleIcon(
                        icon: CupertinoIcons.sparkles,
                        color: AppColors.primaryPink,
                      ),
                      title: Text('Animasi 240fps++ Super Halus', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                      subtitle: Text(
                        'Overhaul animasi tingkat hardware di seluruh screen: Staggered entry list, PressableCard scale feedback, StateCrossfade, dan toast slide down.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                      ),
                    ),
                    CupertinoListTile(
                      leading: SquircleIcon(
                        icon: CupertinoIcons.zoom_in,
                        color: Color(0xFF5856D6),
                      ),
                      title: Text('Tap-to-Zoom Foto & UX Polish', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                      subtitle: Text(
                        'Foto cover kostum kini mendukung pinch-to-zoom layar penuh, margin bawah 160pt konsisten di semua tab, dan toast validasi responsif.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                      ),
                    ),
                  ],
                ),
                CupertinoListSection.insetGrouped(
                  header: const Text('VERSI 1.0.70 (BUILD 105)'),
                  backgroundColor: Colors.transparent,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  children: const [
                    CupertinoListTile(
                      leading: SquircleIcon(
                        icon: CupertinoIcons.calendar_badge_plus,
                        color: AppColors.primaryPink,
                      ),
                      title: Text('Snug Fit Entry Chooser & Aksesori HIG', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                      subtitle: Text(
                        'Pilihan metode input pesanan kalender proporsional pas (snug fit) dengan tombol Tutup, dan list aksesori kostum seragam Inset Grouped.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                      ),
                    ),
                    CupertinoListTile(
                      leading: SquircleIcon(
                        icon: CupertinoIcons.creditcard_fill,
                        color: Color(0xFF5856D6),
                      ),
                      title: Text('Detail Cicilan & Riwayat Apple HIG', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                      subtitle: Text(
                        'Standardisasi modal sheet Buku Cicilan ke Inset Grouped, nominal pembayaran presisi di tengah vertikal saat tanpa catatan, dan konfirmasi hapus aman.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                      ),
                    ),
                    CupertinoListTile(
                      leading: SquircleIcon(
                        icon: CupertinoIcons.person_badge_plus_fill,
                        color: Color(0xFF007AFF),
                      ),
                      title: Text('Dokumen Identitas & Aksi Salin', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                      subtitle: Text(
                        'Preview foto KTP dan selfie jaminan dengan viewer zoom/pinch interaktif, serta tombol circular copy HIG.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                      ),
                    ),
                  ],
                ),
                CupertinoListSection.insetGrouped(
                  header: const Text('VERSI 1.0.69 (BUILD 104)'),
                  backgroundColor: Colors.transparent,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  children: const [
                    CupertinoListTile(
                      leading: SquircleIcon(
                        icon: CupertinoIcons.arrow_2_circlepath_circle_fill,
                        color: Color(0xFF34C759),
                      ),
                      title: Text('Full Two-Way Auto Sync', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                      subtitle: Text(
                        'Push pending queue dan Pull data cloud otomatis secara reaktif saat online tanpa tombol manual.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                      ),
                    ),
                  ],
                ),
                CupertinoListSection.insetGrouped(
                  header: const Text('VERSI 1.0.55 (BUILD 77)'),
                  backgroundColor: Colors.transparent,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  children: const [
                    CupertinoListTile(
                      leading: SquircleIcon(
                        icon: CupertinoIcons.slider_horizontal_3,
                        color: AppColors.primaryPink,
                      ),
                      title: Text('Transisi Wheel Halus 60 FPS', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                      subtitle: Text(
                        'Wheel picker tanggal dan ukuran menggunakan arsitektur deferred slide & engine prewarming tanpa drop frame.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                      ),
                    ),
                    CupertinoListTile(
                      leading: SquircleIcon(
                        icon: CupertinoIcons.gear_alt_fill,
                        color: Color(0xFF5856D6),
                      ),
                      title: Text('Perombakan Menu Pengaturan', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                      subtitle: Text(
                        'Eliminasi chevron mati. Setiap baris interaktif membuka sheet Apple HIG yang responsif dan informatif.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                      ),
                    ),
                    CupertinoListTile(
                      leading: SquircleIcon(
                        icon: CupertinoIcons.cloud_fill,
                        color: Color(0xFF007AFF),
                      ),
                      title: Text('Google Apps Script Serverless', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                      subtitle: Text(
                        'Sinkronisasi dua arah ke Google Sheets dan Google Drive tanpa perlu sewa server.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
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

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(syncStateProvider);

    String statusBadge;
    Color statusColor;
    IconData statusIcon;

    if (!syncState.isOnline) {
      statusBadge = 'Offline';
      statusColor = const Color(0xFFFF9500);
      statusIcon = CupertinoIcons.wifi_slash;
    } else {
      switch (syncState.status) {
        case SyncStatus.idle:
          if (syncState.lastSyncedAt == null && syncState.pendingCount == 0) {
            statusBadge = 'Online';
            statusColor = AppColors.primaryPink;
            statusIcon = CupertinoIcons.cloud;
          } else if (syncState.pendingCount > 0) {
            statusBadge = 'Antrean (${syncState.pendingCount})';
            statusColor = const Color(0xFFFF9500);
            statusIcon = CupertinoIcons.cloud_fill;
          } else {
            statusBadge = 'Tersinkron';
            statusColor = const Color(0xFF34C759);
            statusIcon = CupertinoIcons.checkmark_alt_circle_fill;
          }
          break;
        case SyncStatus.syncing:
          statusBadge = 'Menyinkronkan...';
          statusColor = AppColors.primaryPink;
          statusIcon = CupertinoIcons.arrow_2_circlepath;
          break;
        case SyncStatus.success:
          statusBadge = 'Tersinkron';
          statusColor = const Color(0xFF34C759);
          statusIcon = CupertinoIcons.checkmark_alt_circle_fill;
          break;
        case SyncStatus.error:
          statusBadge = 'Gagal';
          statusColor = const Color(0xFFFF3B30);
          statusIcon = CupertinoIcons.exclamationmark_circle_fill;
          break;
      }
    }

    final formattedLastSync = syncState.lastSyncedAt != null
        ? DateFormat('d MMM yyyy, HH:mm').format(syncState.lastSyncedAt!)
        : 'Belum pernah';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Pengaturan',
          style: AppTypography.largeTitle,
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 180),
        children: [
          // Section 1: CLOUD SYNC
          CupertinoListSection.insetGrouped(
            header: const Text(
              'SINKRONISASI CLOUD',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: Color(0xFF6C6C70),
                letterSpacing: -0.05,
              ),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            backgroundColor: Colors.transparent,
            children: [
              // Row 1: Status Koneksi (NO chevron — informational status)
              CupertinoListTile(
                leading: SquircleIcon(
                  icon: statusIcon,
                  color: statusColor,
                ),
                title: const Text('Status Koneksi', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                additionalInfo: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                  child: Container(
                    key: ValueKey(statusBadge),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      statusBadge,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),

              // Row 2: Antrean Offline (HAS chevron — opens detail sheet)
              CupertinoListTile(
                leading: const SquircleIcon(
                  icon: CupertinoIcons.tray_arrow_up_fill,
                  color: Color(0xFFFF9500),
                ),
                title: const Text('Antrean Offline', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                additionalInfo: Text(
                  '${syncState.pendingCount} item',
                  style: const TextStyle(
                    color: Color(0xFF8E8E93),
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                trailing: const Icon(CupertinoIcons.chevron_right, size: 14, color: Color(0xFFC7C7CC)),
                onTap: _showPendingQueueSheet,
              ),

              // Row 3: Terakhir Sinkron (NO chevron — purely informational timestamp)
              CupertinoListTile(
                leading: const SquircleIcon(
                  icon: CupertinoIcons.clock_fill,
                  color: Color(0xFF34C759),
                ),
                title: const Text('Terakhir Sinkron', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                additionalInfo: Text(
                  formattedLastSync,
                  style: const TextStyle(
                    color: Color(0xFF8E8E93),
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),

              // Row 4: Action Button (Sinkronkan Sekarang)
              CupertinoListTile(
                title: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOutCubic,
                    transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                    child: syncState.status == SyncStatus.syncing
                        ? Row(
                            key: const ValueKey('syncing'),
                            mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            CupertinoActivityIndicator(radius: 8),
                            SizedBox(width: 8),
                            Text(
                              'Menyinkronkan...',
                              style: TextStyle(
                                color: AppColors.primaryPink,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          key: const ValueKey('idle'),
                          'Sinkronkan Sekarang',
                          style: const TextStyle(
                            color: AppColors.primaryPink,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                  ),
                ),
                onTap: syncState.status == SyncStatus.syncing ? null : _handleSync,
              ),

              // Row 5: Action Button (Pulihkan dari Cloud — after reinstall)
              CupertinoListTile(
                title: const Center(
                  child: Text(
                    'Pulihkan dari Cloud',
                    style: TextStyle(
                      color: Color(0xFF007AFF),
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
                onTap: syncState.status == SyncStatus.syncing ? null : _handleRestore,
              ),
            ],
          ),

          // Section 2: DATA & PENYIMPANAN
          CupertinoListSection.insetGrouped(
            header: const Text(
              'DATA & PENYIMPANAN',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: Color(0xFF6C6C70),
                letterSpacing: -0.05,
              ),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            backgroundColor: Colors.transparent,
            children: [
              // Row 1: Database Stats (HAS chevron — opens stats sheet)
              CupertinoListTile(
                leading: const SquircleIcon(
                  icon: CupertinoIcons.circle_grid_hex_fill,
                  color: Color(0xFF34C759),
                ),
                title: const Text('Statistik Database', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                trailing: const Icon(CupertinoIcons.chevron_right, size: 14, color: Color(0xFFC7C7CC)),
                onTap: _showDatabaseStatsSheet,
              ),

              // Row 2: Bersihkan Cache (Opens confirmation dialog — no chevron)
              CupertinoListTile(
                leading: const SquircleIcon(
                  icon: CupertinoIcons.trash_fill,
                  color: Color(0xFFFF3B30),
                ),
                title: const Text('Bersihkan Cache Gambar', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                additionalInfo: _cacheSizeText.isNotEmpty
                    ? Text(_cacheSizeText, style: const TextStyle(fontSize: 15, color: Color(0xFF8E8E93)))
                    : null,
                onTap: _showClearCacheDialog,
              ),
            ],
          ),

          // Section 3: TENTANG APLIKASI
          CupertinoListSection.insetGrouped(
            header: const Text(
              'TENTANG APLIKASI',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: Color(0xFF6C6C70),
                letterSpacing: -0.05,
              ),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            backgroundColor: Colors.transparent,
            children: [
              // Row 1: LilyHouse Rent (HAS chevron — opens about sheet)
              CupertinoListTile(
                leading: const SquircleIcon(
                  icon: CupertinoIcons.heart_fill,
                  color: AppColors.primaryPink,
                ),
                title: const Text('LilyHouse Rent', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                additionalInfo: const Text('v1.0.84', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 15)),
                trailing: const Icon(CupertinoIcons.chevron_right, size: 14, color: Color(0xFFC7C7CC)),
                onTap: _showAboutSheet,
              ),

              // Row 2: Design System (HAS chevron — opens HIG specs sheet)
              CupertinoListTile(
                leading: const SquircleIcon(
                  icon: CupertinoIcons.paintbrush_fill,
                  color: Color(0xFF5856D6),
                ),
                title: const Text('Design System', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                additionalInfo: const Text('Apple HIG / iOS 18', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 15)),
                trailing: const Icon(CupertinoIcons.chevron_right, size: 14, color: Color(0xFFC7C7CC)),
                onTap: _showDesignSystemSheet,
              ),

              // Row 3: Catatan Rilis (HAS chevron — opens changelog sheet)
              CupertinoListTile(
                leading: const SquircleIcon(
                  icon: CupertinoIcons.sparkles,
                  color: Color(0xFFFF9500),
                ),
                title: const Text('Catatan Rilis', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                trailing: const Icon(CupertinoIcons.chevron_right, size: 14, color: Color(0xFFC7C7CC)),
                onTap: _showChangelogSheet,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
