import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import 'add_product_screen.dart';
import 'bom_screen.dart';
import 'production_screen.dart';

class ProductScreen extends StatefulWidget {
  const ProductScreen({super.key});

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen>
    with TickerProviderStateMixin {
  TabController? _tabController;

  List<Map<String, dynamic>> _categories = [];
  final Map<int?, List<Map<String, dynamic>>> _products = {};
  bool _isLoading = true;

  // Search
  bool _isSearching = false;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  // Filter stok: 'all' | 'low' | 'empty'
  String _stockFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    if (mounted) setState(() => _isLoading = true);

    final cats = await DatabaseHelper.instance.getCategories();
    final allProducts =
        await DatabaseHelper.instance.getProductsWithCategory();

    final Map<int?, List<Map<String, dynamic>>> grouped = {
      null: allProducts
    };
    for (final cat in cats) {
      final id = cat['id'] as int;
      grouped[id] =
          allProducts.where((p) => p['category_id'] == id).toList();
    }

    if (!mounted) return;

    final newLength = 1 + cats.length;
    final oldController = _tabController;
    final newController =
        TabController(length: newLength, vsync: this);

    setState(() {
      _categories = cats;
      _products.clear();
      _products.addAll(grouped);
      _tabController = newController;
      _isLoading = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      oldController?.dispose();
    });
  }

  // Terapkan search + filter stok ke list produk
  List<Map<String, dynamic>> _applyFilter(
      List<Map<String, dynamic>> items) {
    var result = items;

    // Filter search
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((p) {
        final name = (p['name'] as String? ?? '').toLowerCase();
        return name.contains(q);
      }).toList();
    }

    // Filter stok
    if (_stockFilter == 'low') {
      result = result.where((p) {
        final double stock =
            (p['stock'] as num?)?.toDouble() ?? 0;
        final double minStock =
            (p['min_stock'] as num?)?.toDouble() ?? 0;
        return stock > 0 && stock <= minStock;
      }).toList();
    } else if (_stockFilter == 'empty') {
      result = result.where((p) {
        final double stock =
            (p['stock'] as num?)?.toDouble() ?? 0;
        return stock <= 0;
      }).toList();
    }

    return result;
  }

  String _fmt(num v) =>
      v == v.toInt() ? v.toInt().toString() : v.toStringAsFixed(2);

  // Fungsi tambahan untuk format Rupiah agar lebih rapi
  String _formatRupiah(num amount) {
    final str = amount.toInt().abs().toString();
    final buf = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buf.write('.');
      buf.write(str[i]);
    }
    return amount < 0 ? '-Rp $buf' : 'Rp $buf';
  }

  // Dialog Transaksi Baru dengan pilihan Tunai / Non-Tunai
  Future<Map<String, dynamic>?> _showTransactionDialog(String title, bool isOut) async {
    final controller = TextEditingController();
    bool isCash = true; // Default tunai

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                decoration: InputDecoration(
                  labelText: "Jumlah",
                  hintText: "Contoh: 5 atau 2.5",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: isCash ? Colors.blue.shade50 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isCash ? Colors.blue.shade200 : Colors.grey.shade300),
                ),
                child: SwitchListTile(
                  title: const Text("Transaksi Tunai", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text(
                    isCash 
                      ? (isOut ? "Uang masuk ke Kasir" : "Uang keluar dari Kasir")
                      : (isOut ? "Piutang / Barang Rusak (Hanya potong stok)" : "Hutang (Hanya tambah stok)"),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  value: isCash,
                  activeColor: Colors.blueAccent,
                  onChanged: (val) => setD(() => isCash = val),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Batal")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                final v = double.tryParse(controller.text);
                if (v == null || v <= 0) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text("Masukkan angka yang valid")),
                  );
                  return;
                }
                Navigator.pop(ctx, {'qty': v, 'isCash': isCash});
              },
              child: const Text("Simpan"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(Map<String, dynamic> item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Hapus Produk"),
        content: Text("Yakin hapus '${item['name']}'?"),
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
            child: const Text("Hapus",
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await DatabaseHelper.instance.deleteProduct(item['id'] as int);
      _loadAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("'${item['name']}' dihapus")),
        );
      }
    }
  }

  Widget _buildProductList(List<Map<String, dynamic>> rawItems) {
    final items = _applyFilter(rawItems);

    if (items.isEmpty) {
      String msg = 'Belum ada produk';
      if (_searchQuery.isNotEmpty) {
        msg = 'Tidak ada produk dengan nama "$_searchQuery"';
      } else if (_stockFilter == 'low') {
        msg = 'Tidak ada produk dengan stok menipis';
      } else if (_stockFilter == 'empty') {
        msg = 'Tidak ada produk dengan stok habis';
      }

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined,
                size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(msg,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100, top: 8),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final item = items[i];
        final double stock = (item['stock'] as num?)?.toDouble() ?? 0;
        final double minStock = (item['min_stock'] as num?)?.toDouble() ?? 0;
        final bool isLow = stock > 0 && stock <= minStock;
        final bool isEmpty = stock <= 0;

        final String name = (item['name'] as String?) ?? '';
        final String initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
        final String catName = (item['category_name'] as String?) ?? '—';
        final String? catType = item['category_type'] as String?;
        final bool isProduct = catType == 'PRODUCT';

        // Highlight teks search
        Widget buildTitle() {
          if (_searchQuery.isEmpty) {
            return Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16));
          }
          final idx = name.toLowerCase().indexOf(_searchQuery.toLowerCase());
          if (idx < 0) {
            return Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16));
          }
          return RichText(
            text: TextSpan(
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
              children: [
                TextSpan(text: name.substring(0, idx)),
                TextSpan(
                  text: name.substring(idx, idx + _searchQuery.length),
                  style: const TextStyle(
                    backgroundColor: Color(0xFFFFE082),
                    color: Colors.black,
                  ),
                ),
                TextSpan(text: name.substring(idx + _searchQuery.length)),
              ],
            ),
          );
        }

        // Penentuan warna Card berdasarkan stok
        Color cardColor = Colors.white;
        Color borderColor = Colors.grey.shade200;
        if (isEmpty) {
          cardColor = Colors.red.shade50;
          borderColor = Colors.red.shade200;
        } else if (isLow) {
          cardColor = Colors.orange.shade50;
          borderColor = Colors.orange.shade200;
        }

        return Card(
          elevation: 0,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: borderColor),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // BAGIAN ATAS: Info Produk
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: isEmpty
                          ? Colors.red
                          : isLow
                              ? Colors.orange
                              : Colors.blueAccent,
                      child: Text(initial,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: buildTitle()),
                              if (isEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text('Habis',
                                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                )
                              else if (isLow)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text('Menipis',
                                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                )
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(catName,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 8),
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(fontSize: 14, color: Colors.black87),
                              children: [
                                const TextSpan(text: 'Stok: '),
                                TextSpan(
                                  text: '${_fmt(stock)} ${(item['unit'] as String?) ?? ''}',
                                  style: TextStyle(
                                    color: isEmpty ? Colors.red : isLow ? Colors.orange.shade800 : Colors.black87,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Beli: ${_formatRupiah(item['purchase_price'] ?? 0)}  |  Jual: ${_formatRupiah(item['selling_price'] ?? 0)}",
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Divider(height: 1),
                ),
                
                // BAGIAN BAWAH: Tombol Aksi
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      if (isProduct)
                        _buildActionButton(
                          icon: Icons.receipt_long,
                          label: "BOM",
                          color: Colors.purple,
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => BomScreen(product: item)),
                            );
                            _loadAll();
                          },
                        ),
                      if (isProduct)
                        _buildActionButton(
                          icon: Icons.factory_outlined,
                          label: "Produksi",
                          color: Colors.green,
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ProductionScreen()),
                            );
                            _loadAll();
                          },
                        ),
                      _buildActionButton(
                        icon: Icons.add_circle_outline,
                        label: "Masuk",
                        color: Colors.teal,
                        onPressed: () async {
                          final data = await _showTransactionDialog("Barang Masuk: $name", false);
                          if (data != null) {
                            try {
                              await DatabaseHelper.instance.insertStockIn(
                                item['id'] as int, 
                                data['qty'], 
                                isCash: data['isCash'],
                              );
                              _loadAll();
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                              }
                            }
                          }
                        },
                      ),
                      _buildActionButton(
                        icon: Icons.remove_circle_outline,
                        label: "Keluar",
                        color: Colors.red,
                        onPressed: () async {
                          final data = await _showTransactionDialog("Barang Keluar: $name", true);
                          if (data != null) {
                            try {
                              await DatabaseHelper.instance.insertStockOut(
                                item['id'] as int, 
                                data['qty'], 
                                isCash: data['isCash'],
                              );
                              _loadAll();
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
                              }
                            }
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.grey),
                        tooltip: "Hapus",
                        onPressed: () => _confirmDelete(item),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper untuk tombol aksi di dalam Card
  Widget _buildActionButton({required IconData icon, required String label, required Color color, required VoidCallback onPressed}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: TextButton.icon(
        icon: Icon(icon, color: color, size: 18),
        label: Text(label, style: TextStyle(color: color, fontSize: 12)),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          backgroundColor: color.withOpacity(0.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: onPressed,
      ),
    );
  }

  // Filter chip bar
  Widget _buildFilterChips() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _filterChip('Semua Produk', 'all', Colors.blue),
            const SizedBox(width: 8),
            _filterChip('Stok Menipis', 'low', Colors.orange),
            const SizedBox(width: 8),
            _filterChip('Stok Habis', 'empty', Colors.red),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, String value, Color color) {
    final bool selected = _stockFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _stockFilter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : Colors.transparent),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black87,
            fontSize: 13,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _tabController == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final tabs = <Tab>[
      const Tab(text: "Semua"),
      ..._categories.map((c) => Tab(text: (c['name'] as String?) ?? '')),
    ];

    final tabViews = <Widget>[
      _buildProductList(_products[null] ?? []),
      ..._categories.map((c) => _buildProductList(_products[c['id'] as int] ?? [])),
    ];

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Cari nama produk...',
                  border: InputBorder.none,
                ),
                style: const TextStyle(fontSize: 16),
                onChanged: (val) => setState(() => _searchQuery = val),
              )
            : const Text("Daftar Produk", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchQuery = '';
                  _searchController.clear();
                }
              });
            },
          ),
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.factory_outlined),
              tooltip: "Produksi",
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProductionScreen()),
                );
                _loadAll();
              },
            ),
        ],
        bottom: TabBar(
          controller: _tabController!,
          isScrollable: true,
          labelColor: Colors.blueAccent,
          unselectedLabelColor: Colors.grey.shade600,
          indicatorColor: Colors.blueAccent,
          indicatorWeight: 3,
          tabs: tabs,
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddProductScreen()),
          );
          if (result == true) _loadAll();
        },
        backgroundColor: Colors.blueAccent,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Produk", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(
            child: TabBarView(
              controller: _tabController!,
              children: tabViews,
            ),
          ),
        ],
      ),
    );
  }
}