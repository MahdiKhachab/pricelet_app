// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// **************************************************************************
// FloorGenerator
// **************************************************************************

abstract class $AppDatabaseBuilderContract {
  /// Adds migrations to the builder.
  $AppDatabaseBuilderContract addMigrations(List<Migration> migrations);

  /// Adds a database [Callback] to the builder.
  $AppDatabaseBuilderContract addCallback(Callback callback);

  /// Creates the database and initializes it.
  Future<AppDatabase> build();
}

// ignore: avoid_classes_with_only_static_members
class $FloorAppDatabase {
  /// Creates a database builder for a persistent database.
  /// Once a database is built, you should keep a reference to it and re-use it.
  static $AppDatabaseBuilderContract databaseBuilder(String name) =>
      _$AppDatabaseBuilder(name);

  /// Creates a database builder for an in memory database.
  /// Information stored in an in memory database disappears when the process is killed.
  /// Once a database is built, you should keep a reference to it and re-use it.
  static $AppDatabaseBuilderContract inMemoryDatabaseBuilder() =>
      _$AppDatabaseBuilder(null);
}

class _$AppDatabaseBuilder implements $AppDatabaseBuilderContract {
  _$AppDatabaseBuilder(this.name);

  final String? name;

  final List<Migration> _migrations = [];

  Callback? _callback;

  @override
  $AppDatabaseBuilderContract addMigrations(List<Migration> migrations) {
    _migrations.addAll(migrations);
    return this;
  }

  @override
  $AppDatabaseBuilderContract addCallback(Callback callback) {
    _callback = callback;
    return this;
  }

  @override
  Future<AppDatabase> build() async {
    final path = name != null
        ? await sqfliteDatabaseFactory.getDatabasePath(name!)
        : ':memory:';
    final database = _$AppDatabase();
    database.database = await database.open(
      path,
      _migrations,
      _callback,
    );
    return database;
  }
}

class _$AppDatabase extends AppDatabase {
  _$AppDatabase([StreamController<String>? listener]) {
    changeListener = listener ?? StreamController<String>.broadcast();
  }

  ProductDao? _productDaoInstance;

  CustomerDao? _customerDaoInstance;

  SaleDao? _saleDaoInstance;

  UserDao? _userDaoInstance;

  SettingDao? _settingDaoInstance;

  Future<sqflite.Database> open(
    String path,
    List<Migration> migrations, [
    Callback? callback,
  ]) async {
    final databaseOptions = sqflite.OpenDatabaseOptions(
      version: 4,
      onConfigure: (database) async {
        await database.execute('PRAGMA foreign_keys = ON');
        await callback?.onConfigure?.call(database);
      },
      onOpen: (database) async {
        await callback?.onOpen?.call(database);
      },
      onUpgrade: (database, startVersion, endVersion) async {
        await MigrationAdapter.runMigrations(
            database, startVersion, endVersion, migrations);

        await callback?.onUpgrade?.call(database, startVersion, endVersion);
      },
      onCreate: (database, version) async {
        await database.execute(
            'CREATE TABLE IF NOT EXISTS `products` (`id` INTEGER PRIMARY KEY AUTOINCREMENT, `name` TEXT NOT NULL, `barcode` TEXT, `category` TEXT NOT NULL, `description` TEXT NOT NULL, `price` REAL NOT NULL, `cost` REAL NOT NULL, `stock` INTEGER NOT NULL, `lowStockThreshold` INTEGER NOT NULL, `trackStock` INTEGER NOT NULL, `active` INTEGER NOT NULL, `createdAt` INTEGER NOT NULL, `updatedAt` INTEGER NOT NULL)');
        await database.execute(
            'CREATE TABLE IF NOT EXISTS `customers` (`id` INTEGER PRIMARY KEY AUTOINCREMENT, `name` TEXT NOT NULL, `phone` TEXT NOT NULL, `email` TEXT NOT NULL, `notes` TEXT NOT NULL, `createdAt` INTEGER NOT NULL)');
        await database.execute(
            'CREATE TABLE IF NOT EXISTS `sales` (`id` INTEGER PRIMARY KEY AUTOINCREMENT, `createdAt` INTEGER NOT NULL, `customerId` INTEGER, `userId` INTEGER, `subtotal` REAL NOT NULL, `discount` REAL NOT NULL, `tax` REAL NOT NULL, `total` REAL NOT NULL, `paymentMethod` TEXT NOT NULL, `amountPaid` REAL NOT NULL, `changeDue` REAL NOT NULL, `exchangeRate` REAL NOT NULL, `status` TEXT NOT NULL, `note` TEXT NOT NULL)');
        await database.execute(
            'CREATE TABLE IF NOT EXISTS `sale_items` (`id` INTEGER PRIMARY KEY AUTOINCREMENT, `saleId` INTEGER NOT NULL, `productId` INTEGER, `name` TEXT NOT NULL, `barcode` TEXT, `quantity` INTEGER NOT NULL, `unitPrice` REAL NOT NULL, `unitCost` REAL NOT NULL, `lineTotal` REAL NOT NULL, FOREIGN KEY (`saleId`) REFERENCES `sales` (`id`) ON UPDATE NO ACTION ON DELETE CASCADE)');
        await database.execute(
            'CREATE TABLE IF NOT EXISTS `users` (`id` INTEGER PRIMARY KEY AUTOINCREMENT, `name` TEXT NOT NULL, `role` TEXT NOT NULL, `pinHash` TEXT NOT NULL, `pinSalt` TEXT NOT NULL, `active` INTEGER NOT NULL, `createdAt` INTEGER NOT NULL)');
        await database.execute(
            'CREATE TABLE IF NOT EXISTS `settings` (`key` TEXT NOT NULL, `value` TEXT NOT NULL, PRIMARY KEY (`key`))');
        await database.execute(
            'CREATE TABLE IF NOT EXISTS `stock_movements` (`id` INTEGER PRIMARY KEY AUTOINCREMENT, `productId` INTEGER NOT NULL, `change` INTEGER NOT NULL, `reason` TEXT NOT NULL, `note` TEXT NOT NULL, `userId` INTEGER, `saleId` INTEGER, `createdAt` INTEGER NOT NULL)');
        await database.execute(
            'CREATE INDEX `index_products_barcode` ON `products` (`barcode`)');
        await database.execute(
            'CREATE INDEX `index_products_name` ON `products` (`name`)');
        await database.execute(
            'CREATE INDEX `index_customers_name` ON `customers` (`name`)');
        await database.execute(
            'CREATE INDEX `index_customers_phone` ON `customers` (`phone`)');
        await database.execute(
            'CREATE INDEX `index_sales_createdAt` ON `sales` (`createdAt`)');
        await database.execute(
            'CREATE INDEX `index_sales_customerId` ON `sales` (`customerId`)');
        await database.execute(
            'CREATE INDEX `index_sale_items_saleId` ON `sale_items` (`saleId`)');
        await database.execute(
            'CREATE INDEX `index_sale_items_productId` ON `sale_items` (`productId`)');
        await database.execute(
            'CREATE INDEX `index_stock_movements_productId` ON `stock_movements` (`productId`)');

        await callback?.onCreate?.call(database, version);
      },
    );
    return sqfliteDatabaseFactory.openDatabase(path, options: databaseOptions);
  }

  @override
  ProductDao get productDao {
    return _productDaoInstance ??= _$ProductDao(database, changeListener);
  }

  @override
  CustomerDao get customerDao {
    return _customerDaoInstance ??= _$CustomerDao(database, changeListener);
  }

  @override
  SaleDao get saleDao {
    return _saleDaoInstance ??= _$SaleDao(database, changeListener);
  }

  @override
  UserDao get userDao {
    return _userDaoInstance ??= _$UserDao(database, changeListener);
  }

  @override
  SettingDao get settingDao {
    return _settingDaoInstance ??= _$SettingDao(database, changeListener);
  }
}

class _$ProductDao extends ProductDao {
  _$ProductDao(
    this.database,
    this.changeListener,
  )   : _queryAdapter = QueryAdapter(database),
        _productInsertionAdapter = InsertionAdapter(
            database,
            'products',
            (Product item) => <String, Object?>{
                  'id': item.id,
                  'name': item.name,
                  'barcode': item.barcode,
                  'category': item.category,
                  'description': item.description,
                  'price': item.price,
                  'cost': item.cost,
                  'stock': item.stock,
                  'lowStockThreshold': item.lowStockThreshold,
                  'trackStock': item.trackStock ? 1 : 0,
                  'active': item.active ? 1 : 0,
                  'createdAt': item.createdAt,
                  'updatedAt': item.updatedAt
                }),
        _stockMovementInsertionAdapter = InsertionAdapter(
            database,
            'stock_movements',
            (StockMovement item) => <String, Object?>{
                  'id': item.id,
                  'productId': item.productId,
                  'change': item.change,
                  'reason': item.reason,
                  'note': item.note,
                  'userId': item.userId,
                  'saleId': item.saleId,
                  'createdAt': item.createdAt
                }),
        _productUpdateAdapter = UpdateAdapter(
            database,
            'products',
            ['id'],
            (Product item) => <String, Object?>{
                  'id': item.id,
                  'name': item.name,
                  'barcode': item.barcode,
                  'category': item.category,
                  'description': item.description,
                  'price': item.price,
                  'cost': item.cost,
                  'stock': item.stock,
                  'lowStockThreshold': item.lowStockThreshold,
                  'trackStock': item.trackStock ? 1 : 0,
                  'active': item.active ? 1 : 0,
                  'createdAt': item.createdAt,
                  'updatedAt': item.updatedAt
                });

  final sqflite.DatabaseExecutor database;

  final StreamController<String> changeListener;

  final QueryAdapter _queryAdapter;

  final InsertionAdapter<Product> _productInsertionAdapter;

  final InsertionAdapter<StockMovement> _stockMovementInsertionAdapter;

  final UpdateAdapter<Product> _productUpdateAdapter;

  @override
  Future<List<Product>> findAllProducts() async {
    return _queryAdapter.queryList(
        'SELECT * FROM products ORDER BY name COLLATE NOCASE',
        mapper: (Map<String, Object?> row) => Product(
            id: row['id'] as int?,
            name: row['name'] as String,
            barcode: row['barcode'] as String?,
            category: row['category'] as String,
            description: row['description'] as String,
            price: row['price'] as double,
            cost: row['cost'] as double,
            stock: row['stock'] as int,
            lowStockThreshold: row['lowStockThreshold'] as int,
            trackStock: (row['trackStock'] as int) != 0,
            active: (row['active'] as int) != 0,
            createdAt: row['createdAt'] as int,
            updatedAt: row['updatedAt'] as int));
  }

  @override
  Future<Product?> findById(int id) async {
    return _queryAdapter.query('SELECT * FROM products WHERE id = ?1',
        mapper: (Map<String, Object?> row) => Product(
            id: row['id'] as int?,
            name: row['name'] as String,
            barcode: row['barcode'] as String?,
            category: row['category'] as String,
            description: row['description'] as String,
            price: row['price'] as double,
            cost: row['cost'] as double,
            stock: row['stock'] as int,
            lowStockThreshold: row['lowStockThreshold'] as int,
            trackStock: (row['trackStock'] as int) != 0,
            active: (row['active'] as int) != 0,
            createdAt: row['createdAt'] as int,
            updatedAt: row['updatedAt'] as int),
        arguments: [id]);
  }

  @override
  Future<Product?> findByBarcode(String barcode) async {
    return _queryAdapter.query(
        'SELECT * FROM products WHERE barcode = ?1 LIMIT 1',
        mapper: (Map<String, Object?> row) => Product(
            id: row['id'] as int?,
            name: row['name'] as String,
            barcode: row['barcode'] as String?,
            category: row['category'] as String,
            description: row['description'] as String,
            price: row['price'] as double,
            cost: row['cost'] as double,
            stock: row['stock'] as int,
            lowStockThreshold: row['lowStockThreshold'] as int,
            trackStock: (row['trackStock'] as int) != 0,
            active: (row['active'] as int) != 0,
            createdAt: row['createdAt'] as int,
            updatedAt: row['updatedAt'] as int),
        arguments: [barcode]);
  }

  @override
  Future<void> deleteById(int id) async {
    await _queryAdapter
        .queryNoReturn('DELETE FROM products WHERE id = ?1', arguments: [id]);
  }

  @override
  Future<void> changeStock(
    int id,
    int delta,
    int now,
  ) async {
    await _queryAdapter.queryNoReturn(
        'UPDATE products SET stock = stock + ?2, updatedAt = ?3 WHERE id = ?1',
        arguments: [id, delta, now]);
  }

  @override
  Future<List<StockMovement>> findMovements(int productId) async {
    return _queryAdapter.queryList(
        'SELECT * FROM stock_movements WHERE productId = ?1 ORDER BY createdAt DESC LIMIT 200',
        mapper: (Map<String, Object?> row) => StockMovement(id: row['id'] as int?, productId: row['productId'] as int, change: row['change'] as int, reason: row['reason'] as String, note: row['note'] as String, userId: row['userId'] as int?, saleId: row['saleId'] as int?, createdAt: row['createdAt'] as int),
        arguments: [productId]);
  }

  @override
  Future<void> deleteMovements(int productId) async {
    await _queryAdapter.queryNoReturn(
        'DELETE FROM stock_movements WHERE productId = ?1',
        arguments: [productId]);
  }

  @override
  Future<int> insertProduct(Product product) {
    return _productInsertionAdapter.insertAndReturnId(
        product, OnConflictStrategy.abort);
  }

  @override
  Future<void> insertMovement(StockMovement movement) async {
    await _stockMovementInsertionAdapter.insert(
        movement, OnConflictStrategy.abort);
  }

  @override
  Future<void> updateProduct(Product product) async {
    await _productUpdateAdapter.update(product, OnConflictStrategy.abort);
  }

  @override
  Future<int> createProduct(
    Product product,
    int? userId,
  ) async {
    if (database is sqflite.Transaction) {
      return super.createProduct(product, userId);
    } else {
      return (database as sqflite.Database)
          .transaction<int>((transaction) async {
        final transactionDatabase = _$AppDatabase(changeListener)
          ..database = transaction;
        return transactionDatabase.productDao.createProduct(product, userId);
      });
    }
  }

  @override
  Future<void> adjustStock(
    int productId,
    int delta,
    String reason,
    String note,
    int? userId,
  ) async {
    if (database is sqflite.Transaction) {
      await super.adjustStock(productId, delta, reason, note, userId);
    } else {
      await (database as sqflite.Database)
          .transaction<void>((transaction) async {
        final transactionDatabase = _$AppDatabase(changeListener)
          ..database = transaction;
        await transactionDatabase.productDao
            .adjustStock(productId, delta, reason, note, userId);
      });
    }
  }

  @override
  Future<void> deleteProduct(int id) async {
    if (database is sqflite.Transaction) {
      await super.deleteProduct(id);
    } else {
      await (database as sqflite.Database)
          .transaction<void>((transaction) async {
        final transactionDatabase = _$AppDatabase(changeListener)
          ..database = transaction;
        await transactionDatabase.productDao.deleteProduct(id);
      });
    }
  }
}

class _$CustomerDao extends CustomerDao {
  _$CustomerDao(
    this.database,
    this.changeListener,
  )   : _queryAdapter = QueryAdapter(database),
        _customerInsertionAdapter = InsertionAdapter(
            database,
            'customers',
            (Customer item) => <String, Object?>{
                  'id': item.id,
                  'name': item.name,
                  'phone': item.phone,
                  'email': item.email,
                  'notes': item.notes,
                  'createdAt': item.createdAt
                }),
        _customerUpdateAdapter = UpdateAdapter(
            database,
            'customers',
            ['id'],
            (Customer item) => <String, Object?>{
                  'id': item.id,
                  'name': item.name,
                  'phone': item.phone,
                  'email': item.email,
                  'notes': item.notes,
                  'createdAt': item.createdAt
                });

  final sqflite.DatabaseExecutor database;

  final StreamController<String> changeListener;

  final QueryAdapter _queryAdapter;

  final InsertionAdapter<Customer> _customerInsertionAdapter;

  final UpdateAdapter<Customer> _customerUpdateAdapter;

  @override
  Future<List<Customer>> findAllCustomers() async {
    return _queryAdapter.queryList(
        'SELECT * FROM customers ORDER BY name COLLATE NOCASE',
        mapper: (Map<String, Object?> row) => Customer(
            id: row['id'] as int?,
            name: row['name'] as String,
            phone: row['phone'] as String,
            email: row['email'] as String,
            notes: row['notes'] as String,
            createdAt: row['createdAt'] as int));
  }

  @override
  Future<Customer?> findById(int id) async {
    return _queryAdapter.query('SELECT * FROM customers WHERE id = ?1',
        mapper: (Map<String, Object?> row) => Customer(
            id: row['id'] as int?,
            name: row['name'] as String,
            phone: row['phone'] as String,
            email: row['email'] as String,
            notes: row['notes'] as String,
            createdAt: row['createdAt'] as int),
        arguments: [id]);
  }

  @override
  Future<void> detachSales(int id) async {
    await _queryAdapter.queryNoReturn(
        'UPDATE sales SET customerId = NULL WHERE customerId = ?1',
        arguments: [id]);
  }

  @override
  Future<void> deleteById(int id) async {
    await _queryAdapter
        .queryNoReturn('DELETE FROM customers WHERE id = ?1', arguments: [id]);
  }

  @override
  Future<int> insertCustomer(Customer customer) {
    return _customerInsertionAdapter.insertAndReturnId(
        customer, OnConflictStrategy.abort);
  }

  @override
  Future<void> updateCustomer(Customer customer) async {
    await _customerUpdateAdapter.update(customer, OnConflictStrategy.abort);
  }

  @override
  Future<void> deleteCustomer(int id) async {
    if (database is sqflite.Transaction) {
      await super.deleteCustomer(id);
    } else {
      await (database as sqflite.Database)
          .transaction<void>((transaction) async {
        final transactionDatabase = _$AppDatabase(changeListener)
          ..database = transaction;
        await transactionDatabase.customerDao.deleteCustomer(id);
      });
    }
  }
}

class _$SaleDao extends SaleDao {
  _$SaleDao(
    this.database,
    this.changeListener,
  )   : _queryAdapter = QueryAdapter(database),
        _saleInsertionAdapter = InsertionAdapter(
            database,
            'sales',
            (Sale item) => <String, Object?>{
                  'id': item.id,
                  'createdAt': item.createdAt,
                  'customerId': item.customerId,
                  'userId': item.userId,
                  'subtotal': item.subtotal,
                  'discount': item.discount,
                  'tax': item.tax,
                  'total': item.total,
                  'paymentMethod': item.paymentMethod,
                  'amountPaid': item.amountPaid,
                  'changeDue': item.changeDue,
                  'exchangeRate': item.exchangeRate,
                  'status': item.status,
                  'note': item.note
                }),
        _saleItemInsertionAdapter = InsertionAdapter(
            database,
            'sale_items',
            (SaleItem item) => <String, Object?>{
                  'id': item.id,
                  'saleId': item.saleId,
                  'productId': item.productId,
                  'name': item.name,
                  'barcode': item.barcode,
                  'quantity': item.quantity,
                  'unitPrice': item.unitPrice,
                  'unitCost': item.unitCost,
                  'lineTotal': item.lineTotal
                }),
        _stockMovementInsertionAdapter = InsertionAdapter(
            database,
            'stock_movements',
            (StockMovement item) => <String, Object?>{
                  'id': item.id,
                  'productId': item.productId,
                  'change': item.change,
                  'reason': item.reason,
                  'note': item.note,
                  'userId': item.userId,
                  'saleId': item.saleId,
                  'createdAt': item.createdAt
                });

  final sqflite.DatabaseExecutor database;

  final StreamController<String> changeListener;

  final QueryAdapter _queryAdapter;

  final InsertionAdapter<Sale> _saleInsertionAdapter;

  final InsertionAdapter<SaleItem> _saleItemInsertionAdapter;

  final InsertionAdapter<StockMovement> _stockMovementInsertionAdapter;

  @override
  Future<List<Sale>> findSalesBetween(
    int from,
    int to,
  ) async {
    return _queryAdapter.queryList(
        'SELECT * FROM sales WHERE createdAt >= ?1 AND createdAt < ?2 ORDER BY createdAt DESC',
        mapper: (Map<String, Object?> row) => Sale(id: row['id'] as int?, createdAt: row['createdAt'] as int, customerId: row['customerId'] as int?, userId: row['userId'] as int?, subtotal: row['subtotal'] as double, discount: row['discount'] as double, tax: row['tax'] as double, total: row['total'] as double, paymentMethod: row['paymentMethod'] as String, amountPaid: row['amountPaid'] as double, changeDue: row['changeDue'] as double, exchangeRate: row['exchangeRate'] as double, status: row['status'] as String, note: row['note'] as String),
        arguments: [from, to]);
  }

  @override
  Future<List<Sale>> findRecentSales(int limit) async {
    return _queryAdapter.queryList(
        'SELECT * FROM sales ORDER BY createdAt DESC LIMIT ?1',
        mapper: (Map<String, Object?> row) => Sale(
            id: row['id'] as int?,
            createdAt: row['createdAt'] as int,
            customerId: row['customerId'] as int?,
            userId: row['userId'] as int?,
            subtotal: row['subtotal'] as double,
            discount: row['discount'] as double,
            tax: row['tax'] as double,
            total: row['total'] as double,
            paymentMethod: row['paymentMethod'] as String,
            amountPaid: row['amountPaid'] as double,
            changeDue: row['changeDue'] as double,
            exchangeRate: row['exchangeRate'] as double,
            status: row['status'] as String,
            note: row['note'] as String),
        arguments: [limit]);
  }

  @override
  Future<List<Sale>> findSalesByCustomer(int customerId) async {
    return _queryAdapter.queryList(
        'SELECT * FROM sales WHERE customerId = ?1 ORDER BY createdAt DESC',
        mapper: (Map<String, Object?> row) => Sale(
            id: row['id'] as int?,
            createdAt: row['createdAt'] as int,
            customerId: row['customerId'] as int?,
            userId: row['userId'] as int?,
            subtotal: row['subtotal'] as double,
            discount: row['discount'] as double,
            tax: row['tax'] as double,
            total: row['total'] as double,
            paymentMethod: row['paymentMethod'] as String,
            amountPaid: row['amountPaid'] as double,
            changeDue: row['changeDue'] as double,
            exchangeRate: row['exchangeRate'] as double,
            status: row['status'] as String,
            note: row['note'] as String),
        arguments: [customerId]);
  }

  @override
  Future<Sale?> findById(int id) async {
    return _queryAdapter.query('SELECT * FROM sales WHERE id = ?1',
        mapper: (Map<String, Object?> row) => Sale(
            id: row['id'] as int?,
            createdAt: row['createdAt'] as int,
            customerId: row['customerId'] as int?,
            userId: row['userId'] as int?,
            subtotal: row['subtotal'] as double,
            discount: row['discount'] as double,
            tax: row['tax'] as double,
            total: row['total'] as double,
            paymentMethod: row['paymentMethod'] as String,
            amountPaid: row['amountPaid'] as double,
            changeDue: row['changeDue'] as double,
            exchangeRate: row['exchangeRate'] as double,
            status: row['status'] as String,
            note: row['note'] as String),
        arguments: [id]);
  }

  @override
  Future<List<SaleItem>> findItems(int saleId) async {
    return _queryAdapter.queryList(
        'SELECT * FROM sale_items WHERE saleId = ?1 ORDER BY id',
        mapper: (Map<String, Object?> row) => SaleItem(
            id: row['id'] as int?,
            saleId: row['saleId'] as int,
            productId: row['productId'] as int?,
            name: row['name'] as String,
            barcode: row['barcode'] as String?,
            quantity: row['quantity'] as int,
            unitPrice: row['unitPrice'] as double,
            unitCost: row['unitCost'] as double,
            lineTotal: row['lineTotal'] as double),
        arguments: [saleId]);
  }

  @override
  Future<void> setStatus(
    int id,
    String status,
  ) async {
    await _queryAdapter.queryNoReturn(
        'UPDATE sales SET status = ?2 WHERE id = ?1',
        arguments: [id, status]);
  }

  @override
  Future<Product?> findProduct(int id) async {
    return _queryAdapter.query('SELECT * FROM products WHERE id = ?1',
        mapper: (Map<String, Object?> row) => Product(
            id: row['id'] as int?,
            name: row['name'] as String,
            barcode: row['barcode'] as String?,
            category: row['category'] as String,
            description: row['description'] as String,
            price: row['price'] as double,
            cost: row['cost'] as double,
            stock: row['stock'] as int,
            lowStockThreshold: row['lowStockThreshold'] as int,
            trackStock: (row['trackStock'] as int) != 0,
            active: (row['active'] as int) != 0,
            createdAt: row['createdAt'] as int,
            updatedAt: row['updatedAt'] as int),
        arguments: [id]);
  }

  @override
  Future<void> changeStock(
    int id,
    int delta,
    int now,
  ) async {
    await _queryAdapter.queryNoReturn(
        'UPDATE products SET stock = stock + ?2, updatedAt = ?3 WHERE id = ?1',
        arguments: [id, delta, now]);
  }

  @override
  Future<int> insertSale(Sale sale) {
    return _saleInsertionAdapter.insertAndReturnId(
        sale, OnConflictStrategy.abort);
  }

  @override
  Future<void> insertSaleItems(List<SaleItem> items) async {
    await _saleItemInsertionAdapter.insertList(items, OnConflictStrategy.abort);
  }

  @override
  Future<void> insertMovement(StockMovement movement) async {
    await _stockMovementInsertionAdapter.insert(
        movement, OnConflictStrategy.abort);
  }

  @override
  Future<int> recordSale(
    Sale sale,
    List<SaleItem> items,
  ) async {
    if (database is sqflite.Transaction) {
      return super.recordSale(sale, items);
    } else {
      return (database as sqflite.Database)
          .transaction<int>((transaction) async {
        final transactionDatabase = _$AppDatabase(changeListener)
          ..database = transaction;
        return transactionDatabase.saleDao.recordSale(sale, items);
      });
    }
  }

  @override
  Future<void> refundSale(
    int saleId,
    int? userId,
  ) async {
    if (database is sqflite.Transaction) {
      await super.refundSale(saleId, userId);
    } else {
      await (database as sqflite.Database)
          .transaction<void>((transaction) async {
        final transactionDatabase = _$AppDatabase(changeListener)
          ..database = transaction;
        await transactionDatabase.saleDao.refundSale(saleId, userId);
      });
    }
  }
}

class _$UserDao extends UserDao {
  _$UserDao(
    this.database,
    this.changeListener,
  )   : _queryAdapter = QueryAdapter(database),
        _userEntityInsertionAdapter = InsertionAdapter(
            database,
            'users',
            (UserEntity item) => <String, Object?>{
                  'id': item.id,
                  'name': item.name,
                  'role': item.role,
                  'pinHash': item.pinHash,
                  'pinSalt': item.pinSalt,
                  'active': item.active ? 1 : 0,
                  'createdAt': item.createdAt
                }),
        _userEntityUpdateAdapter = UpdateAdapter(
            database,
            'users',
            ['id'],
            (UserEntity item) => <String, Object?>{
                  'id': item.id,
                  'name': item.name,
                  'role': item.role,
                  'pinHash': item.pinHash,
                  'pinSalt': item.pinSalt,
                  'active': item.active ? 1 : 0,
                  'createdAt': item.createdAt
                });

  final sqflite.DatabaseExecutor database;

  final StreamController<String> changeListener;

  final QueryAdapter _queryAdapter;

  final InsertionAdapter<UserEntity> _userEntityInsertionAdapter;

  final UpdateAdapter<UserEntity> _userEntityUpdateAdapter;

  @override
  Future<List<UserEntity>> findAllUsers() async {
    return _queryAdapter.queryList(
        'SELECT * FROM users ORDER BY name COLLATE NOCASE',
        mapper: (Map<String, Object?> row) => UserEntity(
            id: row['id'] as int?,
            name: row['name'] as String,
            role: row['role'] as String,
            pinHash: row['pinHash'] as String,
            pinSalt: row['pinSalt'] as String,
            active: (row['active'] as int) != 0,
            createdAt: row['createdAt'] as int));
  }

  @override
  Future<UserEntity?> findById(int id) async {
    return _queryAdapter.query('SELECT * FROM users WHERE id = ?1',
        mapper: (Map<String, Object?> row) => UserEntity(
            id: row['id'] as int?,
            name: row['name'] as String,
            role: row['role'] as String,
            pinHash: row['pinHash'] as String,
            pinSalt: row['pinSalt'] as String,
            active: (row['active'] as int) != 0,
            createdAt: row['createdAt'] as int),
        arguments: [id]);
  }

  @override
  Future<int> insertUser(UserEntity user) {
    return _userEntityInsertionAdapter.insertAndReturnId(
        user, OnConflictStrategy.abort);
  }

  @override
  Future<void> updateUser(UserEntity user) async {
    await _userEntityUpdateAdapter.update(user, OnConflictStrategy.abort);
  }
}

class _$SettingDao extends SettingDao {
  _$SettingDao(
    this.database,
    this.changeListener,
  )   : _queryAdapter = QueryAdapter(database),
        _settingInsertionAdapter = InsertionAdapter(
            database,
            'settings',
            (Setting item) =>
                <String, Object?>{'key': item.key, 'value': item.value});

  final sqflite.DatabaseExecutor database;

  final StreamController<String> changeListener;

  final QueryAdapter _queryAdapter;

  final InsertionAdapter<Setting> _settingInsertionAdapter;

  @override
  Future<List<Setting>> findAll() async {
    return _queryAdapter.queryList('SELECT * FROM settings',
        mapper: (Map<String, Object?> row) =>
            Setting(row['key'] as String, row['value'] as String));
  }

  @override
  Future<void> upsertAll(List<Setting> settings) async {
    await _settingInsertionAdapter.insertList(
        settings, OnConflictStrategy.replace);
  }
}
