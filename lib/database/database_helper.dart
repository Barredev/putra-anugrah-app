import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

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
      version: 4,
      // v1→v2 : categories + bom + kolom note
      // v2→v3 : contacts + debts + production_logs + stock REAL
      // v3→v4 : category_id di tabel finance
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

    // category_id untuk laporan keuangan per kategori
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

    // type: CUSTOMER | SUPPLIER
    await db.execute('''
      CREATE TABLE contacts (
        id      INTEGER PRIMARY KEY AUTOINCREMENT,
        name    TEXT    NOT NULL,
        phone   TEXT,
        address TEXT,
        type    TEXT    NOT NULL DEFAULT 'CUSTOMER'
      )
    ''');

    // debt_type: RECEIVABLE | PAYABLE  |  status: OPEN | PARTIAL | PAID
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
      try { await db.execute('ALTER TABLE products ADD COLUMN category_id INTEGER'); } catch (_) {}
      try { await db.execute('ALTER TABLE finance ADD COLUMN note TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE finance ADD COLUMN ref_id INTEGER DEFAULT 0'); } catch (_) {}
      try { await db.execute('ALTER TABLE stock_movements ADD COLUMN note TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE stock_movements ADD COLUMN ref_id INTEGER DEFAULT 0'); } catch (_) {}
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

      // Migrasi stock INTEGER → REAL (SQLite tidak support ALTER COLUMN)
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

      // Migrasi quantity stock_movements INTEGER → REAL
      await db.execute('ALTER TABLE stock_movements RENAME TO stock_movements_old');
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
      // Tambah category_id ke finance untuk laporan per kategori
      try {
        await db.execute('ALTER TABLE finance ADD COLUMN category_id INTEGER');
      } catch (_) {}
    }
  }

  Future _seedCategories(Database db) async {
    final defaults = [
      {'name': 'Bahan Bangunan',    'type': 'MATERIAL'},
      {'name': 'Bahan Baku Mebel',  'type': 'RAW'},
      {'name': 'Produk Jadi Mebel', 'type': 'PRODUCT'},
    ];
    for (final cat in defaults) {
      await db.insert('categories', cat,
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  // ═══════════════════════════════════════════════════════
  // BACKUP & RESTORE
  // ═══════════════════════════════════════════════════════
  Future<Directory> _getBackupDir() async {
    final extDir = await getExternalStorageDirectory();
    if (extDir == null) throw Exception('Storage eksternal tidak tersedia');
    final parts = extDir.path.split('/');
    final rootIndex = parts.indexOf('Android');
    if (rootIndex == -1)
      throw Exception('Struktur path tidak dikenali: ${extDir.path}');
    final rootPath = parts.sublist(0, rootIndex).join('/');
    final downloadDir = Directory('$rootPath/Download');
    if (!await downloadDir.exists()) await downloadDir.create(recursive: true);
    return downloadDir;
  }

  Future<String> backupDatabase() async {
    final db = await instance.database;
    await db.rawQuery('PRAGMA wal_checkpoint(FULL)');
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'app.db');
    final downloadDir = await _getBackupDir();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final backupPath = '${downloadDir.path}/backup_$timestamp.db';
    await File(path).copy(backupPath);
    return backupPath;
  }

  Future<void> restoreDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'app.db');
    final downloadDir = await _getBackupDir();
    final allEntries = downloadDir.listSync();
    final dbFiles = allEntries
        .whereType<File>()
        .where((f) {
          final name = basename(f.path);
          return name.startsWith('backup_') && name.endsWith('.db');
        })
        .toList();
    if (dbFiles.isEmpty)
      throw Exception('Tidak ada file backup di ${downloadDir.path}');
    dbFiles.sort(
        (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    final latestFile = dbFiles.first;
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
    await deleteDatabase(path);
    await latestFile.copy(path);
    _database = await _initDB('app.db');
  }

  // ═══════════════════════════════════════════════════════
  // CATEGORIES
  // ═══════════════════════════════════════════════════════
  Future<List<Map<String, dynamic>>> getCategories() async {
    final db = await instance.database;
    return await db.query('categories', orderBy: 'name ASC');
  }

  Future<int> insertCategory(String name, String type) async {
    final db = await instance.database;
    return await db.insert('categories', {'name': name, 'type': type},
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<int> updateCategory(int id, String name, String type) async {
    final db = await instance.database;
    return await db.update('categories', {'name': name, 'type': type},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteCategory(int id) async {
    final db = await instance.database;
    await db.update('products', {'category_id': null},
        where: 'category_id = ?', whereArgs: [id]);
    return await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  // ═══════════════════════════════════════════════════════
  // PRODUCTS
  // ═══════════════════════════════════════════════════════
  Future<int> insertProduct(Map<String, dynamic> data) async {
    final db = await instance.database;
    return await db.insert('products', data);
  }

  /// [categoryId] null = semua, diisi = filter per kategori
  Future<List<Map<String, dynamic>>> getProducts({int? categoryId}) async {
    final db = await instance.database;
    if (categoryId != null) {
      return await db.query('products',
          where: 'category_id = ?',
          whereArgs: [categoryId],
          orderBy: 'name ASC');
    }
    return await db.query('products', orderBy: 'name ASC');
  }

  Future<List<Map<String, dynamic>>> getProductsWithCategory() async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT p.*, c.name as category_name, c.type as category_type
      FROM products p
      LEFT JOIN categories c ON p.category_id = c.id
      ORDER BY c.name ASC, p.name ASC
    ''');
  }

  Future<List<Map<String, dynamic>>> getRawMaterials() async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT p.* FROM products p
      JOIN categories c ON p.category_id = c.id
      WHERE c.type = 'RAW'
      ORDER BY p.name ASC
    ''');
  }

  Future<int> updateProduct(Map<String, dynamic> data) async {
    final db = await instance.database;
    return await db.update('products', data,
        where: 'id = ?', whereArgs: [data['id']]);
  }

  Future<int> deleteProduct(int id) async {
    final db = await instance.database;
    await db.delete('stock_movements', where: 'product_id = ?', whereArgs: [id]);
    await db.delete('bom',
        where: 'product_id = ? OR material_id = ?', whereArgs: [id, id]);
    return await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  // ═══════════════════════════════════════════════════════
  // BOM
  // ═══════════════════════════════════════════════════════
  Future<List<Map<String, dynamic>>> getBom(int productId) async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT b.id, b.quantity, p.id as material_id,
             p.name as material_name, p.unit as material_unit,
             p.stock as material_stock
      FROM bom b
      JOIN products p ON b.material_id = p.id
      WHERE b.product_id = ?
      ORDER BY p.name ASC
    ''', [productId]);
  }

  Future<int> insertBomItem(
      int productId, int materialId, double quantity) async {
    final db = await instance.database;
    final existing = await db.query('bom',
        where: 'product_id = ? AND material_id = ?',
        whereArgs: [productId, materialId]);
    if (existing.isNotEmpty) {
      return await db.update('bom', {'quantity': quantity},
          where: 'product_id = ? AND material_id = ?',
          whereArgs: [productId, materialId]);
    }
    return await db.insert('bom', {
      'product_id': productId,
      'material_id': materialId,
      'quantity': quantity,
    });
  }

  Future<int> updateBomItem(int bomId, double quantity) async {
    final db = await instance.database;
    return await db.update('bom', {'quantity': quantity},
        where: 'id = ?', whereArgs: [bomId]);
  }

  Future<int> deleteBomItem(int bomId) async {
    final db = await instance.database;
    return await db.delete('bom', where: 'id = ?', whereArgs: [bomId]);
  }

  Future<void> deleteAllBom(int productId) async {
    final db = await instance.database;
    await db.delete('bom', where: 'product_id = ?', whereArgs: [productId]);
  }

  Future<List<Map<String, dynamic>>> checkBomStock(
      int productId, double qty) async {
    final bomItems = await getBom(productId);
    final List<Map<String, dynamic>> shortages = [];
    for (final item in bomItems) {
      final double needed = (item['quantity'] as num).toDouble() * qty;
      final double available =
          (item['material_stock'] as num?)?.toDouble() ?? 0;
      if (available < needed) {
        shortages.add({
          'material_name': item['material_name'],
          'needed': needed,
          'available': available,
          'unit': item['material_unit'],
        });
      }
    }
    return shortages;
  }

  // ═══════════════════════════════════════════════════════
  // PRODUKSI — atomic
  // ═══════════════════════════════════════════════════════
Future<void> produceProduct(int productId, double qty) async {
    if (qty <= 0) throw Exception('Jumlah produksi harus lebih dari 0');

    final shortages = await checkBomStock(productId, qty);
    if (shortages.isNotEmpty) {
      final detail = shortages
          .map((s) =>
              '${s['material_name']}: butuh ${s['needed']}, ada ${s['available']} ${s['unit']}')
          .join('\n');
      throw Exception('Bahan tidak cukup:\n$detail');
    }

    final db = await instance.database;
    final now = DateTime.now().toIso8601String();
    final bomItems = await getBom(productId);

    // Ambil purchase_price tiap bahan untuk hitung HPP (di luar transaksi)
    final List<Map<String, dynamic>> materialDetails = [];
    for (final item in bomItems) {
      final mats = await db.query('products',
          where: 'id = ?', whereArgs: [item['material_id']]);
      if (mats.isNotEmpty) {
        materialDetails.add({
          'material_id': item['material_id'],
          'needed': (item['quantity'] as num).toDouble() * qty,
          'material_stock': (item['material_stock'] as num?)?.toDouble() ?? 0,
          'purchase_price': (mats.first['purchase_price'] as int?) ?? 0,
        });
      }
    }

    await db.transaction((txn) async {
      int totalHpp = 0;

      for (final detail in materialDetails) {
        final int materialId = detail['material_id'] as int;
        final double needed = detail['needed'] as double;
        final double currentStock = detail['material_stock'] as double;
        final int purchasePrice = detail['purchase_price'] as int;

        await txn.update('products', {'stock': currentStock - needed},
            where: 'id = ?', whereArgs: [materialId]);

        await txn.insert('stock_movements', {
          'product_id': materialId,
          'type': 'PRODUCTION_OUT',
          'quantity': needed,
          'date': now,
          'note': 'Produksi produk id=$productId',
          'ref_id': productId,
        });

        // Akumulasi HPP: qty_dipakai × harga_beli_bahan
        totalHpp += (needed * purchasePrice).toInt();
      }

      final products = await txn.query('products',
          where: 'id = ?', whereArgs: [productId]);
      if (products.isEmpty) throw Exception('Produk tidak ditemukan');
      final double currentStock =
          (products.first['stock'] as num?)?.toDouble() ?? 0;
      final int? categoryId = products.first['category_id'] as int?;

      await txn.update('products', {'stock': currentStock + qty},
          where: 'id = ?', whereArgs: [productId]);

      await txn.insert('stock_movements', {
        'product_id': productId,
        'type': 'PRODUCTION_IN',
        'quantity': qty,
        'date': now,
        'note': 'Hasil produksi',
        'ref_id': productId,
      });

      // TWEAK BISNIS: Catat HPP dengan type khusus 'HPP' agar tidak bocor ke Dashboard Pengeluaran
      if (totalHpp > 0) {
        await txn.insert('finance', {
          'type': 'HPP', // <-- DIUBAH DARI EXPENSE MENJADI HPP
          'amount': totalHpp,
          'date': now,
          'note': 'HPP produksi ${qty.toInt()} unit (product_id=$productId)',
          'ref_id': productId,
          'category_id': categoryId,
        });
      }

      await txn.insert('production_logs', {
        'product_id': productId,
        'qty_produced': qty,
        'created_at': now,
      });
    });
  }

  // ═══════════════════════════════════════════════════════
  // STOCK IN / OUT — otomatis simpan category_id ke finance
  // ═══════════════════════════════════════════════════════
Future<void> insertStockIn(int productId, double qty, {bool isCash = true}) async {
    if (qty <= 0) throw Exception('Jumlah harus lebih dari 0');
    final db = await instance.database;

    final rows = await db.rawQuery('SELECT * FROM products WHERE id = ?', [productId]);
    if (rows.isEmpty) throw Exception('Produk tidak ditemukan');

    final product = rows.first;
    final double currentStock = (product['stock'] as num?)?.toDouble() ?? 0;
    final int price = (product['purchase_price'] as int?) ?? 0;
    final int? categoryId = product['category_id'] as int?;
    
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      await txn.update('products', {'stock': currentStock + qty},
          where: 'id = ?', whereArgs: [productId]);
      await txn.insert('stock_movements', {
        'product_id': productId,
        'type': 'IN',
        'quantity': qty,
        'date': now,
      });
      // TWEAK BISNIS: Hanya catat pengeluaran tunai jika isCash = true
      if (isCash) {
        await txn.insert('finance', {
          'type': 'EXPENSE',
          'amount': (price * qty).toInt(),
          'date': now,
          'category_id': categoryId,
          'note': 'Pembelian Tunai Stok',
        });
      }
    });
  }

  Future<void> insertStockOut(int productId, double qty, {bool isCash = true}) async {
    if (qty <= 0) throw Exception('Jumlah harus lebih dari 0');
    final db = await instance.database;
    final products =
        await db.query('products', where: 'id = ?', whereArgs: [productId]);
    if (products.isEmpty) throw Exception('Produk tidak ditemukan');
    final product = products.first;
    final double currentStock = (product['stock'] as num?)?.toDouble() ?? 0;
    final int price = (product['selling_price'] as int?) ?? 0;
    final int? categoryId = product['category_id'] as int?;
    if (currentStock < qty) {
      throw Exception('Stok tidak cukup. Saat ini: $currentStock, diminta: $qty');
    }
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      await txn.update('products', {'stock': currentStock - qty},
          where: 'id = ?', whereArgs: [productId]);
      await txn.insert('stock_movements', {
        'product_id': productId,
        'type': 'OUT',
        'quantity': qty,
        'date': now,
      });
      // TWEAK BISNIS: Hanya catat pemasukan jika isCash = true (bukan piutang)
      if (isCash) {
        await txn.insert('finance', {
          'type': 'INCOME',
          'amount': (price * qty).toInt(),
          'date': now,
          'category_id': categoryId, 
          'note': 'Penjualan Tunai',
        });
      }
    });
  }

  // ═══════════════════════════════════════════════════════
  // CONTACTS
  // ═══════════════════════════════════════════════════════
  Future<int> insertContact(Map<String, dynamic> data) async {
    final db = await instance.database;
    return await db.insert('contacts', data);
  }

  Future<List<Map<String, dynamic>>> getContacts({String? type}) async {
    final db = await instance.database;
    if (type != null) {
      return await db.query('contacts',
          where: 'type = ?', whereArgs: [type], orderBy: 'name ASC');
    }
    return await db.query('contacts', orderBy: 'name ASC');
  }

  Future<int> updateContact(Map<String, dynamic> data) async {
    final db = await instance.database;
    return await db.update('contacts', data,
        where: 'id = ?', whereArgs: [data['id']]);
  }

  Future<int> deleteContact(int id) async {
    final db = await instance.database;
    return await db.delete('contacts', where: 'id = ?', whereArgs: [id]);
  }

  // ═══════════════════════════════════════════════════════
  // DEBTS
  // ═══════════════════════════════════════════════════════
  Future<int> insertDebt(Map<String, dynamic> data) async {
    final db = await instance.database;
    data['created_at'] = DateTime.now().toIso8601String();
    data['status'] = 'OPEN';
    data['amount_paid'] = 0;
    return await db.insert('debts', data);
  }

  Future<List<Map<String, dynamic>>> getDebts({
    String? debtType,
    String? status,
  }) async {
    final db = await instance.database;
    final conditions = <String>[];
    final args = <dynamic>[];
    if (debtType != null) { conditions.add('d.debt_type = ?'); args.add(debtType); }
    if (status != null)   { conditions.add('d.status = ?');    args.add(status); }
    final where =
        conditions.isNotEmpty ? 'WHERE ${conditions.join(' AND ')}' : '';
    return await db.rawQuery('''
      SELECT d.*, c.name as contact_name, c.phone as contact_phone
      FROM debts d
      JOIN contacts c ON d.contact_id = c.id
      $where
      ORDER BY d.due_date ASC, d.created_at DESC
    ''', args);
  }

  Future<void> payDebt(int debtId, int payAmount) async {
    if (payAmount <= 0) throw Exception('Jumlah bayar harus lebih dari 0');
    final db = await instance.database;
    final debts =
        await db.query('debts', where: 'id = ?', whereArgs: [debtId]);
    if (debts.isEmpty) throw Exception('Data hutang tidak ditemukan');
    final debt = debts.first;
    final int totalAmount = (debt['amount'] as int?) ?? 0;
    final int alreadyPaid = (debt['amount_paid'] as int?) ?? 0;
    final int newPaid = alreadyPaid + payAmount;
    if (newPaid > totalAmount) {
      throw Exception(
          'Pembayaran melebihi total hutang. Sisa: ${totalAmount - alreadyPaid}');
    }
    final String newStatus = newPaid >= totalAmount ? 'PAID' : 'PARTIAL';

    await db.transaction((txn) async {
      await txn.update('debts',
          {'amount_paid': newPaid, 'status': newStatus},
          where: 'id = ?', whereArgs: [debtId]);
      final String debtType = (debt['debt_type'] as String?) ?? 'RECEIVABLE';
      await txn.insert('finance', {
        'type': debtType == 'RECEIVABLE' ? 'INCOME' : 'EXPENSE',
        'amount': payAmount,
        'date': DateTime.now().toIso8601String(),
        'note':
            'Bayar ${debtType == 'RECEIVABLE' ? 'piutang' : 'hutang'} id=$debtId',
        'ref_id': debtId,
        'category_id': null, // hutang piutang tidak terikat kategori produk
      });
    });
  }

  Future<int> deleteDebt(int id) async {
    final db = await instance.database;
    return await db.delete('debts', where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, dynamic>> getDebtSummary() async {
    final db = await instance.database;
    final receivable = await db.rawQuery('''
      SELECT SUM(amount - amount_paid) as total
      FROM debts WHERE debt_type = 'RECEIVABLE' AND status != 'PAID'
    ''');
    final payable = await db.rawQuery('''
      SELECT SUM(amount - amount_paid) as total
      FROM debts WHERE debt_type = 'PAYABLE' AND status != 'PAID'
    ''');
    final overdue = await db.rawQuery('''
      SELECT COUNT(*) as count FROM debts
      WHERE status != 'PAID' AND due_date < ?
    ''', [DateTime.now().toIso8601String().substring(0, 10)]);

    return {
      'total_receivable': (receivable.first['total'] as num?)?.toInt() ?? 0,
      'total_payable':    (payable.first['total'] as num?)?.toInt() ?? 0,
      'overdue_count':    (overdue.first['count'] as int?) ?? 0,
    };
  }

  // ═══════════════════════════════════════════════════════
  // FINANCE — query total & per kategori
  // ═══════════════════════════════════════════════════════

  /// Harian untuk 1 bulan. [categoryId] null = semua kategori.
  Future<List<Map<String, dynamic>>> getIncomeExpenseDaily(
      String month, {int? categoryId}) async {
    final db = await instance.database;
    final catFilter =
        categoryId != null ? 'AND category_id = $categoryId' : '';
    return await db.rawQuery('''
      SELECT
        substr(date, 1, 10) as day,
        SUM(CASE WHEN type = 'INCOME'  THEN amount ELSE 0 END) as income,
        SUM(CASE WHEN type = 'EXPENSE' THEN amount ELSE 0 END) as expense
      FROM finance
      WHERE substr(date, 1, 7) = ? $catFilter
      GROUP BY day ORDER BY day ASC
    ''', [month]);
  }

  /// Ringkasan income/expense per kategori untuk 1 bulan.
  /// Dipakai di analysis screen untuk switch antar kategori.
  Future<List<Map<String, dynamic>>> getIncomeExpenseByCategory(
      String month) async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT
        c.id   as category_id,
        c.name as category_name,
        c.type as category_type,
        SUM(CASE WHEN f.type = 'INCOME'  THEN f.amount ELSE 0 END) as income,
        SUM(CASE WHEN f.type = 'EXPENSE' THEN f.amount ELSE 0 END) as expense
      FROM finance f
      LEFT JOIN categories c ON f.category_id = c.id
      WHERE substr(f.date, 1, 7) = ?
      GROUP BY f.category_id
      ORDER BY c.name ASC
    ''', [month]);
  }

  /// Menarik data pemasukan/pengeluaran spesifik per produk dalam satu kategori (berdasarkan bulan)
  Future<List<Map<String, dynamic>>> getIncomeExpenseByProduct(String month, int categoryId) async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT
        p.id as product_id,
        p.name as product_name,
        SUM(CASE WHEN f.type = 'INCOME' THEN f.amount ELSE 0 END) as income,
        SUM(CASE WHEN f.type = 'EXPENSE' THEN f.amount ELSE 0 END) as expense
      FROM products p
      JOIN stock_movements sm ON p.id = sm.product_id
      JOIN finance f ON f.date = sm.date AND f.category_id = p.category_id
      WHERE p.category_id = ? AND substr(f.date, 1, 7) = ?
      GROUP BY p.id, p.name
      HAVING income > 0 OR expense > 0
      ORDER BY p.name ASC
    ''', [categoryId, month]);
  }

  /// Dashboard summary — total all-time + ringkasan per kategori bulan ini.
  Future<Map<String, dynamic>> getDashboardSummary() async {
    final db = await instance.database;
    final now = DateTime.now();
    final currentMonth =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';

    final income = await db.rawQuery(
        "SELECT SUM(amount) as total FROM finance WHERE type='INCOME'");
    final expense = await db.rawQuery(
        "SELECT SUM(amount) as total FROM finance WHERE type='EXPENSE'");
    final int totalIncome = income.first['total'] == null
        ? 0
        : (income.first['total'] as num).toInt();
    final int totalExpense = expense.first['total'] == null
        ? 0
        : (expense.first['total'] as num).toInt();

    // Ringkasan per kategori bulan berjalan — untuk kartu di dashboard
    final byCategory = await getIncomeExpenseByCategory(currentMonth);

    final debtSummary = await getDebtSummary();

    return {
      'income':           totalIncome,
      'expense':          totalExpense,
      'profit':           totalIncome - totalExpense,
      'total_receivable': debtSummary['total_receivable'],
      'total_payable':    debtSummary['total_payable'],
      'overdue_count':    debtSummary['overdue_count'],
      'by_category':      byCategory,  // List<Map> — income/expense per kategori bulan ini
      'current_month':    currentMonth,
    };
  }

  Future<List<Map<String, dynamic>>> getLowStockProducts() async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT p.*, c.name as category_name
      FROM products p
      LEFT JOIN categories c ON p.category_id = c.id
      WHERE p.stock <= p.min_stock
      ORDER BY p.stock ASC
    ''');
  }

  // ═══════════════════════════════════════════════════════
  // LAPORAN LABA PER PRODUK
  // ═══════════════════════════════════════════════════════

  /// [month] null = semua waktu, diisi = filter bulan (format: '2026-01')
  Future<List<Map<String, dynamic>>> getProfitByProduct(
      {String? month}) async {
    final db = await instance.database;

    // Query 1: semua produk jadi
    final products = await db.rawQuery('''
      SELECT p.id, p.name, p.unit, p.stock
      FROM products p
      JOIN categories c ON p.category_id = c.id
      WHERE c.type = 'PRODUCT'
      ORDER BY p.name ASC
    ''');

    // Query 2: total INCOME per produk (dari stock_movements type OUT)
    // ref_id di finance untuk penjualan tidak diset, jadi pakai
    // stock_movements sebagai sumber qty terjual dan finance untuk income
    final incomeRows = await db.rawQuery('''
      SELECT
        sm.product_id,
        SUM(f.amount)   as total_income,
        SUM(sm.quantity) as qty_sold
      FROM stock_movements sm
      JOIN finance f ON f.date = sm.date
                     AND f.type = 'INCOME'
                     AND f.category_id = (
                       SELECT category_id FROM products WHERE id = sm.product_id
                     )
     WHERE sm.type = 'OUT' ${month != null ? "AND substr(sm.date, 1, 7) = '$month'" : ''}
      GROUP BY sm.product_id
    ''');

    // Query 3: total HPP per produk (dari finance)
    final hppRows = await db.rawQuery('''
      SELECT
        ref_id as product_id,
        SUM(amount) as total_hpp
      FROM finance
      WHERE type = 'HPP'
        ${month != null ? "AND substr(date, 1, 7) = '$month'" : ''}
      GROUP BY ref_id
    ''');

    // Query 4: total unit diproduksi per produk
    final prodRows = await db.rawQuery('''
      SELECT
        product_id,
        SUM(qty_produced) as qty_produced
      FROM production_logs
      ${month != null ? "WHERE substr(created_at, 1, 7) = '$month'" : ''}
      GROUP BY product_id
    ''');

    // Gabungkan semua query di Dart
    final incomeMap = {
      for (final r in incomeRows)
        r['product_id'] as int: r
    };
    final hppMap = {
      for (final r in hppRows)
        r['product_id'] as int: r
    };
    final prodMap = {
      for (final r in prodRows)
        r['product_id'] as int: r
    };

    final result = products.map((p) {
      final id = p['id'] as int;
      final income = incomeMap[id];
      final hpp = hppMap[id];
      final prod = prodMap[id];

      final int totalIncome =
          (income?['total_income'] as num?)?.toInt() ?? 0;
      final int totalHpp =
          (hpp?['total_hpp'] as num?)?.toInt() ?? 0;
      final double qtySold =
          (income?['qty_sold'] as num?)?.toDouble() ?? 0;
      final double qtyProduced =
          (prod?['qty_produced'] as num?)?.toDouble() ?? 0;
      final int laba = totalIncome - totalHpp;
      final double margin =
          totalIncome == 0 ? 0 : (laba / totalIncome) * 100;

      return {
        'product_id':    id,
        'product_name':  p['name'],
        'product_unit':  p['unit'],
        'stock':         p['stock'],
        'total_income':  totalIncome,
        'total_hpp':     totalHpp,
        'laba':          laba,
        'margin':        margin,
        'qty_sold':      qtySold,
        'qty_produced':  qtyProduced,
      };
    }).toList();

    // Sort: laba tertinggi dulu
    result.sort((a, b) =>
        (b['laba'] as int).compareTo(a['laba'] as int));

    return result;
  }

  // PRODUCTION LOGS
  Future<List<Map<String, dynamic>>> getProductionLogs(
      {int? productId}) async {
    final db = await instance.database;
    if (productId != null) {
      return await db.rawQuery('''
        SELECT pl.*, p.name as product_name, p.unit as product_unit
        FROM production_logs pl
        JOIN products p ON pl.product_id = p.id
        WHERE pl.product_id = ?
        ORDER BY pl.created_at DESC
      ''', [productId]);
    }
    return await db.rawQuery('''
      SELECT pl.*, p.name as product_name, p.unit as product_unit
      FROM production_logs pl
      JOIN products p ON pl.product_id = p.id
      ORDER BY pl.created_at DESC
    ''');
  }
}