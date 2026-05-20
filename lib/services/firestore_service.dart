import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/hospital.dart';
import '../models/token_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Hospitals ────────────────────────────────────────────────────────────

  Stream<List<Hospital>> getHospitals() {
    return _db
        .collection('hospitals')
        .snapshots()
        .map((snap) => snap.docs.map(Hospital.fromFirestore).toList());
  }

  /// Writes the sample hospitals to Firestore if none exist yet.
  Future<void> seedHospitalsIfEmpty() async {
    final snap = await _db.collection('hospitals').limit(1).get();
    if (snap.docs.isNotEmpty) return;

    final batch = _db.batch();
    for (final hospital in sampleHospitals) {
      final ref = _db.collection('hospitals').doc(hospital.id);
      batch.set(ref, hospital.toFirestore());
    }
    await batch.commit();
  }

  // ── Tokens ───────────────────────────────────────────────────────────────

  Future<String> bookToken({
    required String userId,
    required String hospitalId,
    required String hospitalName,
    required String hospitalShort,
    required String session,
    required int currentQueue,
    required int estimatedWaitMinutes,
    required String tokenNumber,
  }) async {
    final today = DateTime.now();
    final dateStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final safeSession = session.replaceAll(' ', '_').toLowerCase();
    final queueDocId = '${hospitalId}_${dateStr}_$safeSession';

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
      'token_position': currentQueue + 1,
      'people_ahead': currentQueue,
      'estimated_wait_minutes': estimatedWaitMinutes,
      'issued_at': FieldValue.serverTimestamp(),
    });

    return tokenRef.id;
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
}
