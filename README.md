# Putra Anugrah App

Aplikasi manajemen toko material bangunan dan mebel berbasis Flutter (Android) secara **offline-first**. Dirancang untuk membantu owner mengelola stok, produksi berbasis resep (BOM), arus kas, laba per produk, dan hutang piutang dalam satu aplikasi.

---

## Fitur Utama

### Manajemen Produk
- 3 kategori default: **Bahan Bangunan** (`MATERIAL`), **Bahan Baku Mebel** (`RAW`), **Produk Jadi Mebel** (`PRODUCT`)
- Tambah, **edit**, dan hapus produk dengan format input ribuan otomatis
- Stok mendukung angka desimal (`REAL` — liter, meter, kg, dll)
- Transaksi Barang Masuk / Keluar dengan pilihan **Tunai** vs **Non-Tunai** (piutang / barang rusak)
- Peringatan otomatis stok menipis & stok habis
- Pencarian produk (dengan highlight) & filter kondisi stok

### Bill of Materials (BOM)
- Susun resep bahan baku untuk setiap produk jadi
- Indikator kecukupan stok bahan secara langsung

### Produksi
- Input jumlah produksi (atau buka langsung dari kartu produk) → stok bahan baku otomatis berkurang dan stok produk jadi bertambah secara atomik
- Validasi ketersediaan bahan secara real-time di dalam transaksi
- HPP produksi otomatis dihitung (`qty × harga beli bahan`) dan dicatat dengan tipe khusus `HPP` agar tidak tercampur dengan pengeluaran kas di Dashboard

### Hutang Piutang
- Catat piutang pelanggan & hutang ke supplier (kontak tersimpan atau buat baru)
- Catat pembayaran sebagian maupun lunas dengan format ribuan otomatis
- Status otomatis: `OPEN` → `PARTIAL` → `PAID`
- **Riwayat cicilan** per tagihan beserta tanggal/jam pembayaran
- Notifikasi tagihan jatuh tempo di Dashboard dengan filter langsung ke tagihan terlambat

### Laporan Keuangan & Laba Per Produk
- Grafik pemasukan & pengeluaran harian (`fl_chart` — line chart / bar chart)
- Filter per bulan & per kategori, serta rincian pemasukan/pengeluaran/profit per produk
- **Laporan Laba Per Produk**: menghitung laba bersih berdasarkan **HPP barang terjual** (`qty_sold × rata-rata tertimbang HPP/unit`, fallback ke estimasi BOM / harga beli), bukan total biaya produksi periode tersebut, lengkap dengan margin % & ranking

### Keamanan
- PIN lock 4 digit saat membuka aplikasi
- **Cooldown lockout bertingkat** (30 detik → 60 detik → 120 detik → maks 5 menit) setelah 5 kali salah percobaan, tersimpan persisten di `SharedPreferences`
- Fitur **Ganti PIN** di Dashboard (wajib verifikasi PIN lama terlebih dahulu)

### Backup & Restore
- Backup database `.db` melalui pemilih file sistem (Storage Access Framework / `file_picker`) dengan `PRAGMA wal_checkpoint(FULL)`
- Restore dari file backup `.db` pilihan user dengan **validasi header SQLite & struktur tabel** terlebih dahulu serta **rollback otomatis** bila terjadi error

---

## Logika Keuangan

| Aksi | Dampak ke Tabel `finance` |
|------|---------------------------|
| Barang Masuk — Tunai (`isCash: true`) | `EXPENSE` (terhubung via `ref_id = product_id`) |
| Barang Masuk — Non-Tunai (`isCash: false`) | Tidak dicatat ke kas (hanya tambah stok) |
| Barang Keluar — Tunai (`isCash: true`) | `INCOME` (terhubung via `ref_id = product_id`) |
| Barang Keluar — Non-Tunai (`isCash: false`) | Tidak dicatat ke kas (hanya potong stok) |
| Produksi | `HPP` (dipakai untuk perhitungan HPP/unit, tidak dihitung sebagai pengeluaran kas) |
| Bayar piutang pelanggan | `INCOME` (`ref_id = debt_id`, `category_id = null`) |
| Bayar hutang supplier | `EXPENSE` (`ref_id = debt_id`, `category_id = null`) |

---

## Tech Stack

| Komponen | Detail |
|----------|--------|
| Framework | Flutter (Material 3) |
| Platform | Android |
| Database | SQLite via `sqflite` |
| State Management | `setState` + Repository Pattern |
| Chart | `fl_chart` |
| Backup/Restore Picker | `file_picker` (SAF) |
| Splash Screen | `flutter_native_splash` |
| PIN Storage | `shared_preferences` |

---

## Struktur Folder

```text
lib/
├── main.dart
├── database/
│   ├── database_helper.dart              # Koneksi DB, migrasi v1–v5, backup/restore & façade
│   └── repositories/
│       ├── product_repository.dart       # Kategori, produk, BOM, stok menipis
│       ├── production_repository.dart    # Produksi atomik & log produksi
│       ├── finance_repository.dart       # Stok in/out, arus kas, dashboard & laba produk
│       └── debt_repository.dart          # Kontak, hutang piutang, cicilan & ringkasan
├── models/
│   ├── category.dart
│   ├── debt.dart
│   └── product.dart
├── screens/
│   ├── splash_screen.dart
│   ├── pin_screen.dart
│   ├── setup_pin_screen.dart
│   ├── dashboard_screen.dart
│   ├── product_screen.dart
│   ├── add_product_screen.dart
│   ├── analysis_screen.dart
│   ├── profit_screen.dart
│   ├── production_screen.dart
│   ├── bom_screen.dart
│   ├── debt_screen.dart
│   ├── add_debt_screen.dart
│   └── debt_detail_screen.dart
├── utils/
│   └── formatters.dart                   # formatRupiah, formatQty, CurrencyInputFormatter, dll
└── widgets/
    ├── month_picker_dialog.dart          # Dialog pilih bulan bersama
    └── pin_numpad.dart                   # Numpad PIN bersama
```

---

## Database Schema & Migrasi

Versi database saat ini: **v5**

```text
categories      → id, name, type (MATERIAL / RAW / PRODUCT)
products        → id, name, category_id, stock (REAL), purchase_price, selling_price, unit, min_stock (REAL)
bom             → id, product_id, material_id, quantity (REAL)
finance         → id, type (INCOME / EXPENSE / HPP), amount, date, note, ref_id, category_id
stock_movements → id, product_id, type (IN / OUT / PRODUCTION_IN / PRODUCTION_OUT), quantity (REAL), date, note, ref_id
production_logs → id, product_id, qty_produced (REAL), note, created_at
contacts        → id, name, phone, address, type (CUSTOMER / SUPPLIER)
debts           → id, contact_id, debt_type (RECEIVABLE / PAYABLE), amount, amount_paid, due_date, status, note, created_at
```

| Versi | Perubahan |
|-------|-----------|
| v1 | Schema awal: `products`, `finance`, `stock_movements` |
| v2 | Tambah: `categories`, `bom`, kolom `note` & `ref_id` |
| v3 | Tambah: `contacts`, `debts`, `production_logs`. Migrasi `stock` & `quantity` ke `REAL` |
| v4 | Tambah: `category_id` di tabel `finance` |
| v5 | Backfill `ref_id` pada tabel `finance` dari `stock_movements` agar laporan produk & laba tidak bergantung pada JOIN timestamp |

---

## Jalankan & Uji Project

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

---

## Developer

Dikembangkan untuk kebutuhan internal toko **Putra Anugrah**.
