import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _authService = AuthService();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  bool _otpSent = false;
  bool _loading = false;
  String? _verificationId;
  String? _errorMessage;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
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
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Background radial glows
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF00E5C8).withOpacity(0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -100,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF0057FF).withOpacity(0.07),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(28, topPad + 20, 28, bottomPad + 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),

                  // ── Branding ──────────────────────────────────────
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Colors.white, Color(0xFFB0D8D4)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds),
                    child: Text(
                      'LineSkip',
                      style: TextStyle(fontFamily: 'Poppins',
                        fontSize: 44,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -1,
                        height: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ScaleTransition(
                        scale: _pulseAnimation,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF00E5C8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Skip the Wait. Own Your Day.',
                        style: TextStyle(fontFamily: 'Poppins',
                          fontSize: 14,
                          color: const Color(0xFF00E5C8),
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 60),

                  // ── Step indicator ────────────────────────────────
                  Text(
                    _otpSent ? 'Verify your number' : 'Sign in to continue',
                    style: TextStyle(fontFamily: 'Poppins',
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _otpSent
                        ? 'Enter the 6-digit code sent to +975 ${_phoneController.text.trim()}'
                        : 'Enter your Bhutan phone number to receive an OTP',
                    style: TextStyle(fontFamily: 'Poppins',
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.5),
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── Phone number input ────────────────────────────
                  if (!_otpSent) ...[
                    _InputLabel(label: 'Phone Number'),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: const Color(0xFF152438),
                        border: Border.all(
                          color: const Color(0xFF1E3A52),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Country code prefix
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 18),
                            decoration: const BoxDecoration(
                              border: Border(
                                right: BorderSide(
                                    color: Color(0xFF1E3A52), width: 1),
                              ),
                            ),
                            child: Text(
                              '+975',
                              style: TextStyle(fontFamily: 'Poppins',
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF00E5C8),
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
                              style: TextStyle(fontFamily: 'Poppins',
                                color: Colors.white,
                                fontSize: 15,
                              ),
                              decoration: InputDecoration(
                                hintText: '17 XXX XXX',
                                hintStyle: TextStyle(fontFamily: 'Poppins',
                                  color: Colors.white.withOpacity(0.25),
                                  fontSize: 15,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 18),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // ── OTP input ─────────────────────────────────────
                  if (_otpSent) ...[
                    _InputLabel(label: 'One-Time Password'),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: const Color(0xFF152438),
                        border: Border.all(
                          color: const Color(0xFF1E3A52),
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        autofocus: true,
                        style: TextStyle(fontFamily: 'Poppins',
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 8,
                        ),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          hintText: '······',
                          hintStyle: TextStyle(fontFamily: 'Poppins',
                            color: Colors.white.withOpacity(0.2),
                            fontSize: 22,
                            letterSpacing: 8,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 18),
                        ),
                      ),
                    ),

                    // Resend link
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => setState(() {
                        _otpSent = false;
                        _otpController.clear();
                        _errorMessage = null;
                      }),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 12,
                            color: Colors.white.withOpacity(0.4),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Change number',
                            style: TextStyle(fontFamily: 'Poppins',
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // ── Error message ─────────────────────────────────
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.red.withOpacity(0.08),
                        border: Border.all(
                          color: Colors.red.withOpacity(0.25),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline_rounded,
                              size: 16, color: Colors.redAccent),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(fontFamily: 'Poppins',
                                fontSize: 12.5,
                                color: Colors.redAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // ── Action button ─────────────────────────────────
                  GestureDetector(
                    onTap: _loading
                        ? null
                        : (_otpSent ? _verifyOtp : _sendOtp),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: _loading
                            ? null
                            : const LinearGradient(
                                colors: [
                                  Color(0xFF00E5C8),
                                  Color(0xFF00B8A0),
                                ],
                              ),
                        color: _loading
                            ? const Color(0xFF152438)
                            : null,
                        boxShadow: _loading
                            ? null
                            : [
                                BoxShadow(
                                  color: const Color(0xFF00E5C8)
                                      .withOpacity(0.35),
                                  blurRadius: 20,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                      ),
                      child: Center(
                        child: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Color(0xFF00E5C8),
                                ),
                              )
                            : Text(
                                _otpSent ? 'Verify OTP' : 'Send OTP',
                                style: TextStyle(fontFamily: 'Poppins',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0D1B2A),
                                  letterSpacing: 0.2,
                                ),
                              ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Notice ────────────────────────────────────────
                  Center(
                    child: Text(
                      'By continuing, you agree to our Terms of Service.\nStandard message rates may apply.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: 'Poppins',
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.25),
                        height: 1.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InputLabel extends StatelessWidget {
  final String label;
  const _InputLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(fontFamily: 'Poppins',
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.white.withOpacity(0.6),
        letterSpacing: 0.3,
      ),
    );
  }
}
