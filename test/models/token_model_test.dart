import 'package:flutter_test/flutter_test.dart';
import 'package:noline_skip/models/token_model.dart';

void main() {
  final fixedDate = DateTime(2024, 1, 15, 10, 0, 0);

  TokenModel makeToken({
    String id = 'tok1',
    String queueId = 'q1',
    String userId = 'u1',
    String hospitalId = 'h1',
    String hospitalName = 'JDWNRH',
    String hospitalShort = 'JDW',
    String tokenNumber = 'OPD-001',
    String session = 'morning',
    String status = 'active',
    int tokenPosition = 1,
    int peopleAhead = 0,
    int estimatedWaitMinutes = 0,
  }) =>
      TokenModel(
        id: id,
        queueId: queueId,
        userId: userId,
        hospitalId: hospitalId,
        hospitalName: hospitalName,
        hospitalShort: hospitalShort,
        tokenNumber: tokenNumber,
        session: session,
        status: status,
        tokenPosition: tokenPosition,
        peopleAhead: peopleAhead,
        estimatedWaitMinutes: estimatedWaitMinutes,
        issuedAt: fixedDate,
      );

  group('TokenModel fields', () {
    test('stores all fields correctly', () {
      final token = makeToken(
        id: 'tok99',
        queueId: 'q42',
        userId: 'u7',
        hospitalId: 'hosp1',
        hospitalName: 'Jigme Dorji Wangchuck National Referral Hospital',
        hospitalShort: 'JDWNRH',
        tokenNumber: 'OPD-007',
        session: 'afternoon',
        status: 'active',
        tokenPosition: 5,
        peopleAhead: 4,
        estimatedWaitMinutes: 16,
      );

      expect(token.id, 'tok99');
      expect(token.queueId, 'q42');
      expect(token.userId, 'u7');
      expect(token.hospitalId, 'hosp1');
      expect(token.hospitalName, 'Jigme Dorji Wangchuck National Referral Hospital');
      expect(token.hospitalShort, 'JDWNRH');
      expect(token.tokenNumber, 'OPD-007');
      expect(token.session, 'afternoon');
      expect(token.status, 'active');
      expect(token.tokenPosition, 5);
      expect(token.peopleAhead, 4);
      expect(token.estimatedWaitMinutes, 16);
      expect(token.issuedAt, fixedDate);
    });

    test('default values produce zero counts', () {
      final token = makeToken();
      expect(token.tokenPosition, 1);
      expect(token.peopleAhead, 0);
      expect(token.estimatedWaitMinutes, 0);
    });
  });

  group('TokenModel.isActive', () {
    test('returns true for active status', () {
      expect(makeToken(status: 'active').isActive, isTrue);
    });

    test('returns true for called status', () {
      expect(makeToken(status: 'called').isActive, isTrue);
    });

    test('returns false for completed status', () {
      expect(makeToken(status: 'completed').isActive, isFalse);
    });

    test('returns false for absent status', () {
      expect(makeToken(status: 'absent').isActive, isFalse);
    });

    test('returns false for cancelled status', () {
      expect(makeToken(status: 'cancelled').isActive, isFalse);
    });
  });
}
