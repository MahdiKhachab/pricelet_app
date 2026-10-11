import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pricelet_app/src/core/theme.dart';

/// Breakpoint above which pages use side-by-side layouts.
const wideLayoutWidth = 900.0;

bool isWide(BuildContext context) => MediaQuery.sizeOf(context).width >= wideLayoutWidth;

void showMessage(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? AppColors.danger : null,
    ));
}

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: AppColors.danger) : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.subtle),
            const SizedBox(height: 12),
            Text(title, style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600), textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(message!, style: textTheme.bodyMedium?.copyWith(color: AppColors.muted), textAlign: TextAlign.center),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;

  const ErrorView({super.key, required this.error, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.error_outline_rounded,
      title: 'Something went wrong',
      message: '$error',
      action: onRetry == null ? null : OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
    );
  }
}

/// White rounded card with an optional title row.
class SectionCard extends StatelessWidget {
  final String? title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const SectionCard({
    super.key,
    this.title,
    this.trailing,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(title!, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    ),
                    if (trailing != null) trailing!,
                  ],
                ),
              ),
            child,
          ],
        ),
      ),
    );
  }
}

class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? caption;

  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color = AppColors.primary,
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: textTheme.labelMedium?.copyWith(color: AppColors.muted)),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(value, style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  ),
                  if (caption != null)
                    Text(caption!, style: textTheme.labelSmall?.copyWith(color: AppColors.subtle), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lays out [children] in a responsive grid of equal-width tiles.
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double minTileWidth;
  final double spacing;

  const ResponsiveGrid({super.key, required this.children, this.minTileWidth = 220, this.spacing = 12});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final columns = (constraints.maxWidth / minTileWidth).floor().clamp(1, children.length);
      final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [for (final child in children) SizedBox(width: width, child: child)],
      );
    });
  }
}

class StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const StatusChip({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

class InitialAvatar extends StatelessWidget {
  final String name;
  final double radius;

  const InitialAvatar({super.key, required this.name, this.radius = 20});

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primarySoft,
      child: Text(
        trimmed.isEmpty ? '?' : trimmed[0].toUpperCase(),
        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: radius * 0.8),
      ),
    );
  }
}

/// Allows digits with an optional decimal separator.
final decimalInputFormatters = <TextInputFormatter>[
  FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d*')),
];

double? parseDecimal(String text) => double.tryParse(text.trim().replaceAll(',', '.'));

String? requiredValidator(String? value) => (value == null || value.trim().isEmpty) ? 'Required' : null;

String? decimalValidator(String? value) {
  if (value == null || value.trim().isEmpty) return 'Required';
  final parsed = parseDecimal(value);
  if (parsed == null || parsed < 0) return 'Enter a valid amount';
  return null;
}
