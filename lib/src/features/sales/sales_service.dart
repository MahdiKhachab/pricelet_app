import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pricelet_app/database/database.dart';
import 'package:pricelet_app/entity/customer_entity.dart';
import 'package:pricelet_app/entity/sale_entity.dart';
import 'package:pricelet_app/entity/sale_item_entity.dart';
import 'package:pricelet_app/entity/user_entity.dart';
import 'package:pricelet_app/src/core/money.dart';
import 'package:pricelet_app/src/core/providers.dart';
import 'package:pricelet_app/src/features/auth/auth.dart';
import 'package:pricelet_app/src/features/pos/cart.dart';
import 'package:pricelet_app/src/features/settings/app_settings.dart';

/// A sale with everything needed to show or print its receipt.
class SaleDetail {
  final Sale sale;
  final List<SaleItem> items;
  final Customer? customer;
  final UserEntity? cashier;

  const SaleDetail({required this.sale, required this.items, this.customer, this.cashier});
}

/// Half-open range [start, end) used to query sales.
class DateRange {
  final DateTime start;
  final DateTime end;

  const DateRange(this.start, this.end);

  factory DateRange.day(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    return DateRange(start, DateTime(start.year, start.month, start.day + 1));
  }

  /// The [days] days ending today (inclusive).
  factory DateRange.lastDays(int days, {DateTime? now}) {
    final today = DateRange.day(now ?? DateTime.now());
    return DateRange(DateTime(today.start.year, today.start.month, today.start.day - (days - 1)), today.end);
  }

  factory DateRange.thisMonth({DateTime? now}) {
    final n = now ?? DateTime.now();
    return DateRange(DateTime(n.year, n.month), DateRange.day(n).end);
  }

  int get startMs => start.millisecondsSinceEpoch;
  int get endMs => end.millisecondsSinceEpoch;

  @override
  bool operator ==(Object other) => other is DateRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

final salesInRangeProvider = FutureProvider.family<List<Sale>, DateRange>((ref, range) {
  ref.watch(dataVersionProvider);
  return ref.watch(databaseProvider).saleDao.findSalesBetween(range.startMs, range.endMs);
});

final saleDetailProvider = FutureProvider.family<SaleDetail?, int>((ref, saleId) {
  ref.watch(dataVersionProvider);
  return ref.watch(salesServiceProvider).loadDetail(saleId);
});

final salesServiceProvider = Provider<SalesService>((ref) => SalesService(ref));

class SalesService {
  final Ref _ref;

  SalesService(this._ref);

  AppDatabase get _db => _ref.read(databaseProvider);

  void _changed() => _ref.read(dataVersionProvider.notifier).state++;

  /// Records the cart as a completed sale and returns its id.
  Future<int> checkout(Cart cart, {required String paymentMethod, required double amountPaid}) async {
    if (cart.isEmpty) throw CartException('The cart is empty');
    final settings = _ref.read(settingsProvider);
    final totals = cart.totals(taxRate: settings.taxRate, decimals: settings.currencyDecimals);
    final paid = paymentMethod == PaymentMethod.cash ? amountPaid : totals.total;
    if (paid + 0.000001 < totals.total) throw CartException('Amount paid is less than the total');

    final sale = Sale(
      createdAt: DateTime.now().millisecondsSinceEpoch,
      customerId: cart.customer?.id,
      userId: _ref.read(currentUserProvider)?.id,
      subtotal: totals.subtotal,
      discount: totals.discount,
      tax: totals.tax,
      total: totals.total,
      paymentMethod: paymentMethod,
      amountPaid: paid,
      changeDue: paid - totals.total,
      exchangeRate: settings.secondaryEnabled ? settings.exchangeRate : 1,
    );
    final items = [
      for (final line in cart.lines)
        SaleItem(
          saleId: 0, // replaced inside the transaction
          productId: line.product.id,
          name: line.product.name,
          barcode: line.product.barcode,
          quantity: line.quantity,
          unitPrice: line.product.price,
          unitCost: line.product.cost,
          lineTotal: roundMoney(line.total, settings.currencyDecimals),
        ),
    ];
    final id = await _db.saleDao.recordSale(sale, items);
    _changed();
    return id;
  }

  Future<void> refund(Sale sale) async {
    await _db.saleDao.refundSale(sale.id!, _ref.read(currentUserProvider)?.id);
    _changed();
  }

  Future<SaleDetail?> loadDetail(int saleId) async {
    final sale = await _db.saleDao.findById(saleId);
    if (sale == null) return null;
    final items = await _db.saleDao.findItems(saleId);
    final customer = sale.customerId == null ? null : await _db.customerDao.findById(sale.customerId!);
    final cashier = sale.userId == null ? null : await _db.userDao.findById(sale.userId!);
    return SaleDetail(sale: sale, items: items, customer: customer, cashier: cashier);
  }
}
