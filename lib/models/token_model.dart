import 'package:cloud_firestore/cloud_firestore.dart';

class TokenModel {
  final String id;
  final String queueId;
  final String userId;
  final String hospitalId;
  final String hospitalName;
  final String hospitalShort;
  final String tokenNumber;
  final String session;
  final String status; // 'active', 'completed', 'cancelled'
  final int tokenPosition;
  final int peopleAhead;
  final int estimatedWaitMinutes;
  final DateTime issuedAt;

  const TokenModel({
    required this.id,
    required this.queueId,
    required this.userId,
    required this.hospitalId,
    required this.hospitalName,
    required this.hospitalShort,
    required this.tokenNumber,
    required this.session,
    required this.status,
    required this.tokenPosition,
    required this.peopleAhead,
    required this.estimatedWaitMinutes,
    required this.issuedAt,
  });

  factory TokenModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TokenModel(
      id: doc.id,
      queueId: data['queue_id'] ?? '',
      userId: data['user_id'] ?? '',
      hospitalId: data['hospital_id'] ?? '',
      hospitalName: data['hospital_name'] ?? '',
      hospitalShort: data['hospital_short'] ?? '',
      tokenNumber: data['token_number'] ?? '',
      session: data['session'] ?? '',
      status: data['status'] ?? 'active',
      tokenPosition: data['token_position'] ?? 0,
      peopleAhead: data['people_ahead'] ?? 0,
      estimatedWaitMinutes: data['estimated_wait_minutes'] ?? 0,
      issuedAt: (data['issued_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'queue_id': queueId,
        'user_id': userId,
        'hospital_id': hospitalId,
        'hospital_name': hospitalName,
        'hospital_short': hospitalShort,
        'token_number': tokenNumber,
        'session': session,
        'status': status,
        'token_position': tokenPosition,
        'people_ahead': peopleAhead,
        'estimated_wait_minutes': estimatedWaitMinutes,
        'issued_at': Timestamp.fromDate(issuedAt),
      };

  bool get isActive => status == 'active';
}
