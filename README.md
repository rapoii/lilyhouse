# 🌸 LilyHouse

A modern, offline-first mobile application designed specifically for cosplay costume rental businesses (**Lilycosrent**), built with **Flutter** and strictly crafted according to **Apple iOS & macOS Human Interface Guidelines (HIG)**.

---

## ✨ Features

- **🎨 100% Authentic Apple HIG Aesthetic**:
  - Inset-grouped form sections with 12px padding and hairline 0.5px borders (`#E5E5EA`).
  - SF Pro typography hierarchy and native `CupertinoIcons`.
  - Floating frosted-glass dock navigation bar with dynamic 1:1 dragging indicator and liquid color flow.
  - Interactive two-layer draggable segmented controls (`AppleSlidingSegmentedControl`) with real-time text weight/color transition.
  - 85% viewport rounded modal sheets (`CupertinoModalPopup`) and inline expandable iOS date pickers.
  - High refresh-rate engine support (up to 240Hz display mode unlock).

- **⚡ WhatsApp Smart Order Parser**:
  - Instant one-tap clipboard parsing for booking formats (10-point customer data: identity, emergency contact, costume item, rental dates, purpose, KTP/KIA, selfie ID).
  - Smart date range detector with auto-duration and pricing calculations.

- **👗 Complete Costume Catalog & Sub-Ledger**:
  - Costume inventory tracking with rental status (Available, Booked, Rented).
  - Sub-ledger accessory tracking (wigs, props, accessories) linked to primary costume IDs.
  - In-app photo picker and gallery storage.

- **📅 Conflict-Free Booking Calendar**:
  - Integrated rental schedule viewer with automatic clash detection across overlapping dates.

- **💳 Installment Book (Buku Cicilan)**:
  - Financial ledger for costume investments and installment plans.
  - Real-time remaining balance and payment log tracking with proof-of-payment receipts.

- **☁️ Offline-First & Google Sheets/Drive Cloud Sync**:
  - Primary local storage powered by SQLite (`sqflite`).
  - Background sync queue for resilient offline transactions.
  - Serverless cloud integration via Google Apps Script (GAS) Web App, syncing rows to Google Sheets and storing photos in Google Drive.

---

## 🛠️ Architecture & Tech Stack

- **Framework**: [Flutter](https://flutter.dev) (iOS Cupertino design language)
- **State Management**: [Riverpod](https://riverpod.dev)
- **Local Database**: [SQLite](https://pub.dev/packages/sqflite)
- **Backend / Sync**: Google Apps Script (GAS) Web API + Google Sheets & Google Drive
- **Code Graph Engine**: Full project symbol indexing and call-graph analysis via [CodeGraph](https://github.com)

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK 3.24+ (Dart 3.5+)
- Android SDK (API 34+)
- Git

### Installation

```bash
# Clone the repository
git clone https://github.com/rapoii/lilyhouse.git
cd lilyhouse

# Install dependencies
flutter pub get

# Run tests
flutter test

# Run on connected device or emulator
flutter run
```

### Building Release APK

To generate an optimized release build for Android devices:

```bash
flutter build apk --release --split-per-abi
```
Target arm64 APK will be generated at `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (~17.5 MB).

---

## 📄 License

MIT License. Designed with ❤️ for **Lilycosrent**.
