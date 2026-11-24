class Category {
  final int? id;
  final String name;
  final String type; // MATERIAL | RAW | PRODUCT

  const Category({
    this.id,
    required this.name,
    required this.type,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'type': type,
      };

  factory Category.fromMap(Map<String, dynamic> map) => Category(
        id: map['id'] as int?,
        name: (map['name'] as String?) ?? '',
        type: (map['type'] as String?) ?? 'MATERIAL',
      );
}
