import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../utils/formatters.dart';
import '../widgets/month_picker_dialog.dart';

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
    final picked = await showMonthPickerDialog(
      context: context,
      initialYear: _selectedYear,
      initialMonth: _selectedMonthNum,
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedYear = picked.year;
        _selectedMonthNum = picked.month;
        _selectedMonth = picked.formatted;
      });
      _loadData();
    }
  }

  Widget _buildSummaryCard() {
    final int totalIncome =
        _data.fold(0, (s, d) => s + (d['total_income'] as int));
    final int totalHpp =
        _data.fold(0, (s, d) => s + (d['total_hpp'] as int));
    final int totalLaba = totalIncome - totalHpp;
    final double avgMargin =
        totalIncome == 0 ? 0 : (totalLaba / totalIncome) * 100;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: totalLaba >= 0
              ? Colors.teal.withValues(alpha: 0.3)
              : Colors.red.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedMonth == null
                      ? 'Ringkasan Semua Waktu'
                      : 'Ringkasan Bulan $_selectedMonth',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (totalLaba >= 0 ? Colors.teal : Colors.red)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Margin ${avgMargin.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: totalLaba >= 0 ? Colors.teal : Colors.red,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _summaryCol(
                    'Pemasukan',
                    formatRupiah(totalIncome),
                    Colors.green,
                  ),
                ),
                Container(width: 1, height: 32, color: Colors.grey.shade200),
                Expanded(
                  child: _summaryCol(
                    'HPP Terjual',
                    formatRupiah(totalHpp),
                    Colors.redAccent,
                  ),
                ),
                Container(width: 1, height: 32, color: Colors.grey.shade200),
                Expanded(
                  child: _summaryCol(
                    'Laba Bersih',
                    formatRupiah(totalLaba),
                    totalLaba >= 0 ? Colors.blueAccent : Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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

  Widget _buildProductCard(Map<String, dynamic> item, int rank) {
    final int laba = item['laba'] as int;
    final int income = item['total_income'] as int;
    final int hpp = item['total_hpp'] as int;
    final int hppPerUnit = (item['hpp_per_unit'] as num?)?.toInt() ?? 0;
    final double margin = item['margin'] as double;
    final double qtySold = item['qty_sold'] as double;
    final double qtyProduced = item['qty_produced'] as double;
    final String name = item['product_name'] as String? ?? '';
    final String unit = item['product_unit'] as String? ?? '';
    final bool isProfit = laba >= 0;
    final bool hasSales = income > 0 || qtySold > 0;
    final bool hasData = hasSales || hpp > 0 || qtyProduced > 0;

    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: rank + nama + badge laba/rugi
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: rank == 1
                        ? Colors.amber
                        : rank == 2
                            ? Colors.grey.shade400
                            : rank == 3
                                ? Colors.brown.shade300
                                : Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$rank',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: rank <= 3 ? Colors.white : Colors.grey.shade600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.black87,
                    ),
                  ),
                ),
                if (hasSales)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: (isProfit ? Colors.green : Colors.red)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isProfit ? 'Untung' : 'Rugi',
                      style: TextStyle(
                        fontSize: 11,
                        color: isProfit ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            if (!hasData)
              Text(
                'Belum ada data penjualan atau produksi',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: _statBox(
                      'Pemasukan',
                      formatRupiah(income),
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _statBox(
                      'HPP Terjual',
                      formatRupiah(hpp),
                      Colors.redAccent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _statBox(
                      'Laba',
                      formatRupiah(laba),
                      isProfit ? Colors.blueAccent : Colors.orange,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  const Text(
                    'Margin:',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (margin / 100).clamp(0.0, 1.0),
                        backgroundColor: Colors.grey.shade200,
                        color: isProfit ? Colors.green : Colors.redAccent,
                        minHeight: 7,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${margin.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isProfit ? Colors.green : Colors.redAccent,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),
              Divider(height: 1, color: Colors.grey.shade100),
              const SizedBox(height: 8),

              Row(
                children: [
                  Icon(Icons.factory_outlined,
                      size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    'Produksi: ${formatQty(qtyProduced, decimals: 1)} $unit',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.shopping_bag_outlined,
                      size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    'Terjual: ${formatQty(qtySold, decimals: 1)} $unit',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
              if (hppPerUnit > 0) ...[
                const SizedBox(height: 4),
                Text(
                  'Estimasi HPP/unit: ${formatRupiah(hppPerUnit)}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _statBox(String label, String value, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 10, color: Colors.grey)),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: const Text(
          'Laba Per Produk',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_selectedMonth != null)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Reset ke semua waktu',
              onPressed: () {
                setState(() => _selectedMonth = null);
                _loadData();
              },
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Filter bar putih konsisten dengan AnalysisScreen
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pickMonth,
                    icon: const Icon(Icons.calendar_month_outlined, size: 18),
                    label: Text(
                      _selectedMonth == null
                          ? 'Semua Waktu'
                          : 'Bulan: $_selectedMonth',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: Colors.blueAccent.withValues(alpha: 0.1),
                      foregroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                if (_selectedMonth != null) ...[
                  const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed: () {
                      setState(() => _selectedMonth = null);
                      _loadData();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey.shade700,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('Semua'),
                  ),
                ],
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      _buildSummaryCard(),
                      if (_data.isEmpty)
                        Expanded(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.trending_up_rounded,
                                  size: 56,
                                  color: Colors.grey.shade300,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Belum ada data produk jadi',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.only(bottom: 24, top: 4),
                            itemCount: _data.length,
                            itemBuilder: (ctx, i) =>
                                _buildProductCard(_data[i], i + 1),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
