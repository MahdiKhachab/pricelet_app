import 'package:floor/floor.dart';
import 'package:pricelet_app/entity/customer_entity.dart';

@dao
abstract class CustomerDao {
  @Query('SELECT * FROM customers ORDER BY name COLLATE NOCASE')
  Future<List<Customer>> findAllCustomers();

  @Query('SELECT * FROM customers WHERE id = :id')
  Future<Customer?> findById(int id);

  @insert
  Future<int> insertCustomer(Customer customer);

  @update
  Future<void> updateCustomer(Customer customer);

  @Query('UPDATE sales SET customerId = NULL WHERE customerId = :id')
  Future<void> detachSales(int id);

  @Query('DELETE FROM customers WHERE id = :id')
  Future<void> deleteById(int id);

  /// Deletes the customer but keeps their past sales.
  @transaction
  Future<void> deleteCustomer(int id) async {
    await detachSales(id);
    await deleteById(id);
  }
}
