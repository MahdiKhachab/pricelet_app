import 'package:floor/floor.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

/// Floor runs every migration whose start version is >= the installed version,
/// so each older version needs an entry in the chain.
final appMigrations = <Migration>[
  Migration(1, 2, (db) async {}),
  Migration(2, 3, (db) async {}),
  Migration(3, 4, migrateLegacySchema),
];

/// Schema of database version 4. Must match the CREATE statements Floor
/// generates in database.g.dart.
const schemaV4 = <String>[
  'CREATE TABLE IF NOT EXISTS `products` (`id` INTEGER PRIMARY KEY AUTOINCREMENT, `name` TEXT NOT NULL, `barcode` TEXT, `category` TEXT NOT NULL, `description` TEXT NOT NULL, `price` REAL NOT NULL, `cost` REAL NOT NULL, `stock` INTEGER NOT NULL, `lowStockThreshold` INTEGER NOT NULL, `trackStock` INTEGER NOT NULL, `active` INTEGER NOT NULL, `createdAt` INTEGER NOT NULL, `updatedAt` INTEGER NOT NULL)',
  'CREATE TABLE IF NOT EXISTS `customers` (`id` INTEGER PRIMARY KEY AUTOINCREMENT, `name` TEXT NOT NULL, `phone` TEXT NOT NULL, `email` TEXT NOT NULL, `notes` TEXT NOT NULL, `createdAt` INTEGER NOT NULL)',
  'CREATE TABLE IF NOT EXISTS `sales` (`id` INTEGER PRIMARY KEY AUTOINCREMENT, `createdAt` INTEGER NOT NULL, `customerId` INTEGER, `userId` INTEGER, `subtotal` REAL NOT NULL, `discount` REAL NOT NULL, `tax` REAL NOT NULL, `total` REAL NOT NULL, `paymentMethod` TEXT NOT NULL, `amountPaid` REAL NOT NULL, `changeDue` REAL NOT NULL, `exchangeRate` REAL NOT NULL, `status` TEXT NOT NULL, `note` TEXT NOT NULL)',
  'CREATE TABLE IF NOT EXISTS `sale_items` (`id` INTEGER PRIMARY KEY AUTOINCREMENT, `saleId` INTEGER NOT NULL, `productId` INTEGER, `name` TEXT NOT NULL, `barcode` TEXT, `quantity` INTEGER NOT NULL, `unitPrice` REAL NOT NULL, `unitCost` REAL NOT NULL, `lineTotal` REAL NOT NULL, FOREIGN KEY (`saleId`) REFERENCES `sales` (`id`) ON UPDATE NO ACTION ON DELETE CASCADE)',
  'CREATE TABLE IF NOT EXISTS `users` (`id` INTEGER PRIMARY KEY AUTOINCREMENT, `name` TEXT NOT NULL, `role` TEXT NOT NULL, `pinHash` TEXT NOT NULL, `pinSalt` TEXT NOT NULL, `active` INTEGER NOT NULL, `createdAt` INTEGER NOT NULL)',
  'CREATE TABLE IF NOT EXISTS `settings` (`key` TEXT NOT NULL, `value` TEXT NOT NULL, PRIMARY KEY (`key`))',
  'CREATE TABLE IF NOT EXISTS `stock_movements` (`id` INTEGER PRIMARY KEY AUTOINCREMENT, `productId` INTEGER NOT NULL, `change` INTEGER NOT NULL, `reason` TEXT NOT NULL, `note` TEXT NOT NULL, `userId` INTEGER, `saleId` INTEGER, `createdAt` INTEGER NOT NULL)',
  'CREATE INDEX IF NOT EXISTS `index_products_barcode` ON `products` (`barcode`)',
  'CREATE INDEX IF NOT EXISTS `index_products_name` ON `products` (`name`)',
  'CREATE INDEX IF NOT EXISTS `index_customers_name` ON `customers` (`name`)',
  'CREATE INDEX IF NOT EXISTS `index_customers_phone` ON `customers` (`phone`)',
  'CREATE INDEX IF NOT EXISTS `index_sales_createdAt` ON `sales` (`createdAt`)',
  'CREATE INDEX IF NOT EXISTS `index_sales_customerId` ON `sales` (`customerId`)',
  'CREATE INDEX IF NOT EXISTS `index_sale_items_saleId` ON `sale_items` (`saleId`)',
  'CREATE INDEX IF NOT EXISTS `index_sale_items_productId` ON `sale_items` (`productId`)',
  'CREATE INDEX IF NOT EXISTS `index_stock_movements_productId` ON `stock_movements` (`productId`)',
];

/// Upgrades the original price-list schema (`items` + `rate`) to the POS
/// schema. Old tables are kept, renamed with a `legacy_` prefix, so no data is
/// ever lost.
Future<void> migrateLegacySchema(sqflite.Database db) async {
  final tables = (await db.rawQuery("SELECT name FROM sqlite_master WHERE type = 'table'"))
      .map((row) => row['name'] as String)
      .toSet();

  // Tables from unreleased development schemas with incompatible columns.
  for (final name in ['products', 'customers', 'sales', 'sale_items', 'users']) {
    if (tables.contains(name)) {
      await db.execute('ALTER TABLE `$name` RENAME TO `legacy_$name`');
    }
  }

  for (final statement in schemaV4) {
    await db.execute(statement);
  }

  final now = DateTime.now().millisecondsSinceEpoch;

  if (tables.contains('items')) {
    await db.rawInsert(
      'INSERT INTO products (name, barcode, category, description, price, cost, stock, '
      'lowStockThreshold, trackStock, active, createdAt, updatedAt) '
      "SELECT name, NULLIF(TRIM(barcode), ''), '', '', price, 0, 0, 0, 0, 1, ?, ? FROM items",
      [now, now],
    );
    await db.execute('ALTER TABLE items RENAME TO legacy_items');
  }

  if (tables.contains('products')) {
    // Dev schema: (id, sku, name, description, price, quantity, cost).
    try {
      await db.rawInsert(
        'INSERT INTO products (name, barcode, category, description, price, cost, stock, '
        'lowStockThreshold, trackStock, active, createdAt, updatedAt) '
        "SELECT name, NULLIF(TRIM(sku), ''), '', description, price, cost, quantity, 5, 1, 1, ?, ? "
        'FROM legacy_products',
        [now, now],
      );
    } on sqflite.DatabaseException {
      // Unknown shape; leave the data in legacy_products untouched.
    }
  }

  if (tables.contains('rate')) {
    final rows = await db.rawQuery('SELECT rate FROM rate ORDER BY id LIMIT 1');
    if (rows.isNotEmpty) {
      final rate = (rows.first['rate'] as num).toDouble();
      // The old app multiplied item prices by this rate to show Lebanese pounds.
      const insert = 'INSERT OR REPLACE INTO settings (`key`, `value`) VALUES (?, ?)';
      await db.rawInsert(insert, ['currencySymbol', r'$']);
      await db.rawInsert(insert, ['secondaryEnabled', 'true']);
      await db.rawInsert(insert, ['secondarySymbol', 'L.L']);
      await db.rawInsert(insert, ['secondaryDecimals', '0']);
      await db.rawInsert(insert, ['exchangeRate', rate.toString()]);
    }
    await db.execute('ALTER TABLE rate RENAME TO legacy_rate');
  }
}
