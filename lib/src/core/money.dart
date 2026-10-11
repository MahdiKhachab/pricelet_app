import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pricelet_app/src/features/settings/app_settings.dart';

/// Rounds [value] to [decimals] places, avoiding binary floating point drift.
double roundMoney(double value, [int decimals = 2]) {
  final factor = math.pow(10, decimals);
  return (value * factor).roundToDouble() / factor;
}

/// Formats amounts in the store's primary and (optional) secondary currency.
class Money {
  final AppSettings settings;

  Money(this.settings);

  bool get hasSecondary => settings.secondaryEnabled && settings.exchangeRate > 0;

  String call(double amount) =>
      _format(amount, settings.currencySymbol, settings.currencyDecimals);

  double toSecondary(double amount) => amount * settings.exchangeRate;

  double fromSecondary(double amount) =>
      settings.exchangeRate <= 0 ? amount : amount / settings.exchangeRate;

  /// Converts a primary amount at the current rate and formats it.
  String secondary(double amount) => formatSecondary(toSecondary(amount));

  /// Formats an amount already expressed in the secondary currency.
  String formatSecondary(double amount) =>
      _format(amount, settings.secondarySymbol, settings.secondaryDecimals);

  /// "$12.50  ·  1,118,750 L.L" when a secondary currency is enabled.
  String both(double amount) => hasSecondary ? '${call(amount)}  ·  ${secondary(amount)}' : call(amount);

  static String _format(double amount, String symbol, int decimals) {
    final pattern = decimals <= 0 ? '#,##0' : '#,##0.${'0' * decimals}';
    final number = NumberFormat(pattern, 'en_US').format(amount.abs());
    final sign = amount < 0 ? '-' : '';
    // Short symbols ($, €) go in front; longer codes (L.L, USD) after.
    return symbol.length <= 1 ? '$sign$symbol$number' : '$sign$number $symbol';
  }
}

final moneyProvider = Provider<Money>((ref) => Money(ref.watch(settingsProvider)));

final dateTimeFormat = DateFormat('dd MMM yyyy, HH:mm');
final dateFormat = DateFormat('dd MMM yyyy');
final timeFormat = DateFormat('HH:mm');
