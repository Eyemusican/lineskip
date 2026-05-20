import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';

RecaptchaVerifier? _recaptchaVerifier;
ConfirmationResult? _confirmationResult;

Future<void> initRecaptchaAndSendOtp({
  required FirebaseAuth auth,
  required String phoneNumber,
  required PhoneCodeSent codeSent,
  required PhoneVerificationFailed verificationFailed,
}) async {
  try {
    _recaptchaVerifier?.clear();

    // FirebaseAuth._delegate is private; reconstruct the platform instance
    // from the two public getters FirebaseAuth inherits via FirebasePluginPlatform.
    final authPlatform = FirebaseAuthPlatform.instanceFor(
      app: auth.app,
      pluginConstants: auth.pluginConstants,
    );

    _recaptchaVerifier = RecaptchaVerifier(
      auth: authPlatform,
      container: 'recaptcha-container',
      size: RecaptchaVerifierSize.normal,
      onSuccess: () {},
      onError: (e) => verificationFailed(e),
      onExpired: () {},
    );

    await _recaptchaVerifier!.render();

    _confirmationResult = await auth.signInWithPhoneNumber(
      phoneNumber,
      _recaptchaVerifier!,
    );

    // Widget no longer needed once OTP has been dispatched.
    _recaptchaVerifier!.clear();
    _recaptchaVerifier = null;

    codeSent(_confirmationResult!.verificationId, null);
  } on FirebaseAuthException catch (e) {
    _recaptchaVerifier?.clear();
    _recaptchaVerifier = null;
    _confirmationResult = null;
    verificationFailed(e);
  }
}

Future<UserCredential?> confirmWithStoredResult(String smsCode) async {
  if (_confirmationResult == null) return null;
  return await _confirmationResult!.confirm(smsCode);
}

bool get hasStoredResult => _confirmationResult != null;

void clearRecaptcha() {
  _recaptchaVerifier?.clear();
  _recaptchaVerifier = null;
  _confirmationResult = null;
}
