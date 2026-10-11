import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pricelet_app/entity/sale_entity.dart';
import 'package:pricelet_app/src/core/money.dart';
import 'package:pricelet_app/src/core/theme.dart';
import 'package:pricelet_app/src/core/widgets.dart';
import 'package:pricelet_app/src/features/pos/cart.dart';
import 'package:pricelet_app/src/features/sales/sale_detail_page.dart';
import 'package:pricelet_app/src/features/sales/sales_service.dart';

/// Opens the payment dialog for the current cart. On success the cart is
/// cleared and the receipt is shown. Returns whether a sale was completed.
Future<bool> startCheckout(BuildContext context, WidgetRef ref) async {
  if (ref.read(cartProvider).isEmpty) return false;
  final saleId = await showDialog<int>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const CheckoutDialog(),
  );
  if (saleId == null || !context.mounted) return false;
  ref.read(cartProvider.notifier).clear();
  await Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => SaleDetailPage(saleId: saleId, justCompleted: true)),
  );
  return true;
}

class CheckoutDialog extends ConsumerStatefulWidget {
  const CheckoutDialog({super.key});

  @override
  ConsumerState<CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends ConsumerState<CheckoutDialog> {
  final _tendered = TextEditingController();
  String _method = PaymentMethod.cash;
  bool _inSecondary = false;
  bool _saving = false;

  @override
  void dispose() {
    _tendered.dispose();
    super.dispose();
  }

  /// Amount tendered converted to the primary currency.
  double? _paid(Money money) {
    final value = parseDecimal(_tendered.text);
    if (value == null) return null;
    return _inSecondary ? money.fromSecondary(value) : value;
  }

  Future<void> _complete(double total, Money money) async {
    final paid = _method == PaymentMethod.cash ? (_paid(money) ?? total) : total;
    if (paid + 0.000001 < total) {
      showMessage(context, 'Amount tendered is less than the total', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final id = await ref.read(salesServiceProvider).checkout(
            ref.read(cartProvider),
            paymentMethod: _method,
            amountPaid: paid,
          );
      if (mounted) Navigator.pop(context, id);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showMessage(context, 'Could not complete sale: $e', error: true);
      }
    }
  }

  /// Exact amount plus a few round notes above it.
  List<double> _suggestions(double total) {
    final result = <double>{total};
    for (final step in [1, 5, 10, 20, 50, 100]) {
      final rounded = (total / step).ceil() * step.toDouble();
      if (rounded > total) result.add(rounded);
      if (result.length >= 5) break;
    }
    return result.toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    final totals = ref.watch(cartTotalsProvider);
    final money = ref.watch(moneyProvider);
    final total = totals.total;
    final paid = _paid(money);
    final change = paid == null ? 0.0 : math.max(0.0, paid - total);
    final short = paid != null && paid + 0.000001 < total;
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      title: const Text('Payment'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  children: [
                    const Text('Amount due', style: TextStyle(color: AppColors.muted)),
                    Text(money(total), style: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
                    if (money.hasSecondary) Text(money.secondary(total), style: textTheme.titleMedium?.copyWith(color: AppColors.muted)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: PaymentMethod.cash, label: Text('Cash'), icon: Icon(Icons.payments_outlined)),
                  ButtonSegment(value: PaymentMethod.card, label: Text('Card'), icon: Icon(Icons.credit_card_rounded)),
                  ButtonSegment(value: PaymentMethod.other, label: Text('Other'), icon: Icon(Icons.more_horiz_rounded)),
                ],
                selected: {_method},
                onSelectionChanged: (s) => setState(() => _method = s.first),
              ),
              if (_method == PaymentMethod.cash) ...[
                const SizedBox(height: 16),
                if (money.hasSecondary)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SegmentedButton<bool>(
                      segments: [
                        ButtonSegment(value: false, label: Text('Paid in ${money.settings.currencySymbol}')),
                        ButtonSegment(value: true, label: Text('Paid in ${money.settings.secondarySymbol}')),
                      ],
                      selected: {_inSecondary},
                      onSelectionChanged: (s) => setState(() {
                        _inSecondary = s.first;
                        _tendered.clear();
                      }),
                    ),
                  ),
                TextField(
                  controller: _tendered,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: decimalInputFormatters,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _saving ? null : _complete(total, money),
                  decoration: InputDecoration(
                    labelText: 'Cash received',
                    hintText: 'Leave empty for exact amount',
                    suffixText: _inSecondary ? money.settings.secondarySymbol : money.settings.currencySymbol,
                    errorText: short ? 'Less than amount due' : null,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final amount in _suggestions(_inSecondary ? money.toSecondary(total) : total))
                      ActionChip(
                        label: Text(_inSecondary
                            ? money.secondary(money.fromSecondary(amount))
                            : money(amount)),
                        onPressed: () => setState(() => _tendered.text = amount.toStringAsFixed(_inSecondary ? money.settings.secondaryDecimals : money.settings.currencyDecimals)),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text('Change', style: textTheme.titleMedium),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(money(change), style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, color: AppColors.success)),
                        if (money.hasSecondary) Text(money.secondary(change), style: const TextStyle(color: AppColors.muted)),
                      ],
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton.icon(
          onPressed: _saving || short ? null : () => _complete(total, money),
          icon: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.check_rounded),
          label: const Text('Complete sale'),
        ),
      ],
    );
  }
}
