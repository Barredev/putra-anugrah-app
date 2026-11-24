import 'package:sqflite/sqflite.dart';

/// Repository untuk proses produksi atomik dan riwayat produksi.
class ProductionRepository {
  final Future<Database> Function() _getDatabase;

  ProductionRepository(this._getDatabase);

  Future<void> produceProduct(int productId, double qty) async {
    if (qty <= 0) throw Exception('Jumlah produksi harus lebih dari 0');

    final db = await _getDatabase();
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      final bomItems = await txn.rawQuery('''
        SELECT b.id, b.quantity, p.id as material_id,
               p.name as material_name, p.unit as material_unit,
               p.stock as material_stock, p.purchase_price as purchase_price
        FROM bom b
        JOIN products p ON b.material_id = p.id
        WHERE b.product_id = ?
        ORDER BY p.name ASC
      ''', [productId]);

      if (bomItems.isEmpty) {
        throw Exception('BOM kosong untuk produk ini');
      }

      // Validasi stok bahan di dalam transaksi agar bebas race condition
      final List<String> shortages = [];
      for (final item in bomItems) {
        final double needed = (item['quantity'] as num).toDouble() * qty;
        final double available =
            (item['material_stock'] as num?)?.toDouble() ?? 0;
        if (available < needed) {
          shortages.add(
            '${item['material_name']}: butuh $needed, ada $available ${item['material_unit']}',
          );
        }
      }
      if (shortages.isNotEmpty) {
        throw Exception('Bahan tidak cukup:\n${shortages.join('\n')}');
      }

      double totalHppRaw = 0;

      for (final item in bomItems) {
        final int materialId = item['material_id'] as int;
        final double needed = (item['quantity'] as num).toDouble() * qty;
        final double currentStock =
            (item['material_stock'] as num?)?.toDouble() ?? 0;
        final int purchasePrice =
            (item['purchase_price'] as num?)?.toInt() ?? 0;

        await txn.update(
          'products',
          {'stock': currentStock - needed},
          where: 'id = ?',
          whereArgs: [materialId],
        );

        await txn.insert('stock_movements', {
          'product_id': materialId,
          'type': 'PRODUCTION_OUT',
          'quantity': needed,
          'date': now,
          'note': 'Produksi produk id=$productId',
          'ref_id': productId,
        });

        totalHppRaw += needed * purchasePrice;
      }

      final int totalHpp = totalHppRaw.round();

      final products = await txn.query(
        'products',
        where: 'id = ?',
        whereArgs: [productId],
      );
      if (products.isEmpty) throw Exception('Produk tidak ditemukan');
      final double currentStock =
          (products.first['stock'] as num?)?.toDouble() ?? 0;
      final int? categoryId = products.first['category_id'] as int?;

      await txn.update(
        'products',
        {'stock': currentStock + qty},
        where: 'id = ?',
        whereArgs: [productId],
      );

      await txn.insert('stock_movements', {
        'product_id': productId,
        'type': 'PRODUCTION_IN',
        'quantity': qty,
        'date': now,
        'note': 'Hasil produksi',
        'ref_id': productId,
      });

      if (totalHpp > 0) {
        await txn.insert('finance', {
          'type': 'HPP',
          'amount': totalHpp,
          'date': now,
          'note':
              'HPP produksi ${qty == qty.toInt() ? qty.toInt() : qty} unit (product_id=$productId)',
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

  Future<List<Map<String, dynamic>>> getProductionLogs({int? productId}) async {
    final db = await _getDatabase();
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
