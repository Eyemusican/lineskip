import 'package:flutter_test/flutter_test.dart';
import 'package:noline_skip/models/token_model.dart';

// Pure business logic extracted from FirestoreService and QueueNotificationService.
// These formulas are tested in isolation without any Firebase dependency.

String generateTokenNumber(int sequentialCount) =>
    'OPD-${sequentialCount.toString().padLeft(3, '0')}';

int calculatePeopleAhead(int activeTokensBeforeYou) => activeTokensBeforeYou;

int estimatedWaitMinutes(int peopleAhead, {int minutesPerPatient = 4}) =>
    peopleAhead * minutesPerPatient;

int earlyAlertThreshold(int initialPeopleAhead) =>
    (initialPeopleAhead * 0.3).ceil();

bool shouldFireEarlyAlert({
  required int initialPeopleAhead,
  required int currentAhead,
}) {
  if (initialPeopleAhead <= 10) return false;
  final threshold = earlyAlertThreshold(initialPeopleAhead);
  return currentAhead <= threshold && currentAhead > 5;
}

// Mirrors the auto-call logic inside markTokenStatus in FirestoreService.
String? findNextTokenToCall(String servedTokenId, List<TokenModel> allTokens) {
  final servedToken =
      allTokens.where((t) => t.id == servedTokenId).firstOrNull;
  if (servedToken == null) return null;
  final candidates = allTokens
      .where((t) =>
          t.status == 'active' &&
          t.queueId == servedToken.queueId &&
          t.id != servedTokenId)
      .toList()
    ..sort((a, b) => a.tokenPosition.compareTo(b.tokenPosition));
  return candidates.isEmpty ? null : candidates.first.id;
}

TokenModel _makeToken({
  required String id,
  required String queueId,
  required String status,
  required int tokenPosition,
}) =>
    TokenModel.fromMap({
      'queue_id': queueId,
      'status': status,
      'token_position': tokenPosition,
      'people_ahead': tokenPosition - 1,
    }, id);

void main() {
  group('Token number generation', () {
    test('first token is OPD-001', () {
      expect(generateTokenNumber(1), 'OPD-001');
    });

    test('second token is OPD-002', () {
      expect(generateTokenNumber(2), 'OPD-002');
    });

    test('tenth token is OPD-010', () {
      expect(generateTokenNumber(10), 'OPD-010');
    });

    test('hundredth token is OPD-100', () {
      expect(generateTokenNumber(100), 'OPD-100');
    });

    test('token number always has OPD- prefix', () {
      for (final n in [1, 5, 50, 999]) {
        expect(generateTokenNumber(n), startsWith('OPD-'));
      }
    });
  });

  group('People ahead calculation', () {
    test('no active tokens before you means 0 people ahead', () {
      expect(calculatePeopleAhead(0), 0);
    });

    test('position 5 with 4 active tokens before = 4 people ahead', () {
      expect(calculatePeopleAhead(4), 4);
    });

    test('20 active tokens before = 20 people ahead', () {
      expect(calculatePeopleAhead(20), 20);
    });
  });

  group('Estimated wait time', () {
    test('0 people ahead = 0 minutes', () {
      expect(estimatedWaitMinutes(0), 0);
    });

    test('5 people ahead = 20 minutes', () {
      expect(estimatedWaitMinutes(5), 20);
    });

    test('10 people ahead = 40 minutes', () {
      expect(estimatedWaitMinutes(10), 40);
    });

    test('each patient adds 4 minutes', () {
      for (var n = 1; n <= 20; n++) {
        expect(estimatedWaitMinutes(n), n * 4);
      }
    });
  });

  group('Early alert threshold (30% rule)', () {
    test('30% of 20 = 6', () {
      expect(earlyAlertThreshold(20), 6);
    });

    test('30% of 30 = 9', () {
      expect(earlyAlertThreshold(30), 9);
    });

    test('30% of 15 rounds up to 5', () {
      expect(earlyAlertThreshold(15), 5);
    });
  });

  group('Early alert firing logic', () {
    test('fires when initial > 10 and current is at 30% threshold', () {
      expect(
        shouldFireEarlyAlert(initialPeopleAhead: 20, currentAhead: 6),
        isTrue,
      );
    });

    test('does not fire when initial queue is 10 or fewer', () {
      expect(
        shouldFireEarlyAlert(initialPeopleAhead: 10, currentAhead: 3),
        isFalse,
      );
    });

    test('does not fire when current is above threshold', () {
      expect(
        shouldFireEarlyAlert(initialPeopleAhead: 20, currentAhead: 7),
        isFalse,
      );
    });

    test('does not fire when current is 5 or fewer (closer alerts take over)', () {
      expect(
        shouldFireEarlyAlert(initialPeopleAhead: 20, currentAhead: 5),
        isFalse,
      );
    });

    test('fires in the band: threshold >= current > 5', () {
      expect(
        shouldFireEarlyAlert(initialPeopleAhead: 30, currentAhead: 9),
        isTrue,
      );
    });
  });

  group('Auto-call next token after serve', () {
    test('calls the next active token in the same queue', () {
      final tokens = [
        _makeToken(id: 'tok1', queueId: 'q1', status: 'called', tokenPosition: 1),
        _makeToken(id: 'tok2', queueId: 'q1', status: 'active', tokenPosition: 2),
        _makeToken(id: 'tok3', queueId: 'q1', status: 'active', tokenPosition: 3),
      ];
      expect(findNextTokenToCall('tok1', tokens), 'tok2');
    });

    test('returns null when no active tokens remain in the queue', () {
      final tokens = [
        _makeToken(id: 'tok1', queueId: 'q1', status: 'called', tokenPosition: 1),
      ];
      expect(findNextTokenToCall('tok1', tokens), isNull);
    });

    test('returns null when remaining tokens are all served or absent', () {
      final tokens = [
        _makeToken(id: 'tok1', queueId: 'q1', status: 'called', tokenPosition: 1),
        _makeToken(id: 'tok2', queueId: 'q1', status: 'served', tokenPosition: 2),
        _makeToken(id: 'tok3', queueId: 'q1', status: 'absent', tokenPosition: 3),
      ];
      expect(findNextTokenToCall('tok1', tokens), isNull);
    });

    test('picks the token with the lowest token_position regardless of list order', () {
      final tokens = [
        _makeToken(id: 'tok1', queueId: 'q1', status: 'called', tokenPosition: 1),
        _makeToken(id: 'tok4', queueId: 'q1', status: 'active', tokenPosition: 4),
        _makeToken(id: 'tok2', queueId: 'q1', status: 'active', tokenPosition: 2),
        _makeToken(id: 'tok3', queueId: 'q1', status: 'active', tokenPosition: 3),
      ];
      expect(findNextTokenToCall('tok1', tokens), 'tok2');
    });

    test('does not call a token from a different queue', () {
      final tokens = [
        _makeToken(id: 'tok1', queueId: 'q1', status: 'called', tokenPosition: 1),
        _makeToken(id: 'tok2', queueId: 'q2', status: 'active', tokenPosition: 1),
      ];
      expect(findNextTokenToCall('tok1', tokens), isNull);
    });

    test('does not call an already-called token, only active', () {
      final tokens = [
        _makeToken(id: 'tok1', queueId: 'q1', status: 'called', tokenPosition: 1),
        _makeToken(id: 'tok2', queueId: 'q1', status: 'called', tokenPosition: 2),
        _makeToken(id: 'tok3', queueId: 'q1', status: 'active', tokenPosition: 3),
      ];
      expect(findNextTokenToCall('tok1', tokens), 'tok3');
    });

    test('returns null when servedTokenId is not in the list', () {
      final tokens = [
        _makeToken(id: 'tok2', queueId: 'q1', status: 'active', tokenPosition: 2),
      ];
      expect(findNextTokenToCall('tok1', tokens), isNull);
    });
  });
}
