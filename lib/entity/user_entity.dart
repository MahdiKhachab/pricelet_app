import 'package:floor/floor.dart';

class UserRole {
  static const admin = 'admin';
  static const cashier = 'cashier';

  static String label(String role) => role == admin ? 'Manager' : 'Cashier';
}

/// A staff member who signs in to the register with a PIN.
@Entity(tableName: 'users')
class UserEntity {
  @PrimaryKey(autoGenerate: true)
  final int? id;

  final String name;
  final String role; // see [UserRole]
  final String pinHash;
  final String pinSalt;
  final bool active;
  final int createdAt; // epoch millis

  const UserEntity({
    this.id,
    required this.name,
    required this.role,
    required this.pinHash,
    required this.pinSalt,
    this.active = true,
    required this.createdAt,
  });

  bool get isAdmin => role == UserRole.admin;

  UserEntity copyWith({
    String? name,
    String? role,
    String? pinHash,
    String? pinSalt,
    bool? active,
  }) {
    return UserEntity(
      id: id,
      name: name ?? this.name,
      role: role ?? this.role,
      pinHash: pinHash ?? this.pinHash,
      pinSalt: pinSalt ?? this.pinSalt,
      active: active ?? this.active,
      createdAt: createdAt,
    );
  }
}
