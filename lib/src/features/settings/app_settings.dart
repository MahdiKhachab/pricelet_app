import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pricelet_app/database/database.dart';
import 'package:pricelet_app/entity/setting_entity.dart';
import 'package:pricelet_app/src/core/providers.dart';

/// Store-wide configuration, persisted in the `settings` table.
class AppSettings {
  final String storeName;
  final String storeAddress;
  final String storePhone;
  final String receiptFooter;
  final String currencySymbol;
  final int currencyDecimals;
  final bool secondaryEnabled;
  final String secondarySymbol;
  final int secondaryDecimals;
  final double exchangeRate; // 1 primary = exchangeRate secondary
  final double taxRate; // percent, applied on top of prices

  const AppSettings({
    this.storeName = 'Pricelet Store',
    this.storeAddress = '',
    this.storePhone = '',
    this.receiptFooter = 'Thank you for your purchase!',
    this.currencySymbol = r'$',
    this.currencyDecimals = 2,
    this.secondaryEnabled = false,
    this.secondarySymbol = 'L.L',
    this.secondaryDecimals = 0,
    this.exchangeRate = 1,
    this.taxRate = 0,
  });

  factory AppSettings.fromMap(Map<String, String> map) {
    const d = AppSettings();
    return AppSettings(
      storeName: map['storeName'] ?? d.storeName,
      storeAddress: map['storeAddress'] ?? d.storeAddress,
      storePhone: map['storePhone'] ?? d.storePhone,
      receiptFooter: map['receiptFooter'] ?? d.receiptFooter,
      currencySymbol: map['currencySymbol'] ?? d.currencySymbol,
      currencyDecimals: int.tryParse(map['currencyDecimals'] ?? '') ?? d.currencyDecimals,
      secondaryEnabled: (map['secondaryEnabled'] ?? '${d.secondaryEnabled}') == 'true',
      secondarySymbol: map['secondarySymbol'] ?? d.secondarySymbol,
      secondaryDecimals: int.tryParse(map['secondaryDecimals'] ?? '') ?? d.secondaryDecimals,
      exchangeRate: double.tryParse(map['exchangeRate'] ?? '') ?? d.exchangeRate,
      taxRate: double.tryParse(map['taxRate'] ?? '') ?? d.taxRate,
    );
  }

  Map<String, String> toMap() => {
        'storeName': storeName,
        'storeAddress': storeAddress,
        'storePhone': storePhone,
        'receiptFooter': receiptFooter,
        'currencySymbol': currencySymbol,
        'currencyDecimals': '$currencyDecimals',
        'secondaryEnabled': '$secondaryEnabled',
        'secondarySymbol': secondarySymbol,
        'secondaryDecimals': '$secondaryDecimals',
        'exchangeRate': '$exchangeRate',
        'taxRate': '$taxRate',
      };

  AppSettings copyWith({
    String? storeName,
    String? storeAddress,
    String? storePhone,
    String? receiptFooter,
    String? currencySymbol,
    int? currencyDecimals,
    bool? secondaryEnabled,
    String? secondarySymbol,
    int? secondaryDecimals,
    double? exchangeRate,
    double? taxRate,
  }) {
    return AppSettings(
      storeName: storeName ?? this.storeName,
      storeAddress: storeAddress ?? this.storeAddress,
      storePhone: storePhone ?? this.storePhone,
      receiptFooter: receiptFooter ?? this.receiptFooter,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      currencyDecimals: currencyDecimals ?? this.currencyDecimals,
      secondaryEnabled: secondaryEnabled ?? this.secondaryEnabled,
      secondarySymbol: secondarySymbol ?? this.secondarySymbol,
      secondaryDecimals: secondaryDecimals ?? this.secondaryDecimals,
      exchangeRate: exchangeRate ?? this.exchangeRate,
      taxRate: taxRate ?? this.taxRate,
    );
  }

  static Future<AppSettings> load(AppDatabase db) async {
    final rows = await db.settingDao.findAll();
    return AppSettings.fromMap({for (final s in rows) s.key: s.value});
  }
}

/// Settings loaded before the app starts; overridden in `main`.
final initialSettingsProvider = Provider<AppSettings>((ref) => const AppSettings());

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.read(initialSettingsProvider);

  Future<void> save(AppSettings settings) async {
    final rows = settings.toMap().entries.map((e) => Setting(e.key, e.value)).toList();
    await ref.read(databaseProvider).settingDao.upsertAll(rows);
    state = settings;
  }
}
