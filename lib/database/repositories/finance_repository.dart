import 'package:sqflite/sqflite.dart';
import 'debt_repository.dart';

/// Repository untuk transaksi stok masuk/keluar, arus kas, ringkasan dashboard, dan laporan laba.
class FinanceRepository {
  final Future<Database> Function() _getDatabase;
  final DebtRepository _debts;

  FinanceRepository(this._getDatabase, this._debts);

  // ── STOCK IN / OUT ──────────────────────────────────────
  Future<void> insertStockIn(
    int productId,
    double qty, {
    bool isCash = true,
  }) async {
    if (qty <= 0) throw Exception('Jumlah harus lebih dari 0');
    final db = await _getDatabase();
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      final rows = await txn.query(
        'products',
        where: 'id = ?',
        whereArgs: [productId],
      );
      if (rows.isEmpty) throw Exception('Produk tidak ditemukan');

      final product = rows.first;
      final double currentStock = (product['stock'] as num?)?.toDouble() ?? 0;
      final int price = (product['purchase_price'] as num?)?.toInt() ?? 0;
      final int? categoryId = product['category_id'] as int?;

      await txn.update(
        'products',
        {'stock': currentStock + qty},
        where: 'id = ?',
        whereArgs: [productId],
      );
      await txn.insert('stock_movements', {
        'product_id': productId,
        'type': 'IN',
        'quantity': qty,
        'date': now,
        'note': isCash ? 'Pembelian Tunai Stok' : 'Stok Masuk Non-Tunai',
        'ref_id': productId,
      });
      if (isCash) {
        await txn.insert('finance', {
          'type': 'EXPENSE',
          'amount': (price * qty).round(),
          'date': now,
          'ref_id': productId,
          'category_id': categoryId,
          'note': 'Pembelian Tunai Stok',
        });
      }
    });
  }

  Future<void> insertStockOut(
    int productId,
    double qty, {
    bool isCash = true,
  }) async {
    if (qty <= 0) throw Exception('Jumlah harus lebih dari 0');
    final db = await _getDatabase();
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      final products = await txn.query(
        'products',
        where: 'id = ?',
        whereArgs: [productId],
      );
      if (products.isEmpty) throw Exception('Produk tidak ditemukan');

      final product = products.first;
      final double currentStock = (product['stock'] as num?)?.toDouble() ?? 0;
      final int price = (product['selling_price'] as num?)?.toInt() ?? 0;
      final int? categoryId = product['category_id'] as int?;

      if (currentStock < qty) {
        throw Exception(
          'Stok tidak cukup. Saat ini: $currentStock, diminta: $qty',
        );
      }

      await txn.update(
        'products',
        {'stock': currentStock - qty},
        where: 'id = ?',
        whereArgs: [productId],
      );
      await txn.insert('stock_movements', {
        'product_id': productId,
        'type': 'OUT',
        'quantity': qty,
        'date': now,
        'note': isCash ? 'Penjualan Tunai' : 'Keluar Non-Tunai',
        'ref_id': productId,
      });
      if (isCash) {
        await txn.insert('finance', {
          'type': 'INCOME',
          'amount': (price * qty).round(),
          'date': now,
          'ref_id': productId,
          'category_id': categoryId,
          'note': 'Penjualan Tunai',
        });
      }
    });
  }

  // ── ANALISIS KEUANGAN ───────────────────────────────────
  Future<List<Map<String, dynamic>>> getIncomeExpenseDaily(
    String month, {
    int? categoryId,
  }) async {
    final db = await _getDatabase();
    final args = <dynamic>[month];
    final catFilter = categoryId != null ? 'AND category_id = ?' : '';
    if (categoryId != null) args.add(categoryId);
    return await db.rawQuery('''
      SELECT
        substr(date, 1, 10) as day,
        SUM(CASE WHEN type = 'INCOME'  THEN amount ELSE 0 END) as income,
        SUM(CASE WHEN type = 'EXPENSE' THEN amount ELSE 0 END) as expense
      FROM finance
      WHERE substr(date, 1, 7) = ?
        AND type IN ('INCOME', 'EXPENSE')
        $catFilter
      GROUP BY day ORDER BY day ASC
    ''', args);
  }

  Future<List<Map<String, dynamic>>> getIncomeExpenseByCategory(
    String month,
  ) async {
    final db = await _getDatabase();
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
        AND f.type IN ('INCOME', 'EXPENSE')
      GROUP BY f.category_id
      ORDER BY c.name ASC
    ''', [month]);
  }

  Future<List<Map<String, dynamic>>> getIncomeExpenseByProduct(
    String month,
    int categoryId,
  ) async {
    final db = await _getDatabase();
    return await db.rawQuery('''
      SELECT
        p.id as product_id,
        p.name as product_name,
        SUM(CASE WHEN f.type = 'INCOME'  THEN f.amount ELSE 0 END) as income,
        SUM(CASE WHEN f.type = 'EXPENSE' THEN f.amount ELSE 0 END) as expense
      FROM finance f
      JOIN products p ON p.id = f.ref_id
      WHERE f.category_id = ?
        AND substr(f.date, 1, 7) = ?
        AND f.type IN ('INCOME', 'EXPENSE')
        AND f.ref_id > 0
      GROUP BY p.id, p.name
      HAVING income > 0 OR expense > 0
      ORDER BY p.name ASC
    ''', [categoryId, month]);
  }

  Future<Map<String, dynamic>> getDashboardSummary() async {
    final db = await _getDatabase();
    final now = DateTime.now();
    final currentMonth =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';

    final income = await db.rawQuery(
      "SELECT SUM(amount) as total FROM finance WHERE type='INCOME'",
    );
    final expense = await db.rawQuery(
      "SELECT SUM(amount) as total FROM finance WHERE type='EXPENSE'",
    );
    final int totalIncome = income.first['total'] == null
        ? 0
        : (income.first['total'] as num).toInt();
    final int totalExpense = expense.first['total'] == null
        ? 0
        : (expense.first['total'] as num).toInt();

    final byCategory = await getIncomeExpenseByCategory(currentMonth);
    final debtSummary = await _debts.getDebtSummary();

    return {
      'income': totalIncome,
      'expense': totalExpense,
      'profit': totalIncome - totalExpense,
      'total_receivable': debtSummary['total_receivable'],
      'total_payable': debtSummary['total_payable'],
      'overdue_count': debtSummary['overdue_count'],
      'by_category': byCategory,
      'current_month': currentMonth,
    };
  }

  // ── LAPORAN LABA PER PRODUK (BERBASIS HPP TERJUAL) ──────
  Future<List<Map<String, dynamic>>> getProfitByProduct({String? month}) async {
    final db = await _getDatabase();

    final products = await db.rawQuery('''
      SELECT p.id, p.name, p.unit, p.stock, p.purchase_price
      FROM products p
      JOIN categories c ON p.category_id = c.id
      WHERE c.type = 'PRODUCT'
      ORDER BY p.name ASC
    ''');

    final monthArgs = month != null ? <dynamic>[month] : <dynamic>[];

    final incomeRows = await db.rawQuery('''
      SELECT
        f.ref_id as product_id,
        SUM(f.amount) as total_income
      FROM finance f
      WHERE f.type = 'INCOME'
        AND f.category_id IS NOT NULL
        AND f.ref_id > 0
        ${month != null ? 'AND substr(f.date, 1, 7) = ?' : ''}
      GROUP BY f.ref_id
    ''', monthArgs);

    final soldRows = await db.rawQuery('''
      SELECT
        sm.product_id,
        SUM(sm.quantity) as qty_sold
      FROM stock_movements sm
      WHERE sm.type = 'OUT'
        AND (sm.note IS NULL OR sm.note = 'Penjualan Tunai')
        ${month != null ? 'AND substr(sm.date, 1, 7) = ?' : ''}
      GROUP BY sm.product_id
    ''', monthArgs);

    final allTimeHppRows = await db.rawQuery('''
      SELECT
        ref_id as product_id,
        SUM(amount) as total_hpp_produced
      FROM finance
      WHERE type = 'HPP' AND ref_id > 0
      GROUP BY ref_id
    ''');

    final allTimeProdRows = await db.rawQuery('''
      SELECT
        product_id,
        SUM(qty_produced) as qty_produced
      FROM production_logs
      GROUP BY product_id
    ''');

    final bomCostRows = await db.rawQuery('''
      SELECT
        b.product_id,
        SUM(b.quantity * m.purchase_price) as bom_unit_hpp
      FROM bom b
      JOIN products m ON m.id = b.material_id
      GROUP BY b.product_id
    ''');

    final periodProdRows = await db.rawQuery('''
      SELECT
        product_id,
        SUM(qty_produced) as qty_produced
      FROM production_logs
      ${month != null ? 'WHERE substr(created_at, 1, 7) = ?' : ''}
      GROUP BY product_id
    ''', monthArgs);

    final incomeMap = {
      for (final r in incomeRows) (r['product_id'] as num).toInt(): r
    };
    final soldMap = {
      for (final r in soldRows) (r['product_id'] as num).toInt(): r
    };
    final allTimeHppMap = {
      for (final r in allTimeHppRows) (r['product_id'] as num).toInt(): r
    };
    final allTimeProdMap = {
      for (final r in allTimeProdRows) (r['product_id'] as num).toInt(): r
    };
    final bomCostMap = {
      for (final r in bomCostRows) (r['product_id'] as num).toInt(): r
    };
    final periodProdMap = {
      for (final r in periodProdRows) (r['product_id'] as num).toInt(): r
    };

    final result = products.map((p) {
      final id = (p['id'] as num).toInt();
      final int fallbackPurchasePrice =
          (p['purchase_price'] as num?)?.toInt() ?? 0;

      final int totalIncome =
          (incomeMap[id]?['total_income'] as num?)?.toInt() ?? 0;
      final double qtySold =
          (soldMap[id]?['qty_sold'] as num?)?.toDouble() ?? 0;
      final double qtyProduced =
          (periodProdMap[id]?['qty_produced'] as num?)?.toDouble() ?? 0;

      final double allTimeHpp =
          (allTimeHppMap[id]?['total_hpp_produced'] as num?)?.toDouble() ?? 0;
      final double allTimeQty =
          (allTimeProdMap[id]?['qty_produced'] as num?)?.toDouble() ?? 0;
      final double bomUnitHpp =
          (bomCostMap[id]?['bom_unit_hpp'] as num?)?.toDouble() ?? 0;

      final double hppPerUnit;
      if (allTimeQty > 0 && allTimeHpp > 0) {
        hppPerUnit = allTimeHpp / allTimeQty;
      } else if (bomUnitHpp > 0) {
        hppPerUnit = bomUnitHpp;
      } else {
        hppPerUnit = fallbackPurchasePrice.toDouble();
      }

      final int totalHppSold = (qtySold * hppPerUnit).round();
      final int laba = totalIncome - totalHppSold;
      final double margin =
          totalIncome == 0 ? 0.0 : (laba / totalIncome) * 100;

      return {
        'product_id': id,
        'product_name': p['name'],
        'product_unit': p['unit'],
        'stock': p['stock'],
        'total_income': totalIncome,
        'total_hpp': totalHppSold,
        'hpp_per_unit': hppPerUnit.round(),
        'laba': laba,
        'margin': margin,
        'qty_sold': qtySold,
        'qty_produced': qtyProduced,
      };
    }).toList();

    result.sort((a, b) => (b['laba'] as int).compareTo(a['laba'] as int));
    return result;
  }
}
