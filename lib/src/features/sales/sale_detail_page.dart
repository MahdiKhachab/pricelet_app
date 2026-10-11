import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:pricelet_app/entity/sale_entity.dart';
import 'package:pricelet_app/src/core/money.dart';
import 'package:pricelet_app/src/core/theme.dart';
import 'package:pricelet_app/src/core/widgets.dart';
import 'package:pricelet_app/src/features/auth/auth.dart';
import 'package:pricelet_app/src/features/sales/receipt_pdf.dart';
import 'package:pricelet_app/src/features/sales/sales_service.dart';

/// Receipt view for a sale, with print/share and refund actions.
class SaleDetailPage extends ConsumerWidget {
  final int saleId;

  /// True right after checkout: shows a prominent "New sale" button.
  final bool justCompleted;

  const SaleDetailPage({super.key, required this.saleId, this.justCompleted = false});

  Future<void> _print(BuildContext context, SaleDetail detail, Money money) async {
    try {
      await Printing.layoutPdf(
        name: 'Receipt ${detail.sale.receiptNo}',
        format: PdfPageFormat.roll80,
        onLayout: (_) => buildReceiptPdf(detail, money),
      );
    } catch (e) {
      if (context.mounted) showMessage(context, 'Printing failed: $e', error: true);
    }
  }

  Future<void> _share(BuildContext context, SaleDetail detail, Money money) async {
    try {
      final bytes = await buildReceiptPdf(detail, money);
      await Printing.sharePdf(bytes: bytes, filename: 'receipt-${detail.sale.id}.pdf');
    } catch (e) {
      if (context.mounted) showMessage(context, 'Could not share receipt: $e', error: true);
    }
  }

  Future<void> _refund(BuildContext context, WidgetRef ref, Sale sale, Money money) async {
    final ok = await confirmAction(
      context,
      title: 'Refund sale ${sale.receiptNo}?',
      message: 'Return ${money(sale.total)} to the customer. Items go back into stock.',
      confirmLabel: 'Refund',
      destructive: true,
    );
    if (!ok) return;
    await ref.read(salesServiceProvider).refund(sale);
    if (context.mounted) showMessage(context, 'Sale refunded');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(saleDetailProvider(saleId));
    final money = ref.watch(moneyProvider);
    final isAdmin = ref.watch(isAdminProvider);
    final detail = detailAsync.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(justCompleted ? 'Sale complete' : 'Sale ${detail?.sale.receiptNo ?? ''}'),
        actions: [
          if (detail != null) ...[
            IconButton(tooltip: 'Print', onPressed: () => _print(context, detail, money), icon: const Icon(Icons.print_rounded)),
            IconButton(tooltip: 'Share PDF', onPressed: () => _share(context, detail, money), icon: const Icon(Icons.ios_share_rounded)),
            if (isAdmin && !detail.sale.isRefunded)
              IconButton(
                tooltip: 'Refund',
                onPressed: () => _refund(context, ref, detail.sale, money),
                icon: const Icon(Icons.undo_rounded, color: AppColors.danger),
              ),
          ],
          const SizedBox(width: 8),
        ],
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(error: e),
        data: (detail) => detail == null
            ? const EmptyState(icon: Icons.receipt_long_outlined, title: 'Sale not found')
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Column(
                      children: [
                        if (justCompleted) _CompletedBanner(sale: detail.sale, money: money),
                        ReceiptView(detail: detail, money: money),
                      ],
                    ),
                  ),
                ),
              ),
      ),
      bottomNavigationBar: justCompleted && detail != null
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _print(context, detail, money),
                        icon: const Icon(Icons.print_rounded),
                        label: const Text('Print receipt'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        autofocus: true,
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.add_shopping_cart_rounded),
                        label: const Text('New sale'),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}

class _CompletedBanner extends StatelessWidget {
  final Sale sale;
  final Money money;

  const _CompletedBanner({required this.sale, required this.money});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.navy, AppColors.navyLight]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 44),
          const SizedBox(height: 8),
          Text('Paid ${money(sale.total)}', style: textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
          if (sale.changeDue > 0) ...[
            const SizedBox(height: 4),
            Text('Change due: ${money(sale.changeDue)}', style: textTheme.titleMedium?.copyWith(color: Colors.white)),
            if (money.hasSecondary)
              Text(money.secondary(sale.changeDue), style: textTheme.bodyMedium?.copyWith(color: Colors.white70)),
          ],
        ],
      ),
    );
  }
}

/// On-screen version of the printed receipt.
class ReceiptView extends StatelessWidget {
  final SaleDetail detail;
  final Money money;

  const ReceiptView({super.key, required this.detail, required this.money});

  @override
  Widget build(BuildContext context) {
    final sale = detail.sale;
    final settings = money.settings;
    final textTheme = Theme.of(context).textTheme;
    const muted = TextStyle(color: AppColors.muted);

    Widget row(String label, String value, {TextStyle? style}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [Expanded(child: Text(label, style: style ?? muted)), Text(value, style: style)]),
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(settings.storeName, textAlign: TextAlign.center, style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            if (settings.storeAddress.isNotEmpty) Text(settings.storeAddress, textAlign: TextAlign.center, style: muted),
            if (settings.storePhone.isNotEmpty) Text(settings.storePhone, textAlign: TextAlign.center, style: muted),
            const SizedBox(height: 12),
            if (sale.isRefunded)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Center(child: StatusChip(label: 'REFUNDED', color: AppColors.danger)),
              ),
            row('Receipt', sale.receiptNo),
            row('Date', dateTimeFormat.format(sale.date)),
            if (detail.cashier != null) row('Cashier', detail.cashier!.name),
            if (detail.customer != null) row('Customer', detail.customer!.name),
            const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider()),
            for (final item in detail.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text('${item.quantity} × ${money(item.unitPrice)}', style: muted),
                        ],
                      ),
                    ),
                    Text(money(item.lineTotal), style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider()),
            row('Subtotal', money(sale.subtotal)),
            if (sale.discount > 0) row('Discount', '-${money(sale.discount)}'),
            if (sale.tax > 0) row('Tax', money(sale.tax)),
            const SizedBox(height: 4),
            row('Total', money(sale.total), style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            if (settings.secondaryEnabled && sale.exchangeRate != 1)
              Align(
                alignment: Alignment.centerRight,
                child: Text(money.formatSecondary(sale.total * sale.exchangeRate), style: muted),
              ),
            const SizedBox(height: 8),
            row('Paid (${PaymentMethod.label(sale.paymentMethod)})', money(sale.amountPaid)),
            if (sale.changeDue > 0) row('Change', money(sale.changeDue)),
            if (settings.receiptFooter.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(settings.receiptFooter, textAlign: TextAlign.center, style: muted),
            ],
          ],
        ),
      ),
    );
  }
}
