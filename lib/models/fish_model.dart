class FishModel {
  final String id;
  final String name;
  final String description;
  final double price;
  final double quantityKg; // Changed to double for kg support
  final String ownerId;
  final String? imageUrl;

  FishModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.quantityKg,
    required this.ownerId,
    this.imageUrl,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'description': description,
    'price': price,
    'quantityKg': quantityKg,
    'ownerId': ownerId,
    'imageUrl': imageUrl,
  };

  factory FishModel.fromMap(Map<String, dynamic> map) {
    return FishModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] ?? 0.0) + 0.0,
      quantityKg: (map['quantityKg'] ?? map['quantity'] ?? 0.0) + 0.0, // Support both old and new field names
      ownerId: map['ownerId'] ?? '',
      imageUrl: map['imageUrl'],
    );
  }
}
