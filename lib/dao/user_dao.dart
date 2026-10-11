import 'package:floor/floor.dart';
import 'package:pricelet_app/entity/user_entity.dart';

@dao
abstract class UserDao {
  @Query('SELECT * FROM users ORDER BY name COLLATE NOCASE')
  Future<List<UserEntity>> findAllUsers();

  @Query('SELECT * FROM users WHERE id = :id')
  Future<UserEntity?> findById(int id);

  @insert
  Future<int> insertUser(UserEntity user);

  @update
  Future<void> updateUser(UserEntity user);
}
