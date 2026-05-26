import 'package:flutter_test/flutter_test.dart';
import 'package:noline_skip/models/hospital.dart';

void main() {
  final fullMap = <String, dynamic>{
    'name': 'Jigme Dorji Wangchuck National Referral Hospital',
    'short_name': 'JDWNRH',
    'location': 'Thimphu',
    'current_queue': 15,
    'estimated_wait_minutes': 60,
    'speciality': 'General OPD',
    'is_active': true,
    'operating_hours': {'monday': '8:00-17:00', 'friday': '8:00-12:00'},
  };

  group('Hospital.fromMap — full data', () {
    late Hospital hospital;

    setUpAll(() => hospital = Hospital.fromMap(fullMap, 'hosp001'));

    test('parses id', () => expect(hospital.id, 'hosp001'));
    test('parses name', () => expect(hospital.name, 'Jigme Dorji Wangchuck National Referral Hospital'));
    test('parses short_name', () => expect(hospital.shortName, 'JDWNRH'));
    test('parses location', () => expect(hospital.location, 'Thimphu'));
    test('parses current_queue', () => expect(hospital.currentQueue, 15));
    test('parses estimated_wait_minutes', () => expect(hospital.estimatedWaitMinutes, 60));
    test('parses speciality', () => expect(hospital.speciality, 'General OPD'));
    test('parses is_active as isOpen', () => expect(hospital.isOpen, isTrue));
    test('parses operating_hours', () => expect(hospital.operatingHours, {'monday': '8:00-17:00', 'friday': '8:00-12:00'}));
  });

  group('Hospital.fromMap — default values', () {
    late Hospital hospital;

    setUpAll(() => hospital = Hospital.fromMap({}, 'h0'));

    test('id from argument', () => expect(hospital.id, 'h0'));
    test('name defaults to empty string', () => expect(hospital.name, ''));
    test('shortName defaults to empty string', () => expect(hospital.shortName, ''));
    test('location defaults to empty string', () => expect(hospital.location, ''));
    test('currentQueue defaults to 0', () => expect(hospital.currentQueue, 0));
    test('estimatedWaitMinutes defaults to 0', () => expect(hospital.estimatedWaitMinutes, 0));
    test('speciality defaults to empty string', () => expect(hospital.speciality, ''));
    test('isOpen defaults to false', () => expect(hospital.isOpen, isFalse));
    test('operatingHours defaults to empty map', () => expect(hospital.operatingHours, isEmpty));
  });

  group('Hospital.toFirestore', () {
    late Map<String, dynamic> map;

    setUpAll(() => map = Hospital.fromMap(fullMap, 'hosp001').toFirestore());

    test('uses name key', () => expect(map['name'], 'Jigme Dorji Wangchuck National Referral Hospital'));
    test('uses short_name key (not shortName)', () => expect(map['short_name'], 'JDWNRH'));
    test('uses is_active key (not isOpen)', () => expect(map['is_active'], isTrue));
    test('uses current_queue key', () => expect(map['current_queue'], 15));
    test('uses estimated_wait_minutes key', () => expect(map['estimated_wait_minutes'], 60));
    test('uses speciality key', () => expect(map['speciality'], 'General OPD'));
    test('uses operating_hours key', () => expect(map['operating_hours'], {'monday': '8:00-17:00', 'friday': '8:00-12:00'}));
    test('does not include id', () => expect(map.containsKey('id'), isFalse));
  });
}
