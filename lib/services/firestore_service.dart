import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/hospital.dart';
import '../models/token_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DateTime _todayStart() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  // ── Hospitals ────────────────────────────────────────────────────────────

  Stream<List<Hospital>> getHospitals() {
    return _db
        .collection('hospitals')
        .snapshots()
        .map((snap) => snap.docs.map(Hospital.fromFirestore).toList());
  }

  // ── Live queue counts ─────────────────────────────────────────────────────

  /// Real-time count of active+called tokens for a hospital today.
  Stream<int> getActiveTokenCountStream(String hospitalId) {
    final dayStart = _todayStart();
    return _db
        .collection('tokens')
        .where('hospital_id', isEqualTo: hospitalId)
        .snapshots()
        .map((snap) => snap.docs.where((doc) {
              final data = doc.data();
              final status = data['status'] as String? ?? '';
              if (status != 'active' && status != 'called') return false;
              final issuedAt = (data['issued_at'] as Timestamp?)?.toDate();
              return issuedAt != null && !issuedAt.isBefore(dayStart);
            }).length);
  }

  /// Real-time {hospitalId: activeCount} for all hospitals today.
  Stream<Map<String, int>> getTodayActiveCountsStream() {
    final dayStart = _todayStart();
    return _db.collection('tokens').snapshots().map((snap) {
      final counts = <String, int>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        final status = data['status'] as String? ?? '';
        if (status != 'active' && status != 'called') continue;
        final issuedAt = (data['issued_at'] as Timestamp?)?.toDate();
        if (issuedAt == null || issuedAt.isBefore(dayStart)) continue;
        final hid = data['hospital_id'] as String? ?? '';
        if (hid.isEmpty) continue;
        counts[hid] = (counts[hid] ?? 0) + 1;
      }
      return counts;
    });
  }

  /// Real-time token number currently being called for a hospital today.
  Stream<String?> getNowServingStream(String hospitalId) {
    final dayStart = _todayStart();
    return _db
        .collection('tokens')
        .where('hospital_id', isEqualTo: hospitalId)
        .where('status', isEqualTo: 'called')
        .snapshots()
        .map((snap) {
      final todayDocs = snap.docs.where((doc) {
        final issuedAt =
            (doc.data()['issued_at'] as Timestamp?)?.toDate();
        return issuedAt != null && !issuedAt.isBefore(dayStart);
      }).toList();
      if (todayDocs.isEmpty) return null;
      todayDocs.sort((a, b) {
        final aPos = (a.data()['token_position'] as int?) ?? 0;
        final bPos = (b.data()['token_position'] as int?) ?? 0;
        return aPos.compareTo(bPos);
      });
      return todayDocs.first.data()['token_number'] as String?;
    });
  }

  // ── Tokens ───────────────────────────────────────────────────────────────

  /// Books a token. Returns (tokenId, tokenNumber).
  /// Token number is sequential (OPD-001, OPD-002…).
  /// Position and wait time are calculated from live Firestore counts.
  /// Throws [DuplicateBookingException] if the user already has an active token today.
  Future<(String tokenId, String tokenNumber)> bookToken({
    required String userId,
    required String hospitalId,
    required String hospitalName,
    required String hospitalShort,
    required String session,
    required int minutesPerPatient,
  }) async {
    final today = DateTime.now();
    final dayStart = DateTime(today.year, today.month, today.day);

    // Prevent duplicate booking — check for any active/called token today
    final existingSnap = await _db
        .collection('tokens')
        .where('user_id', isEqualTo: userId)
        .where('status', whereIn: ['active', 'called'])
        .get();
    for (final doc in existingSnap.docs) {
      final issuedAt = (doc.data()['issued_at'] as Timestamp?)?.toDate();
      if (issuedAt != null && !issuedAt.isBefore(dayStart)) {
        throw const DuplicateBookingException();
      }
    }
    final dateStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final safeSession = session.replaceAll(' ', '_').toLowerCase();
    final queueDocId = '${hospitalId}_${dateStr}_$safeSession';

    // Count today's tokens for sequential numbering and position
    final todaySnap = await _db
        .collection('tokens')
        .where('hospital_id', isEqualTo: hospitalId)
        .get();

    int activeCount = 0;
    int allTodayCount = 0;
    for (final doc in todaySnap.docs) {
      final data = doc.data();
      final issuedAt = (data['issued_at'] as Timestamp?)?.toDate();
      if (issuedAt == null || issuedAt.isBefore(dayStart)) continue;
      allTodayCount++;
      final status = data['status'] as String? ?? '';
      if (status == 'active' || status == 'called') activeCount++;
    }

    final tokenNumber =
        'OPD-${(allTodayCount + 1).toString().padLeft(3, '0')}';
    final estimatedWait = activeCount * minutesPerPatient;

    // Create / update the queue document for today
    await _db.collection('queues').doc(queueDocId).set({
      'hospital_id': hospitalId,
      'date': dateStr,
      'session': session,
      'status': 'active',
      'total_tokens': FieldValue.increment(1),
    }, SetOptions(merge: true));

    // Create the token document
    final tokenRef = await _db.collection('tokens').add({
      'queue_id': queueDocId,
      'user_id': userId,
      'hospital_id': hospitalId,
      'hospital_name': hospitalName,
      'hospital_short': hospitalShort,
      'token_number': tokenNumber,
      'session': session,
      'status': 'active',
      'token_position': activeCount + 1,
      'people_ahead': activeCount,
      'estimated_wait_minutes': estimatedWait,
      'issued_at': FieldValue.serverTimestamp(),
    });

    return (tokenRef.id, tokenNumber);
  }

  Stream<List<TokenModel>> getUserTokens(String userId) {
    return _db
        .collection('tokens')
        .where('user_id', isEqualTo: userId)
        .orderBy('issued_at', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(TokenModel.fromFirestore).toList());
  }

  Stream<TokenModel?> getTokenStream(String tokenId) {
    return _db
        .collection('tokens')
        .doc(tokenId)
        .snapshots()
        .map((doc) => doc.exists ? TokenModel.fromFirestore(doc) : null);
  }

  /// Returns a stream of {sessionLabel: bookedCount} for a hospital on a given date.
  Stream<Map<String, int>> getSessionTokenCounts(
      String hospitalId, String dateStr) {
    return _db
        .collection('tokens')
        .where('hospital_id', isEqualTo: hospitalId)
        .snapshots()
        .map((snap) {
      final counts = <String, int>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        final status = data['status'] as String? ?? '';
        if (status == 'absent' || status == 'cancelled') continue;
        final issuedAt = (data['issued_at'] as Timestamp?)?.toDate();
        if (issuedAt == null) continue;
        final tokenDate =
            '${issuedAt.year}-${issuedAt.month.toString().padLeft(2, '0')}-${issuedAt.day.toString().padLeft(2, '0')}';
        if (tokenDate != dateStr) continue;
        final session = data['session'] as String? ?? '';
        counts[session] = (counts[session] ?? 0) + 1;
      }
      return counts;
    });
  }

  // ── Notifications ─────────────────────────────────────────────────────────

  Future<void> saveNotification({
    required String tokenId,
    required String type,
  }) {
    return _db.collection('notifications').add({
      'token_id': tokenId,
      'type': type,
      'sent_at': FieldValue.serverTimestamp(),
    });
  }

  // ── Staff ─────────────────────────────────────────────────────────────────

  /// Returns the hospital_id for a staff user from their Firestore user doc.
  Future<String?> getStaffHospitalId(String uid) async {
    try {
      final q = await _db
          .collection('users')
          .where('uid', isEqualTo: uid)
          .limit(1)
          .get(const GetOptions(source: Source.server));
      if (q.docs.isNotEmpty) {
        return q.docs.first.data()['hospital_id'] as String?;
      }
    } catch (_) {}
    return null;
  }

  /// Saves a hospital assignment for a staff user (creates or merges user doc).
  Future<void> saveStaffHospitalId(String uid, String hospitalId) {
    return _db.collection('users').doc(uid).set({
      'uid': uid,
      'hospital_id': hospitalId,
      'role': 'staff',
    }, SetOptions(merge: true));
  }

  Stream<List<TokenModel>> getTodayTokensStream(String hospitalId) {
    final dayStart = _todayStart();
    return _db
        .collection('tokens')
        .where('hospital_id', isEqualTo: hospitalId)
        .snapshots()
        .map((snap) {
      final tokens = snap.docs
          .map(TokenModel.fromFirestore)
          .where((t) => !t.issuedAt.isBefore(dayStart))
          .toList();
      tokens.sort((a, b) => a.tokenPosition.compareTo(b.tokenPosition));
      return tokens;
    });
  }

  Future<void> callNextToken(List<TokenModel> tokens) async {
    final active = tokens
        .where((t) => t.status == 'active')
        .toList()
      ..sort((a, b) => a.tokenPosition.compareTo(b.tokenPosition));
    if (active.isEmpty) return;
    await _db
        .collection('tokens')
        .doc(active.first.id)
        .update({'status': 'called'});
  }

  Future<void> markTokenStatus(
    String tokenId,
    String newStatus,
    List<TokenModel> allTokens,
    int tokenPosition,
  ) async {
    final batch = _db.batch();
    batch.update(
        _db.collection('tokens').doc(tokenId), {'status': newStatus});

    // Shift people_ahead for active/called tokens behind this one
    for (final t in allTokens) {
      if (t.tokenPosition > tokenPosition &&
          (t.status == 'active' || t.status == 'called') &&
          t.id != tokenId) {
        batch.update(_db.collection('tokens').doc(t.id), {
          'people_ahead': FieldValue.increment(-1),
        });
      }
    }

    await batch.commit();

    // Auto-call the next waiting token in the same queue after serving
    if (newStatus == 'served') {
      final servedToken = allTokens.where((t) => t.id == tokenId).firstOrNull;
      if (servedToken != null) {
        final next = allTokens
            .where((t) =>
                t.status == 'active' &&
                (servedToken.queueId.isNotEmpty
                    ? t.queueId == servedToken.queueId
                    : t.hospitalId == servedToken.hospitalId &&
                      t.session == servedToken.session))
            .toList()
          ..sort((a, b) => a.tokenPosition.compareTo(b.tokenPosition));
        final nextToken = next.firstOrNull;
        if (nextToken != null) {
          await _db
              .collection('tokens')
              .doc(nextToken.id)
              .update({'status': 'called'});
        }
      }
    }
  }

  Future<void> skipToken(
      TokenModel token, List<TokenModel> allTokens) async {
    final pending = allTokens
        .where((t) =>
            (t.status == 'active' || t.status == 'called') &&
            t.id != token.id)
        .toList()
      ..sort((a, b) => a.tokenPosition.compareTo(b.tokenPosition));

    final batch = _db.batch();
    for (int i = 0; i < pending.length; i++) {
      batch.update(_db.collection('tokens').doc(pending[i].id), {
        'token_position': i + 1,
        'people_ahead': i,
      });
    }
    batch.update(_db.collection('tokens').doc(token.id), {
      'token_position': pending.length + 1,
      'people_ahead': pending.length,
    });
    await batch.commit();
  }

  Future<void> setEmergencyPriority(
    TokenModel emergencyToken,
    List<TokenModel> allTokens,
  ) async {
    final pending = allTokens
        .where((t) =>
            (t.status == 'active' || t.status == 'called') &&
            t.id != emergencyToken.id)
        .toList()
      ..sort((a, b) => a.tokenPosition.compareTo(b.tokenPosition));

    final batch = _db.batch();
    for (int i = 0; i < pending.length; i++) {
      batch.update(_db.collection('tokens').doc(pending[i].id), {
        'token_position': i + 2,
        'people_ahead': i + 1,
      });
    }
    batch.update(_db.collection('tokens').doc(emergencyToken.id), {
      'token_position': 1,
      'people_ahead': 0,
    });
    await batch.commit();
  }
}

class DuplicateBookingException implements Exception {
  const DuplicateBookingException();
}
