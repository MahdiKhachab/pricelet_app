import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pricelet_app/entity/sale_entity.dart';
import 'package:pricelet_app/src/core/money.dart';
import 'package:pricelet_app/src/features/sales/sales_service.dart';

/// Builds an 80mm thermal-printer receipt for [detail].
Future<Uint8List> buildReceiptPdf(SaleDetail detail, Money money) async {
  final sale = detail.sale;
  final settings = money.settings;
  final doc = pw.Document(title: 'Receipt ${sale.receiptNo}');
  const small = pw.TextStyle(fontSize: 8);
  final bold = pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold);

  pw.Widget row(String label, String value, {pw.TextStyle? style}) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [pw.Text(label, style: style ?? small), pw.Text(value, style: style ?? small)],
      );

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.roll80.copyWith(marginLeft: 12, marginRight: 12, marginTop: 12, marginBottom: 12),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Text(settings.storeName, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          if (settings.storeAddress.isNotEmpty) pw.Text(settings.storeAddress, textAlign: pw.TextAlign.center, style: small),
          if (settings.storePhone.isNotEmpty) pw.Text(settings.storePhone, textAlign: pw.TextAlign.center, style: small),
          pw.SizedBox(height: 6),
          if (sale.isRefunded)
            pw.Text('*** REFUNDED ***', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          row('Receipt', sale.receiptNo),
          row('Date', dateTimeFormat.format(sale.date)),
          if (detail.cashier != null) row('Cashier', detail.cashier!.name),
          if (detail.customer != null) row('Customer', detail.customer!.name),
          pw.Divider(thickness: 0.5),
          for (final item in detail.items) ...[
            pw.Text(item.name, style: bold),
            row('  ${item.quantity} x ${money(item.unitPrice)}', money(item.lineTotal)),
          ],
          pw.Divider(thickness: 0.5),
          row('Subtotal', money(sale.subtotal)),
          if (sale.discount > 0) row('Discount', '-${money(sale.discount)}'),
          if (sale.tax > 0) row('Tax', money(sale.tax)),
          row('TOTAL', money(sale.total), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          if (settings.secondaryEnabled && sale.exchangeRate > 0 && sale.exchangeRate != 1)
            row('', money.formatSecondary(sale.total * sale.exchangeRate)),
          pw.SizedBox(height: 4),
          row(PaymentMethod.label(sale.paymentMethod), money(sale.amountPaid)),
          if (sale.changeDue > 0) row('Change', money(sale.changeDue)),
          pw.SizedBox(height: 10),
          if (settings.receiptFooter.isNotEmpty) pw.Text(settings.receiptFooter, textAlign: pw.TextAlign.center, style: small),
        ],
      ),
    ),
  );
  return doc.save();
}
