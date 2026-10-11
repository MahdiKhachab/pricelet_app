import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pricelet_app/database/database.dart';
import 'package:pricelet_app/entity/customer_entity.dart';
import 'package:pricelet_app/entity/product_entity.dart';
import 'package:pricelet_app/entity/sale_entity.dart';
import 'package:pricelet_app/src/app.dart';
import 'package:pricelet_app/src/core/providers.dart';
import 'package:pricelet_app/src/features/auth/auth.dart';
import 'package:pricelet_app/src/features/pos/cart.dart';
import 'package:pricelet_app/src/features/sales/sales_service.dart';
import 'package:pricelet_app/src/features/settings/app_settings.dart';
import 'package:pricelet_app/src/features/shell/app_shell.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Renders every section at desktop and phone sizes against a seeded database
/// and fails on any layout or build error.
void main() {
  sqfliteFfiInit();

  const settings = AppSettings(
    storeName: 'Test Store',
    secondaryEnabled: true,
    secondarySymbol: 'L.L',
    exchangeRate: 89500,
    taxRate: 11,
  );

  Future<(AppDatabase, ProviderContainer)> seed() async {
    final db = await AppDatabase.inMemory();
    await ensureAdminUser(db);
    final now = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < 14; i++) {
      await db.productDao.createProduct(
        Product(
          name: 'Product with a fairly long name $i',
          barcode: '10$i',
          category: i.isEven ? 'Drinks' : 'Snacks',
          price: 1.25 + i,
          cost: 0.5 + i,
          stock: i,
          createdAt: now,
          updatedAt: now,
        ),
        null,
      );
    }
    await db.customerDao.insertCustomer(Customer(name: 'Rami', phone: '70123456', createdAt: now));
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      initialSettingsProvider.overrideWithValue(settings),
    ]);
    final products = await db.productDao.findAllProducts();
    await container.read(salesServiceProvider).checkout(
          Cart(lines: [CartLine(products.last, 2), CartLine(products[5], 1)]),
          paymentMethod: PaymentMethod.cash,
          amountPaid: 100,
        );
    return (db, container);
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  for (final size in const [Size(1400, 900), Size(400, 820)]) {
    testWidgets('all sections render at ${size.width.toInt()}px', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final (db, container) = (await tester.runAsync(seed))!;
      addTearDown(() async {
        container.dispose();
        await tester.runAsync(db.close);
      });

      // Print full details (including the widget location) of layout errors.
      final original = FlutterError.onError;
      FlutterError.onError = (d) {
        debugPrint(d.toString());
        original?.call(d);
      };
      addTearDown(() => FlutterError.onError = original);

      await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const PriceletApp()));
      await settle(tester);
      expect(find.text('Admin'), findsOneWidget); // login screen

      final admin = (await tester.runAsync(db.userDao.findAllUsers))!.first;
      container.read(currentUserProvider.notifier).state = admin;
      await settle(tester);

      for (final section in AppSection.values) {
        container.read(sectionProvider.notifier).state = section;
        await settle(tester);
        final error = tester.takeException();
        if (error is FlutterError) debugPrint(error.toStringDeep());
        expect(error, isNull, reason: 'section ${section.label}');
      }

      // Ring up a sale through the UI and open the payment dialog.
      container.read(sectionProvider.notifier).state = AppSection.register;
      await settle(tester);
      await tester.tap(find.text('Product with a fairly long name 13').first);
      await settle(tester);
      expect(container.read(cartProvider).itemCount, 1);
      final products = (await tester.runAsync(db.productDao.findAllProducts))!;
      container.read(cartProvider.notifier).add(products[3]);
      await settle(tester);
      if (size.width < 900) {
        await tester.tap(find.text('2 items'));
        await settle(tester);
      }
      await tester.tap(find.textContaining('Charge'));
      await settle(tester);
      expect(find.text('Payment'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
