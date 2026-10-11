import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pricelet_app/entity/product_entity.dart';
import 'package:pricelet_app/src/core/barcode.dart';
import 'package:pricelet_app/src/core/money.dart';
import 'package:pricelet_app/src/core/theme.dart';
import 'package:pricelet_app/src/core/widgets.dart';
import 'package:pricelet_app/src/features/pos/pos_page.dart';
import 'package:pricelet_app/src/features/products/product_list_page.dart';
import 'package:pricelet_app/src/features/products/products_service.dart';
import 'package:pricelet_app/src/features/shell/app_shell.dart';

/// Look up a product's price by scanning or typing its barcode.
class PriceCheckPage extends ConsumerStatefulWidget {
  const PriceCheckPage({super.key});

  @override
  ConsumerState<PriceCheckPage> createState() => _PriceCheckPageState();
}

class _PriceCheckPageState extends ConsumerState<PriceCheckPage> {
  final _code = TextEditingController();
  final _focus = FocusNode();
  Product? _product;
  String? _notFound;

  @override
  void dispose() {
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _lookup(String code) async {
    final value = code.trim();
    if (value.isEmpty) return;
    final product = await ref.read(productsServiceProvider).findByBarcode(value);
    if (!mounted) return;
    setState(() {
      _product = product;
      _notFound = product == null ? value : null;
      _code.clear();
    });
    _focus.requestFocus();
  }

  Future<void> _scan() async {
    final code = await scanBarcode(context);
    if (code != null) await _lookup(code);
  }

  @override
  Widget build(BuildContext context) {
    final money = ref.watch(moneyProvider);
    final p = _product;
    final textTheme = Theme.of(context).textTheme;

    return ShellScaffold(
      title: 'Price check',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _code,
                        focusNode: _focus,
                        autofocus: !cameraScanSupported,
                        onSubmitted: _lookup,
                        decoration: const InputDecoration(hintText: 'Scan or type a barcode', prefixIcon: Icon(Icons.qr_code_rounded)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      tooltip: 'Scan with camera',
                      onPressed: _scan,
                      padding: const EdgeInsets.all(14),
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (p != null)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppColors.navy, AppColors.navyLight], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      children: [
                        Text(p.name, textAlign: TextAlign.center, style: textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                        if (p.barcode != null) Text(p.barcode!, style: const TextStyle(color: Colors.white60)),
                        const SizedBox(height: 16),
                        Text(money(p.price), style: textTheme.displaySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
                        if (money.hasSecondary)
                          Text(money.secondary(p.price), style: textTheme.titleLarge?.copyWith(color: Colors.white70)),
                        const SizedBox(height: 16),
                        StockBadge(product: p),
                        const SizedBox(height: 16),
                        if (p.active)
                          FilledButton.icon(
                            style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.primary),
                            onPressed: () {
                              addToCart(context, ref, p);
                              ref.read(sectionProvider.notifier).state = AppSection.register;
                            },
                            icon: const Icon(Icons.add_shopping_cart_rounded),
                            label: const Text('Add to sale'),
                          ),
                      ],
                    ),
                  )
                else if (_notFound != null)
                  EmptyState(icon: Icons.search_off_rounded, title: 'No product found', message: 'Nothing matches barcode "$_notFound".')
                else
                  const EmptyState(icon: Icons.qr_code_scanner_rounded, title: 'Scan an item to see its price'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
