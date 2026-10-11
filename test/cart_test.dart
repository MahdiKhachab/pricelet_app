import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pricelet_app/entity/product_entity.dart';
import 'package:pricelet_app/src/core/money.dart';
import 'package:pricelet_app/src/features/pos/cart.dart';
import 'package:pricelet_app/src/features/settings/app_settings.dart';

Product product(int id, double price, {int stock = 10, bool track = true}) => Product(
      id: id,
      name: 'P$id',
      price: price,
      stock: stock,
      trackStock: track,
      createdAt: 0,
      updatedAt: 0,
    );

void main() {
  group('Cart totals', () {
    test('sums lines, applies amount discount then tax', () {
      final cart = Cart(
        lines: [CartLine(product(1, 2.5), 3), CartLine(product(2, 10), 1)],
        discountValue: 2.5,
      );
      final t = cart.totals(taxRate: 10);
      expect(t.subtotal, 17.5);
      expect(t.discount, 2.5);
      expect(t.tax, 1.5);
      expect(t.total, 16.5);
    });

    test('percent discount is capped at 100% and amount at subtotal', () {
      final lines = [CartLine(product(1, 10), 1)];
      expect(Cart(lines: lines, discountType: DiscountType.percent, discountValue: 150).totals().total, 0);
      expect(Cart(lines: lines, discountValue: 50).totals().discount, 10);
    });

    test('rounds to currency decimals', () {
      final cart = Cart(lines: [CartLine(product(1, 0.1), 3)]);
      expect(cart.totals().subtotal, 0.3);
      expect(Cart(lines: [CartLine(product(1, 1.005), 1)]).totals(decimals: 0).total, 1);
    });
  });

  group('CartController', () {
    late ProviderContainer container;
    setUp(() => container = ProviderContainer());
    tearDown(() => container.dispose());

    test('merges repeated adds and enforces stock', () {
      final c = container.read(cartProvider.notifier);
      final p = product(1, 5, stock: 2);
      c.add(p);
      c.add(p);
      expect(container.read(cartProvider).itemCount, 2);
      expect(() => c.add(p), throwsA(isA<CartException>()));
      expect(container.read(cartProvider).itemCount, 2);
    });

    test('untracked products ignore stock; quantity 0 removes the line', () {
      final c = container.read(cartProvider.notifier);
      final p = product(1, 5, stock: 0, track: false);
      c.add(p, quantity: 50);
      expect(container.read(cartProvider).itemCount, 50);
      c.setQuantity(p, 0);
      expect(container.read(cartProvider).isEmpty, isTrue);
    });
  });

  group('Money', () {
    test('formats primary and secondary currencies', () {
      final money = Money(const AppSettings(
        currencySymbol: r'$',
        secondaryEnabled: true,
        secondarySymbol: 'L.L',
        secondaryDecimals: 0,
        exchangeRate: 89500,
      ));
      expect(money(1234.5), r'$1,234.50');
      expect(money(-3), r'-$3.00');
      expect(money.secondary(2), '179,000 L.L');
      expect(money.fromSecondary(179000), 2);
    });

    test('roundMoney avoids floating point drift', () {
      expect(roundMoney(0.1 + 0.2), 0.3);
      expect(roundMoney(2.675, 2), 2.68);
    });
  });
}
