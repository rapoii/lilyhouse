# Design Document: Minimalist & Age-Inclusive UX Overhaul

- **Date**: 2026-09-14
- **Project**: LilyHouse
- **Author**: Lily & Rafi Permana
- **Status**: Approved by User

---

## 1. Problem Statement & Background
Aplikasi LilyHouse telah memenuhi standar visual murni Apple Human Interface Guidelines (HIG) iOS 18 (zero Material remnants, hairline borders, warm off-white background `0xFFF8F9FA`). Namun dari sisi *User Experience* (UX), antarmuka saat ini terlalu padat teks (*high cognitive load*).
- Informasi detail (nama toko, tanggal, persentase, catatan, ukuran, aksesoris) ditaruh sekaligus di kartu list utama.
- Font pendukung berukuran kecil dan berderet rapat, menyulitkan pengguna dari berbagai rentang usia (termasuk pengguna yang matanya mudah lelah atau ingin membaca sekilas/glanceability).
- Diperlukan perombakan tata letak menuju **Ekstrem Minimalis**, mengutamakan keterbacaan tinggi (*Large & Legible*), kartu melayang mandiri (*Floating Minimalist Cards*), dan pengalihan informasi sekunder ke lembar detail (*Progressive Disclosure*).

---

## 2. Core UX Principles

### 2.1 Aturan 3 Elemen Utama (The 3-Element Rule)
Setiap kartu daftar pada layar utama hanya boleh menampilkan maksimal 3 elemen esensial:
1. **Identitas Utama (Title)**: Ukuran font **17pt Semibold** (`#1C1C1E`). Maksimal 1 baris dengan truncation `TextOverflow.ellipsis`.
2. **Kondisi / Status (Badge)**: Badge pill halus dengan teks **12–13pt Bold**. Maksimal 1 kata status ringkas (`Tersedia`, `Disewa`, `Cicilan`, `Lunas`).
3. **Metrik Kunci (Key Number)**: Ukuran font **16pt Bold/Semibold**. Nominal rupiah atau tanggal esensial yang langsung menjawab pertanyaan utama pengguna.

### 2.2 Progressive Disclosure
Informasi pelengkap (metadata non-kritis) disembunyikan sepenuhnya dari daftar kartu utama dan hanya disajikan saat kartu ditekan (*tap to open detail/sheet*).

### 2.3 Sentuhan Ramah Usia (Age-Inclusive Touch Target)
- Tinggi minimum kartu: **72pt**.
- Padding internal kartu: **16pt** merata.
- Jarak antar kartu (*gap*): **12pt**.
- Menghindari tombol mikro di dalam kartu yang rawan salah pencet.

---

## 3. Spesifikasi Per Halaman / Tab

### 3.1 Tab Katalog Kostum (`costume_card.dart` & `costume_list_screen.dart`)
- **Tampilan Kartu**:
  - Thumbnail foto: 52×52pt (sudut bulat radius 10).
  - Judul: Nama karakter/kostum (17pt Semibold, misal: *Hu Tao*, *Furina*).
  - Status Badge: `Tersedia` (mint), `Disewa` (soft pink), `Perawatan` (oranye muda).
  - Metrik Kunci: Nominal harga sewa format ringkas (`Rp 150rb / 3hr`, 15pt Bold warna `AppColors.primaryPink`).
- **Elemen yang Dihapus dari Kartu**:
  - Teks seri anime/game.
  - Badge ukuran pakaian (*Size M*, *Size L*).
  - Jumlah kelengkapan aksesoris.
- **Tujuan Detail**: Semua informasi ukuran, seri anime, dan daftar aksesoris tetap dapat diakses penuh melalui `costume_detail_screen.dart`.

### 3.2 Tab Cicilan (`installment_card.dart` & `installment_list_screen.dart`)
- **Tampilan Kartu**:
  - Judul: Nama barang / kostum (17pt Semibold).
  - Status Badge: `Cicilan` atau `Lunas`.
  - Metrik Kunci: Sisa tagihan format jelas (`Sisa Rp 450.000`, 16pt Bold).
  - Progress Bar: Garis aksen ramping tinggi 6pt (warna mint/pink), tanpa label teks persentase numerik.
- **Elemen yang Dihapus dari Kartu**:
  - Teks nama toko/penjual.
  - Tanggal pembuatan / batas jatuh tempo.
  - Breakdown nominal total harga dan nominal sudah dibayar.
  - Catatan transaksi.
- **Tujuan Detail**: Breakdown lengkap pembayaran, toko, dan riwayat cicilan diakses via `installment_detail_screen.dart`.

### 3.3 Tab Kalender Rental (`calendar_screen.dart`)
- **Tampilan Kartu Booking Event**:
  - Judul: Nama penyewa & kostum yang disewa (17pt Semibold).
  - Status Badge: `Aktif`, `Selesai`, `Menunggu`.
  - Metrik Kunci: Rentang tanggal sewa yang jelas (15pt Medium) atau total biaya.
- **Elemen yang Dihapus dari Kartu**:
  - Alamat atau nomor kontak penyewa.
  - Daftar perintilan aksesoris yang dipinjam.
  - Catatan uang jaminan/deposit.
- **Tujuan Detail**: Lembar `rental_detail_sheet.dart` tetap menjadi tempat utama pengecekan KTP, deposit, dan kontak penyewa.

### 3.4 Tab Pengaturan (`settings_screen.dart`)
- **Penyederhanaan Baris Menu**:
  - Menghilangkan teks subtitle penjelasan panjang di bawah label menu utama yang jarang dibaca.
  - Mempertahankan ikon menu yang tegas dalam kontainer squircle warna pastel.
  - Judul menu ditingkatkan ke 17pt Regular/Medium untuk kemudahan membaca.
  - Indikator status sinkronisasi cloud disajikan visual (warna titik status) tanpa paragraf penjelas teknis.

---

## 4. Design Tokens & Styling Guide
- **Container**: `BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Color(0xFFE5E5EA), width: 0.5), boxShadow: [BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 1))])`
- **Background Halaman**: `AppColors.background` (`0xFFF8F9FA` warm off-white).
- **Text Primary**: 17pt, `FontWeight.w600`, color `Color(0xFF1C1C1E)`.
- **Text Highlight / Metric**: 15–16pt, `FontWeight.w700`, color `AppColors.primaryPink` atau `Color(0xFF1C1C1E)`.
- **Badge Font**: 12–13pt, `FontWeight.bold`.

---

## 5. Rencana Verifikasi & Testing
- Memperbarui widget test (`costume_screens_test.dart`, dll.) untuk menyesuaikan ekspektasi teks di kartu (memastikan finder tidak gagal karena penghapusan badge anime/ukuran di layar list).
- Memastikan `flutter analyze --no-pub` tetap exit 0 (0 error, 0 warning).
- Menjalankan seluruh test suite hingga 103/103 passed.
