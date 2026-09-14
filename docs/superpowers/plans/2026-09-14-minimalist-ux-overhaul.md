# Minimalist & Age-Inclusive UX Overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Overhaul the primary list cards and rows across LilyHouse to an extreme minimalist, 3-element hierarchy (Title + Status Badge + Key Metric) with large typography (17pt/16pt) and progressive disclosure for optimal age-inclusive readability and reduced cognitive load.

**Architecture:** Refactor `CostumeCard`, `InstallmentCard`, and `_RentalSlotCard` into clean, uncluttered floating cards adhering to the 3-element rule; streamline `SettingsScreen` by stripping redundant subtitle noise; update test finders to reflect the new minimalist card content while keeping 100% test pass rate.

**Tech Stack:** Flutter 3.x, Cupertino Widgets, Dart 3.x.

**Spec:** `docs/superpowers/specs/2026-09-14-minimalist-ux-overhaul-design.md`

## Global Constraints
- Every primary list card must adhere to the 3-Element Rule: Title (17pt semibold) + Status Pill (12-13pt bold) + Key Metric (15-16pt bold).
- Card container: `color: Colors.white`, `borderRadius: BorderRadius.circular(12.0)`, `border: Border.all(color: Color(0xFFE5E5EA), width: 0.5)`, `boxShadow: [BoxShadow(color: Color(0x08000000), blurRadius: 8.0, offset: Offset(0, 1))]`.
- No Material remnants allowed (`0` TextField, Divider, LinearProgressIndicator, etc.).
- All 103 unit and widget tests must pass after changes.
- Zero analysis errors (`flutter analyze --no-pub` exit 0).

---

### Task 1: Streamline `CostumeCard` to 3 Essential Elements & Update Widget Tests

**Files:**
- Modify: `lib/features/costumes/presentation/widgets/costume_card.dart:90-220`
- Test: `test/features/inventory/costume_screens_test.dart:180-230`

**Interfaces:**
- Consumes: `Costume` model (`name`, `status`, `rentPrice3Days`, `coverPhoto`).
- Produces: Simplified `CostumeCard` without anime series subtitle, size badge, or accessory counts.

- [ ] **Step 1: Inspect existing widget test assertions on `CostumeCard`**

Run: `flutter test test/features/inventory/costume_screens_test.dart`
Verify baseline passes. Note any finders checking for anime series text or size pills.

- [ ] **Step 2: Refactor `CostumeCard` layout**

In `lib/features/costumes/presentation/widgets/costume_card.dart`:
- Set thumbnail size to 56×56 with `BorderRadius.circular(10.0)`.
- Set costume name style: `fontSize: 17`, `fontWeight: FontWeight.w600`, color `Color(0xFF1C1C1E)`.
- Status pill: keep current badge data, set padding `symmetric(horizontal: 10, vertical: 4)`, text `fontSize: 12`, `fontWeight: FontWeight.bold`.
- Key Metric: Price per 3 days formatted clearly (e.g. `_formatCurrency(costume.rentPrice3Days) / 3hr`), `fontSize: 15`, `fontWeight: FontWeight.bold`, color `AppColors.primaryPink`.
- Remove: `costume.animeSeries` Text widget, size badge Container (`Size ${costume.size}`), and spacer/accessory references from the card.

- [ ] **Step 3: Update `test/features/inventory/costume_screens_test.dart` if needed**

Ensure any test finder expecting `Size M` or anime series in the card list does not break.

- [ ] **Step 4: Run tests to verify pass**

Run: `flutter test test/features/inventory/costume_screens_test.dart`
Expected: 100% tests pass.

- [ ] **Step 5: Commit changes**

```bash
git add lib/features/costumes/presentation/widgets/costume_card.dart test/features/inventory/costume_screens_test.dart
git commit -m "refactor(costumes): streamline CostumeCard to 3 essential elements"
```

---

### Task 2: Streamline `InstallmentCard` to 3 Essential Elements

**Files:**
- Modify: `lib/features/installments/presentation/widgets/installment_card.dart:50-265`

**Interfaces:**
- Consumes: `Installment` model (`itemName`, `isPaidOff`, `progress`, `remainingBalance`).
- Produces: Minimalist `InstallmentCard` containing only Item Name, Status Pill, Remaining Balance, and a slim 6pt progress bar.

- [ ] **Step 1: Refactor `InstallmentCard` layout**

In `lib/features/installments/presentation/widgets/installment_card.dart`:
- Header row:
  - Item name: `fontSize: 17`, `fontWeight: FontWeight.w600`, color `Color(0xFF1C1C1E)`, `maxLines: 1`, `overflow: TextOverflow.ellipsis`.
  - Status badge: pill `isDone ? 'Lunas' : 'Cicilan'`, `fontSize: 12`, `fontWeight: FontWeight.bold`.
- Key Metric row:
  - Text `Sisa Tagihan` or `isDone ? 'Lunas Sepenuhnya' : 'Sisa ${_formatCurrency(installment.remainingBalance)}'`, `fontSize: 16`, `fontWeight: FontWeight.bold`, color: `isDone ? AppColors.successMint : AppColors.primaryPink`.
- Progress bar:
  - Height 6pt, `borderRadius: BorderRadius.circular(3)`.
  - Background `AppColors.softPinkBg`, fill `isDone ? AppColors.successMint : AppColors.primaryPink`.
  - Key `'installment_progress_bar'` retained for widget tests.
- Remove from card:
  - Store name (`installment.storeName`) and shopping bag icon.
  - "Progress Pembayaran" text and percentage "$percent%" text.
  - Financial breakdown row ("Terbayar" & "Total Harga").
  - Hairline divider container.
  - Footer row ("Jatuh Tempo" date).

- [ ] **Step 2: Run installment tests**

Run: `flutter test test/features/installments/`
Expected: All installment tests pass.

- [ ] **Step 3: Commit changes**

```bash
git add lib/features/installments/presentation/widgets/installment_card.dart
git commit -m "refactor(installments): simplify InstallmentCard to title, status, and remaining balance"
```

---

### Task 3: Streamline `_RentalSlotCard` in `CalendarScreen` to 3 Essential Elements

**Files:**
- Modify: `lib/features/calendar/presentation/calendar_screen.dart:490-620`

**Interfaces:**
- Consumes: `Rental` (`costumeId`, `customerId`, `itemStatus`, `totalPrice`, `startDate`, `endDate`), `Customer`, `Costume`.
- Produces: Uncluttered calendar rental card with Conflict Banner (if any), Costume & Customer title, Status Pill, and Rent Price / Date metric.

- [ ] **Step 1: Refactor `_RentalSlotCard`**

In `lib/features/calendar/presentation/calendar_screen.dart`:
- Maintain Conflict Banner at top if `hasConflict`.
- Row 1 (Identity + Status):
  - Title: Costume name (`fontSize: 17`, `fontWeight: FontWeight.w600`, color `Color(0xFF1C1C1E)`).
  - Status pill: single item status badge (`_buildItemStatusPill(rental.itemStatus)`).
- Row 2 (Customer & Key Metric):
  - Customer name with subtle icon (`fontSize: 14`, color `AppColors.textMuted`).
  - Spacer.
  - Key Metric: `Rp ${rental.totalPrice.toStringAsFixed(0)}` (16pt bold `AppColors.primaryPink`) OR rental dates clearly stated.
- Remove from card:
  - Secondary payment status pill (`_buildPaymentStatusPill`) which duplicates status.
  - Rental purpose badge (`rental.purpose`).
  - Overlapping date range pills (detailed schedule is viewed in `RentalDetailSheet`).

- [ ] **Step 2: Run calendar tests**

Run: `flutter test test/features/calendar/` (or related calendar tests).
Expected: All pass.

- [ ] **Step 3: Commit changes**

```bash
git add lib/features/calendar/presentation/calendar_screen.dart
git commit -m "refactor(calendar): streamline rental slot card to 3 essential elements"
```

---

### Task 4: Clean Up Subtitles & Streamline Rows in `SettingsScreen`

**Files:**
- Modify: `lib/features/settings/presentation/settings_screen.dart:910-985`

**Interfaces:**
- Consumes: `CupertinoListTile` items in Settings screen.
- Produces: Clean, modern settings list without redundant subtitle captions under action tiles.

- [ ] **Step 1: Remove redundant subtitles from `SettingsScreen`**

In `lib/features/settings/presentation/settings_screen.dart`:
- Row 'Statistik Database': remove `subtitle: const Text('Katalog, booking, dan pelanggan lokal'...)`.
- Row 'Bersihkan Cache Gambar': remove `subtitle: const Text('Hapus thumbnail sementara'...)`.
- Row 'Catatan Rilis': remove `subtitle: const Text('Pembaruan fitur di build 105'...)`.
- Set title font sizes to 17pt where applicable for high readability.

- [ ] **Step 2: Verify `flutter analyze` and run tests**

Run: `flutter analyze --no-pub`
Run: `flutter test --no-pub`
Expected: 0 errors, 103/103 tests pass.

- [ ] **Step 3: Commit changes**

```bash
git add lib/features/settings/presentation/settings_screen.dart
git commit -m "refactor(settings): remove clutter subtitles and standardize tile typography"
```

---

### Task 5: Full Regression Testing & Verification

**Files:**
- All modified files across features and tests.

- [ ] **Step 1: Full static analysis**

Run: `flutter analyze --no-pub`
Expected: 0 errors, 0 warnings.

- [ ] **Step 2: Full test suite execution**

Run: `flutter test --no-pub`
Expected: 103/103 tests passed.

- [ ] **Step 3: Review git status and diff**

Run: `git status -s` and `git diff HEAD~4`
Verify clean changes and no regressions.
