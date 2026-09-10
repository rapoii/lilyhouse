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
import '../../../core/widgets/squircle_icon.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  void _showIosToast(String message, {IconData icon = CupertinoIcons.checkmark_circle_fill}) {
    HapticFeedback.lightImpact();
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => Positioned(
        top: MediaQuery.of(ctx).padding.top + 16,
        left: 24,
        right: 24,
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xEE1C1C1E),
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x26000000),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: AppColors.primaryPink, size: 18),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      message,
                      style: const TextStyle(
                        fontFamily: '.SF Pro Text',
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (entry.mounted) entry.remove();
    });
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

  void _copyScriptBackend() {
    Clipboard.setData(const ClipboardData(text: 'google_apps_script.js'));
    _showIosToast('File script disalin ke clipboard');
  }

  void _copyEndpointUrl() {
    Clipboard.setData(const ClipboardData(
      text:
          'https://script.google.com/macros/s/AKfycbxLnaF6AG1Ag06TD2MDp0Tws45ZOlVC9NJNdQKmYMGg6gy1OQmJfZVdkuX0hD9xfoz9ug/exec',
    ));
    _showIosToast('URL Endpoint disalin ke clipboard');
  }

  void _copySpreadsheetUrl() {
    Clipboard.setData(const ClipboardData(
      text:
          'https://docs.google.com/spreadsheets/d/1ey7p0jETE1IsNITdFxK_FVYPdKTnH1wIF6QbLcLclIg/edit',
    ));
    _showIosToast('Link Google Sheets disalin ke clipboard');
  }

  void _showPendingQueueSheet() {
    HapticFeedback.selectionClick();
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => DraggableSheetContainer(
        backgroundColor: AppColors.background,
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
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: const Color(0xFF34C759).withOpacity(0.12),
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

  void _showBackendGuideSheet() {
    HapticFeedback.selectionClick();
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => DraggableSheetContainer(
        backgroundColor: AppColors.background,
        initialHeightFraction: 0.85,
        maxHeightFraction: 0.95,
        builder: (sheetCtx) => DefaultTextStyle(
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
              middle: const Text('Panduan Deployment', style: AppTypography.navTitle),
              trailing: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.pop(sheetCtx),
                child: const Text('Tutup', style: AppTypography.actionButton),
              ),
            ),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE5E5EA)),
                  ),
                  child: Row(
                    children: [
                      const SquircleIcon(
                        icon: CupertinoIcons.doc_text_fill,
                        color: Color(0xFF5856D6),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'google_apps_script.js',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: AppColors.textDark,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Script serverless untuk Google Sheets & Drive',
                              style: TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
                            ),
                          ],
                        ),
                      ),
                      CupertinoButton(
                        padding: const EdgeInsets.all(8),
                        onPressed: _copyScriptBackend,
                        child: const Icon(CupertinoIcons.doc_on_clipboard, size: 20, color: AppColors.primaryPink),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'LANGKAH DEPLOYMENT',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF6C6C70),
                    letterSpacing: -0.05,
                  ),
                ),
                const SizedBox(height: 10),
                _buildGuideStep(
                  step: '1',
                  title: 'Buat Spreadsheet Baru',
                  desc: 'Buka Google Sheets di browser, buat spreadsheet baru untuk database rental kostum.',
                ),
                _buildGuideStep(
                  step: '2',
                  title: 'Buka Apps Script Editor',
                  desc: 'Di menu Google Sheets, pilih Extensions > Apps Script untuk membuka code editor.',
                ),
                _buildGuideStep(
                  step: '3',
                  title: 'Tempel Kode Script',
                  desc: 'Salin seluruh isi file google_apps_script.js dari folder proyek dan tempel ke Code.gs.',
                ),
                _buildGuideStep(
                  step: '4',
                  title: 'Deploy sebagai Web App',
                  desc: 'Klik tombol Deploy > New Deployment > Web App. Atur "Execute as: Me" dan "Who has access: Anyone".',
                ),
                _buildGuideStep(
                  step: '5',
                  title: 'Dapatkan Endpoint URL',
                  desc: 'Salin URL Web App yang dihasilkan. Endpoint ini siap menerima request sinkronisasi otomatis dari aplikasi.',
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGuideStep({required String step, required String title, required String desc}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: AppColors.primaryPink.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                step,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryPink,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textDark),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E93), height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDatabaseStatsSheet() {
    HapticFeedback.selectionClick();
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => DraggableSheetContainer(
        backgroundColor: AppColors.background,
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
              backgroundColor: AppColors.background,
              border: const Border(bottom: BorderSide(color: Color(0xFFE5E5EA), width: 0.5)),
              middle: const Text('Statistik Database', style: AppTypography.navTitle),
              trailing: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.pop(sheetCtx),
                child: const Text('Tutup', style: AppTypography.actionButton),
              ),
            ),
            child: FutureBuilder<Map<String, int>>(
              future: DatabaseHelper.instance.getTableCounts(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CupertinoActivityIndicator());
                }
                final counts = snapshot.data ?? {};
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
                            '${counts['rentals'] ?? 0} booking',
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
                      children: const [
                        CupertinoListTile(
                          leading: SquircleIcon(
                            icon: CupertinoIcons.circle_grid_hex_fill,
                            color: Color(0xFF5856D6),
                          ),
                          title: Text('Database Engine', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                          additionalInfo: Text('SQLite v3.x', style: TextStyle(fontSize: 15, color: Color(0xFF8E8E93))),
                        ),
                        CupertinoListTile(
                          leading: SquircleIcon(
                            icon: CupertinoIcons.folder_fill,
                            color: Color(0xFF8E8E93),
                          ),
                          title: Text('Nama Berkas', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                          additionalInfo: Text('lilyhouse.db', style: TextStyle(fontSize: 15, color: Color(0xFF8E8E93))),
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
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Bersihkan Cache Gambar?'),
        message: const Text(
          'File cache thumbnail dan memori sementara akan dibersihkan. '
          'Data kostum, foto tersimpan, dan catatan booking tidak akan terhapus.',
        ),
        actions: [
          CupertinoActionSheetAction(
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
                _showIosToast('Cache gambar berhasil dibersihkan');
              } catch (_) {
                _showIosToast('Gagal membersihkan cache', icon: CupertinoIcons.exclamationmark_circle_fill);
              }
            },
            child: const Text('Bersihkan Cache'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Batal'),
        ),
      ),
    );
  }

  void _showAboutSheet() {
    HapticFeedback.selectionClick();
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => DraggableSheetContainer(
        backgroundColor: AppColors.background,
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
                    'Versi 1.0.55 (Build 85)',
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

    switch (syncState.status) {
      case SyncStatus.idle:
        if (syncState.lastSyncedAt == null && syncState.pendingCount == 0) {
          statusBadge = 'Siap';
          statusColor = AppColors.primaryPink;
          statusIcon = CupertinoIcons.cloud;
        } else if (syncState.pendingCount > 0) {
          statusBadge = 'Offline';
          statusColor = const Color(0xFFFF9500);
          statusIcon = CupertinoIcons.cloud_fill;
        } else {
          statusBadge = 'Tersinkron';
          statusColor = const Color(0xFF34C759);
          statusIcon = CupertinoIcons.cloud_fill;
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
            footer: const Text(
              'Perubahan data rental & cicilan otomatis masuk ke antrean jika offline, dan tersinkron ke cloud saat online.',
              style: TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
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
                additionalInfo: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
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
                  child: syncState.status == SyncStatus.syncing
                      ? Row(
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
                      : const Text(
                          'Sinkronkan Sekarang',
                          style: TextStyle(
                            color: AppColors.primaryPink,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                ),
                onTap: syncState.status == SyncStatus.syncing ? null : _handleSync,
              ),
            ],
          ),

          // Section 2: INTEGRASI GOOGLE APPS SCRIPT
          CupertinoListSection.insetGrouped(
            header: const Text(
              'INTEGRASI GOOGLE APPS SCRIPT',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: Color(0xFF6C6C70),
                letterSpacing: -0.05,
              ),
            ),
            footer: const Text(
              'Backend serverless gratis tanpa server, tersinkron ke Google Sheets & Google Drive.',
              style: TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            backgroundColor: Colors.transparent,
            children: [
              // Row 1: Endpoint URL (HAS copy action)
              CupertinoListTile(
                leading: const SquircleIcon(
                  icon: CupertinoIcons.cloud_fill,
                  color: Color(0xFF34C759),
                ),
                title: const Text('Endpoint Web App', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                subtitle: const Text(
                  'script.google.com/.../exec',
                  style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: Color(0xFF8E8E93)),
                ),
                trailing: const Icon(CupertinoIcons.doc_on_clipboard, size: 18, color: AppColors.primaryPink),
                onTap: _copyEndpointUrl,
              ),

              // Row 2: Spreadsheet Data (HAS copy action)
              CupertinoListTile(
                leading: const SquircleIcon(
                  icon: CupertinoIcons.table_badge_more_fill,
                  color: Color(0xFF30B0C7),
                ),
                title: const Text('Spreadsheet Cloud', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                subtitle: const Text(
                  'LilyHouse_Data (Google Sheets)',
                  style: TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
                ),
                trailing: const Icon(CupertinoIcons.doc_on_clipboard, size: 18, color: AppColors.primaryPink),
                onTap: _copySpreadsheetUrl,
              ),

              // Row 3: File Script Backend (HAS action copy button)
              CupertinoListTile(
                leading: const SquircleIcon(
                  icon: CupertinoIcons.doc_text_fill,
                  color: Color(0xFF5856D6),
                ),
                title: const Text('File Backend', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                subtitle: const Text(
                  'google_apps_script.js',
                  style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: Color(0xFF8E8E93)),
                ),
                trailing: const Icon(CupertinoIcons.doc_on_clipboard, size: 18, color: AppColors.primaryPink),
                onTap: _copyScriptBackend,
              ),

              // Row 4: Panduan Deployment (HAS chevron — opens guide sheet)
              CupertinoListTile(
                leading: const SquircleIcon(
                  icon: CupertinoIcons.book_fill,
                  color: Color(0xFF007AFF),
                ),
                title: const Text('Panduan Setup', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                subtitle: const Text('Langkah deploy ke Google Apps Script', style: TextStyle(fontSize: 12, color: Color(0xFF8E8E93))),
                trailing: const Icon(CupertinoIcons.chevron_right, size: 14, color: Color(0xFFC7C7CC)),
                onTap: _showBackendGuideSheet,
              ),
            ],
          ),

          // Section 3: DATA & PENYIMPANAN
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
                subtitle: const Text('Katalog, booking, dan pelanggan lokal', style: TextStyle(fontSize: 12, color: Color(0xFF8E8E93))),
                trailing: const Icon(CupertinoIcons.chevron_right, size: 14, color: Color(0xFFC7C7CC)),
                onTap: _showDatabaseStatsSheet,
              ),

              // Row 2: Bersihkan Cache (HAS chevron — opens action sheet)
              CupertinoListTile(
                leading: const SquircleIcon(
                  icon: CupertinoIcons.trash_fill,
                  color: Color(0xFFFF3B30),
                ),
                title: const Text('Bersihkan Cache Gambar', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                subtitle: const Text('Hapus thumbnail sementara', style: TextStyle(fontSize: 12, color: Color(0xFF8E8E93))),
                trailing: const Icon(CupertinoIcons.chevron_right, size: 14, color: Color(0xFFC7C7CC)),
                onTap: _showClearCacheDialog,
              ),
            ],
          ),

          // Section 4: TENTANG APLIKASI
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
                additionalInfo: const Text('v1.0.55 (Build 85)', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 15)),
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
                subtitle: const Text('Pembaruan fitur di build 77', style: TextStyle(fontSize: 12, color: Color(0xFF8E8E93))),
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
