# Task 4 Brief: Clean Up Subtitles & Streamline Rows in SettingsScreen

## Requirements
Modify `lib/features/settings/presentation/settings_screen.dart` (around lines 900-985):
1. **Bersihkan Subtitle Berlebih**:
   - Baris `Statistik Database`: hapus `subtitle: const Text('Katalog, booking, dan pelanggan lokal'...)` -> jadikan `subtitle: null` (atau hapus properti `subtitle`).
   - Baris `Bersihkan Cache Gambar`: hapus `subtitle: const Text('Hapus thumbnail sementara'...)` -> jadikan `subtitle: null`.
   - Baris `Catatan Rilis`: hapus `subtitle: const Text('Pembaruan fitur di build 105'...)` -> jadikan `subtitle: null`.
2. **Keterbacaan & Typography**:
   - Pastikan label menu utama tetap `fontSize: 16` atau `17` yang jelas dan mantap.
   - Pertahankan icon squircle dan trailing chevron yang sudah sesuai standar iOS HIG.
3. **Testing**:
   - Jalankan `flutter test test/features/settings/` atau tes terkait jika ada.
   - Jalankan `flutter analyze --no-pub`.
4. **Commit**:
   Commit dengan pesan: `refactor(settings): remove clutter subtitles and standardize tile typography`
