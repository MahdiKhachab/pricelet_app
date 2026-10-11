import 'package:floor/floor.dart';

class StockReason {
  static const initial = 'initial';
  static const sale = 'sale';
  static const refund = 'refund';
  static const restock = 'restock';
  static const adjustment = 'adjustment';

  static String label(String reason) {
    switch (reason) {
      case initial:
        return 'Opening stock';
      case sale:
        return 'Sale';
      case refund:
        return 'Refund';
      case restock:
        return 'Received stock';
      default:
        return 'Adjustment';
    }
  }
}

/// Audit log of every stock change.
@Entity(tableName: 'stock_movements', indices: [
  Index(value: ['productId']),
])
class StockMovement {
  @PrimaryKey(autoGenerate: true)
  final int? id;

  final int productId;
  final int change; // positive = in, negative = out
  final String reason; // see [StockReason]
  final String note;
  final int? userId;
  final int? saleId;
  final int createdAt; // epoch millis

  const StockMovement({
    this.id,
    required this.productId,
    required this.change,
    required this.reason,
    this.note = '',
    this.userId,
    this.saleId,
    required this.createdAt,
  });
}
