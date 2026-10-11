import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pricelet_app/entity/product_entity.dart';
import 'package:pricelet_app/src/core/barcode.dart';
import 'package:pricelet_app/src/core/money.dart';
import 'package:pricelet_app/src/core/theme.dart';
import 'package:pricelet_app/src/core/widgets.dart';
import 'package:pricelet_app/src/features/auth/auth.dart';
import 'package:pricelet_app/src/features/customers/customers_page.dart';
import 'package:pricelet_app/src/features/pos/cart.dart';
import 'package:pricelet_app/src/features/pos/checkout_dialog.dart';
import 'package:pricelet_app/src/features/products/product_edit_page.dart';
import 'package:pricelet_app/src/features/products/products_service.dart';
import 'package:pricelet_app/src/features/shell/app_shell.dart';

/// Adds [product] to the cart, reporting stock problems in a snackbar.
void addToCart(BuildContext context, WidgetRef ref, Product product, {int quantity = 1}) {
  try {
    ref.read(cartProvider.notifier).add(product, quantity: quantity);
  } on CartException catch (e) {
    showMessage(context, e.message, error: true);
  }
}

class PosPage extends ConsumerWidget {
  const PosPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = isWide(context);
    final cart = ref.watch(cartProvider);
    final totals = ref.watch(cartTotalsProvider);
    final money = ref.watch(moneyProvider);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.f9): () => startCheckout(context, ref),
      },
      child: ShellScaffold(
        title: 'Register',
        actions: [
          IconButton(
            tooltip: 'Refresh products',
            onPressed: () => ref.invalidate(productsProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
        body: wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Expanded(child: _Catalog()),
                  SizedBox(
                    width: 400,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 4, 16, 16),
                      child: Card(child: CartPanel(onCheckout: () => startCheckout(context, ref))),
                    ),
                  ),
                ],
              )
            : const _Catalog(),
        bottomNavigationBar: wide || cart.isEmpty
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _CartPage())),
                    child: Row(
                      children: [
                        const Icon(Icons.shopping_cart_rounded),
                        const SizedBox(width: 10),
                        Text('${cart.itemCount} items'),
                        const Spacer(),
                        Text(money(totals.total), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _CartPage extends ConsumerWidget {
  const _CartPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Current sale')),
      body: CartPanel(
        onCheckout: () async {
          final done = await startCheckout(context, ref);
          if (done && context.mounted) Navigator.pop(context);
        },
      ),
    );
  }
}

class _Catalog extends ConsumerStatefulWidget {
  const _Catalog();

  @override
  ConsumerState<_Catalog> createState() => _CatalogState();
}

class _CatalogState extends ConsumerState<_Catalog> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  String? _category;

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  List<Product> _filter(List<Product> products) {
    final q = _search.text.trim().toLowerCase();
    return products.where((p) {
      if (!p.active) return false;
      if (_category != null && p.category != _category) return false;
      if (q.isEmpty) return true;
      return p.name.toLowerCase().contains(q) || (p.barcode ?? '').toLowerCase() == q || (p.barcode ?? '').contains(q);
    }).toList();
  }

  /// Enter in the search box: exact barcode match first, else the only match.
  Future<void> _submit(String value) async {
    final code = value.trim();
    if (code.isEmpty) return;
    final products = ref.read(productsProvider).valueOrNull ?? const <Product>[];
    final exact = products.where((p) => p.active && p.barcode == code).firstOrNull;
    final matches = _filter(products);
    final product = exact ?? (matches.length == 1 ? matches.first : null);
    if (product != null) {
      addToCart(context, ref, product);
      _search.clear();
      setState(() {});
    } else {
      _unknownBarcode(code);
    }
    _searchFocus.requestFocus();
  }

  Future<void> _scan() async {
    final code = await scanBarcode(context);
    if (code == null || !mounted) return;
    final product = await ref.read(productsServiceProvider).findByBarcode(code);
    if (!mounted) return;
    if (product != null && product.active) {
      addToCart(context, ref, product);
    } else {
      _unknownBarcode(code);
    }
  }

  void _unknownBarcode(String code) {
    final isAdmin = ref.read(isAdminProvider);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('No product found for "$code"'),
        action: isAdmin
            ? SnackBarAction(
                label: 'Create',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ProductEditPage(initialBarcode: code)),
                ),
              )
            : null,
      ));
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    final categories = ref.watch(categoriesProvider);
    final cart = ref.watch(cartProvider);
    final money = ref.watch(moneyProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  focusNode: _searchFocus,
                  autofocus: !cameraScanSupported,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: _submit,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search or scan barcode, press Enter to add',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(onPressed: () => setState(_search.clear), icon: const Icon(Icons.close_rounded)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Scan barcode',
                onPressed: _scan,
                padding: const EdgeInsets.all(14),
                icon: const Icon(Icons.qr_code_scanner_rounded),
              ),
            ],
          ),
        ),
        if (categories.isNotEmpty)
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(label: const Text('All'), selected: _category == null, onSelected: (_) => setState(() => _category = null)),
                ),
                for (final c in categories)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(label: Text(c), selected: _category == c, onSelected: (_) => setState(() => _category = c)),
                  ),
              ],
            ),
          ),
        Expanded(
          child: productsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(productsProvider)),
            data: (all) {
              final products = _filter(all);
              if (products.isEmpty) {
                return EmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: all.isEmpty ? 'No products yet' : 'No matching products',
                  message: all.isEmpty ? 'Add products from the Products page to start selling.' : null,
                );
              }
              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 200,
                  mainAxisExtent: 128,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: products.length,
                itemBuilder: (context, i) {
                  final p = products[i];
                  return _ProductCard(
                    product: p,
                    price: money(p.price),
                    inCart: p.id == null ? 0 : cart.quantityOf(p.id!),
                    onTap: () => addToCart(context, ref, p),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final String price;
  final int inCart;
  final VoidCallback onTap;

  const _ProductCard({required this.product, required this.price, required this.inCart, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = product;
    final soldOut = p.isOutOfStock;
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: inCart > 0 ? AppColors.primary : const Color(0xFFE6EAF2), width: inCart > 0 ? 1.5 : 1),
      ),
      child: InkWell(
        onTap: soldOut ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  InitialAvatar(name: p.name, radius: 16),
                  const Spacer(),
                  if (inCart > 0)
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: AppColors.primary,
                      child: Text('$inCart', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  p.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w700, color: soldOut ? AppColors.subtle : AppColors.ink),
                ),
              ),
              Row(
                children: [
                  Expanded(child: Text(price, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary))),
                  if (p.trackStock)
                    Text(
                      soldOut ? 'Sold out' : '${p.stock}',
                      style: TextStyle(fontSize: 12, color: p.isLowStock ? AppColors.danger : AppColors.subtle, fontWeight: FontWeight.w600),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lines, discount, customer and totals of the current sale.
class CartPanel extends ConsumerWidget {
  final VoidCallback onCheckout;

  const CartPanel({super.key, required this.onCheckout});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final totals = ref.watch(cartTotalsProvider);
    final money = ref.watch(moneyProvider);
    final settings = money.settings;
    final controller = ref.read(cartProvider.notifier);
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Row(
            children: [
              Expanded(child: Text('Current sale', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
              TextButton.icon(
                onPressed: cart.isEmpty && cart.customer == null
                    ? null
                    : () async {
                        final ok = await confirmAction(context, title: 'Clear sale?', message: 'Remove all items from the current sale.', confirmLabel: 'Clear', destructive: true);
                        if (ok) controller.clear();
                      },
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                icon: const Icon(Icons.delete_sweep_outlined),
                label: const Text('Clear'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: cart.customer == null
              ? OutlinedButton.icon(
                  onPressed: () async {
                    final c = await pickCustomer(context);
                    if (c != null) controller.setCustomer(c);
                  },
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
                  icon: const Icon(Icons.person_add_alt_outlined),
                  label: const Text('Add customer'),
                )
              : InputChip(
                  avatar: const Icon(Icons.person_rounded, size: 18),
                  label: Text(cart.customer!.name),
                  onDeleted: () => controller.setCustomer(null),
                ),
        ),
        const SizedBox(height: 8),
        const Divider(),
        Expanded(
          child: cart.isEmpty
              ? const EmptyState(icon: Icons.shopping_basket_outlined, title: 'No items yet', message: 'Tap a product or scan a barcode.')
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: cart.lines.length,
                  separatorBuilder: (_, __) => const Divider(indent: 16, endIndent: 16),
                  itemBuilder: (context, i) => _CartLineTile(line: cart.lines[i], money: money),
                ),
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TotalRow(label: 'Subtotal', value: money(totals.subtotal)),
              InkWell(
                onTap: cart.isEmpty ? null : () => _editDiscount(context, ref),
                borderRadius: BorderRadius.circular(8),
                child: _TotalRow(
                  label: totals.discount > 0 && cart.discountType == DiscountType.percent
                      ? 'Discount (${_trim(cart.discountValue)}%)'
                      : 'Discount',
                  value: totals.discount > 0 ? '-${money(totals.discount)}' : 'Add',
                  valueColor: totals.discount > 0 ? AppColors.success : AppColors.primary,
                ),
              ),
              if (settings.taxRate > 0) _TotalRow(label: 'Tax (${_trim(settings.taxRate)}%)', value: money(totals.tax)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text('Total', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const Spacer(),
                  Text(money(totals.total), style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                ],
              ),
              if (money.hasSecondary)
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(money.secondary(totals.total), style: textTheme.titleSmall?.copyWith(color: AppColors.muted)),
                ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: cart.isEmpty ? null : onCheckout,
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18)),
                icon: const Icon(Icons.payments_rounded),
                label: Text('Charge ${money(totals.total)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _editDiscount(BuildContext context, WidgetRef ref) async {
    final cart = ref.read(cartProvider);
    final result = await showDialog<(DiscountType, double)>(
      context: context,
      builder: (_) => _DiscountDialog(type: cart.discountType, value: cart.discountValue),
    );
    if (result != null) ref.read(cartProvider.notifier).setDiscount(result.$1, result.$2);
  }
}

String _trim(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _TotalRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: AppColors.muted))),
          Text(value, style: TextStyle(fontWeight: FontWeight.w700, color: valueColor)),
        ],
      ),
    );
  }
}

class _CartLineTile extends ConsumerWidget {
  final CartLine line;
  final Money money;

  const _CartLineTile({required this.line, required this.money});

  void _set(BuildContext context, WidgetRef ref, int quantity) {
    try {
      ref.read(cartProvider.notifier).setQuantity(line.product, quantity);
    } on CartException catch (e) {
      showMessage(context, e.message, error: true);
    }
  }

  Future<void> _typeQuantity(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: '${line.quantity}');
    final value = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(line.product.name),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(labelText: 'Quantity'),
          onSubmitted: (v) => Navigator.pop(context, int.tryParse(v)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, int.tryParse(controller.text)), child: const Text('OK')),
        ],
      ),
    );
    controller.dispose();
    if (value != null && context.mounted) _set(context, ref, value);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.product.name, style: const TextStyle(fontWeight: FontWeight.w700), maxLines: 2, overflow: TextOverflow.ellipsis),
                Text('${money(line.product.price)} each', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => _set(context, ref, line.quantity - 1),
            icon: Icon(line.quantity == 1 ? Icons.delete_outline_rounded : Icons.remove_circle_outline_rounded,
                color: line.quantity == 1 ? AppColors.danger : null),
          ),
          InkWell(
            onTap: () => _typeQuantity(context, ref),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              constraints: const BoxConstraints(minWidth: 36),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              alignment: Alignment.center,
              child: Text('${line.quantity}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => _set(context, ref, line.quantity + 1),
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
          SizedBox(
            width: 84,
            child: Text(money(line.total), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

class _DiscountDialog extends StatefulWidget {
  final DiscountType type;
  final double value;

  const _DiscountDialog({required this.type, required this.value});

  @override
  State<_DiscountDialog> createState() => _DiscountDialogState();
}

class _DiscountDialogState extends State<_DiscountDialog> {
  late DiscountType _type = widget.type;
  late final _value = TextEditingController(text: widget.value == 0 ? '' : _trim(widget.value));

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  void _apply() => Navigator.pop(context, (_type, parseDecimal(_value.text) ?? 0));

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Discount'),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<DiscountType>(
              segments: const [
                ButtonSegment(value: DiscountType.amount, label: Text('Amount')),
                ButtonSegment(value: DiscountType.percent, label: Text('Percent')),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _value,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: decimalInputFormatters,
              onSubmitted: (_) => _apply(),
              decoration: InputDecoration(labelText: _type == DiscountType.percent ? 'Percent off' : 'Amount off', suffixText: _type == DiscountType.percent ? '%' : null),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, (_type, 0.0)), child: const Text('Remove')),
        FilledButton(onPressed: _apply, child: const Text('Apply')),
      ],
    );
  }
}
