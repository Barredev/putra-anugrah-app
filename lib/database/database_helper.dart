import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

import 'repositories/debt_repository.dart';
import 'repositories/finance_repository.dart';
import 'repositories/product_repository.dart';
import 'repositories/production_repository.dart';

/// Mengelola koneksi SQLite, migrasi schema, backup/restore,
/// serta menyediakan akses repository per domain (`products`, `production`, `debts`, `finance`).
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  late final ProductRepository products = ProductRepository(() => database);
  late final ProductionRepository production =
      ProductionRepository(() => database);
  late final DebtRepository debts = DebtRepository(() => database);
  late final FinanceRepository finance =
      FinanceRepository(() => database, debts);

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('app.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
      path,
      version: 5,
      // v1→v2 : categories + bom + kolom note
      // v2→v3 : contacts + debts + production_logs + stock REAL
      // v3→v4 : category_id di tabel finance
      // v4→v5 : backfill ref_id di tabel finance dari stock_movements
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  // ═══════════════════════════════════════════════════════
  // CREATE — fresh install
  // ═══════════════════════════════════════════════════════
  Future _createDB(Database db, int version) async {
    // type: MATERIAL (bahan bangunan) | RAW (bahan baku mebel) | PRODUCT (produk jadi mebel)
    await db.execute('''
      CREATE TABLE categories (
        id   INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT    NOT NULL UNIQUE,
        type TEXT    NOT NULL DEFAULT 'MATERIAL'
      )
    ''');

    // stock REAL agar support desimal (liter, meter, dll)
    await db.execute('''
      CREATE TABLE products (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        name           TEXT    NOT NULL,
        category_id    INTEGER,
        stock          REAL    NOT NULL DEFAULT 0,
        purchase_price INTEGER NOT NULL DEFAULT 0,
        selling_price  INTEGER NOT NULL DEFAULT 0,
        unit           TEXT    NOT NULL DEFAULT '',
        min_stock      REAL    NOT NULL DEFAULT 0,
        FOREIGN KEY (category_id) REFERENCES categories(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE finance (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        type        TEXT    NOT NULL,
        amount      INTEGER NOT NULL DEFAULT 0,
        date        TEXT    NOT NULL,
        note        TEXT,
        ref_id      INTEGER DEFAULT 0,
        category_id INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE stock_movements (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        type       TEXT    NOT NULL,
        quantity   REAL    NOT NULL,
        date       TEXT    NOT NULL,
        note       TEXT,
        ref_id     INTEGER DEFAULT 0,
        FOREIGN KEY (product_id) REFERENCES products(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE bom (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id  INTEGER NOT NULL,
        material_id INTEGER NOT NULL,
        quantity    REAL    NOT NULL DEFAULT 1,
        FOREIGN KEY (product_id)  REFERENCES products(id),
        FOREIGN KEY (material_id) REFERENCES products(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE contacts (
        id      INTEGER PRIMARY KEY AUTOINCREMENT,
        name    TEXT    NOT NULL,
        phone   TEXT,
        address TEXT,
        type    TEXT    NOT NULL DEFAULT 'CUSTOMER'
      )
    ''');

    await db.execute('''
      CREATE TABLE debts (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        contact_id   INTEGER NOT NULL,
        debt_type    TEXT    NOT NULL DEFAULT 'RECEIVABLE',
        amount       INTEGER NOT NULL DEFAULT 0,
        amount_paid  INTEGER NOT NULL DEFAULT 0,
        due_date     TEXT,
        status       TEXT    NOT NULL DEFAULT 'OPEN',
        note         TEXT,
        created_at   TEXT    NOT NULL,
        FOREIGN KEY (contact_id) REFERENCES contacts(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE production_logs (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id   INTEGER NOT NULL,
        qty_produced REAL    NOT NULL,
        note         TEXT,
        created_at   TEXT    NOT NULL,
        FOREIGN KEY (product_id) REFERENCES products(id)
      )
    ''');

    await _seedCategories(db);
  }

  // ═══════════════════════════════════════════════════════
  // UPGRADE — user sudah punya db lama
  // ═══════════════════════════════════════════════════════
  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS categories (
          id   INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT    NOT NULL UNIQUE,
          type TEXT    NOT NULL DEFAULT 'MATERIAL'
        )
      ''');
      try {
        await db.execute('ALTER TABLE products ADD COLUMN category_id INTEGER');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE finance ADD COLUMN note TEXT');
      } catch (_) {}
      try {
        await db
            .execute('ALTER TABLE finance ADD COLUMN ref_id INTEGER DEFAULT 0');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE stock_movements ADD COLUMN note TEXT');
      } catch (_) {}
      try {
        await db.execute(
            'ALTER TABLE stock_movements ADD COLUMN ref_id INTEGER DEFAULT 0');
      } catch (_) {}
      await db.execute('''
        CREATE TABLE IF NOT EXISTS bom (
          id          INTEGER PRIMARY KEY AUTOINCREMENT,
          product_id  INTEGER NOT NULL,
          material_id INTEGER NOT NULL,
          quantity    REAL    NOT NULL DEFAULT 1,
          FOREIGN KEY (product_id)  REFERENCES products(id),
          FOREIGN KEY (material_id) REFERENCES products(id)
        )
      ''');
      await _seedCategories(db);
    }

    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS contacts (
          id      INTEGER PRIMARY KEY AUTOINCREMENT,
          name    TEXT    NOT NULL,
          phone   TEXT,
          address TEXT,
          type    TEXT    NOT NULL DEFAULT 'CUSTOMER'
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS debts (
          id          INTEGER PRIMARY KEY AUTOINCREMENT,
          contact_id  INTEGER NOT NULL,
          debt_type   TEXT    NOT NULL DEFAULT 'RECEIVABLE',
          amount      INTEGER NOT NULL DEFAULT 0,
          amount_paid INTEGER NOT NULL DEFAULT 0,
          due_date    TEXT,
          status      TEXT    NOT NULL DEFAULT 'OPEN',
          note        TEXT,
          created_at  TEXT    NOT NULL,
          FOREIGN KEY (contact_id) REFERENCES contacts(id)
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS production_logs (
          id           INTEGER PRIMARY KEY AUTOINCREMENT,
          product_id   INTEGER NOT NULL,
          qty_produced REAL    NOT NULL,
          note         TEXT,
          created_at   TEXT    NOT NULL,
          FOREIGN KEY (product_id) REFERENCES products(id)
        )
      ''');

      await db.execute('ALTER TABLE products RENAME TO products_old');
      await db.execute('''
        CREATE TABLE products (
          id             INTEGER PRIMARY KEY AUTOINCREMENT,
          name           TEXT    NOT NULL,
          category_id    INTEGER,
          stock          REAL    NOT NULL DEFAULT 0,
          purchase_price INTEGER NOT NULL DEFAULT 0,
          selling_price  INTEGER NOT NULL DEFAULT 0,
          unit           TEXT    NOT NULL DEFAULT '',
          min_stock      REAL    NOT NULL DEFAULT 0,
          FOREIGN KEY (category_id) REFERENCES categories(id)
        )
      ''');
      await db.execute('''
        INSERT INTO products (id, name, category_id, stock, purchase_price, selling_price, unit, min_stock)
        SELECT id, name, category_id, CAST(stock AS REAL), purchase_price, selling_price, unit, CAST(min_stock AS REAL)
        FROM products_old
      ''');
      await db.execute('DROP TABLE products_old');

      await db
          .execute('ALTER TABLE stock_movements RENAME TO stock_movements_old');
      await db.execute('''
        CREATE TABLE stock_movements (
          id         INTEGER PRIMARY KEY AUTOINCREMENT,
          product_id INTEGER NOT NULL,
          type       TEXT    NOT NULL,
          quantity   REAL    NOT NULL,
          date       TEXT    NOT NULL,
          note       TEXT,
          ref_id     INTEGER DEFAULT 0,
          FOREIGN KEY (product_id) REFERENCES products(id)
        )
      ''');
      await db.execute('''
        INSERT INTO stock_movements (id, product_id, type, quantity, date, note, ref_id)
        SELECT id, product_id, type, CAST(quantity AS REAL), date, note, COALESCE(ref_id, 0)
        FROM stock_movements_old
      ''');
      await db.execute('DROP TABLE stock_movements_old');
    }

    if (oldVersion < 4) {
      try {
        await db.execute('ALTER TABLE finance ADD COLUMN category_id INTEGER');
      } catch (_) {}
    }

    if (oldVersion < 5) {
      try {
        await db.execute('''
          UPDATE finance
          SET ref_id = COALESCE(
            (
              SELECT sm.product_id
              FROM stock_movements sm
              JOIN products p ON p.id = sm.product_id
              WHERE sm.date = finance.date
                AND p.category_id = finance.category_id
                AND (
                  (finance.type = 'INCOME'  AND sm.type = 'OUT') OR
                  (finance.type = 'EXPENSE' AND sm.type = 'IN')
                )
              LIMIT 1
            ),
            ref_id,
            0
          )
          WHERE (ref_id IS NULL OR ref_id = 0)
            AND category_id IS NOT NULL
            AND type IN ('INCOME', 'EXPENSE')
        ''');
      } catch (_) {}
    }
  }

  Future _seedCategories(Database db) async {
    final defaults = [
      {'name': 'Bahan Bangunan', 'type': 'MATERIAL'},
      {'name': 'Bahan Baku Mebel', 'type': 'RAW'},
      {'name': 'Produk Jadi Mebel', 'type': 'PRODUCT'},
    ];
    for (final cat in defaults) {
      await db.insert(
        'categories',
        cat,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  // ═══════════════════════════════════════════════════════
  // BACKUP & RESTORE
  // ═══════════════════════════════════════════════════════
  static const List<int> _sqliteMagicHeader = [
    0x53, 0x51, 0x4C, 0x69, 0x74, 0x65, 0x20, 0x66,
    0x6F, 0x72, 0x6D, 0x61, 0x74, 0x20, 0x33, 0x00,
  ]; // "SQLite format 3\0"

  static bool isValidSqliteHeader(List<int> bytes) {
    if (bytes.length < _sqliteMagicHeader.length) return false;
    for (int i = 0; i < _sqliteMagicHeader.length; i++) {
      if (bytes[i] != _sqliteMagicHeader[i]) return false;
    }
    return true;
  }

  Future<Uint8List> exportDatabaseBytes() async {
    final db = await instance.database;
    await db.rawQuery('PRAGMA wal_checkpoint(FULL)');
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'app.db');
    final file = File(path);
    if (!await file.exists()) {
      throw Exception('File database tidak ditemukan');
    }
    return await file.readAsBytes();
  }

  Future<void> validateBackupFile(String sourcePath) async {
    final file = File(sourcePath);
    if (!await file.exists()) {
      throw Exception('File backup tidak ditemukan');
    }
    final length = await file.length();
    if (length < 100) {
      throw Exception('File terlalu kecil atau rusak');
    }

    final raf = await file.open();
    final List<int> header;
    try {
      header = await raf.read(16);
    } finally {
      await raf.close();
    }

    if (!isValidSqliteHeader(header)) {
      throw Exception('File bukan database SQLite (.db) yang valid');
    }

    final dbPath = await getDatabasesPath();
    final tmpPath = join(
      dbPath,
      'restore_validate_${DateTime.now().millisecondsSinceEpoch}.db',
    );
    Database? checkDb;
    try {
      await file.copy(tmpPath);
      checkDb = await openReadOnlyDatabase(tmpPath);
      final tables = await checkDb.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      );
      final tableNames = tables.map((r) => r['name'] as String?).toSet();
      if (!tableNames.contains('products') || !tableNames.contains('finance')) {
        throw Exception(
          'Struktur database tidak cocok dengan Putra Anugrah App',
        );
      }
    } catch (e) {
      if (e.toString().contains('Struktur database tidak cocok')) rethrow;
      throw Exception('File database rusak atau tidak bisa dibuka: $e');
    } finally {
      if (checkDb != null && checkDb.isOpen) {
        await checkDb.close();
      }
      await deleteDatabase(tmpPath);
    }
  }

  Future<void> restoreDatabaseFromFile(String sourcePath) async {
    await validateBackupFile(sourcePath);

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'app.db');
    final safetyPath = join(dbPath, 'app_safety_bak.db');

    if (_database != null && _database!.isOpen) {
      await _database!.rawQuery('PRAGMA wal_checkpoint(FULL)');
      await _database!.close();
      _database = null;
    }

    final currentFile = File(path);
    final bool hasSafety = await currentFile.exists();
    if (hasSafety) {
      await currentFile.copy(safetyPath);
    }

    try {
      await deleteDatabase(path);
      await File(sourcePath).copy(path);
      _database = await _initDB('app.db');
      if (hasSafety && await File(safetyPath).exists()) {
        await File(safetyPath).delete();
      }
    } catch (e) {
      if (hasSafety && await File(safetyPath).exists()) {
        await deleteDatabase(path);
        await File(safetyPath).copy(path);
        await File(safetyPath).delete();
        _database = await _initDB('app.db');
      }
      rethrow;
    }
  }

  Future<Directory> _getBackupDir() async {
    final extDir = await getExternalStorageDirectory();
    if (extDir == null) throw Exception('Storage eksternal tidak tersedia');
    final parts = extDir.path.split('/');
    final rootIndex = parts.indexOf('Android');
    if (rootIndex == -1) {
      throw Exception('Struktur path tidak dikenali: ${extDir.path}');
    }
    final rootPath = parts.sublist(0, rootIndex).join('/');
    final downloadDir = Directory('$rootPath/Download');
    if (!await downloadDir.exists()) await downloadDir.create(recursive: true);
    return downloadDir;
  }

  Future<String> backupDatabase() async {
    final bytes = await exportDatabaseBytes();
    final downloadDir = await _getBackupDir();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final backupPath = '${downloadDir.path}/backup_$timestamp.db';
    await File(backupPath).writeAsBytes(bytes, flush: true);
    return backupPath;
  }

  Future<void> restoreDatabase() async {
    final downloadDir = await _getBackupDir();
    final allEntries = downloadDir.listSync();
    final dbFiles = allEntries
        .whereType<File>()
        .where((f) {
          final name = basename(f.path);
          return name.startsWith('backup_') && name.endsWith('.db');
        })
        .toList();
    if (dbFiles.isEmpty) {
      throw Exception('Tidak ada file backup di ${downloadDir.path}');
    }
    dbFiles.sort(
      (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
    );
    await restoreDatabaseFromFile(dbFiles.first.path);
  }

  // ═══════════════════════════════════════════════════════
  // DELEGATE FAÇADE — kompatibel dengan seluruh screen
  // ═══════════════════════════════════════════════════════

  // Categories & Products & BOM
  Future<List<Map<String, dynamic>>> getCategories() =>
      products.getCategories();
  Future<int> insertCategory(String name, String type) =>
      products.insertCategory(name, type);
  Future<int> updateCategory(int id, String name, String type) =>
      products.updateCategory(id, name, type);
  Future<int> deleteCategory(int id) => products.deleteCategory(id);
  Future<int> insertProduct(Map<String, dynamic> data) =>
      products.insertProduct(data);
  Future<List<Map<String, dynamic>>> getProducts({int? categoryId}) =>
      products.getProducts(categoryId: categoryId);
  Future<List<Map<String, dynamic>>> getProductsWithCategory() =>
      products.getProductsWithCategory();
  Future<List<Map<String, dynamic>>> getRawMaterials() =>
      products.getRawMaterials();
  Future<List<Map<String, dynamic>>> getLowStockProducts() =>
      products.getLowStockProducts();
  Future<int> updateProduct(Map<String, dynamic> data) =>
      products.updateProduct(data);
  Future<int> deleteProduct(int id) => products.deleteProduct(id);
  Future<List<Map<String, dynamic>>> getBom(int productId) =>
      products.getBom(productId);
  Future<int> insertBomItem(int productId, int materialId, double quantity) =>
      products.insertBomItem(productId, materialId, quantity);
  Future<int> updateBomItem(int bomId, double quantity) =>
      products.updateBomItem(bomId, quantity);
  Future<int> deleteBomItem(int bomId) => products.deleteBomItem(bomId);
  Future<void> deleteAllBom(int productId) => products.deleteAllBom(productId);
  Future<List<Map<String, dynamic>>> checkBomStock(int productId, double qty) =>
      products.checkBomStock(productId, qty);

  // Production
  Future<void> produceProduct(int productId, double qty) =>
      production.produceProduct(productId, qty);
  Future<List<Map<String, dynamic>>> getProductionLogs({int? productId}) =>
      production.getProductionLogs(productId: productId);

  // Stock In/Out & Finance & Profit
  Future<void> insertStockIn(int productId, double qty, {bool isCash = true}) =>
      finance.insertStockIn(productId, qty, isCash: isCash);
  Future<void> insertStockOut(
    int productId,
    double qty, {
    bool isCash = true,
  }) =>
      finance.insertStockOut(productId, qty, isCash: isCash);
  Future<List<Map<String, dynamic>>> getIncomeExpenseDaily(
    String month, {
    int? categoryId,
  }) =>
      finance.getIncomeExpenseDaily(month, categoryId: categoryId);
  Future<List<Map<String, dynamic>>> getIncomeExpenseByCategory(String month) =>
      finance.getIncomeExpenseByCategory(month);
  Future<List<Map<String, dynamic>>> getIncomeExpenseByProduct(
    String month,
    int categoryId,
  ) =>
      finance.getIncomeExpenseByProduct(month, categoryId);
  Future<Map<String, dynamic>> getDashboardSummary() =>
      finance.getDashboardSummary();
  Future<List<Map<String, dynamic>>> getProfitByProduct({String? month}) =>
      finance.getProfitByProduct(month: month);

  // Contacts & Debts
  Future<int> insertContact(Map<String, dynamic> data) =>
      debts.insertContact(data);
  Future<List<Map<String, dynamic>>> getContacts({String? type}) =>
      debts.getContacts(type: type);
  Future<int> updateContact(Map<String, dynamic> data) =>
      debts.updateContact(data);
  Future<int> deleteContact(int id) => debts.deleteContact(id);
  Future<int> insertDebt(Map<String, dynamic> data) => debts.insertDebt(data);
  Future<List<Map<String, dynamic>>> getDebts({
    String? debtType,
    String? status,
  }) =>
      debts.getDebts(debtType: debtType, status: status);
  Future<void> payDebt(int debtId, int payAmount) =>
      debts.payDebt(debtId, payAmount);
  Future<int> deleteDebt(int id) => debts.deleteDebt(id);
  Future<List<Map<String, dynamic>>> getDebtPaymentHistory(int debtId) =>
      debts.getDebtPaymentHistory(debtId);
  Future<Map<String, dynamic>> getDebtSummary() => debts.getDebtSummary();
}
