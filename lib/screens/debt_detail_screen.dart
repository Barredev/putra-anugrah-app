import 'package:flutter/material.dart';
import '../database/database_helper.dart';

class DebtDetailScreen extends StatefulWidget {
  final Map<String, dynamic> debt;

  const DebtDetailScreen({super.key, required this.debt});

  @override
  State<DebtDetailScreen> createState() => _DebtDetailScreenState();
}

class _DebtDetailScreenState extends State<DebtDetailScreen> {
  late Map<String, dynamic> _debt;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _debt = Map<String, dynamic>.from(widget.debt);
  }

  // Reload data debt terbaru dari DB
  Future<void> _reload() async {
    final debtType = _debt['debt_type'] as String;
    final all = await DatabaseHelper.instance
        .getDebts(debtType: debtType);
    final updated = all.firstWhere(
      (d) => d['id'] == _debt['id'],
      orElse: () => _debt,
    );
    if (mounted) setState(() => _debt = Map<String, dynamic>.from(updated));
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
      case 'PARTIAL': return 'Sebagian Terbayar';
      default:        return 'Belum Bayar';
    }
  }

  bool get _isOverdue {
    final dueDate = _debt['due_date'] as String?;
    if (dueDate == null || _debt['status'] == 'PAID') return false;
    return DateTime.tryParse(dueDate)?.isBefore(DateTime.now()) ?? false;
  }

  Future<void> _showPaymentDialog() async {
    final int total = (_debt['amount'] as int?) ?? 0;
    final int paid = (_debt['amount_paid'] as int?) ?? 0;
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
          title: const Text('Catat Pembayaran'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info sisa
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Sisa tagihan:',
                        style: TextStyle(fontSize: 13)),
                    Text(
                      _formatRupiah(sisa),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Checkbox bayar lunas
              Row(
                children: [
                  Checkbox(
                    value: payFull,
                    onChanged: (val) {
                      setD(() {
                        payFull = val ?? false;
                        if (payFull) {
                          controller.text = sisa.toString();
                        } else {
                          controller.clear();
                        }
                      });
                    },
                  ),
                  const Text('Bayar lunas sekarang'),
                ],
              ),

              const SizedBox(height: 8),

              // Input jumlah bayar
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                enabled: !payFull,
                decoration: const InputDecoration(
                  labelText: 'Jumlah Pembayaran (Rp)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
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
              onPressed: () async {
                final amount = int.tryParse(controller.text);
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                        content: Text('Masukkan jumlah yang valid')),
                  );
                  return;
                }
                if (amount > sisa) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Melebihi sisa tagihan (${_formatRupiah(sisa)})'),
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
                            'Pembayaran ${_formatRupiah(amount)} berhasil dicatat'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(e.toString()),
                          backgroundColor: Colors.red),
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
        title: const Text('Hapus Data'),
        content: const Text(
            'Yakin hapus data hutang/piutang ini?\nRiwayat pembayaran yang sudah masuk ke laporan keuangan tidak akan terhapus.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await DatabaseHelper.instance.deleteDebt(_debt['id'] as int);
      if (mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final int total = (_debt['amount'] as int?) ?? 0;
    final int paid = (_debt['amount_paid'] as int?) ?? 0;
    final int sisa = total - paid;
    final String status = (_debt['status'] as String?) ?? 'OPEN';
    final String contactName =
        (_debt['contact_name'] as String?) ?? '—';
    final String? phone = _debt['contact_phone'] as String?;
    final String? dueDate = _debt['due_date'] as String?;
    final String? note = _debt['note'] as String?;
    final String debtType = (_debt['debt_type'] as String?) ?? 'RECEIVABLE';
    final bool isReceivable = debtType == 'RECEIVABLE';

    return Scaffold(
      appBar: AppBar(
        title: Text(isReceivable ? 'Detail Piutang' : 'Detail Hutang'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Hapus',
            onPressed: _deleteDebt,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Kartu utama ──────────────────────────
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Nama kontak + badge status
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor:
                                    _statusColor(status),
                                radius: 24,
                                child: Text(
                                  contactName.isNotEmpty
                                      ? contactName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      contactName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16),
                                    ),
                                    if (phone != null &&
                                        phone.isNotEmpty)
                                      Text(phone,
                                          style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 13)),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _statusColor(status)
                                      .withOpacity(0.15),
                                  borderRadius:
                                      BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _statusLabel(status),
                                  style: TextStyle(
                                    color: _statusColor(status),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const Divider(height: 24),

                          // Info keuangan
                          _infoRow('Total Tagihan',
                              _formatRupiah(total), Colors.grey.shade700),
                          const SizedBox(height: 8),
                          _infoRow('Sudah Dibayar',
                              _formatRupiah(paid), Colors.green),
                          const SizedBox(height: 8),
                          _infoRow(
                              'Sisa',
                              _formatRupiah(sisa),
                              sisa > 0 ? Colors.red : Colors.green),

                          const SizedBox(height: 12),

                          // Progress bar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: total == 0
                                  ? 0
                                  : (paid / total).clamp(0.0, 1.0),
                              backgroundColor: Colors.grey.shade200,
                              color: _statusColor(status),
                              minHeight: 10,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${total == 0 ? 0 : ((paid / total) * 100).toInt()}% terbayar',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),

                          if (dueDate != null) ...[
                            const Divider(height: 20),
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 16,
                                  color: _isOverdue
                                      ? Colors.orange
                                      : Colors.grey,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Jatuh tempo: ${dueDate.substring(0, 10)}',
                                  style: TextStyle(
                                    color: _isOverdue
                                        ? Colors.orange
                                        : Colors.grey,
                                    fontWeight: _isOverdue
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                                if (_isOverdue) ...[
                                  const SizedBox(width: 6),
                                  const Text('⚠ Lewat jatuh tempo',
                                      style: TextStyle(
                                          color: Colors.orange,
                                          fontSize: 12)),
                                ],
                              ],
                            ),
                          ],

                          if (note != null && note.isNotEmpty) ...[
                            const Divider(height: 20),
                            Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.note,
                                    size: 16, color: Colors.grey),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(note,
                                      style: const TextStyle(
                                          color: Colors.grey)),
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
                    ElevatedButton.icon(
                      onPressed: _showPaymentDialog,
                      icon: const Icon(Icons.payment),
                      label: Text(isReceivable
                          ? 'Catat Pembayaran dari Pelanggan'
                          : 'Catat Pembayaran ke Supplier'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),

                  if (status == 'PAID')
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.green.shade200),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle,
                              color: Colors.green),
                          SizedBox(width: 8),
                          Text('Tagihan ini sudah lunas',
                              style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),

                  const SizedBox(height: 8),

                  // Info ke laporan keuangan
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isReceivable
                          ? 'Setiap pembayaran dari pelanggan otomatis masuk sebagai Pemasukan di laporan keuangan.'
                          : 'Setiap pembayaran ke supplier otomatis masuk sebagai Pengeluaran di laporan keuangan.',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _infoRow(String label, String value, Color color) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.grey, fontSize: 14)),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
        ],
      );
}