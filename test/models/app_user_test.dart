import 'package:flutter_test/flutter_test.dart';
import 'package:noline_skip/models/app_user.dart';

void main() {
  final createdAt = DateTime(2024, 6, 1, 9, 0, 0);

  group('AppUser fields', () {
    test('stores all fields correctly', () {
      final user = AppUser(
        uid: 'uid123',
        name: 'Tenzin Wangchuk',
        phone: '+97517123456',
        role: 'patient',
        createdAt: createdAt,
      );

      expect(user.uid, 'uid123');
      expect(user.name, 'Tenzin Wangchuk');
      expect(user.phone, '+97517123456');
      expect(user.role, 'patient');
      expect(user.createdAt, createdAt);
    });

    test('default role is patient', () {
      final user = AppUser(
        uid: 'uid123',
        name: 'Tenzin',
        phone: '+97517123456',
        createdAt: createdAt,
      );
      expect(user.role, 'patient');
    });

    test('role can be staff', () {
      final user = AppUser(
        uid: 'uid456',
        name: 'Dr. Karma',
        phone: '+97517654321',
        role: 'staff',
        createdAt: createdAt,
      );
      expect(user.role, 'staff');
    });
  });

  group('AppUser.toFirestore', () {
    test('produces correct map keys and values', () {
      final user = AppUser(
        uid: 'uid123',
        name: 'Tenzin Wangchuk',
        phone: '+97517123456',
        role: 'patient',
        createdAt: createdAt,
      );

      final map = user.toFirestore();

      expect(map['name'], 'Tenzin Wangchuk');
      expect(map['phone'], '+97517123456');
      expect(map['role'], 'patient');
      expect(map.containsKey('created_at'), isTrue);
    });

    test('staff role is preserved in map', () {
      final user = AppUser(
        uid: 'uid456',
        name: 'Dr. Karma',
        phone: '+97517654321',
        role: 'staff',
        createdAt: createdAt,
      );
      expect(user.toFirestore()['role'], 'staff');
    });

    test('uid is not included in toFirestore output', () {
      final user = AppUser(
        uid: 'uid123',
        name: 'Tenzin',
        phone: '+975',
        createdAt: createdAt,
      );
      expect(user.toFirestore().containsKey('uid'), isFalse);
    });
  });
}
