import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pricelet_app/entity/product_entity.dart';
import 'package:pricelet_app/entity/stock_movement_entity.dart';
import 'package:pricelet_app/src/core/theme.dart';
import 'package:pricelet_app/src/core/widgets.dart';
import 'package:pricelet_app/src/features/products/products_service.dart';

Future<void> showStockAdjustDialog(BuildContext context, Product product) {
  return showDialog(context: context, builder: (_) => _StockAdjustDialog(product: product));
}

enum _Mode { receive, remove, count }

class _StockAdjustDialog extends ConsumerStatefulWidget {
  final Product product;

  const _StockAdjustDialog({required this.product});

  @override
  ConsumerState<_StockAdjustDialog> createState() => _StockAdjustDialogState();
}

class _StockAdjustDialogState extends ConsumerState<_StockAdjustDialog> {
  final _quantity = TextEditingController();
  final _note = TextEditingController();
  _Mode _mode = _Mode.receive;
  bool _saving = false;

  @override
  void dispose() {
    _quantity.dispose();
    _note.dispose();
    super.dispose();
  }

  int? get _delta {
    final value = int.tryParse(_quantity.text);
    if (value == null) return null;
    switch (_mode) {
      case _Mode.receive:
        return value;
      case _Mode.remove:
        return -value;
      case _Mode.count:
        return value - widget.product.stock;
    }
  }

  Future<void> _save() async {
    final delta = _delta;
    if (delta == null || delta == 0) {
      Navigator.pop(context);
      return;
    }
    setState(() => _saving = true);
    final reason = _mode == _Mode.receive ? StockReason.restock : StockReason.adjustment;
    final note = _note.text.trim().isNotEmpty ? _note.text.trim() : (_mode == _Mode.count ? 'Stock count' : '');
    await ref.read(productsServiceProvider).adjustStock(widget.product, delta, reason, note);
    if (!mounted) return;
    Navigator.pop(context);
    showMessage(context, 'Stock updated');
  }

  @override
  Widget build(BuildContext context) {
    final delta = _delta;
    final after = widget.product.stock + (delta ?? 0);
    return AlertDialog(
      title: Text('Adjust stock · ${widget.product.name}'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<_Mode>(
              segments: const [
                ButtonSegment(value: _Mode.receive, label: Text('Receive'), icon: Icon(Icons.add_rounded)),
                ButtonSegment(value: _Mode.remove, label: Text('Remove'), icon: Icon(Icons.remove_rounded)),
                ButtonSegment(value: _Mode.count, label: Text('Count'), icon: Icon(Icons.fact_check_outlined)),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _quantity,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(labelText: _mode == _Mode.count ? 'Counted quantity' : 'Quantity'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              decoration: InputDecoration(labelText: _mode == _Mode.remove ? 'Reason (damaged, expired...)' : 'Note (supplier, invoice...)'),
            ),
            const SizedBox(height: 16),
            Text(
              'Stock: ${widget.product.stock} → $after',
              style: TextStyle(fontWeight: FontWeight.w700, color: after < 0 ? AppColors.danger : AppColors.ink),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _saving ? null : _save, child: const Text('Save')),
      ],
    );
  }
}
