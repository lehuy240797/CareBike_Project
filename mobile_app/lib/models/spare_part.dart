class SparePart {
  final int id;
  final String name;
  final double price;
  final String? description;
  final String? imageUrl;

  SparePart({
    required this.id,
    required this.name,
    required this.price,
    this.description,
    this.imageUrl,
  });

  factory SparePart.fromJson(Map<String, dynamic> json) {
    return SparePart(
      id: json['id'] as int,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      description: json['description'] as String?,
      imageUrl: json['imageUrl'] as String?,
    );
  }
}
