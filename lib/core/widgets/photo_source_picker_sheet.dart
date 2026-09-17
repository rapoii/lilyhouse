import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'draggable_sheet_container.dart';
import 'squircle_icon.dart';

/// Apple HIG-compliant modal sheet for picking photo sources (Camera vs Gallery).
class PhotoSourcePickerSheet extends StatelessWidget {
  final String title;
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  const PhotoSourcePickerSheet({
    super.key,
    this.title = 'Pilih Sumber Foto',
    required this.onCamera,
    required this.onGallery,
  });

  static Future<void> show({
    required BuildContext context,
    String title = 'Pilih Sumber Foto',
    required VoidCallback onCamera,
    required VoidCallback onGallery,
  }) {
    return showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => PhotoSourcePickerSheet(
        title: title,
        onCamera: onCamera,
        onGallery: onGallery,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableSheetContainer(
      initialHeightFraction: 0.28,
      maxHeightFraction: 0.34,
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
            automaticallyImplyLeading: false,
            backgroundColor: AppColors.background,
            border: const Border(bottom: BorderSide(color: Color(0xFFE5E5EA), width: 0.5)),
            middle: Text(title, style: AppTypography.navTitle),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Tutup', style: TextStyle(color: AppColors.deepPinkText, fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
          child: SafeArea(
            top: false,
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(0, 16, 0, 180),
              children: [
                CupertinoListSection.insetGrouped(
                  header: const Text(
                    'PILIH SUMBER FOTO',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  backgroundColor: Colors.transparent,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    CupertinoListTile(
                      leading: const SquircleIcon(
                        icon: CupertinoIcons.camera_fill,
                        color: AppColors.primaryPink,
                      ),
                      title: const Text(
                        'Ambil dari Kamera',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      subtitle: const Text(
                        'Buka kamera HP untuk mengambil foto baru',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      onTap: () {
                        Navigator.of(context).pop();
                        onCamera();
                      },
                    ),
                    CupertinoListTile(
                      leading: const SquircleIcon(
                        icon: CupertinoIcons.photo_fill_on_rectangle_fill,
                        color: Color(0xFF007AFF),
                      ),
                      title: const Text(
                        'Pilih dari Galeri Foto',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      subtitle: const Text(
                        'Pilih foto dari penyimpanan galeri perangkat',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      onTap: () {
                        Navigator.of(context).pop();
                        onGallery();
                      },
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
