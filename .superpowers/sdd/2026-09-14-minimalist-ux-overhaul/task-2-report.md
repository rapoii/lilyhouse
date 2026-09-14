# Task 2 Report: Streamline InstallmentCard to 3 Essential Elements

## Summary
Successfully streamlined `InstallmentCard` to follow the minimal 3-element visual design per the task brief:
1. **Title**: `installment.itemName` (`fontSize: 17`, `fontWeight: FontWeight.w600`, color: `Color(0xFF1C1C1E)`, single line ellipsis).
2. **Status Badge**: `isDone ? 'Lunas' : 'Cicilan'` pill badge (`borderRadius: BorderRadius.circular(20)`, padding `horizontal: 10, vertical: 4`, font size 12, bold).
3. **Key Number**: `isDone ? 'Lunas Sepenuhnya' : 'Sisa ${_formatCurrency(installment.remainingBalance)}'` (`fontSize: 16`, bold, color: `isDone ? AppColors.successMint : AppColors.primaryPink`).
4. **Sleek Progress Bar**: Height 6pt, `borderRadius: BorderRadius.circular(3)`, background `AppColors.softPinkBg`, fill `isDone ? AppColors.successMint : AppColors.primaryPink`, preserving `key: const Key('installment_progress_bar')`.

All extraneous details were removed from the card:
- Store name and shopping bag icon.
- "Progress Pembayaran" & "$percent%" row.
- "Terbayar" & "Total Harga" breakdown row.
- Hairline divider.
- "Jatuh Tempo" / due date footer row.

## Changes Made
- `lib/features/installments/presentation/widgets/installment_card.dart`:
  - Rebuilt card body layout with the 3 essential elements and sleek 6pt progress bar.
  - Kept container decoration, tap gestures (`onTap`), and progress bar Key.
  - Removed unused date formatting helper and Cupertino icons.
- `test/features/installments/installment_widgets_test.dart`:
  - Updated widget tests for `InstallmentCard` to test the new streamlined elements (`Title`, `Status Badge`, `Remaining Balance`, `Lunas Sepenuhnya`, `installment_progress_bar`).
  - Removed outdated card assertions for store name, percentages, and total costs.

## Verification & Results
1. `flutter test test/features/installments/` passed (16 tests passed).
2. Full suite `flutter test` passed (103 tests passed).
3. `flutter analyze --no-pub lib/features/installments/presentation/widgets/installment_card.dart` passed with 0 issues.
4. Git commit created: `refactor(installments): simplify InstallmentCard to title, status, and remaining balance` (`416bc2d`).
