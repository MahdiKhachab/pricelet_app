import 'package:floor/floor.dart';

@Entity(tableName: 'customers', indices: [
  Index(value: ['name']),
  Index(value: ['phone']),
])
class Customer {
  @PrimaryKey(autoGenerate: true)
  final int? id;

  final String name;
  final String phone;
  final String email;
  final String notes;
  final int createdAt; // epoch millis

  const Customer({
    this.id,
    required this.name,
    this.phone = '',
    this.email = '',
    this.notes = '',
    required this.createdAt,
  });

  Customer copyWith({String? name, String? phone, String? email, String? notes}) {
    return Customer(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      notes: notes ?? this.notes,
      createdAt: createdAt,
    );
  }
}
