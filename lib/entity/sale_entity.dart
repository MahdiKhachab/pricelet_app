import 'package:floor/floor.dart';

class SaleStatus {
  static const completed = 'completed';
  static const refunded = 'refunded';
}

class PaymentMethod {
  static const cash = 'cash';
  static const card = 'card';
  static const other = 'other';

  static const all = [cash, card, other];

  static String label(String method) {
    switch (method) {
      case cash:
        return 'Cash';
      case card:
        return 'Card';
      default:
        return 'Other';
    }
  }
}

/// A completed checkout. All amounts are in the primary currency.
@Entity(tableName: 'sales', indices: [
  Index(value: ['createdAt']),
  Index(value: ['customerId']),
])
class Sale {
  @PrimaryKey(autoGenerate: true)
  final int? id;

  final int createdAt; // epoch millis
  final int? customerId;
  final int? userId; // cashier
  final double subtotal;
  final double discount;
  final double tax;
  final double total;
  final String paymentMethod; // see [PaymentMethod]
  final double amountPaid;
  final double changeDue;
  final double exchangeRate; // secondary currency rate at time of sale
  final String status; // see [SaleStatus]
  final String note;

  const Sale({
    this.id,
    required this.createdAt,
    this.customerId,
    this.userId,
    required this.subtotal,
    this.discount = 0,
    this.tax = 0,
    required this.total,
    required this.paymentMethod,
    required this.amountPaid,
    this.changeDue = 0,
    this.exchangeRate = 1,
    this.status = SaleStatus.completed,
    this.note = '',
  });

  bool get isRefunded => status == SaleStatus.refunded;

  String get receiptNo => '#${(id ?? 0).toString().padLeft(6, '0')}';

  DateTime get date => DateTime.fromMillisecondsSinceEpoch(createdAt);
}
