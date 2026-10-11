import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pricelet_app/database/database.dart';
import 'package:pricelet_app/entity/product_entity.dart';
import 'package:pricelet_app/entity/stock_movement_entity.dart';
import 'package:pricelet_app/src/core/providers.dart';
import 'package:pricelet_app/src/features/auth/auth.dart';

final productsProvider = FutureProvider<List<Product>>((ref) {
  ref.watch(dataVersionProvider);
  return ref.watch(databaseProvider).productDao.findAllProducts();
});

final categoriesProvider = Provider<List<String>>((ref) {
  final products = ref.watch(productsProvider).valueOrNull ?? const <Product>[];
  final categories = products.map((p) => p.category.trim()).where((c) => c.isNotEmpty).toSet().toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return categories;
});

final stockMovementsProvider = FutureProvider.family<List<StockMovement>, int>((ref, productId) {
  ref.watch(dataVersionProvider);
  return ref.watch(databaseProvider).productDao.findMovements(productId);
});

final productsServiceProvider = Provider<ProductsService>((ref) => ProductsService(ref));

class ProductValidationException implements Exception {
  final String message;
  ProductValidationException(this.message);

  @override
  String toString() => message;
}

class ProductsService {
  final Ref _ref;

  ProductsService(this._ref);

  AppDatabase get _db => _ref.read(databaseProvider);

  int? get _userId => _ref.read(currentUserProvider)?.id;

  void _changed() => _ref.read(dataVersionProvider.notifier).state++;

  Future<Product?> findByBarcode(String barcode) => _db.productDao.findByBarcode(barcode.trim());

  /// Inserts or updates [product]. Barcodes must be unique; pass a null
  /// barcode for products without one.
  Future<Product> save(Product product) async {
    final barcode = product.barcode;
    if (barcode != null) {
      final existing = await _db.productDao.findByBarcode(barcode);
      if (existing != null && existing.id != product.id) {
        throw ProductValidationException('Barcode already used by "${existing.name}"');
      }
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    Product saved;
    if (product.id == null) {
      final id = await _db.productDao.createProduct(product.copyWith(updatedAt: now), _userId);
      saved = product.copyWith(id: id, updatedAt: now);
    } else {
      // Stock only changes through adjustStock, so every change is logged.
      final current = await _db.productDao.findById(product.id!);
      saved = product.copyWith(stock: current?.stock ?? product.stock, updatedAt: now);
      await _db.productDao.updateProduct(saved);
    }
    _changed();
    return saved;
  }

  Future<void> delete(Product product) async {
    await _db.productDao.deleteProduct(product.id!);
    _changed();
  }

  Future<void> adjustStock(Product product, int delta, String reason, String note) async {
    if (delta == 0) return;
    await _db.productDao.adjustStock(product.id!, delta, reason, note, _userId);
    _changed();
  }
}
