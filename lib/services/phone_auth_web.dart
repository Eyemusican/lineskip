import 'package:firebase_auth/firebase_auth.dart';

ConfirmationResult? _confirmationResult;

Future<void> initRecaptchaAndSendOtp({
  required FirebaseAuth auth,
  required String phoneNumber,
  required PhoneCodeSent codeSent,
  required PhoneVerificationFailed verificationFailed,
}) async {
  if (auth.currentUser != null) return;
  try {
    // No RecaptchaVerifier passed — Firebase handles verification internally.
    _confirmationResult = await auth.signInWithPhoneNumber(phoneNumber);
    codeSent(_confirmationResult!.verificationId, null);
  } on FirebaseAuthException catch (e) {
    _confirmationResult = null;
    verificationFailed(e);
  }
}

Future<UserCredential?> confirmWithStoredResult(String smsCode) async {
  if (_confirmationResult == null) return null;
  final result = await _confirmationResult!.confirm(smsCode);
  _confirmationResult = null;
  return result;
}

bool get hasStoredResult => _confirmationResult != null;

void clearRecaptcha() {
  _confirmationResult = null;
}
