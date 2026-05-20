import 'package:firebase_auth/firebase_auth.dart';

Future<void> initRecaptchaAndSendOtp({
  required FirebaseAuth auth,
  required String phoneNumber,
  required PhoneCodeSent codeSent,
  required PhoneVerificationFailed verificationFailed,
}) async {
  throw UnsupportedError('initRecaptchaAndSendOtp called on non-web platform');
}

Future<UserCredential?> confirmWithStoredResult(String smsCode) async => null;

bool get hasStoredResult => false;

void clearRecaptcha() {}
