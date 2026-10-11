import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pricelet_app/database/database.dart';
import 'package:pricelet_app/entity/user_entity.dart';
import 'package:pricelet_app/src/core/providers.dart';

/// PIN given to the admin account created on first launch.
const defaultAdminPin = '1234';

String newSalt() {
  final random = Random.secure();
  return base64Url.encode(List<int>.generate(16, (_) => random.nextInt(256)));
}

String hashPin(String pin, String salt) => sha256.convert(utf8.encode('$salt:$pin')).toString();

bool verifyPin(UserEntity user, String pin) => hashPin(pin, user.pinSalt) == user.pinHash;

UserEntity newUser({required String name, required String role, required String pin}) {
  final salt = newSalt();
  return UserEntity(
    name: name,
    role: role,
    pinHash: hashPin(pin, salt),
    pinSalt: salt,
    createdAt: DateTime.now().millisecondsSinceEpoch,
  );
}

/// Creates the first manager account when the database has no users.
Future<void> ensureAdminUser(AppDatabase db) async {
  final users = await db.userDao.findAllUsers();
  if (users.isEmpty) {
    await db.userDao.insertUser(newUser(name: 'Admin', role: UserRole.admin, pin: defaultAdminPin));
  }
}

final usersProvider = FutureProvider<List<UserEntity>>((ref) {
  return ref.watch(databaseProvider).userDao.findAllUsers();
});

/// The signed-in staff member, or null when the register is locked.
final currentUserProvider = StateProvider<UserEntity?>((ref) => null);

final isAdminProvider = Provider<bool>((ref) => ref.watch(currentUserProvider)?.isAdmin ?? false);
