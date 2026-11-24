import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../utils/formatters.dart';

/// Screen untuk kelola BOM (Bill of Materials) satu produk jadi.
/// Dipanggil dari product_screen / production_screen dengan passing data produk.
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

  InputDecoration _dialogInputDecor(String label, {String? suffixText}) {
    return InputDecoration(
      labelText: label,
      suffixText: suffixText,
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  // Dialog tambah / edit bahan BOM
  Future<void> _showBomDialog({Map<String, dynamic>? existing}) async {
    final usedIds = _bomItems.map((b) => b['material_id'] as int).toSet();
    if (existing != null) usedIds.remove(existing['material_id'] as int);

    final availableMaterials = _rawMaterials
        .where((m) => !usedIds.contains(m['id'] as int))
        .toList();

    if (availableMaterials.isEmpty && existing == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Semua bahan baku sudah ditambahkan ke BOM ini.\nTambah bahan baku baru di menu Produk.",
          ),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    int? selectedMaterialId = existing?['material_id'] as int?;
    final qtyController = TextEditingController(
      text: existing != null ? formatQty(existing['quantity'] as num) : '',
    );

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            existing == null ? "Tambah Bahan" : "Edit Bahan",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                isExpanded: true,
                initialValue: selectedMaterialId,
                decoration: _dialogInputDecor("Bahan Baku"),
                hint: const Text("Pilih bahan"),
                items: existing != null
                    ? [
                        DropdownMenuItem(
                          value: existing['material_id'] as int,
                          child: Text(
                            "${existing['material_name']} (${existing['material_unit']})",
                            overflow: TextOverflow.ellipsis,
                          ),
                        )
                      ]
                    : availableMaterials.map((m) {
                        return DropdownMenuItem<int>(
                          value: m['id'] as int,
                          child: Text(
                            "${m['name']} (${m['unit']})",
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                onChanged: existing != null
                    ? null
                    : (val) => setD(() => selectedMaterialId = val),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: qtyController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: _dialogInputDecor(
                  "Jumlah dibutuhkan (per 1 unit)",
                  suffixText: selectedMaterialId != null
                      ? _rawMaterials.firstWhere(
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
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () async {
                if (selectedMaterialId == null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text("Pilih bahan baku terlebih dahulu"),
                    ),
                  );
                  return;
                }
                final qty = double.tryParse(qtyController.text);
                if (qty == null || qty <= 0) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text("Masukkan jumlah yang valid"),
                    ),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Hapus Bahan",
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text("Hapus '${item['material_name']}' dari resep ini?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Batal"),
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
            child: const Text("Hapus"),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await DatabaseHelper.instance.deleteBomItem(item['id'] as int);
      _loadAll();
    }
  }

  Future<void> _deleteAllBom() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Hapus Semua Bahan",
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("Yakin hapus semua bahan dari BOM ini?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Batal"),
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
            child: const Text("Hapus Semua"),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await DatabaseHelper.instance.deleteAllBom(widget.product['id'] as int);
      _loadAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final productName = widget.product['name'] as String? ?? '';

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Kelola BOM",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            Text(
              productName,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        actions: [
          if (_bomItems.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, color: Colors.red),
              tooltip: "Hapus semua bahan",
              onPressed: _deleteAllBom,
            ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showBomDialog(),
        backgroundColor: Colors.blueAccent,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          "Tambah Bahan",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _bomItems.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.receipt_long_rounded,
                            size: 56,
                            color: Colors.grey.shade400,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          "Belum ada bahan di BOM ini",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Tap tombol '+ Tambah Bahan' untuk menyusun resep bahan baku produk ini.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    // Info banner modern
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            color: Colors.blueAccent,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Resep untuk 1 unit $productName (${_bomItems.length} bahan)",
                              style: TextStyle(
                                color: Colors.blue.shade800,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                        itemCount: _bomItems.length,
                        itemBuilder: (ctx, i) {
                          final item = _bomItems[i];
                          final double needed =
                              (item['quantity'] as num).toDouble();
                          final double stock =
                              (item['material_stock'] as num?)?.toDouble() ?? 0;
                          final bool isShort = stock < needed;

                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 12),
                            color: isShort ? Colors.red.shade50 : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: isShort
                                    ? Colors.red.shade200
                                    : Colors.grey.shade200,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: isShort
                                        ? Colors.redAccent
                                        : Colors.green,
                                    child: Icon(
                                      isShort
                                          ? Icons.warning_amber_rounded
                                          : Icons.check_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                item['material_name']
                                                        as String? ??
                                                    '',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 3,
                                              ),
                                              decoration: BoxDecoration(
                                                color: (isShort
                                                        ? Colors.red
                                                        : Colors.green)
                                                    .withValues(alpha: 0.12),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                isShort ? 'Kurang' : 'Cukup',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: isShort
                                                      ? Colors.red
                                                      : Colors.green,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "Dibutuhkan: ${formatQty(needed)} ${item['material_unit']}",
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade800,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          "Stok saat ini: ${formatQty(stock)} ${item['material_unit']}",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isShort
                                                ? Colors.red
                                                : Colors.grey.shade600,
                                            fontWeight: isShort
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      color: Colors.blueAccent,
                                      size: 20,
                                    ),
                                    tooltip: "Edit jumlah",
                                    onPressed: () =>
                                        _showBomDialog(existing: item),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.delete_outline,
                                      color: Colors.grey.shade500,
                                      size: 20,
                                    ),
                                    tooltip: "Hapus",
                                    onPressed: () => _deleteBomItem(item),
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
