import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pricelet_app/src/core/money.dart';
import 'package:pricelet_app/src/core/theme.dart';
import 'package:pricelet_app/src/features/reports/reports_service.dart';

/// Single-series bar chart of sales per day. The card title names the series,
/// so there is no legend; each bar shows its value in a tooltip.
class SalesBarChart extends StatelessWidget {
  final List<DailyTotal> days;
  final Money money;
  final double height;

  const SalesBarChart({super.key, required this.days, required this.money, this.height = 180});

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return SizedBox(height: height);
    final max = days.fold<double>(0, (m, d) => d.total > m ? d.total : m);
    final labelEvery = (days.length / 7).ceil();
    final labelFormat = days.length <= 7 ? DateFormat('EEE') : DateFormat('d MMM');
    const axisStyle = TextStyle(fontSize: 11, color: AppColors.subtle);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Peak ${money(max)}', style: axisStyle),
        const SizedBox(height: 6),
        SizedBox(
          height: height,
          child: DecoratedBox(
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE0E5EE)))),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final d in days)
                  Expanded(
                    child: Tooltip(
                      message: '${dateFormat.format(d.day)}\n${money(d.total)} · ${d.count} sales',
                      waitDuration: Duration.zero,
                      triggerMode: TooltipTriggerMode.tap,
                      // Full-height hit target, larger than the bar itself.
                      child: Container(
                        color: Colors.transparent,
                        alignment: Alignment.bottomCenter,
                        padding: const EdgeInsets.symmetric(horizontal: 1),
                        child: FractionallySizedBox(
                          heightFactor: max <= 0 ? 0 : (d.total / max).clamp(0.0, 1.0),
                          widthFactor: days.length > 20 ? 0.8 : 0.6,
                          child: Container(
                            constraints: BoxConstraints(minHeight: d.total > 0 ? 2 : 0),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (var i = 0; i < days.length; i++)
              Expanded(
                child: Text(
                  i % labelEvery == 0 ? labelFormat.format(days[i].day) : '',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  softWrap: false,
                  style: axisStyle,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
