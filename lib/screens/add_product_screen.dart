import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../utils/formatters.dart';

class AddProductScreen extends StatefulWidget {
  /// Jika diisi, screen berjalan dalam mode Edit Produk.
  final Map<String, dynamic>? product;

  const AddProductScreen({super.key, this.product});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final stockController = TextEditingController();
  final purchasePriceController = TextEditingController();
  final sellingPriceController = TextEditingController();
  final unitController = TextEditingController();
  final minStockController = TextEditingController();

  List<Map<String, dynamic>> _categories = [];
  int? _selectedCategoryId;
  bool _isSaving = false;
  bool _isLoadingCategories = true;

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.product;
    if (existing != null) {
      nameController.text = (existing['name'] as String?) ?? '';
      _selectedCategoryId = existing['category_id'] as int?;
      stockController.text =
          formatQty((existing['stock'] as num?)?.toDouble() ?? 0.0);
      purchasePriceController.text = formatThousands(
          (existing['purchase_price'] as num?)?.toInt() ?? 0);
      sellingPriceController.text = formatThousands(
          (existing['selling_price'] as num?)?.toInt() ?? 0);
      unitController.text = (existing['unit'] as String?) ?? '';
      minStockController.text =
          formatQty((existing['min_stock'] as num?)?.toDouble() ?? 0.0);
    }
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final cats = await DatabaseHelper.instance.getCategories();
    if (mounted) {
      // Pastikan kategori terpilih memang ada di daftar kategori
      final validIds = cats.map((c) => c['id'] as int).toSet();
      setState(() {
        _categories = cats;
        if (_selectedCategoryId != null &&
            !validIds.contains(_selectedCategoryId)) {
          _selectedCategoryId = null;
        }
        _isLoadingCategories = false;
      });
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    stockController.dispose();
    purchasePriceController.dispose();
    sellingPriceController.dispose();
    unitController.dispose();
    minStockController.dispose();
    super.dispose();
  }

  Future saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    final purchasePrice = parseFormattedInt(purchasePriceController.text) ?? 0;
    final sellingPrice = parseFormattedInt(sellingPriceController.text) ?? 0;

    if (sellingPrice < purchasePrice) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Peringatan: Harga jual lebih rendah dari harga beli!"),
          backgroundColor: Colors.orange,
        ),
      );
    }

    setState(() => _isSaving = true);

    try {
      final data = {
        'name': nameController.text.trim(),
        'category_id': _selectedCategoryId,
        'stock': double.tryParse(stockController.text) ?? 0.0,
        'purchase_price': purchasePrice,
        'selling_price': sellingPrice,
        'unit': unitController.text.trim(),
        'min_stock': double.tryParse(minStockController.text) ?? 0.0,
      };

      if (_isEditing) {
        data['id'] = widget.product!['id'];
        await DatabaseHelper.instance.updateProduct(data);
      } else {
        await DatabaseHelper.instance.insertProduct(data);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal simpan: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildCategoryLabel(Map<String, dynamic> cat) {
    final type = cat['type'] as String? ?? '';
    final color = type == 'MATERIAL'
        ? Colors.blue
        : type == 'RAW'
            ? Colors.orange
            : Colors.green;
    final label = type == 'MATERIAL'
        ? 'Bangunan'
        : type == 'RAW'
            ? 'Bahan baku'
            : 'Produk jadi';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          cat['name'] as String? ?? '',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  // Menambahkan parameter prefixText untuk "Rp "
  InputDecoration _inputDecor(String label, String hint, IconData icon, {String? prefixText}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixText: prefixText,
      prefixStyle: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16),
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      prefixIcon:
          Icon(icon, color: Colors.blueAccent.withValues(alpha: 0.7), size: 22),
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          _isEditing ? "Edit Produk" : "Tambah Produk",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: _isLoadingCategories
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Informasi Dasar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: nameController,
                      decoration: _inputDecor("Nama Produk", "Masukkan nama produk...", Icons.inventory_2_outlined),
                      validator: (v) => (v == null || v.trim().isEmpty) ? "Nama produk wajib diisi" : null,
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      initialValue: _selectedCategoryId,
                      decoration: _inputDecor("Kategori", "Pilih kategori", Icons.category_outlined),
                      icon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.grey),
                      validator: (v) => v == null ? "Kategori wajib dipilih" : null,
                      items: _categories.map((cat) {
                        return DropdownMenuItem<int>(
                          value: cat['id'] as int,
                          child: _buildCategoryLabel(cat),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedCategoryId = val),
                    ),
                    
                    const SizedBox(height: 24),
                    const Text("Stok & Harga", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                    const SizedBox(height: 16),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: stockController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: _inputDecor(
                              _isEditing ? "Stok Saat Ini" : "Stok Awal",
                              "0",
                              Icons.numbers_rounded,
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return null;
                              if (double.tryParse(v) == null) return "Angka tidak valid";
                              if (double.parse(v) < 0) return "Tidak boleh negatif";
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: unitController,
                            decoration: _inputDecor("Satuan", "pcs, kg...", Icons.straighten_outlined),
                            validator: (v) => (v == null || v.trim().isEmpty) ? "Wajib diisi" : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Harga Beli (Dengan Formatter)
                    TextFormField(
                      controller: purchasePriceController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [CurrencyInputFormatter()],
                      decoration: _inputDecor("Harga Beli", "0", Icons.account_balance_wallet_outlined, prefixText: "Rp "),
                      validator: (v) {
                        if (v == null || v.isEmpty) return "Wajib diisi";
                        final parsed = parseFormattedInt(v);
                        if (parsed == null) return "Harus angka bulat";
                        if (parsed < 0) return "Tidak boleh negatif";
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Harga Jual (Dengan Formatter)
                    TextFormField(
                      controller: sellingPriceController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [CurrencyInputFormatter()],
                      decoration: _inputDecor("Harga Jual", "0", Icons.monetization_on_outlined, prefixText: "Rp "),
                      validator: (v) {
                        if (v == null || v.isEmpty) return "Wajib diisi";
                        final parsed = parseFormattedInt(v);
                        if (parsed == null) return "Harus angka bulat";
                        if (parsed < 0) return "Tidak boleh negatif";
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: minStockController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: _inputDecor("Minimal Stok", "Batas peringatan habis", Icons.warning_amber_rounded),
                      validator: (v) {
                        if (v == null || v.isEmpty) return null;
                        if (double.tryParse(v) == null) return "Harus berupa angka";
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 40),

                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _isSaving ? null : saveProduct,
                        icon: _isSaving 
                            ? const SizedBox.shrink() 
                            : const Icon(Icons.check_circle_outline, size: 22),
                        label: _isSaving
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(
                                _isEditing ? "Simpan Perubahan" : "Simpan Produk",
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }
}