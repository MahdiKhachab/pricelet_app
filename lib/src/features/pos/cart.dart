import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pricelet_app/entity/customer_entity.dart';
import 'package:pricelet_app/entity/product_entity.dart';
import 'package:pricelet_app/src/core/money.dart';
import 'package:pricelet_app/src/features/settings/app_settings.dart';

class CartLine {
  final Product product;
  final int quantity;

  const CartLine(this.product, this.quantity);

  double get total => product.price * quantity;
}

enum DiscountType { amount, percent }

class CartTotals {
  final double subtotal;
  final double discount;
  final double tax;
  final double total;

  const CartTotals({required this.subtotal, required this.discount, required this.tax, required this.total});
}

/// The sale being rung up. Immutable; [CartController] replaces it on change.
class Cart {
  final List<CartLine> lines;
  final DiscountType discountType;
  final double discountValue;
  final Customer? customer;

  const Cart({
    this.lines = const [],
    this.discountType = DiscountType.amount,
    this.discountValue = 0,
    this.customer,
  });

  bool get isEmpty => lines.isEmpty;

  int get itemCount => lines.fold(0, (sum, line) => sum + line.quantity);

  int quantityOf(int productId) =>
      lines.where((l) => l.product.id == productId).fold(0, (sum, l) => sum + l.quantity);

  /// Subtotal, discount and tax rounded to [decimals]. Tax is added on top of
  /// the discounted subtotal at [taxRate] percent.
  CartTotals totals({double taxRate = 0, int decimals = 2}) {
    final subtotal = roundMoney(lines.fold(0.0, (sum, l) => sum + l.total), decimals);
    final rawDiscount = discountType == DiscountType.percent
        ? subtotal * discountValue.clamp(0, 100) / 100
        : discountValue;
    final discount = roundMoney(rawDiscount.clamp(0, subtotal).toDouble(), decimals);
    final tax = roundMoney((subtotal - discount) * taxRate / 100, decimals);
    final total = roundMoney(subtotal - discount + tax, decimals);
    return CartTotals(subtotal: subtotal, discount: discount, tax: tax, total: total);
  }

  Cart copyWith({
    List<CartLine>? lines,
    DiscountType? discountType,
    double? discountValue,
    Customer? customer,
    bool clearCustomer = false,
  }) {
    return Cart(
      lines: lines ?? this.lines,
      discountType: discountType ?? this.discountType,
      discountValue: discountValue ?? this.discountValue,
      customer: clearCustomer ? null : (customer ?? this.customer),
    );
  }
}

class CartException implements Exception {
  final String message;
  CartException(this.message);

  @override
  String toString() => message;
}

final cartProvider = NotifierProvider<CartController, Cart>(CartController.new);

final cartTotalsProvider = Provider<CartTotals>((ref) {
  final settings = ref.watch(settingsProvider);
  return ref.watch(cartProvider).totals(taxRate: settings.taxRate, decimals: settings.currencyDecimals);
});

class CartController extends Notifier<Cart> {
  @override
  Cart build() => const Cart();

  /// Adds [quantity] of [product]. Throws [CartException] when stock is short.
  void add(Product product, {int quantity = 1}) {
    final current = state.quantityOf(product.id!);
    setQuantity(product, current + quantity);
  }

  void setQuantity(Product product, int quantity) {
    if (quantity <= 0) {
      remove(product);
      return;
    }
    if (!product.active) throw CartException('${product.name} is not available for sale');
    if (product.trackStock && quantity > product.stock) {
      throw CartException(product.stock <= 0
          ? '${product.name} is out of stock'
          : 'Only ${product.stock} ${product.name} in stock');
    }
    final lines = [...state.lines];
    final index = lines.indexWhere((l) => l.product.id == product.id);
    if (index >= 0) {
      lines[index] = CartLine(product, quantity);
    } else {
      lines.add(CartLine(product, quantity));
    }
    state = state.copyWith(lines: lines);
  }

  void remove(Product product) {
    state = state.copyWith(lines: state.lines.where((l) => l.product.id != product.id).toList());
  }

  void setDiscount(DiscountType type, double value) {
    state = state.copyWith(discountType: type, discountValue: value < 0 ? 0 : value);
  }

  void setCustomer(Customer? customer) {
    state = state.copyWith(customer: customer, clearCustomer: customer == null);
  }

  void clear() => state = const Cart();
}
