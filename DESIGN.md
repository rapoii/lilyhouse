---
version: alpha
name: LilyHouse Design System
description: Warm Minimalist Apple HIG design tokens, layout hierarchy, and 240fps motion standards for LilyHouse.
colors:
  primary: "#D81B60"
  primary-light: "#FF85A1"
  primary-pastel: "#FFA6BA"
  primary-soft-bg: "#FFE5EC"
  background: "#F8F9FA"
  surface: "#FFFFFF"
  text-primary: "#2D2D3A"
  text-muted: "#8C8CA1"
  text-secondary: "#6C6C70"
  success: "#1B5E20"
  success-bg: "#E8F5E9"
  warning: "#E65100"
  warning-bg: "#FFF3E0"
  danger: "#B71C1C"
  danger-bg: "#FFEBEE"
  border-subtle: "#E5E5EA"
  overlay-dark: "#1C1C1E"
typography:
  large-title:
    fontFamily: SF Pro Display
    fontSize: 22px
    fontWeight: 700
    lineHeight: 1.2
    letterSpacing: "-0.4px"
  nav-title:
    fontFamily: SF Pro Text
    fontSize: 17px
    fontWeight: 600
    lineHeight: 1.2
    letterSpacing: "-0.2px"
  headline:
    fontFamily: SF Pro Text
    fontSize: 17px
    fontWeight: 600
    lineHeight: 1.3
    letterSpacing: "-0.2px"
  body:
    fontFamily: SF Pro Text
    fontSize: 15px
    fontWeight: 400
    lineHeight: 1.4
    letterSpacing: "-0.2px"
  section-header:
    fontFamily: SF Pro Text
    fontSize: 13px
    fontWeight: 500
    lineHeight: 1.3
    letterSpacing: "-0.1px"
  subhead:
    fontFamily: SF Pro Text
    fontSize: 13px
    fontWeight: 400
    lineHeight: 1.3
    letterSpacing: "-0.1px"
  badge:
    fontFamily: SF Pro Text
    fontSize: 12px
    fontWeight: 700
    lineHeight: 1.0
    letterSpacing: "0.0px"
  caption:
    fontFamily: SF Pro Text
    fontSize: 11px
    fontWeight: 400
    lineHeight: 1.2
    letterSpacing: "0.0px"
rounded:
  xs: 6px
  sm: 8px
  md: 10px
  lg: 12px
  pill: 9999px
spacing:
  xs: 4px
  sm: 8px
  md: 12px
  lg: 16px
  xl: 20px
  xxl: 24px
  card-padding: 16px
  card-gap: 12px
  scroll-bottom-margin: 160px
components:
  card-floating:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.text-primary}"
    rounded: "{rounded.lg}"
    padding: "{spacing.card-padding}"
  badge-pill-success:
    backgroundColor: "{colors.success-bg}"
    textColor: "{colors.success}"
    rounded: "{rounded.pill}"
    padding: 6px
  badge-pill-warning:
    backgroundColor: "{colors.warning-bg}"
    textColor: "{colors.warning}"
    rounded: "{rounded.pill}"
    padding: 6px
  badge-pill-danger:
    backgroundColor: "{colors.danger-bg}"
    textColor: "{colors.danger}"
    rounded: "{rounded.pill}"
    padding: 6px
  badge-pill-soft:
    backgroundColor: "{colors.primary-soft-bg}"
    textColor: "{colors.primary}"
    rounded: "{rounded.pill}"
    padding: 6px
  button-action:
    backgroundColor: "{colors.primary-soft-bg}"
    textColor: "{colors.primary}"
    rounded: "{rounded.md}"
    padding: 10px
  button-secondary:
    backgroundColor: "{colors.primary-pastel}"
    textColor: "{colors.surface}"
    rounded: "{rounded.md}"
    padding: 10px
  toast-capsule:
    backgroundColor: "{colors.overlay-dark}"
    textColor: "{colors.surface}"
    rounded: "{rounded.pill}"
    padding: 12px
  list-tile-meta:
    backgroundColor: "{colors.background}"
    textColor: "{colors.text-muted}"
    rounded: "{rounded.sm}"
    padding: 8px
  list-section-header:
    backgroundColor: "{colors.background}"
    textColor: "{colors.text-secondary}"
    rounded: "{rounded.xs}"
    padding: 4px
  accent-indicator:
    backgroundColor: "{colors.primary-light}"
    textColor: "{colors.surface}"
    rounded: "{rounded.pill}"
    padding: 4px
  divider-line:
    backgroundColor: "{colors.border-subtle}"
    textColor: "{colors.text-primary}"
    height: 1px
---

## Overview

LilyHouse mengadopsi bahasa desain **Warm Minimalist Apple HIG (iOS 18 Pure)**.
Desain ini berakar pada tiga prinsip utama:
1. **Ekstrem Minimalis**: Menghilangkan clutter visual dan kebisingan kognitif di seluruh layar utama.
2. **Keterbacaan Lintas Usia (Age-Inclusive)**: Tipografi besar, kontras tegas, dan target sentuh lapang.
3. **Gerakan Sangat Mulus (240fps++ Motion)**: Animasi mikro berbasis pegas (*easeOutCubic*) yang responsif tanpa frame-drop di layar refresh rate tinggi.

Standar ini berlaku mutlak untuk seluruh layar, kartu, modal sheet, dan dialog di LilyHouse.

---

## Colors

Palet warna LilyHouse mengutamakan nuansa hangat (*warm palette*). **Dilarang keras menggunakan abu-abu dingin/polos (*cold gray*)** yang membuat UI tampak kaku atau mentah.

### Palet Inti
- **Primary Light / Brand Pink (`#FF85A1`)**: Warna aksen utama identitas brand LilyHouse. Digunakan untuk sorotan metrik kunci, indikator aktif, dan aksen visual.
- **Primary Dark / Interactive Pink (`#D81B60`)**: Warna pink kontras tinggi untuk label teks tombol interaktif dan badge agar mudah dibaca oleh semua usia.
- **Pastel Pink (`#FFA6BA`)**: Aksen sekunder yang lebih lembut untuk transisi visual.
- **Soft Pink Background (`#FFE5EC`)**: Latar belakang kontainer interaktif, pill badge aktif, dan tombol ikon melingkar.
- **Background Utama (`#F8F9FA`)**: *Warm off-white* lembut sebagai latar belakang layar aplikasi. Menghindari putih mentah (`#FFFFFF`) agar mata tidak cepat lelah saat penggunaan lama.
- **Surface / Card Background (`#FFFFFF`)**: Putih bersih untuk kartu mengambang (*floating cards*) dan sheet kontainer.

### Warna Teks & Netral
- **Text Primary (`#2D2D3A`)**: Tinta gelap dengan undertone hangat untuk judul dan teks utama.
- **Text Muted (`#8C8CA1`)**: Abu-abu hangat untuk subhead, metadata, dan tanggal.
- **Text Secondary (`#6C6C70`)**: Abu-abu netral Apple (iOS `secondaryLabel`) untuk header section.
- **Border Subtle (`#E5E5EA`)**: Hairline separator 0.5pt standar iOS untuk batas kartu dan pemisah list.
- **Overlay Dark (`#1C1C1E`)**: Hitam pekat iOS untuk Dynamic Island Toast dan backdrop modal.

### Warna Status Semantik
- **Success Mint (`#67D4A8` / Text `#1B5E20`, Bg `#E8F5E9`)**: Status `Tersedia`, transaksi `Lunas`, dan sinkronisasi aktif.
- **Warning Orange (`#FFAA5A` / Text `#E65100`, Bg `#FFF3E0`)**: Status `Perawatan`, cicilan `Jatuh Tempo`, dan penundaan.
- **Danger Rose (`#FF5964` / Text `#B71C1C`, Bg `#FFEBEE`)**: Status error, peringatan batas akhir, dan aksi destruktif.

---

## Typography

Seluruh tipografi mengikuti hierarki baku Apple Human Interface Guidelines (SF Pro System Standards):

| Token / Style | Ukuran | Bobot | Tracking | Penggunaan Utama |
|---|---|---|---|---|
| `largeTitle` | 22pt | Bold (w700) | -0.4 | Header tab utama (Katalog, Kalender, Cicilan, Pengaturan) |
| `navTitle` | 17pt | Semibold (w600) | -0.2 | Judul bilah navigasi detail / modal |
| `headline` | 17pt | Semibold (w600) | -0.2 | Judul kartu utama (Aturan Elemen 1) |
| `body` | 15pt | Regular (w400) | -0.2 | Isi teks konten, deskripsi form |
| `actionButton`| 15pt | Semibold (w600) | -0.2 | Tombol aksi header bar (*Smart Paste*, *Tambah*) |
| `subhead` | 13pt | Regular (w400) | -0.1 | Label sekunder, tanggal ringkas |
| `sectionHeader` | 13pt | Medium (w500) | -0.1 | Header `CupertinoListSection` / Inset Grouped |
| `badge` | 12–13pt | Bold (w700) | 0.0 | Teks pill status (Aturan Elemen 2) |
| `caption` | 11pt | Regular (w400) | 0.0 | Metadata pendukung |

### Aturan Anti Double Yellow Underline
Pada widget berbasis Cupertino yang me-render teks tanpa `Scaffold` Material langsung, bungkus selalu dengan `DefaultTextStyle`:
```dart
DefaultTextStyle(
  style: const TextStyle(
    decoration: TextDecoration.none,
    fontFamily: '.SF Pro Text',
    color: AppColors.textDark,
  ),
  child: child,
)
```

---

## Layout

### 1. The 3-Element Rule (Aturan 3 Elemen Utama)
Setiap kartu daftar (*list card*) pada layar utama **hanya boleh** menampilkan maksimal 3 elemen esensial:
1. **Identitas Utama (Title)**: Ukuran font **17pt Semibold** (`#2D2D3A`). Maksimal 1 baris dengan truncation `TextOverflow.ellipsis`.
2. **Kondisi / Status (Badge)**: Badge pill halus dengan teks **12–13pt Bold**. Maksimal 1 kata status ringkas (`Tersedia`, `Disewa`, `Cicilan`, `Lunas`).
3. **Metrik Kunci (Key Number)**: Ukuran font **16pt Bold/Semibold** (`AppColors.primaryPink` atau `#2D2D3A`). Nominal rupiah atau tanggal yang langsung menjawab pertanyaan pengguna.

*Seluruh detail tambahan (nama toko, breakdown cicilan, kelengkapan aksesoris, ukuran pakaian, catatan transaksi) disembunyikan dan dialihkan ke lembar detail (*Progressive Disclosure*).*

### 2. Dimensi Kartu Ramah Usia (Age-Inclusive Target)
- **Tinggi Minimum Kartu**: **72pt**.
- **Padding Internal**: **16pt** merata.
- **Jarak Antar Kartu (Gap)**: **12pt**.
- **Scroll Margin Bawah**: Wajib menyisakan ruang kosong **160–180pt** di bagian bawah setiap list (`SizedBox(height: 180)` atau `contentPadding: EdgeInsets.only(bottom: 180)`) agar kartu terbawah tidak terpotong atau tertutup Floating Bottom Bar.

### 3. Struktur Inset Grouped
Gunakan gaya Inset Grouped iOS untuk form, pengaturan, dan detail:
- Margin horizontal: 16pt.
- Sudut lengkung grup: 12pt.
- Separator: 0.5pt hairline warna `#E5E5EA`.

---

## Elevation & Depth

Desain LilyHouse mengandalkan pencahayaan lembut (*soft diffused depth*) dan batas hairline, bukan drop shadow gelap bertingkat:

- **Floating Card Depth**:
  - Border: Hairline `0.5pt` solid `Color(0xFFE5E5EA)`.
  - Box Shadow: `BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 1))`.
- **Modal Sheet Elevation**:
  - Dimmer latar belakang: `Color(0x66000000)` (black 40%).
  - Permukaan sheet: Putih solid `#FFFFFF` dengan grabber netral abu-abu `Color(0xFFD1D1D6)` (lebar 36pt, tinggi 5pt, radius pill).

---

## Shapes

- **Floating Cards**: Radius sudut **12pt** (`BorderRadius.circular(12)`).
- **Photo Thumbnails**: Dimensi 52×52pt dengan radius sudut **10pt**.
- **Pill Badges**: Radius penuh **9999pt** (`BorderRadius.circular(9999)` atau `StadiumBorder`).
- **Squircle Icons**: Ikon menu dan fitur dibungkus dalam kontainer squircle Apple dengan radius melengkung mulus dan warna background pastel bertingkat (12% opacity).
- **Tombol Salin**: Lingkaran simetris murni (`BoxShape.circle`) dengan diameter 32–36pt, bukan tombol pill memanjang.

---

## Components

### 1. Floating Card & Pressable Feedback (`PressableCard`)
Setiap kartu daftar wajib dibungkus dengan `PressableCard`:
- Efek tekan (*press-down*): Skala menyusut ke **0.97** secara instan dengan kurva `Curves.easeOutCubic` (durasi 120ms).
- Feedback fisik: Memicu `HapticFeedback.lightImpact()`.
- Efek lepas: Kembali ke skala **1.0** secara responsif.

### 2. Staggered Cascade List (`AnimatedListItem`)
Setiap elemen daftar yang masuk ke layar wajib memiliki transisi bertingkat:
- Delay per item: `index * 30ms` (maksimal diclamp hingga 12 item / 360ms agar pengguna tidak menunggu).
- Transisi: Fade-in (0.0 → 1.0) dikombinasikan dengan Slide-up (translasi Y 16pt → 0pt).
- Durasi: **260ms** dengan kurva `Curves.easeOutCubic`.
- Reset Key: Ketika filter atau tanggal berganti, pasang `UniqueKey()` pada list subtree agar animasi masuk kembali terpicu mulus.

### 3. State Crossfade (`StateCrossfade`)
Transisi pergantian status layar (Loading ↔ Empty ↔ Content):
- Menggunakan `AnimatedSwitcher` dengan durasi 220ms `Curves.easeOutCubic`.
- Mencegah layout jump seketika saat data selesai dimuat dari SQLite/GAS.

### 4. Dynamic Island Toast (`IosToast`)
Notifikasi cepat mengambang di atas layar:
- Tampilan: Kapsul hitam pekat `#1C1C1E` dengan sudut pill penuh, ikon semantik pastel, dan teks putih tanpa dekorasi garis bawah.
- Animasi Masuk: Slide-down (Y -20pt → 0pt) + Fade-in (0.0 → 1.0) selama **260ms** `Curves.easeOutCubic`.
- Animasi Keluar: Slide-up (Y 0pt → -12pt) + Fade-out (1.0 → 0.0) selama **200ms** `Curves.easeIn`.

### 5. Bottom Sheet (`DraggableSheetContainer`)
- Lembar modal swipeable dengan pegas penutup interaktif.
- Selector cepat (chooser) harus snug dengan rasio tinggi layar **0.28 – 0.34**.
- Grabber bar horizontal berwarna netral abu-abu lembut.

### 6. Media Preview (KTP & Foto Bukti)
Seluruh tinjauan foto sensitif (KTP, bukti transfer, foto fisik sewa) wajib dibungkus dalam `InteractiveViewer` untuk mendukung gestur pinch-to-zoom dan panning yang lancar.

---

## Do's and Don'ts

### Do's
- **Gunakan Chevron `>` HANYA untuk aksi navigasi atau membuka modal sheet.** Jika baris tidak bisa ditekan, jangan tampilkan chevron.
- **Sediakan `subtitle` pada `CupertinoListTile`** jika baris memuat keterangan. Jika tanpa catatan, set `subtitle: null` agar angka nominal tetap berada di tengah vertikal (*vertically centered*).
- **Gunakan Bahasa Indonesia yang ramah dan konsisten** untuk seluruh label, placeholder, dan pesan sistem.
- **Terapkan `Curves.easeOutCubic`** untuk semua gerakan visual antarmuka agar mendukung refresh rate tinggi (240fps+).
- **Bungkus tombol salin dengan bentuk lingkaran** (`doc_on_doc` icon dalam softPinkBg circular container).
- **Pertahankan 6 Titik Sinkronisasi Versi** saat merilis versi baru (`pubspec.yaml`, `build.gradle.kts` baseCode, `settings_screen.dart` tile info, `settings_screen.dart` about sheet, modal changelog, dan subtitle).

### Don'ts
- **DILARANG KERAS menggunakan emoji / emoticon dalam bentuk apapun** pada teks antarmuka, judul banner, kartu, maupun pesan toast notifikasi (contoh yang dilarang: `✨`, `📋`, `🎉`, `❌`, `✅`).
- **Dilarang menggunakan Material Ripple / InkWell kotak.** Gunakan Cupertino touch feedback atau `PressableCard` scale.
- **Dilarang menaruh badge berderet banyak di kartu utama.** Terapkan aturan 3 elemen.
- **Dilarang menggunakan abu-abu dingin/netral murni.** Berikan selalu warm tint pada background dan ikon.
- **Dilarang menampilkan angka versi dengan format patch ganda liar** (`+xx`); gunakan sinkronisasi versi standar semantik.
- **Dilarang menyisakan timer aktif tanpa pembatalan di `dispose()`** pada komponen animasi (`_timer?.cancel()`).
