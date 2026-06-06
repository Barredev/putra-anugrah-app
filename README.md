# Putra Anugrah App

Aplikasi manajemen toko material bangunan dan mebel berbasis Flutter (Android). Dirancang untuk membantu owner mengelola stok, produksi, keuangan, dan hutang piutang dalam satu aplikasi.

---

## Fitur Utama

### Manajemen Produk
- 3 kategori produk: Bahan Bangunan, Bahan Baku Mebel, Produk Jadi Mebel
- Tambah, edit, hapus produk
- Stok support angka desimal (liter, meter, kg, dll)
- Peringatan otomatis stok menipis & stok habis
- Search produk & filter berdasarkan kondisi stok

### Bill of Materials (BOM)
- Buat resep bahan untuk setiap produk jadi
- Validasi ketersediaan bahan sebelum produksi dijalankan

### Produksi
- Input produksi → stok bahan baku otomatis berkurang sesuai BOM
- HPP (Harga Pokok Produksi) otomatis tercatat di laporan keuangan

### Hutang Piutang
- Catat piutang pelanggan & hutang ke supplier
- Catat pembayaran sebagian maupun lunas
- Status otomatis: OPEN → PARTIAL → PAID
- Notifikasi tagihan jatuh tempo di dashboard

### Laporan Keuangan
- Grafik pemasukan & pengeluaran harian (line chart / bar chart)
- Filter per bulan & per kategori
- Ringkasan per kategori beserta detail per produk
- Pemasukan, pengeluaran, dan profit per produk dalam tiap kategori

### Laporan Laba Per Produk
- Laba bersih per produk jadi
- Filter all time & per bulan
- Ranking produk paling menguntungkan dengan margin %

### Keamanan
- PIN lock 4 digit saat buka aplikasi
- Maksimal 5 percobaan salah, lalu PIN di-reset

### Backup & Restore
- Backup database ke folder Download
- Restore dari file backup `.db`

---

## Logika Keuangan

| Aksi | Finance |
|------|---------|
| Beli Bahan Bangunan (MATERIAL) | EXPENSE |
| Beli Bahan Baku Mebel (RAW) | Tidak dicatat |
| Produksi | EXPENSE (HPP otomatis) |
| Jual produk | INCOME |
| Bayar piutang pelanggan | INCOME |
| Bayar hutang supplier | EXPENSE |

---

## Tech Stack

| Komponen | Detail |
|----------|--------|
| Framework | Flutter |
| Platform | Android |
| Database | SQLite via `sqflite` |
| State Management | setState |
| Chart | `fl_chart` |
| Splash Screen | `flutter_native_splash` |
| PIN Storage | `shared_preferences` |
| Storage Permission | `permission_handler` |

---

## Struktur Folder

```
lib/
├── database/
│   ├── database_helper.dart    # Semua query & logika DB
│   └── dummy_seeder.dart       # Data dummy (development only)
├── models/
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
├── services/
└── widgets/
```

---

## Database Schema

```
categories      → id, name, type (MATERIAL/RAW/PRODUCT/DEBT)
products        → id, name, category_id, stock, purchase_price, selling_price, unit, min_stock
bom             → id, product_id, material_id, quantity
finance         → id, type, amount, date, note, ref_id, category_id
stock_movements → id, product_id, type, quantity, date, note, ref_id
production_logs → id, product_id, qty_produced, note, created_at
contacts        → id, name, phone, address, type (CUSTOMER/SUPPLIER)
debts           → id, contact_id, debt_type, amount, amount_paid, due_date, status, note, created_at
```

---

## Instalasi & Setup

### Requirements
- Flutter SDK >= 3.0.0
- Android SDK >= 21 (Android 5.0)
- Dart >= 3.0.0

### Dependencies
Tambahkan ke `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  sqflite: ^2.3.0
  path: ^1.8.3
  path_provider: ^2.1.1
  permission_handler: ^11.0.0
  fl_chart: ^0.66.0
  flutter_native_splash: ^2.3.6
  shared_preferences: ^2.2.2
```

### Jalankan Project
```bash
flutter pub get
flutter run
```

---

## Database Migration

Versi database saat ini: **v5**

| Versi | Perubahan |
|-------|-----------|
| v1 | Schema awal: products, finance, stock_movements |
| v2 | Tambah: categories, bom, kolom note |
| v3 | Tambah: contacts, debts, production_logs. Migrasi stock ke REAL |
| v4 | Tambah: category_id di tabel finance |
| v5 | Tambah: kategori Hutang Piutang |

---

## Catatan Development

- `dummy_seeder.dart` hanya untuk keperluan testing — **jangan dijalankan di production**
- Backup file tersimpan di `Download/backup_[timestamp].db`
- Produk kategori RAW tidak dicatat ke finance saat pembelian — HPP baru dicatat saat produksi

---

## Screenshot

> Coming soon

---

## Developer

Dikembangkan untuk kebutuhan internal toko **Putra Anugrah**.