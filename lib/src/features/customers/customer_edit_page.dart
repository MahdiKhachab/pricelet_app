import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pricelet_app/entity/customer_entity.dart';
import 'package:pricelet_app/src/core/money.dart';
import 'package:pricelet_app/src/core/theme.dart';
import 'package:pricelet_app/src/core/widgets.dart';
import 'package:pricelet_app/src/features/auth/auth.dart';
import 'package:pricelet_app/src/features/customers/customers_service.dart';
import 'package:pricelet_app/src/features/sales/sale_detail_page.dart';

/// Creates or edits a customer. Pops with the saved [Customer].
class CustomerEditPage extends ConsumerStatefulWidget {
  final Customer? customer;
  final String initialName;

  const CustomerEditPage({super.key, this.customer, this.initialName = ''});

  @override
  ConsumerState<CustomerEditPage> createState() => _CustomerEditPageState();
}

class _CustomerEditPageState extends ConsumerState<CustomerEditPage> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.customer?.name ?? widget.initialName);
  late final _phone = TextEditingController(text: widget.customer?.phone ?? '');
  late final _email = TextEditingController(text: widget.customer?.email ?? '');
  late final _notes = TextEditingController(text: widget.customer?.notes ?? '');
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final customer = Customer(
      id: widget.customer?.id,
      name: _name.text.trim(),
      phone: _phone.text.trim(),
      email: _email.text.trim(),
      notes: _notes.text.trim(),
      createdAt: widget.customer?.createdAt ?? DateTime.now().millisecondsSinceEpoch,
    );
    try {
      final saved = await ref.read(customersServiceProvider).save(customer);
      if (mounted) Navigator.pop(context, saved);
    } catch (e) {
      if (mounted) {
        showMessage(context, 'Could not save customer: $e', error: true);
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _delete() async {
    final ok = await confirmAction(
      context,
      title: 'Delete customer?',
      message: 'Their past sales are kept but will no longer be linked to them.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    await ref.read(customersServiceProvider).delete(widget.customer!);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.customer;
    final isAdmin = ref.watch(isAdminProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(existing == null ? 'New customer' : existing.name),
        actions: [
          if (existing != null && isAdmin)
            IconButton(tooltip: 'Delete', onPressed: _delete, icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger)),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionCard(
                  title: 'Contact',
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _name,
                          autofocus: existing == null,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(labelText: 'Name *'),
                          validator: requiredValidator,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone')),
                        const SizedBox(height: 12),
                        TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
                        const SizedBox(height: 12),
                        TextFormField(controller: _notes, maxLines: 3, decoration: const InputDecoration(labelText: 'Notes')),
                      ],
                    ),
                  ),
                ),
                if (existing != null) ...[
                  const SizedBox(height: 12),
                  _PurchaseHistory(customerId: existing.id!),
                ],
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.check_rounded),
            label: Text(existing == null ? 'Add customer' : 'Save changes'),
          ),
        ),
      ),
    );
  }
}

class _PurchaseHistory extends ConsumerWidget {
  final int customerId;

  const _PurchaseHistory({required this.customerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final money = ref.watch(moneyProvider);
    final salesAsync = ref.watch(customerSalesProvider(customerId));

    return salesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(error: e),
      data: (sales) {
        final completed = sales.where((s) => !s.isRefunded).toList();
        final spent = completed.fold<double>(0, (sum, s) => sum + s.total);
        return SectionCard(
          title: 'Purchase history',
          trailing: Text('${completed.length} visits · ${money(spent)}', style: const TextStyle(color: AppColors.muted)),
          child: sales.isEmpty
              ? const Text('No purchases yet.', style: TextStyle(color: AppColors.muted))
              : Column(
                  children: [
                    for (final s in sales.take(50))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('${s.receiptNo} · ${dateTimeFormat.format(s.date)}'),
                        subtitle: s.isRefunded ? const Text('Refunded', style: TextStyle(color: AppColors.danger)) : null,
                        trailing: Text(money(s.total), style: const TextStyle(fontWeight: FontWeight.w700)),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SaleDetailPage(saleId: s.id!))),
                      ),
                  ],
                ),
        );
      },
    );
  }
}
