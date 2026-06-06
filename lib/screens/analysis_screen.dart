import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../database/database_helper.dart';
import 'profit_screen.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  String get _monthStr =>
      '$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}';

  List<Map<String, dynamic>> _categories = [];
  int? _selectedCategoryId;
  String _selectedCategoryName = 'Semua';

  List<Map<String, dynamic>> _daily = [];
  List<Map<String, dynamic>> _byCat = [];
  bool _isLoading = false;

  // --- STATE BARU UNTUK EXPAND ---
  int? _expandedCategoryId;
  Map<int, List<Map<String, dynamic>>> _productDetailsCache = {};
  bool _isLoadingDetails = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadData();
  }

  Future<void> _loadCategories() async {
    final cats = await DatabaseHelper.instance.getCategories();
    if (mounted) setState(() => _categories = cats);
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _expandedCategoryId = null; // Tutup expand saat load ulang
      _productDetailsCache.clear(); // Bersihkan cache data produk
    });
    try {
      final daily = await DatabaseHelper.instance
          .getIncomeExpenseDaily(_monthStr, categoryId: _selectedCategoryId);
      final byCat =
          await DatabaseHelper.instance.getIncomeExpenseByCategory(_monthStr);
      if (mounted) {
        setState(() {
          _daily = List<Map<String, dynamic>>.from(daily);
          _byCat = List<Map<String, dynamic>>.from(byCat);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal memuat data: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickMonth() async {
    int tYear = _selectedYear, tMonth = _selectedMonth;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Ags', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    await showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Pilih Bulan", style: TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
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
                    Text("$tYear",
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => setD(() => tYear++),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.8,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: List.generate(12, (i) {
                    final m = i + 1;
                    final sel = m == tMonth;
                    return GestureDetector(
                      onTap: () => setD(() => tMonth = m),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: sel
                              ? Colors.blueAccent
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: sel ? Colors.blueAccent : Colors.grey.shade300,
                          ),
                        ),
                        child: Text(
                          months[i],
                          style: TextStyle(
                            color: sel ? Colors.white : Colors.black87,
                            fontWeight: sel ? FontWeight.bold : FontWeight.w500,
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
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text("Batal")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                setState(() {
                  _selectedYear = tYear;
                  _selectedMonth = tMonth;
                });
                Navigator.pop(dialogCtx);
                _loadData();
              },
              child: const Text("Pilih", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _pickCategory() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const Text("Pilih Kategori", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.all_inclusive, color: Colors.blueAccent),
              title: const Text("Semua Kategori", style: TextStyle(fontWeight: FontWeight.w500)),
              selected: _selectedCategoryId == null,
              onTap: () {
                setState(() {
                  _selectedCategoryId = null;
                  _selectedCategoryName = 'Semua';
                });
                Navigator.pop(ctx);
                _loadData();
              },
            ),
            ..._categories.map((cat) => ListTile(
                  leading: Icon(Icons.circle,
                      color: _catColor(cat['type'] as String?), size: 16),
                  title: Text(cat['name'] as String),
                  selected: _selectedCategoryId == cat['id'],
                  onTap: () {
                    setState(() {
                      _selectedCategoryId = cat['id'] as int;
                      _selectedCategoryName = cat['name'] as String;
                    });
                    Navigator.pop(ctx);
                    _loadData();
                  },
                )),
          ],
        ),
      ),
    );
  }

  Color _catColor(String? type) {
    switch (type) {
      case 'MATERIAL':
        return Colors.blue;
      case 'RAW':
        return Colors.orange;
      case 'PRODUCT':
        return Colors.green;
      default:
        return Colors.grey;
    }
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

  int get _totalIncome =>
      _daily.fold(0, (s, e) => s + ((e['income'] ?? 0) as num).toInt());
  int get _totalExpense =>
      _daily.fold(0, (s, e) => s + ((e['expense'] ?? 0) as num).toInt());

  List<FlSpot> _spots(String key) => _daily
      .asMap()
      .entries
      .map((e) =>
          FlSpot(e.key.toDouble(), ((e.value[key] ?? 0) as num).toDouble()))
      .toList();

  double get _maxY {
    final all = [
      ..._spots('income').map((s) => s.y),
      ..._spots('expense').map((s) => s.y),
    ];
    final m = all.fold<double>(0, (a, b) => a > b ? a : b);
    return m == 0 ? 1000 : m * 1.2;
  }

  String _fmtY(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toInt().toString();
  }

  FlTitlesData get _titlesData => FlTitlesData(
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 24,
            interval: 1,
            getTitlesWidget: (v, m) {
              final idx = v.toInt();
              if (idx < 0 || idx >= _daily.length) return const SizedBox.shrink();
              final day = (_daily[idx]['day'] as String? ?? '').split('-').last;
              // Hanya tampilkan setiap tanggal ganjil agar tidak menumpuk jika data sebulan penuh
              if (idx % 2 != 0 && _daily.length > 15) return const SizedBox.shrink();
              return SideTitleWidget(
                axisSide: m.axisSide,
                child: Text(day, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
              );
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            getTitlesWidget: (v, m) {
              if (v == 0) return const SizedBox.shrink();
              return SideTitleWidget(
                axisSide: m.axisSide,
                child: Text(_fmtY(v), style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
              );
            },
          ),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      );

  Widget _buildLineChart() => LineChart(LineChartData(
        minX: 0,
        maxX: (_daily.length - 1).toDouble(),
        minY: 0,
        maxY: _maxY,
        // Grid dibuat lebih tipis dan soft
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.grey.shade200,
            strokeWidth: 1,
          ),
        ),
        // Border chart dihilangkan agar lebih modern
        borderData: FlBorderData(show: false),
        titlesData: _titlesData,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final isIncome = spot.barIndex == 0;
                final label = isIncome ? 'Pemasukan' : 'Pengeluaran';
                final color = isIncome ? Colors.green : Colors.redAccent;
                return LineTooltipItem(
                  '$label\n${_formatRupiah(spot.y.toInt())}',
                  TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: _spots('income'),
            isCurved: true,
            color: Colors.green,
            barWidth: 3,
            // TITIK DIHILANGKAN AGAR CLEAN
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
                show: true, color: Colors.green.withOpacity(0.1)),
          ),
          LineChartBarData(
            spots: _spots('expense'),
            isCurved: true,
            color: Colors.redAccent,
            barWidth: 3,
            // TITIK DIHILANGKAN AGAR CLEAN
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
                show: true, color: Colors.redAccent.withOpacity(0.1)),
          ),
        ],
      ));

  Widget _buildBarChart() => BarChart(BarChartData(
        minY: 0,
        maxY: _maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.grey.shade200,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: _titlesData,
        barGroups: _daily.asMap().entries.map((e) {
          final inc = ((e.value['income'] ?? 0) as num).toDouble();
          final exp = ((e.value['expense'] ?? 0) as num).toDouble();
          return BarChartGroupData(x: e.key, barRods: [
            BarChartRodData(
                toY: inc,
                color: Colors.green,
                width: 16,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
            BarChartRodData(
                toY: exp,
                color: Colors.redAccent,
                width: 16,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
          ], barsSpace: 4);
        }).toList(),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (g, gi, rod, ri) => BarTooltipItem(
              '${ri == 0 ? 'Pemasukan' : 'Pengeluaran'}\n${_formatRupiah(rod.toY.toInt())}',
              TextStyle(
                color: ri == 0 ? Colors.green : Colors.redAccent,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ));

  Widget _miniStat(String label, String value, Color color, CrossAxisAlignment alignment) {
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 13)),
      ],
    );
  }

  Widget _buildCategoryTable() {
    if (_byCat.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Divider(height: 1),
        ),
        const Text("Ringkasan Per Kategori",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        ..._byCat.map((cat) {
          final catId = cat['category_id'] as int?;
          final name = cat['category_name'] as String? ?? 'Lainnya';
          final type = cat['category_type'] as String?;
          final inc = (cat['income'] as num?)?.toInt() ?? 0;
          final exp = (cat['expense'] as num?)?.toInt() ?? 0;
          final prf = inc - exp;
          final color = _catColor(type);

          final isExpanded = _expandedCategoryId == catId && catId != null;

          return Card(
            elevation: 0,
            color: Colors.white,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: color.withOpacity(0.3)),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: catId == null ? null : () async {
                // Toggle expand/collapse
                if (isExpanded) {
                  setState(() => _expandedCategoryId = null);
                } else {
                  setState(() {
                    _expandedCategoryId = catId;
                    _isLoadingDetails = true;
                  });
                  // Fetch data dari database jika belum ada di cache
                  if (!_productDetailsCache.containsKey(catId)) {
                    final details = await DatabaseHelper.instance
                        .getIncomeExpenseByProduct(_monthStr, catId);
                    _productDetailsCache[catId] = details;
                  }
                  setState(() => _isLoadingDetails = false);
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Kategori
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                              color: color.withOpacity(0.8), shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(name,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: color.withOpacity(0.9))),
                        ),
                        if (catId != null)
                          Icon(
                            isExpanded ? Icons.expand_less : Icons.expand_more,
                            color: Colors.grey,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _miniStat("Masuk", _formatRupiah(inc), Colors.green, CrossAxisAlignment.start)),
                        Expanded(child: _miniStat("Keluar", _formatRupiah(exp), Colors.red, CrossAxisAlignment.center)),
                        Expanded(child: _miniStat("Profit", _formatRupiah(prf), prf >= 0 ? Colors.blue : Colors.orange, CrossAxisAlignment.end)),
                      ],
                    ),

                    // Detail List Produk
                    if (isExpanded) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(height: 1),
                      ),
                      if (_isLoadingDetails && !_productDetailsCache.containsKey(catId))
                        const Center(child: SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ))
                      else if (_productDetailsCache[catId]?.isEmpty ?? true)
                        const Center(child: Text("Tidak ada aktivitas produk", style: TextStyle(fontSize: 12, color: Colors.grey)))
                      else
                        ..._productDetailsCache[catId]!.map((prod) {
                          final pName = prod['product_name'] as String;
                          final pInc = (prod['income'] as num?)?.toInt() ?? 0;
                          final pExp = (prod['expense'] as num?)?.toInt() ?? 0;
                          final pPrf = pInc - pExp;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12, left: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // UI Garis Cabang (Branch/Tree)
                                Container(
                                  width: 2,
                                  height: 45,
                                  margin: const EdgeInsets.only(right: 12, top: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade300,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(pName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87)),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Expanded(child: _miniStat("Masuk", _formatRupiah(pInc), Colors.green, CrossAxisAlignment.start)),
                                          Expanded(child: _miniStat("Keluar", _formatRupiah(pExp), Colors.red, CrossAxisAlignment.start)),
                                          Expanded(child: _miniStat("Profit", _formatRupiah(pPrf), pPrf >= 0 ? Colors.blue : Colors.orange, CrossAxisAlignment.start)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                    ],
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _summaryCol(String label, String value, Color color) =>
      Column(children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value,
            style:
                TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
      ]);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Analisis", style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.trending_up_rounded),
            tooltip: "Laporan Laba",
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfitScreen()),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Filter baris
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pickMonth,
                    icon: const Icon(Icons.calendar_month_outlined, size: 18),
                    label: Text(_monthStr),
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: Colors.blueAccent.withOpacity(0.1),
                      foregroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickCategory,
                    icon: const Icon(Icons.filter_list_rounded, size: 18),
                    label: Text(
                      _selectedCategoryName,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: BorderSide(color: Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Konten scrollable
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Kartu ringkasan Grand Total
                        if (_daily.isNotEmpty)
                          Card(
                            elevation: 0,
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: Colors.grey.shade200),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  _summaryCol("Pemasukan", _formatRupiah(_totalIncome), Colors.green),
                                  Container(width: 1, height: 30, color: Colors.grey.shade200),
                                  _summaryCol("Pengeluaran", _formatRupiah(_totalExpense), Colors.redAccent),
                                  Container(width: 1, height: 30, color: Colors.grey.shade200),
                                  _summaryCol(
                                    "Profit",
                                    _formatRupiah(_totalIncome - _totalExpense),
                                    _totalIncome - _totalExpense >= 0 ? Colors.blue : Colors.orange,
                                  ),
                                ],
                              ),
                            ),
                          ),

                        const SizedBox(height: 24),

                        // Legend
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(width: 12, height: 12, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            const Text("Pemasukan", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                            const SizedBox(width: 24),
                            Container(width: 12, height: 12, decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            const Text("Pengeluaran", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Chart
                        if (_daily.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Column(
                              children: [
                                Icon(Icons.bar_chart_rounded, size: 48, color: Colors.grey.shade300),
                                const SizedBox(height: 8),
                                Text(
                                  "Belum ada data pada bulan ini",
                                  style: TextStyle(color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          ),

                        if (_daily.isNotEmpty)
                          Container(
                            height: 280,
                            padding: const EdgeInsets.only(right: 16, top: 16, bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: _daily.length < 2
                                ? _buildBarChart()
                                : _buildLineChart(),
                          ),

                        const SizedBox(height: 8),

                        // Tabel per kategori (Sudah pakai format Dashboard)
                        _buildCategoryTable(),
                        
                        const SizedBox(height: 40), // Ruang ekstra di bawah
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}