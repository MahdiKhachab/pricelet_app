import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pricelet_app/entity/product_entity.dart';
import 'package:pricelet_app/entity/stock_movement_entity.dart';
import 'package:pricelet_app/src/core/barcode.dart';
import 'package:pricelet_app/src/core/money.dart';
import 'package:pricelet_app/src/core/theme.dart';
import 'package:pricelet_app/src/core/widgets.dart';
import 'package:pricelet_app/src/features/products/product_list_page.dart';
import 'package:pricelet_app/src/features/products/products_service.dart';
import 'package:pricelet_app/src/features/products/stock_adjust_dialog.dart';

class ProductEditPage extends ConsumerStatefulWidget {
  final Product? product;

  /// Pre-fills the barcode when creating a product from an unknown scan.
  final String? initialBarcode;

  const ProductEditPage({super.key, this.product, this.initialBarcode});

  @override
  ConsumerState<ProductEditPage> createState() => _ProductEditPageState();
}

class _ProductEditPageState extends ConsumerState<ProductEditPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _barcode;
  late final TextEditingController _category;
  late final TextEditingController _description;
  late final TextEditingController _price;
  late final TextEditingController _cost;
  late final TextEditingController _stock;
  late final TextEditingController _lowStock;
  final _categoryFocus = FocusNode();
  late bool _trackStock;
  late bool _active;
  bool _saving = false;

  bool get _isNew => widget.product == null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    String num(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v';
    _name = TextEditingController(text: p?.name ?? '');
    _barcode = TextEditingController(text: p?.barcode ?? widget.initialBarcode ?? '');
    _category = TextEditingController(text: p?.category ?? '');
    _description = TextEditingController(text: p?.description ?? '');
    _price = TextEditingController(text: p == null ? '' : num(p.price));
    _cost = TextEditingController(text: p == null ? '' : num(p.cost));
    _stock = TextEditingController(text: '${p?.stock ?? 0}');
    _lowStock = TextEditingController(text: '${p?.lowStockThreshold ?? 5}');
    _trackStock = p?.trackStock ?? true;
    _active = p?.active ?? true;
  }

  @override
  void dispose() {
    _categoryFocus.dispose();
    for (final c in [_name, _barcode, _category, _description, _price, _cost, _stock, _lowStock]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _scan() async {
    final code = await scanBarcode(context);
    if (code != null) setState(() => _barcode.text = code);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final barcode = _barcode.text.trim();
    final product = Product(
      id: widget.product?.id,
      name: _name.text.trim(),
      barcode: barcode.isEmpty ? null : barcode,
      category: _category.text.trim(),
      description: _description.text.trim(),
      price: parseDecimal(_price.text) ?? 0,
      cost: parseDecimal(_cost.text) ?? 0,
      stock: int.tryParse(_stock.text) ?? 0,
      lowStockThreshold: int.tryParse(_lowStock.text) ?? 0,
      trackStock: _trackStock,
      active: _active,
      createdAt: widget.product?.createdAt ?? now,
      updatedAt: now,
    );

    setState(() => _saving = true);
    try {
      await ref.read(productsServiceProvider).save(product);
      if (!mounted) return;
      showMessage(context, _isNew ? 'Product added' : 'Product updated');
      Navigator.pop(context);
    } on ProductValidationException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } catch (e) {
      if (mounted) showMessage(context, 'Could not save product: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final product = widget.product!;
    final ok = await confirmAction(
      context,
      title: 'Delete product?',
      message: '"${product.name}" will be removed. Past sales keep their receipt lines.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    await ref.read(productsServiceProvider).delete(product);
    if (!mounted) return;
    showMessage(context, 'Product deleted');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final money = ref.watch(moneyProvider);
    final categories = ref.watch(categoriesProvider);
    final price = parseDecimal(_price.text) ?? 0;
    final cost = parseDecimal(_cost.text) ?? 0;
    final margin = price > 0 ? (price - cost) / price * 100 : 0.0;

    final form = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionCard(
            title: 'Details',
            child: Column(
              children: [
                TextFormField(
                  controller: _name,
                  autofocus: _isNew,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Name *'),
                  validator: requiredValidator,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _barcode,
                  decoration: InputDecoration(
                    labelText: 'Barcode / SKU',
                    suffixIcon: IconButton(tooltip: 'Scan', onPressed: _scan, icon: const Icon(Icons.qr_code_scanner_rounded)),
                  ),
                ),
                const SizedBox(height: 12),
                RawAutocomplete<String>(
                  textEditingController: _category,
                  focusNode: _categoryFocus,
                  optionsBuilder: (value) {
                    final q = value.text.toLowerCase();
                    return categories.where((c) => c.toLowerCase().contains(q) && c != value.text);
                  },
                  fieldViewBuilder: (context, controller, focusNode, onSubmit) => TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Category'),
                  ),
                  optionsViewBuilder: (context, onSelected, options) => Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(12),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 220, maxWidth: 360),
                        child: ListView(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          children: [for (final o in options) ListTile(title: Text(o), onTap: () => onSelected(o))],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _active,
                  onChanged: (v) => setState(() => _active = v),
                  title: const Text('Available for sale'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Pricing',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _price,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: decimalInputFormatters,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(labelText: 'Selling price *'),
                        validator: decimalValidator,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _cost,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: decimalInputFormatters,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(labelText: 'Cost price'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    if (money.hasSecondary) Text('= ${money.secondary(price)}', style: const TextStyle(color: AppColors.muted)),
                    Text(
                      'Margin ${margin.toStringAsFixed(1)}% (${money(price - cost)} per unit)',
                      style: TextStyle(color: margin < 0 ? AppColors.danger : AppColors.muted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Inventory',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _trackStock,
                  onChanged: (v) => setState(() => _trackStock = v),
                  title: const Text('Track stock'),
                  subtitle: const Text('Decrease stock on each sale and warn when running low'),
                ),
                if (_trackStock)
                  Row(
                    children: [
                      if (_isNew) ...[
                        Expanded(
                          child: TextFormField(
                            controller: _stock,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: const InputDecoration(labelText: 'Opening stock'),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: TextFormField(
                          controller: _lowStock,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(labelText: 'Low stock alert at'),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    final product = widget.product;
    final side = product == null ? null : _StockPanel(productId: product.id!);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'New product' : 'Edit product'),
        actions: [
          if (!_isNew)
            IconButton(tooltip: 'Delete', onPressed: _delete, icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger)),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= wideLayoutWidth && side != null;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: twoColumns ? 1100 : 640),
              child: twoColumns
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [Expanded(flex: 3, child: form), const SizedBox(width: 16), Expanded(flex: 2, child: side)],
                    )
                  : Column(children: [form, if (side != null) ...[const SizedBox(height: 12), side]]),
            ),
          ),
        );
      }),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check_rounded),
            label: Text(_isNew ? 'Add product' : 'Save changes'),
          ),
        ),
      ),
    );
  }
}

/// Current stock, adjust button and movement history for a saved product.
class _StockPanel extends ConsumerWidget {
  final int productId;

  const _StockPanel({required this.productId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = ref.watch(productsProvider).valueOrNull?.where((p) => p.id == productId).firstOrNull;
    final movements = ref.watch(stockMovementsProvider(productId));
    if (product == null) return const SizedBox.shrink();

    return SectionCard(
      title: 'Stock',
      trailing: product.trackStock ? StockBadge(product: product) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (product.trackStock) ...[
            Text('${product.stock}', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800)),
            const Text('units on hand', style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => showStockAdjustDialog(context, product),
              icon: const Icon(Icons.tune_rounded),
              label: const Text('Adjust stock'),
            ),
          ] else
            const Text('Stock is not tracked for this product.', style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 16),
          Text('History', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          movements.when(
            loading: () => const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Text('$e'),
            data: (list) => list.isEmpty
                ? const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('No stock movements yet.', style: TextStyle(color: AppColors.muted)))
                : Column(
                    children: [
                      for (final m in list.take(30))
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(StockReason.label(m.reason) + (m.note.isEmpty ? '' : ' · ${m.note}')),
                          subtitle: Text(dateTimeFormat.format(DateTime.fromMillisecondsSinceEpoch(m.createdAt))),
                          trailing: Text(
                            m.change > 0 ? '+${m.change}' : '${m.change}',
                            style: TextStyle(fontWeight: FontWeight.w800, color: m.change > 0 ? AppColors.success : AppColors.danger),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
