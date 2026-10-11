import 'package:floor/floor.dart';

/// A sellable product. Prices are stored in the store's primary currency.
@Entity(
  tableName: 'products',
  indices: [
    Index(value: ['barcode']),
    Index(value: ['name']),
  ],
)
class Product {
  @PrimaryKey(autoGenerate: true)
  final int? id;

  final String name;
  final String? barcode; // SKU / EAN, optional for items sold by name only
  final String category;
  final String description;
  final double price;
  final double cost; // purchase cost, used for profit reporting
  final int stock;
  final int lowStockThreshold;
  final bool trackStock;
  final bool active;
  final int createdAt; // epoch millis
  final int updatedAt; // epoch millis

  const Product({
    this.id,
    required this.name,
    this.barcode,
    this.category = '',
    this.description = '',
    required this.price,
    this.cost = 0,
    this.stock = 0,
    this.lowStockThreshold = 5,
    this.trackStock = true,
    this.active = true,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isLowStock => trackStock && stock <= lowStockThreshold;

  bool get isOutOfStock => trackStock && stock <= 0;

  /// Gross margin as a fraction of the price (0.25 = 25%).
  double get margin => price <= 0 ? 0 : (price - cost) / price;

  Product copyWith({
    int? id,
    String? name,
    String? barcode,
    String? category,
    String? description,
    double? price,
    double? cost,
    int? stock,
    int? lowStockThreshold,
    bool? trackStock,
    bool? active,
    int? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      barcode: barcode ?? this.barcode,
      category: category ?? this.category,
      description: description ?? this.description,
      price: price ?? this.price,
      cost: cost ?? this.cost,
      stock: stock ?? this.stock,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      trackStock: trackStock ?? this.trackStock,
      active: active ?? this.active,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
