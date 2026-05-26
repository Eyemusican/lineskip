import 'package:flutter_test/flutter_test.dart';
import 'package:noline_skip/models/token_model.dart';

void main() {
  final fixedDate = DateTime(2024, 6, 15, 9, 30, 0);

  final fullMap = <String, dynamic>{
    'queue_id': 'q42',
    'user_id': 'u7',
    'hospital_id': 'hosp1',
    'hospital_name': 'Jigme Dorji Wangchuck National Referral Hospital',
    'hospital_short': 'JDWNRH',
    'token_number': 'OPD-007',
    'session': 'morning',
    'status': 'active',
    'token_position': 7,
    'people_ahead': 6,
    'estimated_wait_minutes': 24,
    'issued_at': fixedDate,
  };

  group('TokenModel.fromMap — full data', () {
    late TokenModel token;

    setUpAll(() => token = TokenModel.fromMap(fullMap, 'tok99'));

    test('parses id', () => expect(token.id, 'tok99'));
    test('parses queue_id', () => expect(token.queueId, 'q42'));
    test('parses user_id', () => expect(token.userId, 'u7'));
    test('parses hospital_id', () => expect(token.hospitalId, 'hosp1'));
    test('parses hospital_name', () => expect(token.hospitalName, 'Jigme Dorji Wangchuck National Referral Hospital'));
    test('parses hospital_short', () => expect(token.hospitalShort, 'JDWNRH'));
    test('parses token_number', () => expect(token.tokenNumber, 'OPD-007'));
    test('parses session', () => expect(token.session, 'morning'));
    test('parses status', () => expect(token.status, 'active'));
    test('parses token_position', () => expect(token.tokenPosition, 7));
    test('parses people_ahead', () => expect(token.peopleAhead, 6));
    test('parses estimated_wait_minutes', () => expect(token.estimatedWaitMinutes, 24));
    test('parses issued_at', () => expect(token.issuedAt, fixedDate));
  });

  group('TokenModel.fromMap — default values', () {
    late TokenModel token;

    setUpAll(() => token = TokenModel.fromMap({}, 'empty'));

    test('id from argument', () => expect(token.id, 'empty'));
    test('queueId defaults to empty string', () => expect(token.queueId, ''));
    test('userId defaults to empty string', () => expect(token.userId, ''));
    test('hospitalId defaults to empty string', () => expect(token.hospitalId, ''));
    test('hospitalName defaults to empty string', () => expect(token.hospitalName, ''));
    test('hospitalShort defaults to empty string', () => expect(token.hospitalShort, ''));
    test('tokenNumber defaults to empty string', () => expect(token.tokenNumber, ''));
    test('session defaults to empty string', () => expect(token.session, ''));
    test('status defaults to active', () => expect(token.status, 'active'));
    test('tokenPosition defaults to 0', () => expect(token.tokenPosition, 0));
    test('peopleAhead defaults to 0', () => expect(token.peopleAhead, 0));
    test('estimatedWaitMinutes defaults to 0', () => expect(token.estimatedWaitMinutes, 0));
    test('issuedAt defaults to a non-null DateTime', () => expect(token.issuedAt, isA<DateTime>()));
  });

  group('TokenModel.isActive', () {
    TokenModel withStatus(String s) => TokenModel.fromMap({'status': s}, 'x');

    test('returns true for active', () => expect(withStatus('active').isActive, isTrue));
    test('returns true for called', () => expect(withStatus('called').isActive, isTrue));
    test('returns false for completed', () => expect(withStatus('completed').isActive, isFalse));
    test('returns false for absent', () => expect(withStatus('absent').isActive, isFalse));
    test('returns false for cancelled', () => expect(withStatus('cancelled').isActive, isFalse));
  });

  group('TokenModel.toFirestore', () {
    test('round-trips string fields', () {
      final token = TokenModel.fromMap(fullMap, 'tok99');
      final map = token.toFirestore();
      expect(map['queue_id'], 'q42');
      expect(map['user_id'], 'u7');
      expect(map['hospital_id'], 'hosp1');
      expect(map['token_number'], 'OPD-007');
      expect(map['session'], 'morning');
      expect(map['status'], 'active');
    });

    test('round-trips numeric fields', () {
      final token = TokenModel.fromMap(fullMap, 'tok99');
      final map = token.toFirestore();
      expect(map['token_position'], 7);
      expect(map['people_ahead'], 6);
      expect(map['estimated_wait_minutes'], 24);
    });

    test('includes issued_at as Timestamp', () {
      final token = TokenModel.fromMap(fullMap, 'tok99');
      expect(token.toFirestore().containsKey('issued_at'), isTrue);
    });
  });
}
