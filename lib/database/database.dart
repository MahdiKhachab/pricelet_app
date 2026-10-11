import 'dart:async';
import 'dart:io';

import 'package:floor/floor.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pricelet_app/dao/customer_dao.dart';
import 'package:pricelet_app/dao/product_dao.dart';
import 'package:pricelet_app/dao/sale_dao.dart';
import 'package:pricelet_app/dao/setting_dao.dart';
import 'package:pricelet_app/dao/user_dao.dart';
import 'package:pricelet_app/database/migrations.dart';
import 'package:pricelet_app/entity/customer_entity.dart';
import 'package:pricelet_app/entity/product_entity.dart';
import 'package:pricelet_app/entity/sale_entity.dart';
import 'package:pricelet_app/entity/sale_item_entity.dart';
import 'package:pricelet_app/entity/setting_entity.dart';
import 'package:pricelet_app/entity/stock_movement_entity.dart';
import 'package:pricelet_app/entity/user_entity.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

part 'database.g.dart';

const databaseFileName = 'pricelet.db';

/// Where the database lives. Mobile keeps sqflite's default folder. On
/// desktop, sqflite FFI defaults to `.dart_tool/` under the *working
/// directory*, which changes with how the app is launched, so the database is
/// kept in the per-user application support folder instead.
Future<String> defaultDatabasePath() async {
  if (kIsWeb || Platform.isAndroid || Platform.isIOS) return databaseFileName;

  final dir = await getApplicationSupportDirectory();
  await dir.create(recursive: true);
  final target = p.join(dir.path, databaseFileName);

  // One-time move of a database created by earlier builds in the old location.
  final legacy = File(p.join(Directory.current.path, '.dart_tool', 'sqflite_common_ffi', 'databases', databaseFileName));
  if (!File(target).existsSync() && legacy.existsSync()) {
    await legacy.copy(target);
  }
  return target;
}

@Database(
  version: 4,
  entities: [Product, Customer, Sale, SaleItem, UserEntity, Setting, StockMovement],
)
abstract class AppDatabase extends FloorDatabase {
  ProductDao get productDao;
  CustomerDao get customerDao;
  SaleDao get saleDao;
  UserDao get userDao;
  SettingDao get settingDao;

  /// Opens the single app database, upgrading older installs. Pass an
  /// absolute [path] to override the default location.
  static Future<AppDatabase> open({String? path}) async {
    final location = path ?? await defaultDatabasePath();
    return $FloorAppDatabase.databaseBuilder(location).addMigrations(appMigrations).build();
  }

  static Future<AppDatabase> inMemory() {
    return $FloorAppDatabase.inMemoryDatabaseBuilder().build();
  }
}
