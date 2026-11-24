import 'package:sqflite/sqflite.dart';

/// Repository untuk operasi kategori, produk, BOM, dan stok menipis.
class ProductRepository {
  final Future<Database> Function() _getDatabase;

  ProductRepository(this._getDatabase);

  // ── CATEGORIES ──────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getCategories() async {
    final db = await _getDatabase();
    return await db.query('categories', orderBy: 'name ASC');
  }

  Future<int> insertCategory(String name, String type) async {
    final db = await _getDatabase();
    return await db.insert(
      'categories',
      {'name': name, 'type': type},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<int> updateCategory(int id, String name, String type) async {
    final db = await _getDatabase();
    return await db.update(
      'categories',
      {'name': name, 'type': type},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteCategory(int id) async {
    final db = await _getDatabase();
    await db.update(
      'products',
      {'category_id': null},
      where: 'category_id = ?',
      whereArgs: [id],
    );
    return await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  // ── PRODUCTS ────────────────────────────────────────────
  Future<int> insertProduct(Map<String, dynamic> data) async {
    final db = await _getDatabase();
    return await db.insert('products', data);
  }

  Future<List<Map<String, dynamic>>> getProducts({int? categoryId}) async {
    final db = await _getDatabase();
    if (categoryId != null) {
      return await db.query(
        'products',
        where: 'category_id = ?',
        whereArgs: [categoryId],
        orderBy: 'name ASC',
      );
    }
    return await db.query('products', orderBy: 'name ASC');
  }

  Future<List<Map<String, dynamic>>> getProductsWithCategory() async {
    final db = await _getDatabase();
    return await db.rawQuery('''
      SELECT p.*, c.name as category_name, c.type as category_type
      FROM products p
      LEFT JOIN categories c ON p.category_id = c.id
      ORDER BY c.name ASC, p.name ASC
    ''');
  }

  Future<List<Map<String, dynamic>>> getRawMaterials() async {
    final db = await _getDatabase();
    return await db.rawQuery('''
      SELECT p.* FROM products p
      JOIN categories c ON p.category_id = c.id
      WHERE c.type = 'RAW'
      ORDER BY p.name ASC
    ''');
  }

  Future<List<Map<String, dynamic>>> getLowStockProducts() async {
    final db = await _getDatabase();
    return await db.rawQuery('''
      SELECT p.*, c.name as category_name
      FROM products p
      LEFT JOIN categories c ON p.category_id = c.id
      WHERE p.stock <= p.min_stock
      ORDER BY p.stock ASC
    ''');
  }

  Future<int> updateProduct(Map<String, dynamic> data) async {
    final db = await _getDatabase();
    return await db.update(
      'products',
      data,
      where: 'id = ?',
      whereArgs: [data['id']],
    );
  }

  Future<int> deleteProduct(int id) async {
    final db = await _getDatabase();
    return await db.transaction((txn) async {
      await txn.delete(
        'stock_movements',
        where: 'product_id = ?',
        whereArgs: [id],
      );
      await txn.delete(
        'production_logs',
        where: 'product_id = ?',
        whereArgs: [id],
      );
      await txn.delete(
        'bom',
        where: 'product_id = ? OR material_id = ?',
        whereArgs: [id, id],
      );
      return await txn.delete('products', where: 'id = ?', whereArgs: [id]);
    });
  }

  // ── BOM ─────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getBom(int productId) async {
    final db = await _getDatabase();
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
    int productId,
    int materialId,
    double quantity,
  ) async {
    final db = await _getDatabase();
    final existing = await db.query(
      'bom',
      where: 'product_id = ? AND material_id = ?',
      whereArgs: [productId, materialId],
    );
    if (existing.isNotEmpty) {
      return await db.update(
        'bom',
        {'quantity': quantity},
        where: 'product_id = ? AND material_id = ?',
        whereArgs: [productId, materialId],
      );
    }
    return await db.insert('bom', {
      'product_id': productId,
      'material_id': materialId,
      'quantity': quantity,
    });
  }

  Future<int> updateBomItem(int bomId, double quantity) async {
    final db = await _getDatabase();
    return await db.update(
      'bom',
      {'quantity': quantity},
      where: 'id = ?',
      whereArgs: [bomId],
    );
  }

  Future<int> deleteBomItem(int bomId) async {
    final db = await _getDatabase();
    return await db.delete('bom', where: 'id = ?', whereArgs: [bomId]);
  }

  Future<void> deleteAllBom(int productId) async {
    final db = await _getDatabase();
    await db.delete('bom', where: 'product_id = ?', whereArgs: [productId]);
  }

  Future<List<Map<String, dynamic>>> checkBomStock(
    int productId,
    double qty,
  ) async {
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
}
