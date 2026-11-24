import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../utils/formatters.dart';

class DebtDetailScreen extends StatefulWidget {
  final Map<String, dynamic> debt;

  const DebtDetailScreen({super.key, required this.debt});

  @override
  State<DebtDetailScreen> createState() => _DebtDetailScreenState();
}

class _DebtDetailScreenState extends State<DebtDetailScreen> {
  late Map<String, dynamic> _debt;
  List<Map<String, dynamic>> _paymentHistory = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _debt = Map<String, dynamic>.from(widget.debt);
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final debtId = _debt['id'] as int;
    final history = await DatabaseHelper.instance.getDebtPaymentHistory(debtId);
    if (mounted) {
      setState(() {
        _paymentHistory = List<Map<String, dynamic>>.from(history);
      });
    }
  }

  // Reload data debt terbaru + riwayat cicilan dari DB
  Future<void> _reload() async {
    final debtType = _debt['debt_type'] as String;
    final all = await DatabaseHelper.instance.getDebts(debtType: debtType);
    final updated = all.firstWhere(
      (d) => d['id'] == _debt['id'],
      orElse: () => _debt,
    );
    final history = await DatabaseHelper.instance
        .getDebtPaymentHistory(_debt['id'] as int);
    if (mounted) {
      setState(() {
        _debt = Map<String, dynamic>.from(updated);
        _paymentHistory = List<Map<String, dynamic>>.from(history);
      });
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
        return 'Sebagian Terbayar';
      default:
        return 'Belum Bayar';
    }
  }

  bool get _isOverdue {
    final dueDate = _debt['due_date'] as String?;
    if (dueDate == null || dueDate.length < 10 || _debt['status'] == 'PAID') {
      return false;
    }
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return dueDate.substring(0, 10).compareTo(today) < 0;
  }

  Future<void> _showPaymentDialog() async {
    final int total = (_debt['amount'] as num?)?.toInt() ?? 0;
    final int paid = (_debt['amount_paid'] as num?)?.toInt() ?? 0;
    final int sisa = total - paid;

    if (sisa <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tagihan ini sudah lunas')),
      );
      return;
    }

    final controller = TextEditingController();
    bool payFull = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Catat Pembayaran',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade100),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Sisa tagihan:',
                      style: TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                    Text(
                      formatRupiah(sisa),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text(
                  'Bayar lunas sekarang',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                value: payFull,
                activeColor: Colors.green,
                onChanged: (val) {
                  setD(() {
                    payFull = val ?? false;
                    if (payFull) {
                      controller.text = formatThousands(sisa);
                    } else {
                      controller.clear();
                    }
                  });
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                inputFormatters: [CurrencyInputFormatter()],
                enabled: !payFull,
                autofocus: !payFull,
                decoration: InputDecoration(
                  labelText: 'Jumlah Pembayaran',
                  prefixText: 'Rp ',
                  prefixStyle: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () async {
                final amount = parseFormattedInt(controller.text);
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Masukkan jumlah yang valid'),
                    ),
                  );
                  return;
                }
                if (amount > sisa) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Melebihi sisa tagihan (${formatRupiah(sisa)})',
                      ),
                    ),
                  );
                  return;
                }

                Navigator.pop(ctx);
                setState(() => _isLoading = true);
                try {
                  await DatabaseHelper.instance
                      .payDebt(_debt['id'] as int, amount);
                  await _reload();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Pembayaran ${formatRupiah(amount)} berhasil dicatat',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(e.toString()),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _isLoading = false);
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteDebt() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Hapus Data',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Yakin hapus data hutang/piutang ini?\nRiwayat pembayaran yang sudah masuk ke laporan keuangan tidak akan terhapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await DatabaseHelper.instance.deleteDebt(_debt['id'] as int);
      if (mounted) Navigator.pop(context, true);
    }
  }

  Widget _buildPaymentHistoryCard(bool isReceivable) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Riwayat Cicilan',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.black87,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_paymentHistory.length}x bayar',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_paymentHistory.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Belum ada riwayat pembayaran dicatat.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                ),
              )
            else
              ..._paymentHistory.asMap().entries.map((entry) {
                final idx = entry.key;
                final item = entry.value;
                final amount = (item['amount'] as num?)?.toInt() ?? 0;
                final date = item['date'] as String?;
                final isLast = idx == _paymentHistory.length - 1;
                final seqNum = _paymentHistory.length - idx;

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: (isReceivable
                                      ? Colors.green
                                      : Colors.deepOrange)
                                  .withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isReceivable
                                  ? Icons.arrow_downward_rounded
                                  : Icons.arrow_upward_rounded,
                              size: 18,
                              color: isReceivable
                                  ? Colors.green
                                  : Colors.deepOrange,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pembayaran #$seqNum',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  formatDateTimeShort(date),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            formatRupiah(amount),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isReceivable
                                  ? Colors.green
                                  : Colors.deepOrange,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isLast) Divider(height: 1, color: Colors.grey.shade100),
                  ],
                );
              }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int total = (_debt['amount'] as num?)?.toInt() ?? 0;
    final int paid = (_debt['amount_paid'] as num?)?.toInt() ?? 0;
    final int sisa = total - paid;
    final String status = (_debt['status'] as String?) ?? 'OPEN';
    final String contactName = (_debt['contact_name'] as String?) ?? '—';
    final String? phone = _debt['contact_phone'] as String?;
    final String? dueDate = _debt['due_date'] as String?;
    final String? note = _debt['note'] as String?;
    final String debtType = (_debt['debt_type'] as String?) ?? 'RECEIVABLE';
    final bool isReceivable = debtType == 'RECEIVABLE';

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: Text(
          isReceivable ? 'Detail Piutang' : 'Detail Hutang',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            tooltip: 'Hapus',
            onPressed: _deleteDebt,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Kartu utama ──────────────────────────
                  Card(
                    elevation: 0,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: _statusColor(status),
                                radius: 24,
                                child: Text(
                                  contactName.isNotEmpty
                                      ? contactName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      contactName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    if (phone != null && phone.isNotEmpty)
                                      Text(
                                        phone,
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 13,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: _statusColor(status)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _statusLabel(status),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _statusColor(status),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const Divider(height: 24),

                          _infoRow(
                            'Total Tagihan',
                            formatRupiah(total),
                            Colors.black87,
                          ),
                          const SizedBox(height: 8),
                          _infoRow(
                            'Sudah Dibayar',
                            formatRupiah(paid),
                            Colors.green,
                          ),
                          const SizedBox(height: 8),
                          _infoRow(
                            'Sisa',
                            formatRupiah(sisa),
                            sisa > 0 ? Colors.redAccent : Colors.green,
                          ),

                          const SizedBox(height: 14),

                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: total == 0
                                  ? 0
                                  : (paid / total).clamp(0.0, 1.0),
                              backgroundColor: Colors.grey.shade200,
                              color: _statusColor(status),
                              minHeight: 10,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${total == 0 ? 0 : ((paid / total) * 100).toInt()}% terbayar',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),

                          if (dueDate != null && dueDate.length >= 10) ...[
                            const Divider(height: 22),
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today_outlined,
                                  size: 16,
                                  color: _isOverdue
                                      ? Colors.deepOrange
                                      : Colors.grey.shade600,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Jatuh tempo: ${dueDate.substring(0, 10)}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _isOverdue
                                        ? Colors.deepOrange
                                        : Colors.grey.shade700,
                                    fontWeight: _isOverdue
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                                if (_isOverdue) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.deepOrange
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'Terlambat',
                                      style: TextStyle(
                                        color: Colors.deepOrange,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],

                          if (note != null && note.isNotEmpty) ...[
                            const Divider(height: 22),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.note_outlined,
                                  size: 16,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    note,
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Tombol catat pembayaran ──────────────
                  if (status != 'PAID')
                    SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _showPaymentDialog,
                        icon: const Icon(Icons.payments_outlined),
                        label: Text(
                          isReceivable
                              ? 'Catat Pembayaran dari Pelanggan'
                              : 'Catat Pembayaran ke Supplier',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_rounded, color: Colors.green),
                          SizedBox(width: 8),
                          Text(
                            'Tagihan ini sudah lunas',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 12),

                  // Info ke laporan keuangan
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: Colors.blueAccent,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isReceivable
                                ? 'Setiap pembayaran dari pelanggan otomatis masuk sebagai Pemasukan di laporan keuangan.'
                                : 'Setiap pembayaran ke supplier otomatis masuk sebagai Pengeluaran di laporan keuangan.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Riwayat Cicilan ──────────────────────
                  _buildPaymentHistoryCard(isReceivable),

                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _infoRow(String label, String value, Color color) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      );
}
