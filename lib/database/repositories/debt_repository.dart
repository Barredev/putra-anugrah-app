import 'package:sqflite/sqflite.dart';

/// Repository untuk manajemen kontak, hutang piutang, dan cicilan pembayaran.
class DebtRepository {
  final Future<Database> Function() _getDatabase;

  DebtRepository(this._getDatabase);

  // ── CONTACTS ────────────────────────────────────────────
  Future<int> insertContact(Map<String, dynamic> data) async {
    final db = await _getDatabase();
    return await db.insert('contacts', data);
  }

  Future<List<Map<String, dynamic>>> getContacts({String? type}) async {
    final db = await _getDatabase();
    if (type != null) {
      return await db.query(
        'contacts',
        where: 'type = ?',
        whereArgs: [type],
        orderBy: 'name ASC',
      );
    }
    return await db.query('contacts', orderBy: 'name ASC');
  }

  Future<int> updateContact(Map<String, dynamic> data) async {
    final db = await _getDatabase();
    return await db.update(
      'contacts',
      data,
      where: 'id = ?',
      whereArgs: [data['id']],
    );
  }

  Future<int> deleteContact(int id) async {
    final db = await _getDatabase();
    return await db.delete('contacts', where: 'id = ?', whereArgs: [id]);
  }

  // ── DEBTS ───────────────────────────────────────────────
  Future<int> insertDebt(Map<String, dynamic> data) async {
    final db = await _getDatabase();
    final row = Map<String, dynamic>.from(data);
    row['created_at'] = DateTime.now().toIso8601String();
    row['status'] = 'OPEN';
    row['amount_paid'] = 0;
    return await db.insert('debts', row);
  }

  Future<List<Map<String, dynamic>>> getDebts({
    String? debtType,
    String? status,
  }) async {
    final db = await _getDatabase();
    final conditions = <String>[];
    final args = <dynamic>[];
    if (debtType != null) {
      conditions.add('d.debt_type = ?');
      args.add(debtType);
    }
    if (status != null) {
      conditions.add('d.status = ?');
      args.add(status);
    }
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
    final db = await _getDatabase();

    await db.transaction((txn) async {
      final debts =
          await txn.query('debts', where: 'id = ?', whereArgs: [debtId]);
      if (debts.isEmpty) throw Exception('Data hutang tidak ditemukan');
      final debt = debts.first;
      final int totalAmount = (debt['amount'] as num?)?.toInt() ?? 0;
      final int alreadyPaid = (debt['amount_paid'] as num?)?.toInt() ?? 0;
      final int newPaid = alreadyPaid + payAmount;
      if (newPaid > totalAmount) {
        throw Exception(
          'Pembayaran melebihi total hutang. Sisa: ${totalAmount - alreadyPaid}',
        );
      }
      final String newStatus = newPaid >= totalAmount ? 'PAID' : 'PARTIAL';

      await txn.update(
        'debts',
        {'amount_paid': newPaid, 'status': newStatus},
        where: 'id = ?',
        whereArgs: [debtId],
      );
      final String debtType = (debt['debt_type'] as String?) ?? 'RECEIVABLE';
      await txn.insert('finance', {
        'type': debtType == 'RECEIVABLE' ? 'INCOME' : 'EXPENSE',
        'amount': payAmount,
        'date': DateTime.now().toIso8601String(),
        'note':
            'Bayar ${debtType == 'RECEIVABLE' ? 'piutang' : 'hutang'} id=$debtId',
        'ref_id': debtId,
        'category_id': null,
      });
    });
  }

  Future<int> deleteDebt(int id) async {
    final db = await _getDatabase();
    return await db.delete('debts', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getDebtPaymentHistory(int debtId) async {
    final db = await _getDatabase();
    return await db.query(
      'finance',
      where:
          "ref_id = ? AND category_id IS NULL AND type IN ('INCOME', 'EXPENSE')",
      whereArgs: [debtId],
      orderBy: 'date DESC',
    );
  }

  Future<Map<String, dynamic>> getDebtSummary() async {
    final db = await _getDatabase();
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
      'total_payable': (payable.first['total'] as num?)?.toInt() ?? 0,
      'overdue_count': (overdue.first['count'] as int?) ?? 0,
    };
  }
}
