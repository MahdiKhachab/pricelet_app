import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pricelet_app/entity/customer_entity.dart';
import 'package:pricelet_app/entity/sale_entity.dart';
import 'package:pricelet_app/src/core/providers.dart';

final customersProvider = FutureProvider<List<Customer>>((ref) {
  ref.watch(dataVersionProvider);
  return ref.watch(databaseProvider).customerDao.findAllCustomers();
});

final customerSalesProvider = FutureProvider.family<List<Sale>, int>((ref, customerId) {
  ref.watch(dataVersionProvider);
  return ref.watch(databaseProvider).saleDao.findSalesByCustomer(customerId);
});

final customersServiceProvider = Provider<CustomersService>((ref) => CustomersService(ref));

bool customerMatches(Customer c, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  return c.name.toLowerCase().contains(q) || c.phone.contains(q) || c.email.toLowerCase().contains(q);
}

class CustomersService {
  final Ref _ref;

  CustomersService(this._ref);

  void _changed() => _ref.read(dataVersionProvider.notifier).state++;

  Future<Customer> save(Customer customer) async {
    final dao = _ref.read(databaseProvider).customerDao;
    Customer saved = customer;
    if (customer.id == null) {
      final id = await dao.insertCustomer(customer);
      saved = Customer(
        id: id,
        name: customer.name,
        phone: customer.phone,
        email: customer.email,
        notes: customer.notes,
        createdAt: customer.createdAt,
      );
    } else {
      await dao.updateCustomer(customer);
    }
    _changed();
    return saved;
  }

  Future<void> delete(Customer customer) async {
    await _ref.read(databaseProvider).customerDao.deleteCustomer(customer.id!);
    _changed();
  }
}
