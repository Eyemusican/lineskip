import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'phone_auth_stub.dart' if (dart.library.html) 'phone_auth_web.dart';

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
    final docRef = _db.collection('users').doc(user.uid);
    final doc = await docRef.get();
    if (!doc.exists) {
      await docRef.set({
        'uid': user.uid,
        'name': user.displayName ?? '',
        'phone': user.phoneNumber ?? '',
        'role': 'patient',
        'created_at': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> signOut() async {
    clearRecaptcha();
    await _auth.signOut();
  }
}
