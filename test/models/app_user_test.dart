import 'package:flutter_test/flutter_test.dart';
import 'package:noline_skip/models/app_user.dart';

void main() {
  final fixedDate = DateTime(2024, 6, 1, 9, 0, 0);

  final fullMap = <String, dynamic>{
    'name': 'Tenzin Wangchuk',
    'phone': '+97517123456',
    'role': 'patient',
    'created_at': fixedDate,
  };

  group('AppUser.fromMap — full data', () {
    late AppUser user;

    setUpAll(() => user = AppUser.fromMap(fullMap, 'uid123'));

    test('parses uid from id argument', () => expect(user.uid, 'uid123'));
    test('parses name', () => expect(user.name, 'Tenzin Wangchuk'));
    test('parses phone', () => expect(user.phone, '+97517123456'));
    test('parses role', () => expect(user.role, 'patient'));
    test('parses created_at', () => expect(user.createdAt, fixedDate));
  });

  group('AppUser.fromMap — default values', () {
    late AppUser user;

    setUpAll(() => user = AppUser.fromMap({}, 'uid000'));

    test('uid from argument', () => expect(user.uid, 'uid000'));
    test('name defaults to empty string', () => expect(user.name, ''));
    test('phone defaults to empty string', () => expect(user.phone, ''));
    test('role defaults to patient', () => expect(user.role, 'patient'));
    test('createdAt defaults to a non-null DateTime', () => expect(user.createdAt, isA<DateTime>()));
  });

  group('AppUser.fromMap — role variants', () {
    test('staff role is preserved', () {
      final user = AppUser.fromMap({...fullMap, 'role': 'staff'}, 'uid456');
      expect(user.role, 'staff');
    });

    test('missing role falls back to patient', () {
      final map = Map<String, dynamic>.from(fullMap)..remove('role');
      expect(AppUser.fromMap(map, 'uid789').role, 'patient');
    });
  });

  group('AppUser.toFirestore', () {
    late Map<String, dynamic> map;

    setUpAll(() => map = AppUser.fromMap(fullMap, 'uid123').toFirestore());

    test('contains name', () => expect(map['name'], 'Tenzin Wangchuk'));
    test('contains phone', () => expect(map['phone'], '+97517123456'));
    test('contains role', () => expect(map['role'], 'patient'));
    test('contains created_at', () => expect(map.containsKey('created_at'), isTrue));
    test('does not contain uid', () => expect(map.containsKey('uid'), isFalse));
  });
}
