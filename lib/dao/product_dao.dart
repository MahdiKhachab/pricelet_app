import 'package:floor/floor.dart';
import 'package:pricelet_app/entity/product_entity.dart';
import 'package:pricelet_app/entity/stock_movement_entity.dart';

@dao
abstract class ProductDao {
  @Query('SELECT * FROM products ORDER BY name COLLATE NOCASE')
  Future<List<Product>> findAllProducts();

  @Query('SELECT * FROM products WHERE id = :id')
  Future<Product?> findById(int id);

  @Query('SELECT * FROM products WHERE barcode = :barcode LIMIT 1')
  Future<Product?> findByBarcode(String barcode);

  @insert
  Future<int> insertProduct(Product product);

  @update
  Future<void> updateProduct(Product product);

  @Query('DELETE FROM products WHERE id = :id')
  Future<void> deleteById(int id);

  @Query('UPDATE products SET stock = stock + :delta, updatedAt = :now WHERE id = :id')
  Future<void> changeStock(int id, int delta, int now);

  @insert
  Future<void> insertMovement(StockMovement movement);

  @Query('SELECT * FROM stock_movements WHERE productId = :productId ORDER BY createdAt DESC LIMIT 200')
  Future<List<StockMovement>> findMovements(int productId);

  @Query('DELETE FROM stock_movements WHERE productId = :productId')
  Future<void> deleteMovements(int productId);

  /// Inserts the product and logs its opening stock.
  @transaction
  Future<int> createProduct(Product product, int? userId) async {
    final id = await insertProduct(product);
    if (product.trackStock && product.stock != 0) {
      await insertMovement(StockMovement(
        productId: id,
        change: product.stock,
        reason: StockReason.initial,
        userId: userId,
        createdAt: product.createdAt,
      ));
    }
    return id;
  }

  @transaction
  Future<void> adjustStock(int productId, int delta, String reason, String note, int? userId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await changeStock(productId, delta, now);
    await insertMovement(StockMovement(
      productId: productId,
      change: delta,
      reason: reason,
      note: note,
      userId: userId,
      createdAt: now,
    ));
  }

  @transaction
  Future<void> deleteProduct(int id) async {
    await deleteMovements(id);
    await deleteById(id);
  }
}
