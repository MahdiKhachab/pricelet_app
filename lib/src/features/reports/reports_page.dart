import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pricelet_app/entity/sale_entity.dart';
import 'package:pricelet_app/src/core/money.dart';
import 'package:pricelet_app/src/core/theme.dart';
import 'package:pricelet_app/src/core/widgets.dart';
import 'package:pricelet_app/src/features/reports/reports_service.dart';
import 'package:pricelet_app/src/features/reports/sales_bar_chart.dart';
import 'package:pricelet_app/src/features/sales/date_range_bar.dart';
import 'package:pricelet_app/src/features/sales/sales_service.dart';
import 'package:pricelet_app/src/features/shell/app_shell.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  DateRange _range = DateRange.lastDays(7);

  @override
  Widget build(BuildContext context) {
    final reportAsync = ref.watch(salesReportProvider(_range));
    final money = ref.watch(moneyProvider);

    return ShellScaffold(
      title: 'Reports',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          DateRangeBar(range: _range, onChanged: (r) => setState(() => _range = r)),
          const SizedBox(height: 12),
          reportAsync.when(
            loading: () => const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator())),
            error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(salesReportProvider(_range))),
            data: (r) => _ReportBody(report: r, money: money),
          ),
        ],
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  final SalesReport report;
  final Money money;

  const _ReportBody({required this.report, required this.money});

  @override
  Widget build(BuildContext context) {
    final r = report;
    Widget line(String label, String value, {bool strong = false, Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Expanded(child: Text(label, style: TextStyle(color: strong ? AppColors.ink : AppColors.muted, fontWeight: strong ? FontWeight.w700 : null))),
            Text(value, style: TextStyle(fontWeight: strong ? FontWeight.w800 : FontWeight.w600, color: color)),
          ]),
        );

    final summary = SectionCard(
      title: 'Profit & loss',
      child: Column(
        children: [
          line('Gross sales', money(r.grossSales)),
          line('Discounts', '-${money(r.discounts)}'),
          line('Net sales', money(r.netSales), strong: true),
          line('Cost of goods sold', '-${money(r.cost)}'),
          line('Gross profit', money(r.grossProfit), strong: true, color: r.grossProfit < 0 ? AppColors.danger : AppColors.success),
          const Divider(height: 20),
          line('Tax collected', money(r.tax)),
          line('Total collected', money(r.total), strong: true),
          line('Refunds (${r.refundCount})', money(r.refundTotal)),
        ],
      ),
    );

    final payments = SectionCard(
      title: 'Payment methods',
      child: r.payments.isEmpty
          ? const Text('No sales in this period.', style: TextStyle(color: AppColors.muted))
          : Column(
              children: [
                for (final p in r.payments)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(children: [
                          Expanded(child: Text('${PaymentMethod.label(p.method)} · ${p.count}', style: const TextStyle(fontWeight: FontWeight.w600))),
                          Text(money(p.total), style: const TextStyle(fontWeight: FontWeight.w700)),
                        ]),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: r.total <= 0 ? 0 : p.total / r.total,
                            minHeight: 8,
                            color: AppColors.primary,
                            backgroundColor: AppColors.primarySoft,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );

    final top = SectionCard(
      title: 'Top products',
      child: r.topProducts.isEmpty
          ? const Text('No sales in this period.', style: TextStyle(color: AppColors.muted))
          : _scrollTable(DataTable(
              headingTextStyle: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.muted),
              columns: const [
                DataColumn(label: Text('Product')),
                DataColumn(label: Text('Qty'), numeric: true),
                DataColumn(label: Text('Revenue'), numeric: true),
              ],
              rows: [
                for (final p in r.topProducts)
                  DataRow(cells: [DataCell(Text(p.name)), DataCell(Text('${p.quantity}')), DataCell(Text(money(p.revenue)))]),
              ],
            )),
    );

    final showChart = r.daily.length > 1 && r.daily.length <= 62;
    final daily = SectionCard(
      title: 'Total collected per day',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showChart) ...[SalesBarChart(days: r.daily, money: money), const SizedBox(height: 16)],
          // Table view of the same data.
          _scrollTable(DataTable(
            headingTextStyle: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.muted),
            columns: const [
              DataColumn(label: Text('Day')),
              DataColumn(label: Text('Sales'), numeric: true),
              DataColumn(label: Text('Total'), numeric: true),
            ],
            rows: [
              for (final d in r.daily.reversed.where((d) => d.count > 0 || r.daily.length <= 31))
                DataRow(cells: [DataCell(Text(dateFormat.format(d.day))), DataCell(Text('${d.count}')), DataCell(Text(money(d.total)))]),
            ],
          )),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ResponsiveGrid(children: [
          StatTile(label: 'Net sales', value: money(r.netSales), icon: Icons.payments_rounded),
          StatTile(label: 'Gross profit', value: money(r.grossProfit), icon: Icons.trending_up_rounded, color: AppColors.success, caption: '${r.marginPercent.toStringAsFixed(1)}% margin'),
          StatTile(label: 'Transactions', value: '${r.salesCount}', icon: Icons.receipt_long_rounded, color: const Color(0xFF7A5AF8), caption: '${r.itemsSold} items'),
          StatTile(label: 'Average sale', value: money(r.averageSale), icon: Icons.shopping_basket_rounded, color: const Color(0xFF0E9384)),
        ]),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, c) {
          if (c.maxWidth < 760) {
            return Column(children: [summary, const SizedBox(height: 16), payments, const SizedBox(height: 16), top, const SizedBox(height: 16), daily]);
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Column(children: [summary, const SizedBox(height: 16), payments])),
              const SizedBox(width: 16),
              Expanded(child: Column(children: [top, const SizedBox(height: 16), daily])),
            ],
          );
        }),
      ],
    );
  }

  Widget _scrollTable(Widget table) => SingleChildScrollView(scrollDirection: Axis.horizontal, child: table);
}
