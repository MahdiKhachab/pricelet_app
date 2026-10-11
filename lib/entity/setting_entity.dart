import 'package:floor/floor.dart';

/// Key/value application settings (store info, currency, tax...).
@Entity(tableName: 'settings')
class Setting {
  @primaryKey
  final String key;
  final String value;

  const Setting(this.key, this.value);
}
