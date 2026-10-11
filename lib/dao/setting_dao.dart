import 'package:floor/floor.dart';
import 'package:pricelet_app/entity/setting_entity.dart';

@dao
abstract class SettingDao {
  @Query('SELECT * FROM settings')
  Future<List<Setting>> findAll();

  @Insert(onConflict: OnConflictStrategy.replace)
  Future<void> upsertAll(List<Setting> settings);
}
