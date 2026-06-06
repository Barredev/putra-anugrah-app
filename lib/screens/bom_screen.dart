import 'package:flutter/material.dart';
import '../database/database_helper.dart';

/// Screen untuk kelola BOM (Bill of Materials) satu produk jadi.
/// Dipanggil dari product_screen dengan passing data produk.
class BomScreen extends StatefulWidget {
  final Map<String, dynamic> product;

  const BomScreen({super.key, required this.product});

  @override
  State<BomScreen> createState() => _BomScreenState();
}

class _BomScreenState extends State<BomScreen> {
  List<Map<String, dynamic>> _bomItems = [];
  List<Map<String, dynamic>> _rawMaterials = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    final bom = await DatabaseHelper.instance
        .getBom(widget.product['id'] as int);
    final raws = await DatabaseHelper.instance.getRawMaterials();
    if (mounted) {
      setState(() {
        _bomItems = List<Map<String, dynamic>>.from(bom);
        _rawMaterials = List<Map<String, dynamic>>.from(raws);
        _isLoading = false;
      });
    }
  }

  // Format angka: 2.0 → "2", 1.5 → "1.5"
  String _fmt(num v) =>
      v == v.toInt() ? v.toInt().toString() : v.toStringAsFixed(2);

  // Dialog tambah / edit bahan BOM
  Future<void> _showBomDialog({Map<String, dynamic>? existing}) async {
    // Bahan yang sudah ada di BOM — tidak boleh duplikat saat tambah
    final usedIds = _bomItems.map((b) => b['material_id'] as int).toSet();

    // Saat edit, allow bahan yang sedang diedit
    if (existing != null) usedIds.remove(existing['material_id'] as int);

    final availableMaterials = _rawMaterials
        .where((m) => !usedIds.contains(m['id'] as int))
        .toList();

    if (availableMaterials.isEmpty && existing == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              "Semua bahan baku sudah ditambahkan ke BOM ini.\nTambah bahan baku baru di menu Produk."),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    int? selectedMaterialId = existing?['material_id'] as int?;
    final qtyController = TextEditingController(
      text: existing != null ? _fmt(existing['quantity'] as num) : '',
    );

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(existing == null ? "Tambah Bahan" : "Edit Bahan"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Dropdown pilih bahan baku
              DropdownButtonFormField<int>(
                value: selectedMaterialId,
                decoration: const InputDecoration(
                  labelText: "Bahan Baku",
                  border: OutlineInputBorder(),
                ),
                hint: const Text("Pilih bahan"),
                items: existing != null
                    // Saat edit: hanya tampilkan bahan yang sedang diedit
                    ? [
                        DropdownMenuItem(
                          value: existing['material_id'] as int,
                          child: Text(
                              "${existing['material_name']} (${existing['material_unit']})"),
                        )
                      ]
                    : availableMaterials.map((m) {
                        return DropdownMenuItem<int>(
                          value: m['id'] as int,
                          child: Text(
                              "${m['name']} (${m['unit']})"),
                        );
                      }).toList(),
                onChanged: existing != null
                    ? null // tidak bisa ganti bahan saat edit, hanya qty
                    : (val) => setD(() => selectedMaterialId = val),
              ),
              const SizedBox(height: 12),
              // Input jumlah
              TextField(
                controller: qtyController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: "Jumlah yang dibutuhkan",
                  border: const OutlineInputBorder(),
                  suffixText: selectedMaterialId != null
                      ? _rawMaterials
                          .firstWhere(
                            (m) => m['id'] == selectedMaterialId,
                            orElse: () => {'unit': ''},
                          )['unit'] as String
                      : '',
                ),
                autofocus: existing != null,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Batal"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedMaterialId == null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                        content: Text("Pilih bahan baku terlebih dahulu")),
                  );
                  return;
                }
                final qty = double.tryParse(qtyController.text);
                if (qty == null || qty <= 0) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                        content: Text("Masukkan jumlah yang valid")),
                  );
                  return;
                }

                Navigator.pop(ctx);

                if (existing != null) {
                  await DatabaseHelper.instance
                      .updateBomItem(existing['id'] as int, qty);
                } else {
                  await DatabaseHelper.instance.insertBomItem(
                    widget.product['id'] as int,
                    selectedMaterialId!,
                    qty,
                  );
                }
                _loadAll();
              },
              child: Text(existing == null ? "Tambah" : "Simpan"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteBomItem(Map<String, dynamic> item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Hapus Bahan"),
        content: Text(
            "Hapus '${item['material_name']}' dari resep ini?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text("Hapus", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await DatabaseHelper.instance.deleteBomItem(item['id'] as int);
      _loadAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final productName = widget.product['name'] as String? ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Kelola BOM",
                style: TextStyle(fontSize: 16)),
            Text(productName,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ),
        actions: [
          // Tombol hapus semua BOM
          if (_bomItems.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: "Hapus semua bahan",
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text("Hapus Semua Bahan"),
                    content:
                        const Text("Yakin hapus semua bahan dari BOM ini?"),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text("Batal"),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text("Hapus Semua",
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await DatabaseHelper.instance
                      .deleteAllBom(widget.product['id'] as int);
                  _loadAll();
                }
              },
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showBomDialog(),
        icon: const Icon(Icons.add),
        label: const Text("Tambah Bahan"),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _bomItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long,
                          size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      const Text("Belum ada bahan di BOM ini",
                          style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 4),
                      const Text(
                          "Tap tombol + untuk menambah bahan baku",
                          style: TextStyle(
                              color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Info header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      color: Colors.blue.shade50,
                      child: Text(
                        "Resep untuk 1 unit $productName",
                        style: TextStyle(
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: _bomItems.length,
                        itemBuilder: (ctx, i) {
                          final item = _bomItems[i];
                          final double needed =
                              (item['quantity'] as num).toDouble();
                          final double stock =
                              (item['material_stock'] as num?)
                                      ?.toDouble() ??
                                  0;
                          final bool isShort = stock < needed;

                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    isShort ? Colors.red : Colors.green,
                                child: Icon(
                                  isShort
                                      ? Icons.warning
                                      : Icons.check,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                              title: Text(
                                  item['material_name'] as String? ?? ''),
                              subtitle: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Dibutuhkan: ${_fmt(needed)} ${item['material_unit']}",
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  Text(
                                    "Stok saat ini: ${_fmt(stock)} ${item['material_unit']}",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isShort
                                          ? Colors.red
                                          : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                              isThreeLine: true,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit,
                                        color: Colors.blue),
                                    tooltip: "Edit jumlah",
                                    onPressed: () =>
                                        _showBomDialog(existing: item),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.grey),
                                    tooltip: "Hapus",
                                    onPressed: () =>
                                        _deleteBomItem(item),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}