import 'package:equatable/equatable.dart';

/// A trusted family member who should get access to documents when needed.
class Nominee extends Equatable {
  const Nominee({
    required this.id,
    required this.name,
    required this.relation,
    this.email = '',
    this.phone = '',
  });

  final String id;
  final String name;
  final String relation;
  final String email;
  final String phone;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'relation': relation,
        'email': email,
        'phone': phone,
      };

  factory Nominee.fromMap(Map<String, dynamic> map) => Nominee(
        id: map['id'] as String,
        name: map['name'] as String? ?? '',
        relation: map['relation'] as String? ?? '',
        email: map['email'] as String? ?? '',
        phone: map['phone'] as String? ?? '',
      );

  @override
  List<Object?> get props => [id, name, relation, email, phone];
}
