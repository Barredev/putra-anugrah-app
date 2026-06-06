import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import 'bom_screen.dart';

/// Screen untuk menjalankan produksi.
/// Owner pilih produk jadi → input jumlah → sistem cek bahan → produksi.
class ProductionScreen extends StatefulWidget {
  const ProductionScreen({super.key});

  @override
  State<ProductionScreen> createState() => _ProductionScreenState();
}

class _ProductionScreenState extends State<ProductionScreen> {
  // Daftar produk jadi (kategori PRODUCT)
  List<Map<String, dynamic>> _finishedProducts = [];
  // Produk yang dipilih
  Map<String, dynamic>? _selectedProduct;
  // BOM produk terpilih
  List<Map<String, dynamic>> _bomItems = [];
  // Kekurangan bahan
  List<Map<String, dynamic>> _shortages = [];

  final _qtyController = TextEditingController(text: '1');
  bool _isLoadingProducts = true;
  bool _isCheckingBom = false;
  bool _isProducing = false;

  // Qty produksi saat ini
  double get _qty => double.tryParse(_qtyController.text) ?? 0;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _qtyController.addListener(_onQtyChanged);
  }

  @override
  void dispose() {
    _qtyController.removeListener(_onQtyChanged);
    _qtyController.dispose();
    super.dispose();
  }

  void _onQtyChanged() {
    if (_selectedProduct != null && _qty > 0) {
      _checkBom();
    }
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoadingProducts = true);
    // Ambil semua produk berkategori PRODUCT
    final all = await DatabaseHelper.instance.getProductsWithCategory();
    final finished =
        all.where((p) => p['category_type'] == 'PRODUCT').toList();
    if (mounted) {
      setState(() {
        _finishedProducts = finished;
        _isLoadingProducts = false;
      });
    }
  }

  Future<void> _selectProduct(Map<String, dynamic> product) async {
    setState(() {
      _selectedProduct = product;
      _bomItems = [];
      _shortages = [];
    });
    await _loadBom(product['id'] as int);
    await _checkBom();
  }

  Future<void> _loadBom(int productId) async {
    final bom = await DatabaseHelper.instance.getBom(productId);
    if (mounted) {
      setState(() {
        _bomItems = List<Map<String, dynamic>>.from(bom);
      });
    }
  }

  // Cek ketersediaan bahan untuk qty yang diinput
  Future<void> _checkBom() async {
    if (_selectedProduct == null || _qty <= 0) return;
    setState(() => _isCheckingBom = true);
    final shortages = await DatabaseHelper.instance
        .checkBomStock(_selectedProduct!['id'] as int, _qty);
    if (mounted) {
      setState(() {
        _shortages = shortages;
        _isCheckingBom = false;
      });
    }
  }

  Future<void> _produce() async {
    if (_selectedProduct == null) return;
    if (_qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Masukkan jumlah produksi yang valid")),
      );
      return;
    }
    if (_bomItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("BOM kosong. Tambahkan bahan baku terlebih dahulu."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (_shortages.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Bahan tidak cukup. Periksa daftar kekurangan."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Konfirmasi produksi
    final productName = _selectedProduct!['name'] as String;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Konfirmasi Produksi", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          "Produksi ${_fmt(_qty)} unit $productName?\n\n"
          "Bahan baku akan otomatis dikurangi sesuai BOM.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Ya, Produksi"),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isProducing = true);
    try {
      await DatabaseHelper.instance.produceProduct(
        _selectedProduct!['id'] as int,
        _qty,
      );

      // Reload BOM & stok setelah produksi
      await _loadBom(_selectedProduct!['id'] as int);
      await _checkBom();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                "Berhasil produksi ${_fmt(_qty)} unit $productName"),
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
      if (mounted) setState(() => _isProducing = false);
    }
  }

  String _fmt(num v) =>
      v == v.toInt() ? v.toInt().toString() : v.toStringAsFixed(2);

  // ── Bahan yang dibutuhkan untuk qty produksi
  double _needed(double bomQty) => bomQty * _qty;

  // Helper Dekorasi Input
  InputDecoration _inputDecor(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      prefixIcon: Icon(icon, color: Colors.blueAccent.withOpacity(0.7), size: 22),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Produksi", style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: _isLoadingProducts
          ? const Center(child: CircularProgressIndicator())
          : _finishedProducts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.factory_rounded, size: 64, color: Colors.grey.shade400),
                      ),
                      const SizedBox(height: 24),
                      const Text("Belum ada Produk Jadi",
                          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 8),
                      Text(
                        "Tambah produk dengan kategori\n'Produk Jadi Mebel' di menu Kelola Produk.",
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Pilih produk ──────────────────────
                      const Text("Pilih Produk Jadi",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        isExpanded: true,
                        value: _selectedProduct?['id'] as int?,
                        decoration: _inputDecor("Pilih produk yang akan diproduksi", Icons.inventory_2_outlined),
                        icon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.grey),
                        items: _finishedProducts.map((p) {
                          final stock = (p['stock'] as num?)?.toDouble() ?? 0;
                          return DropdownMenuItem<int>(
                            value: p['id'] as int,
                            child: Text(
                              "${p['name']}  (Stok: ${_fmt(stock)} ${p['unit']})",
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          );
                        }).toList(),
                        onChanged: (id) {
                          final product = _finishedProducts.firstWhere((p) => p['id'] == id);
                          _selectProduct(product);
                        },
                      ),

                      if (_selectedProduct != null) ...[
                        const SizedBox(height: 24),

                        // ── Input jumlah produksi ─────────
                        const Text("Jumlah Produksi",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                        const SizedBox(height: 12),
                        
                        // Counter Produksi Custom
                        Container(
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
                                  onTap: () {
                                    final v = _qty - 1;
                                    if (v >= 1) _qtyController.text = _fmt(v);
                                  },
                                  child: Container(
                                    width: 60,
                                    alignment: Alignment.center,
                                    child: const Icon(Icons.remove, color: Colors.redAccent),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: _qtyController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ),
                              Text(
                                _selectedProduct!['unit'] as String? ?? '',
                                style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(width: 8),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(16)),
                                  onTap: () {
                                    final v = _qty + 1;
                                    _qtyController.text = _fmt(v);
                                  },
                                  child: Container(
                                    width: 60,
                                    alignment: Alignment.center,
                                    child: const Icon(Icons.add, color: Colors.green),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // ── BOM & status bahan ────────────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Kebutuhan Bahan",
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                            TextButton.icon(
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => BomScreen(product: _selectedProduct!)),
                                );
                                await _loadBom(_selectedProduct!['id'] as int);
                                await _checkBom();
                              },
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              label: const Text("Kelola BOM"),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.blueAccent,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        if (_isCheckingBom)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else if (_bomItems.isEmpty)
                          Card(
                            elevation: 0,
                            color: Colors.orange.shade50,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: Colors.orange.shade200),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline_rounded, color: Colors.orange),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      "BOM belum diisi. Tap 'Kelola BOM' untuk menambahkan daftar bahan baku.",
                                      style: TextStyle(fontSize: 13, color: Colors.black87),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ..._bomItems.map((item) {
                            final double bomQty = (item['quantity'] as num).toDouble();
                            final double stockNow = (item['material_stock'] as num?)?.toDouble() ?? 0;
                            final double needed = _needed(bomQty);
                            final bool ok = stockNow >= needed;

                            return Card(
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 12),
                              color: ok ? Colors.white : Colors.red.shade50,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(color: ok ? Colors.grey.shade200 : Colors.red.shade200),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Icon(
                                      ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                      color: ok ? Colors.green : Colors.redAccent,
                                      size: 28,
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item['material_name'] as String? ?? '',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            "Butuh: ${_fmt(needed)} ${item['material_unit']}",
                                            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                                          ),
                                          Text(
                                            "Stok saat ini: ${_fmt(stockNow)} ${item['material_unit']}",
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: ok ? Colors.grey.shade600 : Colors.red,
                                              fontWeight: ok ? FontWeight.normal : FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Progress bar mini
                                    SizedBox(
                                      width: 60,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            ok ? "Cukup" : "Kurang",
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: ok ? Colors.green : Colors.redAccent,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: LinearProgressIndicator(
                                              value: needed == 0 ? 1 : (stockNow / needed).clamp(0.0, 1.0),
                                              backgroundColor: ok ? Colors.grey.shade200 : Colors.red.shade100,
                                              color: ok ? Colors.green : Colors.redAccent,
                                              minHeight: 6,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),

                        const SizedBox(height: 32),

                        // ── Tombol produksi ───────────────
                        SizedBox(
                          width: double.infinity,
                          height: 54, // Tinggi ideal
                          child: ElevatedButton.icon(
                            onPressed: (_isProducing || _bomItems.isEmpty || _shortages.isNotEmpty)
                                ? null
                                : _produce,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              disabledBackgroundColor: Colors.grey.shade300,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            icon: _isProducing
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.factory_outlined, size: 22),
                            label: Text(
                              _isProducing
                                  ? "Memproses Produksi..."
                                  : _shortages.isNotEmpty
                                      ? "Bahan Baku Tidak Cukup"
                                      : _bomItems.isEmpty
                                          ? "BOM Belum Diisi"
                                          : "Mulai Produksi ${_fmt(_qty)} Unit",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ],
                  ),
                ),
    );
  }
}