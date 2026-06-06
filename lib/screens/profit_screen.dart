import 'package:flutter/material.dart';
import '../database/database_helper.dart';

class ProfitScreen extends StatefulWidget {
  const ProfitScreen({super.key});

  @override
  State<ProfitScreen> createState() => _ProfitScreenState();
}

class _ProfitScreenState extends State<ProfitScreen> {
  List<Map<String, dynamic>> _data = [];
  bool _isLoading = true;

  // null = all time, diisi = per bulan
  String? _selectedMonth;
  int _selectedYear = DateTime.now().year;
  int _selectedMonthNum = DateTime.now().month;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final data = await DatabaseHelper.instance
        .getProfitByProduct(month: _selectedMonth);
    if (mounted) {
      setState(() {
        _data = data;
        _isLoading = false;
      });
    }
  }

 Future<void> _pickMonth() async {
    int tYear = _selectedYear;
    int tMonth = _selectedMonthNum;
    const months = [
      'Jan','Feb','Mar','Apr','Mei','Jun',
      'Jul','Ags','Sep','Okt','Nov','Des'
    ];

    await showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(        // ← fix 1: ctx → dialogCtx
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Pilih Bulan'),
          content: SizedBox(                          // ← fix 2: bungkus SizedBox
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => setD(() => tYear--),
                    ),
                    Text('$tYear',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => setD(() => tYear++),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(), // ← fix 3
                  childAspectRatio: 1.8,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  children: List.generate(12, (i) {
                    final m = i + 1;
                    final sel = m == tMonth;
                    return GestureDetector(
                      onTap: () => setD(() => tMonth = m),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: sel
                              ? Theme.of(ctx).primaryColor
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          months[i],
                          style: TextStyle(
                            color: sel ? Colors.white : Colors.black,
                            fontWeight: sel
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx), // ← fix 1
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _selectedYear = tYear;
                  _selectedMonthNum = tMonth;
                  _selectedMonth =
                      '$tYear-${tMonth.toString().padLeft(2, '0')}';
                });
                Navigator.pop(dialogCtx);               // ← fix 1
                _loadData();
              },
              child: const Text('Pilih'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatRupiah(int amount) {
    final isNeg = amount < 0;
    final str = amount.abs().toString();
    final buf = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buf.write('.');
      buf.write(str[i]);
    }
    return isNeg ? '-Rp $buf' : 'Rp $buf';
  }

  String _fmtQty(num v) =>
      v == v.toInt() ? v.toInt().toString() : v.toStringAsFixed(1);

  // Ringkasan total semua produk
  Widget _buildSummaryCard() {
    final int totalIncome =
        _data.fold(0, (s, d) => s + (d['total_income'] as int));
    final int totalHpp =
        _data.fold(0, (s, d) => s + (d['total_hpp'] as int));
    final int totalLaba = totalIncome - totalHpp;
    final double avgMargin = totalIncome == 0
        ? 0
        : (totalLaba / totalIncome) * 100;

    return Card(
      margin: const EdgeInsets.all(12),
      color: totalLaba >= 0 ? Colors.green.shade50 : Colors.red.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: totalLaba >= 0
              ? Colors.green.shade200
              : Colors.red.shade200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(
              _selectedMonth == null
                  ? 'Semua Waktu'
                  : 'Bulan $_selectedMonth',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _summaryCol('Total Pemasukan',
                    _formatRupiah(totalIncome), Colors.green),
                _summaryCol('Total HPP',
                    _formatRupiah(totalHpp), Colors.red),
                _summaryCol(
                  'Laba Bersih',
                  _formatRupiah(totalLaba),
                  totalLaba >= 0 ? Colors.blue : Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Rata-rata margin: ${avgMargin.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCol(String label, String value, Color color) =>
      Column(
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
        ],
      );

  Widget _buildProductCard(Map<String, dynamic> item, int rank) {
    final int laba = item['laba'] as int;
    final int income = item['total_income'] as int;
    final int hpp = item['total_hpp'] as int;
    final double margin = item['margin'] as double;
    final double qtySold = item['qty_sold'] as double;
    final double qtyProduced = item['qty_produced'] as double;
    final String name = item['product_name'] as String? ?? '';
    final String unit = item['product_unit'] as String? ?? '';
    final bool isProfit = laba >= 0;
    final bool hasData = income > 0 || hpp > 0;

    return Card(
      margin:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: rank + nama + badge laba/rugi
            Row(
              children: [
                // Nomor ranking
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: rank == 1
                        ? Colors.amber
                        : rank == 2
                            ? Colors.grey.shade400
                            : rank == 3
                                ? Colors.brown.shade300
                                : Colors.grey.shade200,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$rank',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: rank <= 3
                            ? Colors.white
                            : Colors.grey.shade600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                // Badge laba/rugi
                if (hasData)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isProfit
                          ? Colors.green.shade50
                          : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isProfit
                            ? Colors.green.shade300
                            : Colors.red.shade300,
                      ),
                    ),
                    child: Text(
                      isProfit ? 'Untung' : 'Rugi',
                      style: TextStyle(
                        fontSize: 11,
                        color:
                            isProfit ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 10),

            if (!hasData)
              // Belum ada transaksi
              const Text(
                'Belum ada data penjualan atau produksi',
                style:
                    TextStyle(color: Colors.grey, fontSize: 13),
              )
            else ...[
              // Baris angka keuangan
              Row(
                children: [
                  Expanded(
                    child: _statBox('Pemasukan',
                        _formatRupiah(income), Colors.green),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _statBox(
                        'HPP', _formatRupiah(hpp), Colors.red),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _statBox(
                      'Laba',
                      _formatRupiah(laba),
                      isProfit ? Colors.blue : Colors.orange,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Progress bar margin
              Row(
                children: [
                  const Text('Margin:',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value:
                            (margin / 100).clamp(0.0, 1.0),
                        backgroundColor: Colors.grey.shade200,
                        color: isProfit
                            ? Colors.green
                            : Colors.red,
                        minHeight: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${margin.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isProfit ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              // Qty info
              Row(
                children: [
                  Icon(Icons.factory,
                      size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    'Diproduksi: ${_fmtQty(qtyProduced)} $unit',
                    style: const TextStyle(
                        fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.shopping_cart,
                      size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    'Terjual: ${_fmtQty(qtySold)} $unit',
                    style: const TextStyle(
                        fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statBox(String label, String value, Color color) =>
      Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 10, color: Colors.grey)),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Laba Per Produk'),
        actions: [
          // Reset ke all time
          if (_selectedMonth != null)
            IconButton(
              icon: const Icon(Icons.clear),
              tooltip: 'Reset ke semua waktu',
              onPressed: () {
                setState(() => _selectedMonth = null);
                _loadData();
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── Filter bulan ──────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickMonth,
                          icon: const Icon(
                              Icons.calendar_month, size: 16),
                          label: Text(
                            _selectedMonth == null
                                ? 'Semua Waktu'
                                : 'Bulan: $_selectedMonth',
                          ),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: _selectedMonth != null
                                ? Theme.of(context)
                                    .primaryColor
                                    .withOpacity(0.1)
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Kartu ringkasan total ─────────────────
                _buildSummaryCard(),

                // ── List per produk ───────────────────────
                if (_data.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Belum ada data produk jadi',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: _data.length,
                      itemBuilder: (ctx, i) =>
                          _buildProductCard(_data[i], i + 1),
                    ),
                  ),
              ],
            ),
    );
  }
}