import 'package:flutter_test/flutter_test.dart';
import 'package:noline_skip/models/hospital.dart';

void main() {
  group('Hospital fields', () {
    test('stores all fields correctly', () {
      const hospital = Hospital(
        id: 'hosp001',
        name: 'Jigme Dorji Wangchuck National Referral Hospital',
        shortName: 'JDWNRH',
        location: 'Thimphu',
        currentQueue: 15,
        estimatedWaitMinutes: 60,
        speciality: 'General OPD',
        isOpen: true,
        operatingHours: {'monday': '8:00-17:00'},
      );

      expect(hospital.id, 'hosp001');
      expect(hospital.name, 'Jigme Dorji Wangchuck National Referral Hospital');
      expect(hospital.shortName, 'JDWNRH');
      expect(hospital.location, 'Thimphu');
      expect(hospital.currentQueue, 15);
      expect(hospital.estimatedWaitMinutes, 60);
      expect(hospital.speciality, 'General OPD');
      expect(hospital.isOpen, isTrue);
      expect(hospital.operatingHours, {'monday': '8:00-17:00'});
    });

    test('operatingHours defaults to empty map', () {
      const hospital = Hospital(
        id: 'h',
        name: 'N',
        shortName: 'SN',
        location: 'L',
        currentQueue: 0,
        estimatedWaitMinutes: 0,
        speciality: '',
        isOpen: false,
      );
      expect(hospital.operatingHours, isEmpty);
    });

    test('isOpen can be false', () {
      const hospital = Hospital(
        id: 'h',
        name: 'N',
        shortName: 'SN',
        location: 'L',
        currentQueue: 0,
        estimatedWaitMinutes: 0,
        speciality: '',
        isOpen: false,
      );
      expect(hospital.isOpen, isFalse);
    });
  });

  group('Hospital.toFirestore', () {
    const hospital = Hospital(
      id: 'hosp001',
      name: 'Jigme Dorji Wangchuck National Referral Hospital',
      shortName: 'JDWNRH',
      location: 'Thimphu',
      currentQueue: 15,
      estimatedWaitMinutes: 60,
      speciality: 'General OPD',
      isOpen: true,
      operatingHours: {'monday': '8:00-17:00'},
    );

    test('produces correct map', () {
      final map = hospital.toFirestore();

      expect(map['name'], 'Jigme Dorji Wangchuck National Referral Hospital');
      expect(map['short_name'], 'JDWNRH');
      expect(map['location'], 'Thimphu');
      expect(map['current_queue'], 15);
      expect(map['estimated_wait_minutes'], 60);
      expect(map['speciality'], 'General OPD');
      expect(map['is_active'], isTrue);
      expect(map['operating_hours'], {'monday': '8:00-17:00'});
    });

    test('uses is_active key (not isOpen)', () {
      final map = hospital.toFirestore();
      expect(map.containsKey('is_active'), isTrue);
      expect(map.containsKey('isOpen'), isFalse);
    });

    test('uses short_name key (not shortName)', () {
      final map = hospital.toFirestore();
      expect(map.containsKey('short_name'), isTrue);
      expect(map.containsKey('shortName'), isFalse);
    });
  });
}
