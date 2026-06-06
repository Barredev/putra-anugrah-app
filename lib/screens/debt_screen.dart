import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import 'add_debt_screen.dart';
import 'debt_detail_screen.dart';

class DebtScreen extends StatefulWidget {
  /// Kalau true, langsung buka tab piutang jatuh tempo
  final bool showOverdue;

  const DebtScreen({super.key, this.showOverdue = false});

  @override
  State<DebtScreen> createState() => _DebtScreenState();
}

class _DebtScreenState extends State<DebtScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Tab 0 = Piutang (RECEIVABLE), Tab 1 = Hutang (PAYABLE)
  List<Map<String, dynamic>> _receivables = [];
  List<Map<String, dynamic>> _payables = [];
  bool _isLoading = true;

  // Filter status: null = semua, 'OPEN', 'PARTIAL', 'PAID'
  String? _filterStatus;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: 0,
    );
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    if (mounted) setState(() => _isLoading = true);
    final receivables = await DatabaseHelper.instance
        .getDebts(debtType: 'RECEIVABLE', status: _filterStatus);
    final payables = await DatabaseHelper.instance
        .getDebts(debtType: 'PAYABLE', status: _filterStatus);
    if (mounted) {
      setState(() {
        _receivables = List<Map<String, dynamic>>.from(receivables);
        _payables = List<Map<String, dynamic>>.from(payables);
        _isLoading = false;
      });
    }
  }

  String _formatRupiah(int amount) {
    final str = amount.abs().toString();
    final buf = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buf.write('.');
      buf.write(str[i]);
    }
    return 'Rp $buf';
  }

  // Warna & label status
  Color _statusColor(String status) {
    switch (status) {
      case 'PAID':    return Colors.green;
      case 'PARTIAL': return Colors.orange;
      default:        return Colors.red;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'PAID':    return 'Lunas';
      case 'PARTIAL': return 'Sebagian';
      default:        return 'Belum Bayar';
    }
  }

  // Cek apakah sudah jatuh tempo
  bool _isOverdue(Map<String, dynamic> debt) {
    final dueDate = debt['due_date'] as String?;
    if (dueDate == null || debt['status'] == 'PAID') return false;
    return DateTime.tryParse(dueDate)?.isBefore(DateTime.now()) ?? false;
  }

  Widget _buildDebtList(List<Map<String, dynamic>> items, String type) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              type == 'RECEIVABLE'
                  ? Icons.account_balance_wallet
                  : Icons.payment,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 12),
            Text(
              type == 'RECEIVABLE'
                  ? 'Belum ada piutang'
                  : 'Belum ada hutang',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Ringkasan total di atas list
    final int totalAmount =
        items.fold(0, (s, d) => s + ((d['amount'] as int?) ?? 0));
    final int totalPaid =
        items.fold(0, (s, d) => s + ((d['amount_paid'] as int?) ?? 0));
    final int totalSisa = totalAmount - totalPaid;
    final int overdueCount =
        items.where((d) => _isOverdue(d)).length;

    return Column(
      children: [
        // Kartu ringkasan
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: type == 'RECEIVABLE'
                ? Colors.green.shade50
                : Colors.red.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: type == 'RECEIVABLE'
                  ? Colors.green.shade200
                  : Colors.red.shade200,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _summaryCol('Total Tagihan', _formatRupiah(totalAmount),
                  Colors.grey.shade700),
              _summaryCol('Sudah Bayar', _formatRupiah(totalPaid),
                  Colors.green),
              _summaryCol('Sisa', _formatRupiah(totalSisa),
                  totalSisa > 0 ? Colors.red : Colors.green),
            ],
          ),
        ),

        // Warning jatuh tempo
        if (overdueCount > 0)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning, color: Colors.orange, size: 16),
                const SizedBox(width: 6),
                Text(
                  '$overdueCount tagihan sudah jatuh tempo',
                  style: const TextStyle(
                      color: Colors.orange, fontSize: 13),
                ),
              ],
            ),
          ),

        const SizedBox(height: 8),

        // List item
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: items.length,
            itemBuilder: (ctx, i) {
              final debt = items[i];
              final int amount = (debt['amount'] as int?) ?? 0;
              final int paid = (debt['amount_paid'] as int?) ?? 0;
              final int sisa = amount - paid;
              final String status =
                  (debt['status'] as String?) ?? 'OPEN';
              final String contactName =
                  (debt['contact_name'] as String?) ?? '—';
              final String? dueDate = debt['due_date'] as String?;
              final bool overdue = _isOverdue(debt);

              return Card(
                margin: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
                color: overdue ? Colors.orange.shade50 : null,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DebtDetailScreen(debt: debt),
                      ),
                    );
                    _loadAll();
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        // Avatar inisial
                        CircleAvatar(
                          backgroundColor: overdue
                              ? Colors.orange
                              : _statusColor(status),
                          child: Text(
                            contactName.isNotEmpty
                                ? contactName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Info utama
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      contactName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  if (overdue)
                                    const Icon(Icons.warning,
                                        color: Colors.orange, size: 14),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Total: ${_formatRupiah(amount)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              Text(
                                'Sisa: ${_formatRupiah(sisa)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: sisa > 0
                                      ? Colors.red
                                      : Colors.green,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (dueDate != null)
                                Text(
                                  'Jatuh tempo: ${dueDate.substring(0, 10)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: overdue
                                        ? Colors.orange
                                        : Colors.grey,
                                  ),
                                ),
                              if (debt['note'] != null &&
                                  (debt['note'] as String).isNotEmpty)
                                Text(
                                  debt['note'] as String,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Badge status + progress
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _statusColor(status)
                                    .withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _statusLabel(status),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _statusColor(status),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            // Progress bar bayar
                            SizedBox(
                              width: 60,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: amount == 0
                                      ? 0
                                      : (paid / amount).clamp(0.0, 1.0),
                                  backgroundColor: Colors.grey.shade200,
                                  color: _statusColor(status),
                                  minHeight: 6,
                                ),
                              ),
                            ),
                            Text(
                              '${amount == 0 ? 0 : ((paid / amount) * 100).toInt()}%',
                              style: const TextStyle(fontSize: 10),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _summaryCol(String label, String value, Color color) => Column(
        children: [
          Text(label,
              style:
                  const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hutang Piutang'),
        actions: [
          // Filter status
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter status',
            onSelected: (val) {
              setState(() => _filterStatus = val);
              _loadAll();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                  value: null, child: Text('Semua')),
              const PopupMenuItem(
                  value: 'OPEN', child: Text('Belum Bayar')),
              const PopupMenuItem(
                  value: 'PARTIAL', child: Text('Sebagian')),
              const PopupMenuItem(
                  value: 'PAID', child: Text('Lunas')),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Piutang'),
                  if (_receivables
                      .any((d) => _isOverdue(d))) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle),
                      child: Text(
                        '${_receivables.where((d) => _isOverdue(d)).length}',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Hutang'),
                  if (_payables.any((d) => _isOverdue(d))) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle),
                      child: Text(
                        '${_payables.where((d) => _isOverdue(d)).length}',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddDebtScreen(
                initialType: _tabController.index == 0
                    ? 'RECEIVABLE'
                    : 'PAYABLE',
              ),
            ),
          );
          if (result == true) _loadAll();
        },
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildDebtList(_receivables, 'RECEIVABLE'),
                _buildDebtList(_payables, 'PAYABLE'),
              ],
            ),
    );
  }
}