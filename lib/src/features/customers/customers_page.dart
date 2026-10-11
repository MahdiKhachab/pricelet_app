import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pricelet_app/entity/customer_entity.dart';
import 'package:pricelet_app/src/core/widgets.dart';
import 'package:pricelet_app/src/features/customers/customer_edit_page.dart';
import 'package:pricelet_app/src/features/customers/customers_service.dart';
import 'package:pricelet_app/src/features/shell/app_shell.dart';

class CustomersPage extends ConsumerStatefulWidget {
  const CustomersPage({super.key});

  @override
  ConsumerState<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends ConsumerState<CustomersPage> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _open([Customer? customer]) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => CustomerEditPage(customer: customer)));
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersProvider);

    return ShellScaffold(
      title: 'Customers',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _open,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('New customer'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(hintText: 'Search by name, phone or email', prefixIcon: Icon(Icons.search_rounded)),
            ),
          ),
          Expanded(
            child: customersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(customersProvider)),
              data: (all) {
                final customers = all.where((c) => customerMatches(c, _search.text)).toList();
                if (customers.isEmpty) {
                  return EmptyState(
                    icon: Icons.people_outline_rounded,
                    title: all.isEmpty ? 'No customers yet' : 'No matching customers',
                    message: all.isEmpty ? 'Save regular customers to track their purchases.' : null,
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  itemCount: customers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final c = customers[i];
                    final contact = [c.phone, c.email].where((s) => s.isNotEmpty).join(' · ');
                    return Card(
                      child: ListTile(
                        onTap: () => _open(c),
                        leading: InitialAvatar(name: c.name),
                        title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: contact.isEmpty ? null : Text(contact),
                        trailing: const Icon(Icons.chevron_right_rounded),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Lets the cashier attach a customer to the current sale.
Future<Customer?> pickCustomer(BuildContext context) {
  return showDialog<Customer>(context: context, builder: (_) => const _CustomerPickerDialog());
}

class _CustomerPickerDialog extends ConsumerStatefulWidget {
  const _CustomerPickerDialog();

  @override
  ConsumerState<_CustomerPickerDialog> createState() => _CustomerPickerDialogState();
}

class _CustomerPickerDialogState extends ConsumerState<_CustomerPickerDialog> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final created = await Navigator.of(context).push<Customer>(
      MaterialPageRoute(builder: (_) => CustomerEditPage(initialName: _search.text.trim())),
    );
    if (created != null && mounted) Navigator.pop(context, created);
  }

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(customersProvider).valueOrNull ?? const <Customer>[];
    final matches = customers.where((c) => customerMatches(c, _search.text)).take(50).toList();

    return AlertDialog(
      title: const Text('Select customer'),
      contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      content: SizedBox(
        width: 420,
        height: 420,
        child: Column(
          children: [
            TextField(
              controller: _search,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(hintText: 'Name or phone', prefixIcon: Icon(Icons.search_rounded)),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: matches.isEmpty
                  ? const EmptyState(icon: Icons.person_search_rounded, title: 'No customers found')
                  : ListView(
                      children: [
                        for (final c in matches)
                          ListTile(
                            leading: InitialAvatar(name: c.name, radius: 16),
                            title: Text(c.name),
                            subtitle: c.phone.isEmpty ? null : Text(c.phone),
                            onTap: () => Navigator.pop(context, c),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton.icon(onPressed: _create, icon: const Icon(Icons.person_add_alt_1_rounded), label: const Text('New customer')),
      ],
    );
  }
}
