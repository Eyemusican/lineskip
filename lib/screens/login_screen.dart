import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';

const _primaryBlue = Color(0xFF4F6BED);
const _lightBlue = Color(0xFF6C8BF5);
const _bgColor = Color(0xFFFAFBFD);
const _textPrimary = Color(0xFF1F2937);
const _textSecondary = Color(0xFF9CA3AF);
const _borderColor = Color(0xFFE5E7EB);
const _selectedBg = Color(0xFFEEF2FF);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authService = AuthService();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _otpFocusNode = FocusNode();

  bool _otpSent = false;
  bool _loading = false;
  String? _verificationId;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _otpController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final rawPhone = _phoneController.text.trim();
    if (rawPhone.isEmpty) {
      setState(() => _errorMessage = 'Please enter your phone number.');
      return;
    }
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      await _authService.verifyPhoneNumber(
        phoneNumber: '+975$rawPhone',
        verificationCompleted: (credential) async {
          try {
            await _authService.signInWithCredential(credential);
            if (mounted) _navigateToHome();
          } catch (e) {
            if (mounted) {
              setState(() {
                _loading = false;
                _errorMessage = e.toString();
              });
            }
          }
        },
        verificationFailed: (e) {
          if (mounted) {
            setState(() {
              _loading = false;
              _errorMessage = '[${e.code}] ${e.message ?? 'No message'}';
            });
          }
        },
        codeSent: (verificationId, _) {
          if (mounted) {
            setState(() {
              _loading = false;
              _otpSent = true;
              _verificationId = verificationId;
            });
          }
        },
        codeAutoRetrievalTimeout: (_) {},
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _verifyOtp() async {
    if (_verificationId == null) return;
    final code = _otpController.text.trim();
    if (code.length < 6) {
      setState(() => _errorMessage = 'Enter the 6-digit code sent to your phone.');
      return;
    }
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      await _authService.signInWithOtp(
        verificationId: _verificationId!,
        smsCode: code,
      );
      if (mounted) _navigateToHome();
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMessage = '[${e.code}] ${e.message ?? 'No message'}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: _bgColor,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(28, 0, 28, bottomPad + 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 48),

              // ── Logo block ────────────────────────────────────────
              Image.asset(
                'assets/images/logo.png',
                width: 180,
                height: 180,
              ),

              const SizedBox(height: 40),

              // ── Form card ─────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _borderColor, width: 0.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _otpSent ? 'Verify OTP' : 'Welcome',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _otpSent
                          ? 'Enter the 6-digit code sent to +975 ${_phoneController.text.trim()}'
                          : 'Enter your phone number to continue',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        color: _textSecondary,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Phone input
                    if (!_otpSent) ...[
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _borderColor, width: 0.5),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 16),
                              decoration: const BoxDecoration(
                                border: Border(
                                  right: BorderSide(
                                      color: _borderColor, width: 0.5),
                                ),
                              ),
                              child: const Text(
                                '🇧🇹  +975',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: _textSecondary,
                                ),
                              ),
                            ),
                            Expanded(
                              child: TextField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(8),
                                ],
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  color: _textPrimary,
                                  fontSize: 15,
                                ),
                                decoration: const InputDecoration(
                                  hintText: '17 XXX XXX',
                                  hintStyle: TextStyle(
                                    fontFamily: 'Poppins',
                                    color: Color(0xFFC4C9D4),
                                    fontSize: 15,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 16),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Send OTP button
                      _PrimaryButton(
                        label: 'Send OTP',
                        loading: _loading,
                        onTap: _loading ? null : _sendOtp,
                      ),
                    ],

                    // OTP input (6 boxes)
                    if (_otpSent) ...[
                      Stack(
                        children: [
                          _OtpBoxes(
                            value: _otpController.text,
                            onTap: () => _otpFocusNode.requestFocus(),
                          ),
                          Opacity(
                            opacity: 0,
                            child: TextField(
                              controller: _otpController,
                              focusNode: _otpFocusNode,
                              autofocus: true,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(6),
                              ],
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      GestureDetector(
                        onTap: () => setState(() {
                          _otpSent = false;
                          _otpController.clear();
                          _errorMessage = null;
                        }),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.arrow_back_ios_new_rounded,
                                size: 11, color: _textSecondary),
                            SizedBox(width: 4),
                            Text(
                              'Change number',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13,
                                color: _textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Verify button
                      _PrimaryButton(
                        label: 'Verify & login',
                        loading: _loading,
                        enabled: _otpController.text.length == 6,
                        onTap: (_loading || _otpController.text.length < 6)
                            ? null
                            : _verifyOtp,
                      ),
                    ],

                    // Error message
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: const Color(0xFFFEF2F2),
                          border: Border.all(
                            color: const Color(0xFFFCA5A5),
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                size: 15, color: Color(0xFFEF4444)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  color: Color(0xFFEF4444),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Footer
              RichText(
                textAlign: TextAlign.center,
                text: const TextSpan(
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    color: _textSecondary,
                    height: 1.6,
                  ),
                  children: [
                    TextSpan(text: 'By continuing, you agree to our '),
                    TextSpan(
                      text: 'terms',
                      style: TextStyle(color: _primaryBlue),
                    ),
                    TextSpan(text: ' and '),
                    TextSpan(
                      text: 'privacy policy',
                      style: TextStyle(color: _primaryBlue),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 6-box OTP display ─────────────────────────────────────────────────────────

class _OtpBoxes extends StatelessWidget {
  final String value;
  final VoidCallback onTap;

  const _OtpBoxes({required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(6, (i) {
          final filled = i < value.length;
          return Container(
            width: 44,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: filled ? _selectedBg : Colors.white,
              border: Border.all(
                color: filled ? _primaryBlue : const Color(0xFFD1D5DB),
                width: filled ? 1.5 : 0.5,
              ),
            ),
            child: Center(
              child: filled
                  ? Text(
                      value[i],
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: _primaryBlue,
                      ),
                    )
                  : null,
            ),
          );
        }),
      ),
    );
  }
}

// ── Primary button ─────────────────────────────────────────────────────────────

class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool loading;
  final bool enabled;
  final VoidCallback? onTap;

  const _PrimaryButton({
    required this.label,
    required this.loading,
    this.enabled = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = enabled && !loading;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: active ? _primaryBlue : const Color(0xFFF3F4F6),
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: active ? Colors.white : const Color(0xFF9CA3AF),
                  ),
                ),
        ),
      ),
    );
  }
}
