import 'package:flutter/material.dart';
import 'package:pricelet_app/src/core/money.dart';
import 'package:pricelet_app/src/features/sales/sales_service.dart';

/// Preset chips (today, yesterday, 7 days, this month) plus a custom picker.
class DateRangeBar extends StatelessWidget {
  final DateRange range;
  final ValueChanged<DateRange> onChanged;

  const DateRangeBar({super.key, required this.range, required this.onChanged});

  Future<void> _pickCustom(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: DateTimeRange(start: range.start, end: range.end.subtract(const Duration(days: 1))),
    );
    if (picked != null) onChanged(DateRange(picked.start, DateRange.day(picked.end).end));
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final presets = <String, DateRange>{
      'Today': DateRange.day(now),
      'Yesterday': DateRange.day(DateTime(now.year, now.month, now.day - 1)),
      'Last 7 days': DateRange.lastDays(7, now: now),
      'Last 30 days': DateRange.lastDays(30, now: now),
      'This month': DateRange.thisMonth(now: now),
    };
    final isPreset = presets.containsValue(range);
    final lastDay = range.end.subtract(const Duration(days: 1));
    final customLabel = isPreset
        ? 'Custom'
        : (DateRange.day(range.start) == DateRange.day(lastDay)
            ? dateFormat.format(range.start)
            : '${dateFormat.format(range.start)} – ${dateFormat.format(lastDay)}');

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final entry in presets.entries)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(label: Text(entry.key), selected: range == entry.value, onSelected: (_) => onChanged(entry.value)),
            ),
          ChoiceChip(
            avatar: const Icon(Icons.date_range_rounded, size: 18),
            label: Text(customLabel),
            selected: !isPreset,
            onSelected: (_) => _pickCustom(context),
          ),
        ],
      ),
    );
  }
}
