class Product {
  final int? id;
  final String name;
  final int? categoryId;
  final double stock;
  final int purchasePrice;
  final int sellingPrice;
  final String unit;
  final double minStock;

  Product({
    this.id,
    required this.name,
    this.categoryId,
    required this.stock,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.unit,
    required this.minStock,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category_id': categoryId,
      'stock': stock,
      'purchase_price': purchasePrice,
      'selling_price': sellingPrice,
      'unit': unit,
      'min_stock': minStock,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      categoryId: map['category_id'] as int?,
      stock: (map['stock'] as num?)?.toDouble() ?? 0.0,
      purchasePrice: (map['purchase_price'] as num?)?.toInt() ?? 0,
      sellingPrice: (map['selling_price'] as num?)?.toInt() ?? 0,
      unit: map['unit'] as String? ?? '',
      minStock: (map['min_stock'] as num?)?.toDouble() ?? 0.0,
    );
  }

  // Untuk update sebagian field tanpa buat objek baru
  Product copyWith({
    int? id,
    String? name,
    int? categoryId,
    double? stock,
    int? purchasePrice,
    int? sellingPrice,
    String? unit,
    double? minStock,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      stock: stock ?? this.stock,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      unit: unit ?? this.unit,
      minStock: minStock ?? this.minStock,
    );
  }
}