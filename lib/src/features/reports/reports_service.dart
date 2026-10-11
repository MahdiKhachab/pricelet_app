import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pricelet_app/entity/sale_entity.dart';
import 'package:pricelet_app/src/core/providers.dart';
import 'package:pricelet_app/src/features/sales/sales_service.dart';

class TopProduct {
  final String name;
  final int quantity;
  final double revenue;

  const TopProduct(this.name, this.quantity, this.revenue);
}

class PaymentBreakdown {
  final String method;
  final int count;
  final double total;

  const PaymentBreakdown(this.method, this.count, this.total);
}

class DailyTotal {
  final DateTime day;
  final double total;
  final int count;

  const DailyTotal(this.day, this.total, this.count);
}

/// Aggregated figures for completed (non-refunded) sales in a date range.
class SalesReport {
  final int salesCount;
  final double grossSales; // before discounts
  final double discounts;
  final double tax;
  final double total; // collected, incl. tax
  final double cost;
  final int itemsSold;
  final int refundCount;
  final double refundTotal;
  final List<PaymentBreakdown> payments;
  final List<TopProduct> topProducts;
  final List<DailyTotal> daily;

  const SalesReport({
    required this.salesCount,
    required this.grossSales,
    required this.discounts,
    required this.tax,
    required this.total,
    required this.cost,
    required this.itemsSold,
    required this.refundCount,
    required this.refundTotal,
    required this.payments,
    required this.topProducts,
    required this.daily,
  });

  double get netSales => grossSales - discounts;
  double get grossProfit => netSales - cost;
  double get averageSale => salesCount == 0 ? 0 : total / salesCount;
  double get marginPercent => netSales <= 0 ? 0 : grossProfit / netSales * 100;
}

final salesReportProvider = FutureProvider.family<SalesReport, DateRange>((ref, range) {
  ref.watch(dataVersionProvider);
  return ReportsService(ref).build(range);
});

double _d(Object? v) => (v as num?)?.toDouble() ?? 0;
int _i(Object? v) => (v as num?)?.toInt() ?? 0;

class ReportsService {
  final Ref _ref;

  ReportsService(this._ref);

  Future<SalesReport> build(DateRange range, {int topLimit = 10}) async {
    final db = _ref.read(databaseProvider).database;
    final args = [SaleStatus.completed, range.startMs, range.endMs];
    const where = 'status = ? AND createdAt >= ? AND createdAt < ?';
    const joinWhere = 's.status = ? AND s.createdAt >= ? AND s.createdAt < ?';

    final summary = (await db.rawQuery(
      'SELECT COUNT(*) AS n, SUM(subtotal) AS gross, SUM(discount) AS disc, SUM(tax) AS tax, SUM(total) AS total '
      'FROM sales WHERE $where',
      args,
    ))
        .first;

    final items = (await db.rawQuery(
      'SELECT SUM(si.quantity * si.unitCost) AS cost, SUM(si.quantity) AS qty '
      'FROM sale_items si JOIN sales s ON s.id = si.saleId WHERE $joinWhere',
      args,
    ))
        .first;

    final refunds = (await db.rawQuery(
      'SELECT COUNT(*) AS n, SUM(total) AS total FROM sales WHERE $where',
      [SaleStatus.refunded, range.startMs, range.endMs],
    ))
        .first;

    final payments = await db.rawQuery(
      'SELECT paymentMethod, COUNT(*) AS n, SUM(total) AS total FROM sales WHERE $where '
      'GROUP BY paymentMethod ORDER BY total DESC',
      args,
    );

    final top = await db.rawQuery(
      'SELECT si.name AS name, SUM(si.quantity) AS qty, SUM(si.lineTotal) AS revenue '
      'FROM sale_items si JOIN sales s ON s.id = si.saleId WHERE $joinWhere '
      'GROUP BY COALESCE(si.productId, si.name) ORDER BY revenue DESC LIMIT $topLimit',
      args,
    );

    // Group by local calendar day in Dart so time zones are handled correctly.
    final rows = await db.rawQuery('SELECT createdAt, total FROM sales WHERE $where', args);
    final byDay = <DateTime, DailyTotal>{};
    for (var d = range.start; d.isBefore(range.end); d = DateTime(d.year, d.month, d.day + 1)) {
      byDay[d] = DailyTotal(d, 0, 0);
    }
    for (final row in rows) {
      final t = DateTime.fromMillisecondsSinceEpoch(_i(row['createdAt']));
      final day = DateTime(t.year, t.month, t.day);
      final prev = byDay[day] ?? DailyTotal(day, 0, 0);
      byDay[day] = DailyTotal(day, prev.total + _d(row['total']), prev.count + 1);
    }

    return SalesReport(
      salesCount: _i(summary['n']),
      grossSales: _d(summary['gross']),
      discounts: _d(summary['disc']),
      tax: _d(summary['tax']),
      total: _d(summary['total']),
      cost: _d(items['cost']),
      itemsSold: _i(items['qty']),
      refundCount: _i(refunds['n']),
      refundTotal: _d(refunds['total']),
      payments: [
        for (final p in payments) PaymentBreakdown(p['paymentMethod'] as String, _i(p['n']), _d(p['total'])),
      ],
      topProducts: [
        for (final t in top) TopProduct(t['name'] as String, _i(t['qty']), _d(t['revenue'])),
      ],
      daily: byDay.values.toList()..sort((a, b) => a.day.compareTo(b.day)),
    );
  }
}
