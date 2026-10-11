import 'package:floor/floor.dart';
import 'package:pricelet_app/entity/product_entity.dart';
import 'package:pricelet_app/entity/sale_entity.dart';
import 'package:pricelet_app/entity/sale_item_entity.dart';
import 'package:pricelet_app/entity/stock_movement_entity.dart';

@dao
abstract class SaleDao {
  @Query('SELECT * FROM sales WHERE createdAt >= :from AND createdAt < :to ORDER BY createdAt DESC')
  Future<List<Sale>> findSalesBetween(int from, int to);

  @Query('SELECT * FROM sales ORDER BY createdAt DESC LIMIT :limit')
  Future<List<Sale>> findRecentSales(int limit);

  @Query('SELECT * FROM sales WHERE customerId = :customerId ORDER BY createdAt DESC')
  Future<List<Sale>> findSalesByCustomer(int customerId);

  @Query('SELECT * FROM sales WHERE id = :id')
  Future<Sale?> findById(int id);

  @Query('SELECT * FROM sale_items WHERE saleId = :saleId ORDER BY id')
  Future<List<SaleItem>> findItems(int saleId);

  @insert
  Future<int> insertSale(Sale sale);

  @insert
  Future<void> insertSaleItems(List<SaleItem> items);

  @Query('UPDATE sales SET status = :status WHERE id = :id')
  Future<void> setStatus(int id, String status);

  @Query('SELECT * FROM products WHERE id = :id')
  Future<Product?> findProduct(int id);

  @Query('UPDATE products SET stock = stock + :delta, updatedAt = :now WHERE id = :id')
  Future<void> changeStock(int id, int delta, int now);

  @insert
  Future<void> insertMovement(StockMovement movement);

  /// Saves the sale with its lines and takes the sold quantities out of stock.
  @transaction
  Future<int> recordSale(Sale sale, List<SaleItem> items) async {
    final saleId = await insertSale(sale);
    await insertSaleItems(items.map((item) => item.withSaleId(saleId)).toList());
    for (final item in items) {
      await _moveStock(item, -item.quantity, StockReason.sale, saleId, sale.userId, sale.createdAt);
    }
    return saleId;
  }

  /// Marks the sale refunded and puts its items back in stock.
  @transaction
  Future<void> refundSale(int saleId, int? userId) async {
    final sale = await findById(saleId);
    if (sale == null || sale.isRefunded) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await setStatus(saleId, SaleStatus.refunded);
    for (final item in await findItems(saleId)) {
      await _moveStock(item, item.quantity, StockReason.refund, saleId, userId, now);
    }
  }

  Future<void> _moveStock(SaleItem item, int delta, String reason, int saleId, int? userId, int now) async {
    final productId = item.productId;
    if (productId == null) return;
    final product = await findProduct(productId);
    if (product == null || !product.trackStock) return;
    await changeStock(productId, delta, now);
    await insertMovement(StockMovement(
      productId: productId,
      change: delta,
      reason: reason,
      userId: userId,
      saleId: saleId,
      createdAt: now,
    ));
  }
}
