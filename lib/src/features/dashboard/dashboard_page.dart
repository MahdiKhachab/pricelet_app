import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pricelet_app/entity/product_entity.dart';
import 'package:pricelet_app/src/core/money.dart';
import 'package:pricelet_app/src/core/theme.dart';
import 'package:pricelet_app/src/core/widgets.dart';
import 'package:pricelet_app/src/features/auth/auth.dart';
import 'package:pricelet_app/src/features/products/product_edit_page.dart';
import 'package:pricelet_app/src/features/products/product_list_page.dart';
import 'package:pricelet_app/src/features/products/products_service.dart';
import 'package:pricelet_app/src/features/reports/reports_service.dart';
import 'package:pricelet_app/src/features/reports/sales_bar_chart.dart';
import 'package:pricelet_app/src/features/sales/sale_detail_page.dart';
import 'package:pricelet_app/src/features/sales/sales_service.dart';
import 'package:pricelet_app/src/features/shell/app_shell.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final today = DateRange.day(now);
    final week = DateRange.lastDays(7, now: now);
    final todayAsync = ref.watch(salesReportProvider(today));
    final weekAsync = ref.watch(salesReportProvider(week));
    final money = ref.watch(moneyProvider);
    final user = ref.watch(currentUserProvider);
    final products = ref.watch(productsProvider).valueOrNull ?? const <Product>[];
    final lowStock = products.where((p) => p.active && p.isLowStock).toList()..sort((a, b) => a.stock.compareTo(b.stock));

    final greeting = now.hour < 12 ? 'Good morning' : (now.hour < 18 ? 'Good afternoon' : 'Good evening');

    return ShellScaffold(
      title: 'Dashboard',
      actions: [
        if (MediaQuery.sizeOf(context).width >= 600)
          FilledButton.icon(
            onPressed: () => ref.read(sectionProvider.notifier).state = AppSection.register,
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
            icon: const Icon(Icons.point_of_sale_rounded),
            label: const Text('Open register'),
          )
        else
          IconButton.filled(
            tooltip: 'Open register',
            onPressed: () => ref.read(sectionProvider.notifier).state = AppSection.register,
            icon: const Icon(Icons.point_of_sale_rounded),
          ),
      ],
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(salesReportProvider),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Text('$greeting, ${user?.name ?? ''}', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.muted)),
            const SizedBox(height: 12),
            todayAsync.when(
              loading: () => const SizedBox(height: 90, child: Center(child: CircularProgressIndicator())),
              error: (e, _) => ErrorView(error: e),
              data: (r) => ResponsiveGrid(
                children: [
                  StatTile(label: "Today's sales", value: money(r.total), icon: Icons.payments_rounded, caption: money.hasSecondary ? money.secondary(r.total) : null),
                  StatTile(label: 'Transactions', value: '${r.salesCount}', icon: Icons.receipt_long_rounded, color: const Color(0xFF7A5AF8), caption: '${r.itemsSold} items sold'),
                  StatTile(label: 'Average sale', value: money(r.averageSale), icon: Icons.shopping_basket_rounded, color: const Color(0xFF0E9384)),
                  StatTile(
                    label: 'Gross profit',
                    value: money(r.grossProfit),
                    icon: Icons.trending_up_rounded,
                    color: AppColors.success,
                    caption: '${r.marginPercent.toStringAsFixed(1)}% margin',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(builder: (context, constraints) {
              final chart = SectionCard(
                title: 'Total collected · last 7 days',
                child: weekAsync.when(
                  loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
                  error: (e, _) => ErrorView(error: e),
                  data: (r) => SalesBarChart(days: r.daily, money: money),
                ),
              );
              final top = SectionCard(
                title: 'Top sellers · 7 days',
                child: weekAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (e, _) => const SizedBox.shrink(),
                  data: (r) => r.topProducts.isEmpty
                      ? const Text('No sales yet.', style: TextStyle(color: AppColors.muted))
                      : Column(
                          children: [
                            for (final (i, p) in r.topProducts.take(5).indexed)
                              ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(radius: 13, backgroundColor: AppColors.primarySoft, child: Text('${i + 1}', style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w700))),
                                title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                                subtitle: Text('${p.quantity} sold'),
                                trailing: Text(money(p.revenue), style: const TextStyle(fontWeight: FontWeight.w700)),
                              ),
                          ],
                        ),
                ),
              );
              if (constraints.maxWidth < 760) return Column(children: [chart, const SizedBox(height: 16), top]);
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Expanded(flex: 3, child: chart), const SizedBox(width: 16), Expanded(flex: 2, child: top)],
              );
            }),
            const SizedBox(height: 16),
            LayoutBuilder(builder: (context, constraints) {
              final low = _LowStockCard(products: lowStock);
              final recent = _RecentSalesCard(range: today, money: money);
              if (constraints.maxWidth < 760) return Column(children: [low, const SizedBox(height: 16), recent]);
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Expanded(child: low), const SizedBox(width: 16), Expanded(child: recent)],
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _LowStockCard extends ConsumerWidget {
  final List<Product> products;

  const _LowStockCard({required this.products});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SectionCard(
      title: 'Low stock',
      trailing: products.isEmpty
          ? null
          : TextButton(onPressed: () => ref.read(sectionProvider.notifier).state = AppSection.products, child: const Text('View all')),
      child: products.isEmpty
          ? const Row(children: [
              Icon(Icons.check_circle_outline_rounded, color: AppColors.success),
              SizedBox(width: 8),
              Expanded(child: Text('All products are well stocked.')),
            ])
          : Column(
              children: [
                for (final p in products.take(6))
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: StockBadge(product: p),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductEditPage(product: p))),
                  ),
              ],
            ),
    );
  }
}

class _RecentSalesCard extends ConsumerWidget {
  final DateRange range;
  final Money money;

  const _RecentSalesCard({required this.range, required this.money});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salesAsync = ref.watch(salesInRangeProvider(range));
    return SectionCard(
      title: "Today's sales",
      trailing: TextButton(onPressed: () => ref.read(sectionProvider.notifier).state = AppSection.sales, child: const Text('History')),
      child: salesAsync.when(
        loading: () => const SizedBox.shrink(),
        error: (e, _) => ErrorView(error: e),
        data: (sales) => sales.isEmpty
            ? const Text('No sales yet today.', style: TextStyle(color: AppColors.muted))
            : Column(
                children: [
                  for (final s in sales.take(6))
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text('${s.receiptNo} · ${timeFormat.format(s.date)}'),
                      trailing: Text(
                        money(s.total),
                        style: TextStyle(fontWeight: FontWeight.w700, decoration: s.isRefunded ? TextDecoration.lineThrough : null),
                      ),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SaleDetailPage(saleId: s.id!))),
                    ),
                ],
              ),
      ),
    );
  }
}
