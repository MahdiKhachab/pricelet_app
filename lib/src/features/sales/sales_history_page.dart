import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pricelet_app/entity/sale_entity.dart';
import 'package:pricelet_app/src/core/money.dart';
import 'package:pricelet_app/src/core/theme.dart';
import 'package:pricelet_app/src/core/widgets.dart';
import 'package:pricelet_app/src/features/sales/date_range_bar.dart';
import 'package:pricelet_app/src/features/sales/sale_detail_page.dart';
import 'package:pricelet_app/src/features/sales/sales_service.dart';
import 'package:pricelet_app/src/features/shell/app_shell.dart';

class SalesHistoryPage extends ConsumerStatefulWidget {
  const SalesHistoryPage({super.key});

  @override
  ConsumerState<SalesHistoryPage> createState() => _SalesHistoryPageState();
}

class _SalesHistoryPageState extends ConsumerState<SalesHistoryPage> {
  DateRange _range = DateRange.day(DateTime.now());
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final salesAsync = ref.watch(salesInRangeProvider(_range));
    final money = ref.watch(moneyProvider);

    return ShellScaffold(
      title: 'Sales',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: DateRangeBar(range: _range, onChanged: (r) => setState(() => _range = r)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: 'Find receipt number', prefixIcon: Icon(Icons.search_rounded)),
            ),
          ),
          Expanded(
            child: salesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorView(error: e),
              data: (all) {
                final query = _search.text.replaceAll('#', '').trim();
                final sales = query.isEmpty ? all : all.where((s) => '${s.id}'.contains(query)).toList();
                final completed = all.where((s) => !s.isRefunded);
                final total = completed.fold<double>(0, (sum, s) => sum + s.total);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: Text(
                        '${completed.length} sales · ${money(total)}',
                        style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Expanded(
                      child: sales.isEmpty
                          ? const EmptyState(icon: Icons.receipt_long_outlined, title: 'No sales in this period')
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                              itemCount: sales.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, i) => _SaleTile(sale: sales[i], money: money),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SaleTile extends StatelessWidget {
  final Sale sale;
  final Money money;

  const _SaleTile({required this.sale, required this.money});

  @override
  Widget build(BuildContext context) {
    final icon = switch (sale.paymentMethod) {
      PaymentMethod.cash => Icons.payments_outlined,
      PaymentMethod.card => Icons.credit_card_rounded,
      _ => Icons.more_horiz_rounded,
    };
    return Card(
      child: ListTile(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SaleDetailPage(saleId: sale.id!))),
        leading: CircleAvatar(backgroundColor: AppColors.primarySoft, child: Icon(icon, color: AppColors.primary)),
        title: Text(sale.receiptNo, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('${dateTimeFormat.format(sale.date)} · ${PaymentMethod.label(sale.paymentMethod)}'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              money(sale.total),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                decoration: sale.isRefunded ? TextDecoration.lineThrough : null,
                color: sale.isRefunded ? AppColors.subtle : null,
              ),
            ),
            if (sale.isRefunded) const StatusChip(label: 'Refunded', color: AppColors.danger),
          ],
        ),
      ),
    );
  }
}
