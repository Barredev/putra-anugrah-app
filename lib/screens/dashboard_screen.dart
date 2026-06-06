import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../database/database_helper.dart';
import 'product_screen.dart';
import 'analysis_screen.dart';
import 'production_screen.dart';
import 'debt_screen.dart';
import 'profit_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int income = 0;
  int expense = 0;
  int profit = 0;
  int totalReceivable = 0;
  int totalPayable = 0;
  int overdueCount = 0;
  List<Map<String, dynamic>> lowStockProducts = [];
  List<Map<String, dynamic>> byCategory = [];
  String currentMonth = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    loadSummary();
  }

  Future loadSummary() async {
    setState(() => _isLoading = true);
    try {
      final data = await DatabaseHelper.instance.getDashboardSummary();
      final lowStock = await DatabaseHelper.instance.getLowStockProducts();
      setState(() {
        income = data['income'] as int;
        expense = data['expense'] as int;
        profit = data['profit'] as int;
        totalReceivable = data['total_receivable'] as int;
        totalPayable = data['total_payable'] as int;
        overdueCount = data['overdue_count'] as int;
        byCategory =
            List<Map<String, dynamic>>.from(data['by_category'] as List);
        currentMonth = data['current_month'] as String;
        lowStockProducts = List<Map<String, dynamic>>.from(lowStock);
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _requestStoragePermission() async {
    if (await Permission.manageExternalStorage.isGranted) return true;
    PermissionStatus status = await Permission.storage.request();
    if (!status.isGranted) {
      status = await Permission.manageExternalStorage.request();
    }
    if (!status.isGranted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              "Izin storage diperlukan. Buka pengaturan untuk mengizinkan."),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: "Buka Pengaturan",
            textColor: Colors.white,
            onPressed: () => openAppSettings(),
          ),
        ),
      );
      return false;
    }
    return true;
  }

  Future<void> confirmRestore() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Konfirmasi Restore"),
        content: const Text(
            "Semua data saat ini akan ditimpa dengan data backup.\n\nLanjutkan?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Batal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Ya, Restore",
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await DatabaseHelper.instance.restoreDatabase();
      await loadSummary();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Restore berhasil"),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Restore gagal: $e"),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatRupiah(int amount) {
    final str = amount.abs().toString();
    final buf = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buf.write('.');
      buf.write(str[i]);
    }
    return amount < 0 ? '-Rp $buf' : 'Rp $buf';
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

  // --- WIDGET HELPER UI BARU ---

  // Custom Button agar desain seragam dan warnanya tidak terlalu mencolok (gaya soft pastel)
  Widget _buildMenuButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 54, // Memberi tinggi agar nyaman di-tap
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: color),
        label: Text(
          label,
          style: TextStyle(fontWeight: FontWeight.bold, color: color.withOpacity(0.9)),
        ),
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: color.withOpacity(0.1), // Warna pastel soft
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: color.withOpacity(0.2)),
          ),
        ),
      ),
    );
  }

  // Custom stat untuk bagian per kategori, ditambahkan parameter alignment
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

  Widget _buildCategoryCards() {
    if (byCategory.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Per Kategori — $currentMonth",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        ...byCategory.map((cat) {
          final name = cat['category_name'] as String? ?? 'Lainnya';
          final type = cat['category_type'] as String?;
          final inc = (cat['income'] as num?)?.toInt() ?? 0;
          final exp = (cat['expense'] as num?)?.toInt() ?? 0;
          final prf = inc - exp;
          final color = _catColor(type);

          return Card(
            elevation: 0,
            color: Colors.white,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: color.withOpacity(0.3)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                            color: color.withOpacity(0.8), shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Text(name,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: color.withOpacity(0.9))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // PENGGUNAAN EXPANDED AGAR ALIGNMENT RAPI
                  Row(
                    children: [
                      Expanded(
                        child: _miniStat("Masuk", _formatRupiah(inc), Colors.green, CrossAxisAlignment.start),
                      ),
                      Expanded(
                        child: _miniStat("Keluar", _formatRupiah(exp), Colors.red, CrossAxisAlignment.center),
                      ),
                      Expanded(
                        child: _miniStat("Profit", _formatRupiah(prf), prf >= 0 ? Colors.blue : Colors.orange, CrossAxisAlignment.end),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50, // Background aplikasi lebih soft
      appBar: AppBar(
        title: const Text("Dashboard", style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: loadSummary,
            tooltip: "Refresh",
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20), // Padding diperlebar
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── KEUANGAN TOTAL ──────────────────────
                  const Text("Ringkasan Keuangan",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  
                  // Pemasukan
                  Card(
                    elevation: 0,
                    color: Colors.green.shade50,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: ListTile(
                      leading: const Icon(Icons.arrow_upward_rounded, color: Colors.green),
                      title: const Text("Pemasukan", style: TextStyle(fontSize: 14)),
                      trailing: Text(_formatRupiah(income),
                          style: const TextStyle(
                              color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Pengeluaran
                  Card(
                    elevation: 0,
                    color: Colors.red.shade50,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: ListTile(
                      leading: const Icon(Icons.arrow_downward_rounded, color: Colors.red),
                      title: const Text("Pengeluaran", style: TextStyle(fontSize: 14)),
                      trailing: Text(_formatRupiah(expense),
                          style: const TextStyle(
                              color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Profit
                  Card(
                    elevation: 0,
                    color: profit >= 0 ? Colors.blue.shade50 : Colors.orange.shade50,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: ListTile(
                      leading: Icon(
                        profit >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                        color: profit >= 0 ? Colors.blue : Colors.orange,
                      ),
                      title: const Text("Profit", style: TextStyle(fontSize: 14)),
                      trailing: Text(
                        _formatRupiah(profit),
                        style: TextStyle(
                          color: profit >= 0 ? Colors.blue : Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),

                  // ── HUTANG PIUTANG ───────────────────────
                  if (totalReceivable > 0 || totalPayable > 0) ...[
                    const SizedBox(height: 24),
                    const Text("Hutang Piutang",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: Card(
                          elevation: 0,
                          color: Colors.green.shade50,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                            child: Column(children: [
                              const Text("Piutang (belum lunas)",
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                  textAlign: TextAlign.center),
                              const SizedBox(height: 8),
                              Text(_formatRupiah(totalReceivable),
                                  style: const TextStyle(
                                      color: Colors.green, fontWeight: FontWeight.bold, fontSize: 15)),
                            ]),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Card(
                          elevation: 0,
                          color: Colors.red.shade50,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                            child: Column(children: [
                              const Text("Hutang (belum lunas)",
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                  textAlign: TextAlign.center),
                              const SizedBox(height: 8),
                              Text(_formatRupiah(totalPayable),
                                  style: const TextStyle(
                                      color: Colors.red, fontWeight: FontWeight.bold, fontSize: 15)),
                            ]),
                          ),
                        ),
                      ),
                    ]),
                    if (overdueCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, left: 4),
                        child: GestureDetector(
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const DebtScreen()),
                            );
                            loadSummary();
                          },
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                "$overdueCount tagihan sudah jatuh tempo — Tap untuk lihat",
                                style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.underline),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],

                  // ── PER KATEGORI BULAN INI ───────────────
                  const SizedBox(height: 24),
                  _buildCategoryCards(),

                  // ── STOK MENIPIS ─────────────────────────
                  if (lowStockProducts.isNotEmpty) ...[
                    Card(
                      elevation: 0,
                      color: Colors.red.shade50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.red.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              const Icon(Icons.warning_amber_rounded, color: Colors.red),
                              const SizedBox(width: 8),
                              Text(
                                "Stok Menipis (${lowStockProducts.length} produk)",
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                              ),
                            ]),
                            const SizedBox(height: 12),
                            ...lowStockProducts.map((p) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.circle, size: 6, color: Colors.red),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          "${p['name']}: ${p['stock']} ${p['unit']} (min: ${p['min_stock']})",
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── MENU ────────────────────────────────
                  const SizedBox(height: 8),
                  const Text("Menu",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: _buildMenuButton(
                        label: "Kelola Produk",
                        icon: Icons.inventory_2_outlined,
                        color: Colors.blueAccent,
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ProductScreen()),
                          );
                          loadSummary();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMenuButton(
                        label: "Analisis",
                        icon: Icons.bar_chart_rounded,
                        color: Colors.indigo,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AnalysisScreen()),
                          );
                        },
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  _buildMenuButton(
                    label: "Produksi",
                    icon: Icons.factory_outlined,
                    color: Colors.green,
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ProductionScreen()),
                      );
                      loadSummary();
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildMenuButton(
                    label: "Hutang Piutang",
                    icon: Icons.account_balance_wallet_outlined,
                    color: Colors.purple,
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const DebtScreen()),
                      );
                      loadSummary();
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildMenuButton(
                    label: "Laporan Laba",
                    icon: Icons.trending_up_rounded,
                    color: Colors.teal,
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfitScreen()),
                    ),
                  ),

                  // ── BACKUP & RESTORE ─────────────────────
                  const SizedBox(height: 32),
                  const Text("Sistem",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  
                  // Tombol sistem pakai gaya outline ringan
                  SizedBox(
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final granted = await _requestStoragePermission();
                        if (!granted) return;
                        try {
                          final path = await DatabaseHelper.instance.backupDatabase();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Backup berhasil:\n$path"),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Backup gagal: $e"),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.cloud_upload_outlined, color: Colors.blueGrey),
                      label: const Text("Backup Data", style: TextStyle(color: Colors.blueGrey)),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        side: BorderSide(color: Colors.blueGrey.withOpacity(0.3)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final granted = await _requestStoragePermission();
                        if (!granted) return;
                        confirmRestore();
                      },
                      icon: const Icon(Icons.restore_rounded, color: Colors.deepOrange),
                      label: const Text("Restore Data", style: TextStyle(color: Colors.deepOrange)),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        side: BorderSide(color: Colors.deepOrange.withOpacity(0.3)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24), // Extra bottom padding
                ],
              ),
            ),
    );
  }
}