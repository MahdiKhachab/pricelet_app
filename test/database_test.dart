import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pricelet_app/database/database.dart';
import 'package:pricelet_app/entity/product_entity.dart';
import 'package:pricelet_app/entity/sale_entity.dart';
import 'package:pricelet_app/entity/stock_movement_entity.dart';
import 'package:pricelet_app/src/core/providers.dart';
import 'package:pricelet_app/src/features/auth/auth.dart';
import 'package:pricelet_app/src/features/pos/cart.dart';
import 'package:pricelet_app/src/features/products/products_service.dart';
import 'package:pricelet_app/src/features/reports/reports_service.dart';
import 'package:pricelet_app/src/features/sales/sales_service.dart';
import 'package:pricelet_app/src/features/settings/app_settings.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  group('sales flow', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() async {
      db = await AppDatabase.inMemory();
      await ensureAdminUser(db);
      container = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
        initialSettingsProvider.overrideWithValue(const AppSettings(taxRate: 10)),
      ]);
      container.read(currentUserProvider.notifier).state = (await db.userDao.findAllUsers()).first;
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    Future<Product> addProduct(String name, double price, {String? barcode, int stock = 10}) {
      final now = DateTime.now().millisecondsSinceEpoch;
      return container.read(productsServiceProvider).save(Product(
            name: name,
            barcode: barcode,
            price: price,
            cost: price / 2,
            stock: stock,
            createdAt: now,
            updatedAt: now,
          ));
    }

    test('default admin can sign in with the default PIN', () async {
      final admin = (await db.userDao.findAllUsers()).single;
      expect(admin.isAdmin, isTrue);
      expect(verifyPin(admin, defaultAdminPin), isTrue);
      expect(verifyPin(admin, '0000'), isFalse);
    });

    test('barcodes must be unique', () async {
      await addProduct('Cola', 1, barcode: '111');
      expect(() => addProduct('Other', 2, barcode: '111'), throwsA(isA<ProductValidationException>()));
    });

    test('checkout records sale, lines and stock; refund restores it', () async {
      final cola = await addProduct('Cola', 1.5, barcode: '111', stock: 10);
      final chips = await addProduct('Chips', 2, stock: 5);

      final cart = Cart(lines: [CartLine(cola, 4), CartLine(chips, 1)]);
      final saleId = await container
          .read(salesServiceProvider)
          .checkout(cart, paymentMethod: PaymentMethod.cash, amountPaid: 10);

      final detail = (await container.read(salesServiceProvider).loadDetail(saleId))!;
      expect(detail.items, hasLength(2));
      expect(detail.sale.subtotal, 8);
      expect(detail.sale.tax, 0.8);
      expect(detail.sale.total, 8.8);
      expect(detail.sale.changeDue, closeTo(1.2, 1e-9));
      expect(detail.cashier?.name, 'Admin');
      expect((await db.productDao.findById(cola.id!))!.stock, 6);
      expect((await db.productDao.findById(chips.id!))!.stock, 4);

      final movements = await db.productDao.findMovements(cola.id!);
      expect(movements.map((m) => m.reason), containsAll([StockReason.initial, StockReason.sale]));

      final report = await container.read(salesReportProvider(DateRange.day(DateTime.now())).future);
      expect(report.salesCount, 1);
      expect(report.netSales, 8);
      expect(report.cost, 4);
      expect(report.grossProfit, 4);

      await container.read(salesServiceProvider).refund(detail.sale);
      expect((await db.saleDao.findById(saleId))!.isRefunded, isTrue);
      expect((await db.productDao.findById(cola.id!))!.stock, 10);
      final after = await container.read(salesReportProvider(DateRange.day(DateTime.now())).future);
      expect(after.salesCount, 0);
      expect(after.refundCount, 1);
    });

    test('cash payments below the total are rejected', () async {
      final cola = await addProduct('Cola', 5);
      final cart = Cart(lines: [CartLine(cola, 1)]);
      expect(
        () => container.read(salesServiceProvider).checkout(cart, paymentMethod: PaymentMethod.cash, amountPaid: 1),
        throwsA(isA<CartException>()),
      );
    });
  });

  test('upgrades a legacy v2 database (items + rate)', () async {
    final dir = await Directory.systemTemp.createTemp('pricelet_test');
    final path = p.join(dir.path, 'legacy.db');
    final legacy = await databaseFactoryFfi.openDatabase(path, options: OpenDatabaseOptions(
      version: 2,
      onCreate: (db, _) async {
        await db.execute('CREATE TABLE IF NOT EXISTS `items` (`id` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, `name` TEXT NOT NULL, `barcode` TEXT NOT NULL, `price` REAL NOT NULL, `scheduleTime` TEXT NOT NULL)');
        await db.execute('CREATE TABLE IF NOT EXISTS `rate` (`id` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, `rate` REAL NOT NULL)');
        await db.insert('items', {'name': 'Milk', 'barcode': '123', 'price': 1.25, 'scheduleTime': 'May 01, 2023'});
        await db.insert('items', {'name': 'Bread', 'barcode': ' ', 'price': 0.5, 'scheduleTime': 'May 01, 2023'});
        await db.insert('rate', {'rate': 89500.0});
      },
    ));
    await legacy.close();

    final db = await AppDatabase.open(path: path);
    final products = await db.productDao.findAllProducts();
    expect(products.map((p) => p.name), ['Bread', 'Milk']);
    expect(products.firstWhere((p) => p.name == 'Milk').barcode, '123');
    expect(products.firstWhere((p) => p.name == 'Bread').barcode, isNull);
    expect(products.every((p) => !p.trackStock), isTrue);

    final settings = await AppSettings.load(db);
    expect(settings.secondaryEnabled, isTrue);
    expect(settings.exchangeRate, 89500);
    expect(settings.secondarySymbol, 'L.L');

    // The new schema is fully usable after the upgrade.
    await ensureAdminUser(db);
    expect(await db.userDao.findAllUsers(), hasLength(1));
    await db.close();
    await dir.delete(recursive: true);
  });
}
