import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../utils/formatters.dart';
import 'add_debt_screen.dart';
import 'debt_detail_screen.dart';

class DebtScreen extends StatefulWidget {
  /// Kalau true, langsung aktifkan filter tagihan jatuh tempo.
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

  // Filter: null = semua, 'OVERDUE', 'OPEN', 'PARTIAL', 'PAID'
  String? _filterStatus;
  bool _initialTabChecked = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: 0);
    if (widget.showOverdue) {
      _filterStatus = 'OVERDUE';
    }
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    if (mounted) setState(() => _isLoading = true);
    final dbStatus = _filterStatus == 'OVERDUE' ? null : _filterStatus;
    final receivables = await DatabaseHelper.instance
        .getDebts(debtType: 'RECEIVABLE', status: dbStatus);
    final payables = await DatabaseHelper.instance
        .getDebts(debtType: 'PAYABLE', status: dbStatus);

    if (!mounted) return;
    final recList = List<Map<String, dynamic>>.from(receivables);
    final payList = List<Map<String, dynamic>>.from(payables);

    setState(() {
      _receivables = recList;
      _payables = payList;
      _isLoading = false;
    });

    // Jika dibuka dari peringatan jatuh tempo & piutang tidak ada overdue tapi hutang ada, pindah ke tab Hutang
    if (widget.showOverdue && !_initialTabChecked) {
      _initialTabChecked = true;
      final recOverdue = recList.any(_isOverdue);
      final payOverdue = payList.any(_isOverdue);
      if (!recOverdue && payOverdue && _tabController.index != 1) {
        _tabController.animateTo(1);
      }
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'PAID':
        return Colors.green;
      case 'PARTIAL':
        return Colors.orange;
      default:
        return Colors.redAccent;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'PAID':
        return 'Lunas';
      case 'PARTIAL':
        return 'Sebagian';
      default:
        return 'Belum Bayar';
    }
  }

  // Konsisten dengan query Dashboard: due_date < hari ini (YYYY-MM-DD)
  bool _isOverdue(Map<String, dynamic> debt) {
    final dueDate = debt['due_date'] as String?;
    if (dueDate == null || dueDate.length < 10 || debt['status'] == 'PAID') {
      return false;
    }
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return dueDate.substring(0, 10).compareTo(today) < 0;
  }

  List<Map<String, dynamic>> _applyFilter(List<Map<String, dynamic>> items) {
    if (_filterStatus == 'OVERDUE') {
      return items.where(_isOverdue).toList();
    }
    return items;
  }

  Widget _buildFilterChips() {
    return Container(
      color: Colors.white,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _filterChip('Semua', null, Colors.blueAccent),
            const SizedBox(width: 8),
            _filterChip('Jatuh Tempo', 'OVERDUE', Colors.deepOrange),
            const SizedBox(width: 8),
            _filterChip('Belum Bayar', 'OPEN', Colors.redAccent),
            const SizedBox(width: 8),
            _filterChip('Sebagian', 'PARTIAL', Colors.orange),
            const SizedBox(width: 8),
            _filterChip('Lunas', 'PAID', Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, String? value, Color color) {
    final bool selected = _filterStatus == value;
    return GestureDetector(
      onTap: () {
        if (_filterStatus == value) return;
        setState(() => _filterStatus = value);
        _loadAll();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black87,
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildDebtList(List<Map<String, dynamic>> rawItems, String type) {
    final items = _applyFilter(rawItems);
    final isReceivable = type == 'RECEIVABLE';

    if (items.isEmpty) {
      String emptyMsg = isReceivable ? 'Belum ada piutang' : 'Belum ada hutang';
      if (_filterStatus == 'OVERDUE') {
        emptyMsg = isReceivable
            ? 'Tidak ada piutang yang jatuh tempo'
            : 'Tidak ada hutang yang jatuh tempo';
      } else if (_filterStatus != null) {
        emptyMsg = 'Tidak ada data dengan status "${_statusLabel(_filterStatus!)}"';
      }

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isReceivable
                      ? Icons.account_balance_wallet_outlined
                      : Icons.payments_outlined,
                  size: 52,
                  color: Colors.grey.shade400,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                emptyMsg,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final int totalAmount =
        items.fold(0, (s, d) => s + ((d['amount'] as num?)?.toInt() ?? 0));
    final int totalPaid =
        items.fold(0, (s, d) => s + ((d['amount_paid'] as num?)?.toInt() ?? 0));
    final int totalSisa = totalAmount - totalPaid;
    final int overdueCount = items.where(_isOverdue).length;

    return Column(
      children: [
        // Kartu ringkasan modern
        Card(
          elevation: 0,
          margin: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: (isReceivable ? Colors.green : Colors.redAccent)
                  .withValues(alpha: 0.3),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
            child: Row(
              children: [
                Expanded(
                  child: _summaryCol(
                    'Total Tagihan',
                    formatRupiah(totalAmount),
                    Colors.black87,
                  ),
                ),
                Container(width: 1, height: 30, color: Colors.grey.shade200),
                Expanded(
                  child: _summaryCol(
                    'Sudah Bayar',
                    formatRupiah(totalPaid),
                    Colors.green,
                  ),
                ),
                Container(width: 1, height: 30, color: Colors.grey.shade200),
                Expanded(
                  child: _summaryCol(
                    'Sisa',
                    formatRupiah(totalSisa),
                    totalSisa > 0 ? Colors.redAccent : Colors.green,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Banner peringatan jatuh tempo
        if (overdueCount > 0)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.deepOrange,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  '$overdueCount tagihan sudah lewat jatuh tempo',
                  style: const TextStyle(
                    color: Colors.deepOrange,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
            itemCount: items.length,
            itemBuilder: (ctx, i) {
              final debt = items[i];
              final int amount = (debt['amount'] as num?)?.toInt() ?? 0;
              final int paid = (debt['amount_paid'] as num?)?.toInt() ?? 0;
              final int sisa = amount - paid;
              final String status = (debt['status'] as String?) ?? 'OPEN';
              final String contactName =
                  (debt['contact_name'] as String?) ?? '—';
              final String? dueDate = debt['due_date'] as String?;
              final bool overdue = _isOverdue(debt);

              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 12),
                color: overdue ? Colors.orange.shade50 : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: overdue
                        ? Colors.orange.shade200
                        : Colors.grey.shade200,
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
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
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: overdue
                              ? Colors.deepOrange
                              : _statusColor(status),
                          child: Text(
                            contactName.isNotEmpty
                                ? contactName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
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
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                  if (overdue)
                                    const Icon(
                                      Icons.warning_amber_rounded,
                                      color: Colors.deepOrange,
                                      size: 16,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Total: ${formatRupiah(amount)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              Text(
                                'Sisa: ${formatRupiah(sisa)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: sisa > 0
                                      ? Colors.redAccent
                                      : Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (dueDate != null && dueDate.length >= 10)
                                Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Text(
                                    'Jatuh tempo: ${dueDate.substring(0, 10)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: overdue
                                          ? Colors.deepOrange
                                          : Colors.grey.shade600,
                                      fontWeight: overdue
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              if (debt['note'] != null &&
                                  (debt['note'] as String).isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    debt['note'] as String,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _statusColor(status)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _statusLabel(status),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: _statusColor(status),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: 62,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
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
                            const SizedBox(height: 3),
                            Text(
                              '${amount == 0 ? 0 : ((paid / amount) * 100).toInt()}%',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w600,
                              ),
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
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );

  Widget _tabTitle(String label, List<Map<String, dynamic>> list) {
    final overdueCnt = list.where(_isOverdue).length;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label),
        if (overdueCnt > 0) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.deepOrange,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$overdueCnt',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: const Text(
          'Hutang Piutang',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blueAccent,
          unselectedLabelColor: Colors.grey.shade600,
          indicatorColor: Colors.blueAccent,
          indicatorWeight: 3,
          tabs: [
            Tab(child: _tabTitle('Piutang', _receivables)),
            Tab(child: _tabTitle('Hutang', _payables)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddDebtScreen(
                initialType:
                    _tabController.index == 0 ? 'RECEIVABLE' : 'PAYABLE',
              ),
            ),
          );
          if (result == true) _loadAll();
        },
        backgroundColor: Colors.blueAccent,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Tambah',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildDebtList(_receivables, 'RECEIVABLE'),
                      _buildDebtList(_payables, 'PAYABLE'),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
