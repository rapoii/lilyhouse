# Task 2 Brief: Streamline InstallmentCard to 3 Essential Elements

## Requirements
Modify `lib/features/installments/presentation/widgets/installment_card.dart`:
1. **Container & Structure**:
   - Keep `color: Colors.white`, `borderRadius: BorderRadius.circular(12.0)`, `border: Border.all(color: Color(0xFFE5E5EA), width: 0.5)`, subtle shadow.
   - Retain tap gesture / `onTap`.
2. **Aturan 3 Elemen**:
   - **Judul**: `installment.itemName`, style `fontSize: 17`, `fontWeight: FontWeight.w600`, color `Color(0xFF1C1C1E)`, `maxLines: 1`, `overflow: TextOverflow.ellipsis`.
   - **Status Badge**: `isDone ? 'Lunas' : 'Cicilan'`, pill container `borderRadius: BorderRadius.circular(20)` (or 16), padding `symmetric(horizontal: 10, vertical: 4)`, text `fontSize: 12`, `fontWeight: FontWeight.bold`, color matching isDone (green vs primaryPink).
   - **Angka Kunci**:
     - Teks: `isDone ? 'Lunas Sepenuhnya' : 'Sisa ${_formatCurrency(installment.remainingBalance)}'`
     - Style: `fontSize: 16`, `fontWeight: FontWeight.bold`, color `isDone ? AppColors.successMint : AppColors.primaryPink`.
   - **Progress Bar Ramping**:
     - Height: 6pt, `borderRadius: BorderRadius.circular(3)`.
     - Container `key: const Key('installment_progress_bar')` (wajib dipertahankan untuk finder test!).
     - Background: `AppColors.softPinkBg`, fill: `isDone ? AppColors.successMint : AppColors.primaryPink`.
3. **Elemen yang Dihapus dari Kartu**:
   - Nama toko (`installment.storeName`) & icon bag.
   - Row teks "Progress Pembayaran" & "$percent%".
   - Breakdown baris "Terbayar" & "Total Harga".
   - Hairline divider `Container(height: 1, color: AppColors.softPinkBg)`.
   - Baris footer "Jatuh Tempo" / tanggal.
4. **Testing**:
   - Jalankan `flutter test test/features/installments/` atau tes terkait.
   - Jalankan `flutter analyze --no-pub`.
5. **Commit**:
   Commit dengan pesan: `refactor(installments): simplify InstallmentCard to title, status, and remaining balance`
