import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pricelet_app/entity/product_entity.dart';
import 'package:pricelet_app/src/core/money.dart';
import 'package:pricelet_app/src/core/theme.dart';
import 'package:pricelet_app/src/core/widgets.dart';
import 'package:pricelet_app/src/features/products/product_edit_page.dart';
import 'package:pricelet_app/src/features/products/products_service.dart';
import 'package:pricelet_app/src/features/shell/app_shell.dart';

enum _StockFilter { all, low, inactive }

class ProductListPage extends ConsumerStatefulWidget {
  const ProductListPage({super.key});

  @override
  ConsumerState<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends ConsumerState<ProductListPage> {
  final _search = TextEditingController();
  String? _category;
  _StockFilter _filter = _StockFilter.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Product> _apply(List<Product> products) {
    final query = _search.text.trim().toLowerCase();
    return products.where((p) {
      if (_category != null && p.category != _category) return false;
      switch (_filter) {
        case _StockFilter.low:
          if (!p.isLowStock || !p.active) return false;
          break;
        case _StockFilter.inactive:
          if (p.active) return false;
          break;
        case _StockFilter.all:
          break;
      }
      if (query.isEmpty) return true;
      return p.name.toLowerCase().contains(query) ||
          (p.barcode ?? '').toLowerCase().contains(query) ||
          p.category.toLowerCase().contains(query);
    }).toList();
  }

  void _open([Product? product]) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductEditPage(product: product)));
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    final categories = ref.watch(categoriesProvider);
    final money = ref.watch(moneyProvider);

    return ShellScaffold(
      title: 'Products',
      actions: [
        IconButton(tooltip: 'Refresh', onPressed: () => ref.invalidate(productsProvider), icon: const Icon(Icons.refresh_rounded)),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _open,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New product'),
      ),
      body: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(productsProvider)),
        data: (all) {
          final products = _apply(all);
          final lowCount = all.where((p) => p.active && p.isLowStock).length;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search by name, barcode or category',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(onPressed: () => setState(_search.clear), icon: const Icon(Icons.close_rounded)),
                  ),
                ),
              ),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _chip('All', _filter == _StockFilter.all && _category == null, () => setState(() {
                          _filter = _StockFilter.all;
                          _category = null;
                        })),
                    _chip('Low stock ($lowCount)', _filter == _StockFilter.low, () => setState(() => _filter = _StockFilter.low)),
                    _chip('Inactive', _filter == _StockFilter.inactive, () => setState(() => _filter = _StockFilter.inactive)),
                    if (categories.isNotEmpty) const VerticalDivider(indent: 8, endIndent: 8),
                    for (final c in categories)
                      _chip(c, _category == c, () => setState(() => _category = _category == c ? null : c)),
                  ],
                ),
              ),
              Expanded(
                child: products.isEmpty
                    ? EmptyState(
                        icon: Icons.inventory_2_outlined,
                        title: all.isEmpty ? 'No products yet' : 'No matching products',
                        message: all.isEmpty ? 'Add your first product to start selling.' : null,
                        action: all.isEmpty ? FilledButton.icon(onPressed: _open, icon: const Icon(Icons.add_rounded), label: const Text('Add product')) : null,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                        itemCount: products.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) => _ProductTile(product: products[i], money: money, onTap: () => _open(products[i])),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap()),
      );
}

class _ProductTile extends StatelessWidget {
  final Product product;
  final Money money;
  final VoidCallback onTap;

  const _ProductTile({required this.product, required this.money, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = product;
    final details = [
      if (p.barcode != null) p.barcode!,
      if (p.category.isNotEmpty) p.category,
    ].join(' · ');
    return Card(
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: InitialAvatar(name: p.name),
        title: Text(p.name, style: TextStyle(fontWeight: FontWeight.w700, color: p.active ? null : AppColors.subtle)),
        subtitle: details.isEmpty ? null : Text(details, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(money(p.price), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 4),
            StockBadge(product: p),
          ],
        ),
      ),
    );
  }
}

class StockBadge extends StatelessWidget {
  final Product product;

  const StockBadge({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final p = product;
    if (!p.active) return const StatusChip(label: 'Inactive', color: AppColors.subtle);
    if (!p.trackStock) return const StatusChip(label: 'Not tracked', color: AppColors.subtle);
    if (p.isOutOfStock) return const StatusChip(label: 'Out of stock', color: AppColors.danger);
    if (p.isLowStock) return StatusChip(label: '${p.stock} left', color: AppColors.warning);
    return StatusChip(label: '${p.stock} in stock', color: AppColors.success);
  }
}
