# Task 1 Brief: Streamline CostumeCard to 3 Essential Elements & Update Widget Tests

## Requirements
Modify `lib/features/costumes/presentation/widgets/costume_card.dart`:
1. **Container & Sizing**:
   - Keep `color: Colors.white`, `borderRadius: BorderRadius.circular(12.0)`, `border: Border.all(color: Color(0xFFE5E5EA), width: 0.5)`, subtle shadow.
   - Thumbnail: 56×56 (or 52×52), `borderRadius: BorderRadius.circular(10.0)`.
2. **Aturan 3 Elemen**:
   - **Judul**: `costume.name`, style `fontSize: 17`, `fontWeight: FontWeight.w600`, color `Color(0xFF1C1C1E)` (or `AppColors.textDark`), `maxLines: 1`, `overflow: TextOverflow.ellipsis`.
   - **Status Badge**: `_getStatusBadgeData(costume.status)` pill, `borderRadius: BorderRadius.circular(16)` (pill), padding `symmetric(horizontal: 10, vertical: 4)`, text `fontSize: 12`, `fontWeight: FontWeight.bold`.
   - **Angka Kunci**: Price per 3 days formatted clearly `"${_formatCurrency(costume.rentPrice3Days)} / 3d"`, style `fontSize: 15`, `fontWeight: FontWeight.bold`, color `AppColors.primaryPink`.
3. **Elemen yang Dibuang**:
   - Hapus teks `costume.animeSeries`.
   - Hapus badge ukuran `Size ${costume.size}`.
   - Hapus referensi jumlah aksesoris.
4. **Testing**:
   - Inspect `test/features/inventory/costume_screens_test.dart` and any other costume tests. If tests fail because of removed anime series or size text, adjust the finders or verify they pass.
   - Run `flutter test test/features/inventory/costume_screens_test.dart` and `flutter analyze --no-pub`.
5. **Commit**:
   Commit with message: `refactor(costumes): streamline CostumeCard to 3 essential elements`
