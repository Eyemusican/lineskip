import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String name;
  final String phone;
  final String role;
  final DateTime createdAt;

  const AppUser({
    required this.uid,
    required this.name,
    required this.phone,
    this.role = 'patient',
    required this.createdAt,
  });

  factory AppUser.fromMap(Map<String, dynamic> data, String id) {
    return AppUser(
      uid: id,
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      role: data['role'] ?? 'patient',
      createdAt: data['created_at'] as DateTime? ?? DateTime.now(),
    );
  }

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final raw = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
    final ts = raw['created_at'];
    raw['created_at'] = ts is Timestamp ? ts.toDate() : null;
    return AppUser.fromMap(raw, doc.id);
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'phone': phone,
        'role': role,
        'created_at': Timestamp.fromDate(createdAt),
      };
}
