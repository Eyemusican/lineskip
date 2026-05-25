import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'phone_auth_stub.dart' if (dart.library.html) 'phone_auth_web.dart';
import 'queue_notification_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required PhoneVerificationCompleted verificationCompleted,
    required PhoneVerificationFailed verificationFailed,
    required PhoneCodeSent codeSent,
    required PhoneCodeAutoRetrievalTimeout codeAutoRetrievalTimeout,
  }) async {
    if (kIsWeb) {
      await initRecaptchaAndSendOtp(
        auth: _auth,
        phoneNumber: phoneNumber,
        codeSent: codeSent,
        verificationFailed: verificationFailed,
      );
    } else {
      return _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: verificationCompleted,
        verificationFailed: verificationFailed,
        codeSent: codeSent,
        codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
        timeout: const Duration(seconds: 60),
      );
    }
  }

  Future<UserCredential> signInWithOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    UserCredential result;

    if (kIsWeb && hasStoredResult) {
      final webResult = await confirmWithStoredResult(smsCode);
      if (webResult == null) {
        throw FirebaseAuthException(
          code: 'invalid-verification-code',
          message: 'OTP verification failed. Please try again.',
        );
      }
      result = webResult;
      clearRecaptcha();
    } else {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      result = await _auth.signInWithCredential(credential);
    }

    await _ensureUserDocument(result.user!);
    return result;
  }

  Future<UserCredential> signInWithCredential(
      PhoneAuthCredential credential) async {
    final result = await _auth.signInWithCredential(credential);
    await _ensureUserDocument(result.user!);
    return result;
  }

  Future<void> _ensureUserDocument(User user) async {
    // Check by uid field first — the doc ID may differ from the auth uid
    // (e.g. staff docs created manually with a different ID).
    final existing = await _db
        .collection('users')
        .where('uid', isEqualTo: user.uid)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) return;

    // Also check by phone to avoid duplicating a manually-created doc.
    if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
      final byPhone = await _db
          .collection('users')
          .where('phone', isEqualTo: user.phoneNumber)
          .limit(1)
          .get();
      if (byPhone.docs.isNotEmpty) return;
    }

    // Genuinely new user — create their document.
    await _db.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'name': user.displayName ?? '',
      'phone': user.phoneNumber ?? '',
      'role': 'patient',
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> signOut() async {
    clearRecaptcha();
    QueueNotificationService.instance.detach();
    await _auth.signOut();
    // Clear Firestore local cache so stale role data never survives across logins.
    try {
      await _db.clearPersistence();
    } catch (_) {}
  }
}
