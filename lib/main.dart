import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pricelet_app/database/database.dart';
import 'package:pricelet_app/src/app.dart';
import 'package:pricelet_app/src/core/providers.dart';
import 'package:pricelet_app/src/features/auth/auth.dart';
import 'package:pricelet_app/src/features/settings/app_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final db = await AppDatabase.open();
    await ensureAdminUser(db);
    final settings = await AppSettings.load(db);

    runApp(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        initialSettingsProvider.overrideWithValue(settings),
      ],
      child: const PriceletApp(),
    ));
  } catch (e) {
    runApp(StartupErrorApp(error: e));
  }
}
