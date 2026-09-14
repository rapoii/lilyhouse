# Task 3 Brief: Streamline _RentalSlotCard in CalendarScreen to 3 Essential Elements

## Requirements
Modify `lib/features/calendar/presentation/calendar_screen.dart` (around line 490-620, class `_RentalSlotCard`):
1. **Container & Tap**:
   - Pertahankan `GestureDetector` tap yang membuka `RentalDetailSheet`.
   - Pertahankan banner deteksi konflik (`hasConflict`) jika ada.
   - Container card: radius 12, border 0.5, subtle shadow, margin bottom 12, padding 16.
2. **Aturan 3 Elemen**:
   - **Judul**: Nama kostum (`costume?.name ?? rental.costumeId`), style `fontSize: 17`, `fontWeight: FontWeight.w600`, color `Color(0xFF1C1C1E)`.
   - **Status Badge**: Cukup 1 status badge utama (`_buildItemStatusPill(rental.itemStatus)`).
   - **Baris Kedua / Angka Kunci**:
     - Nama penyewa: icon person, `customer?.fullName ?? rental.customerId`, style `fontSize: 14`, `fontWeight: FontWeight.w500`, color `AppColors.textMuted`.
     - Angka Kunci: `Rp ${rental.totalPrice.toStringAsFixed(0)}`, style `fontSize: 16`, `fontWeight: FontWeight.bold`, color `AppColors.primaryPink`.
3. **Elemen yang Dihapus dari Kartu**:
   - Hapus badge ganda status pembayaran (`_buildPaymentStatusPill`) dari baris atas kartu (informasi pembayaran tetap ada di dalam `RentalDetailSheet`).
   - Hapus badge keperluan (`rental.purpose`).
   - Hapus rentang tanggal teks berulang di kartu ringkasan (karena user sudah memilih tanggal di kalender atas).
4. **Testing**:
   - Jalankan `flutter test test/features/rentals/` atau suite test terkait.
   - Jalankan `flutter analyze --no-pub`.
5. **Commit**:
   Commit dengan pesan: `refactor(calendar): streamline rental slot card to 3 essential elements`
