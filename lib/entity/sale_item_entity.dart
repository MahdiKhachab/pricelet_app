import 'package:floor/floor.dart';
import 'package:pricelet_app/entity/sale_entity.dart';

/// A line on a sale. Name and prices are snapshotted so receipts stay correct
/// after the product is edited or deleted.
@Entity(
  tableName: 'sale_items',
  foreignKeys: [
    ForeignKey(
      childColumns: ['saleId'],
      parentColumns: ['id'],
      entity: Sale,
      onDelete: ForeignKeyAction.cascade,
    ),
  ],
  indices: [
    Index(value: ['saleId']),
    Index(value: ['productId']),
  ],
)
class SaleItem {
  @PrimaryKey(autoGenerate: true)
  final int? id;

  final int saleId;
  final int? productId;
  final String name;
  final String? barcode;
  final int quantity;
  final double unitPrice; // price at time of sale
  final double unitCost; // cost at time of sale
  final double lineTotal;

  const SaleItem({
    this.id,
    required this.saleId,
    this.productId,
    required this.name,
    this.barcode,
    required this.quantity,
    required this.unitPrice,
    this.unitCost = 0,
    required this.lineTotal,
  });

  SaleItem withSaleId(int saleId) => SaleItem(
        id: id,
        saleId: saleId,
        productId: productId,
        name: name,
        barcode: barcode,
        quantity: quantity,
        unitPrice: unitPrice,
        unitCost: unitCost,
        lineTotal: lineTotal,
      );
}
