import 'package:flutter/material.dart';
import 'login_screen.dart';

// Brand colors — light healthcare-startup palette
const _kPrimary = Color(0xFF1A56FF);
const _kBg = Color(0xFFF0F5FF);
const _kCardBg = Colors.white;
const _kTextDark = Color(0xFF0F172A);
const _kTextMid = Color(0xFF475569);
const _kTextLight = Color(0xFF94A3B8);

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with TickerProviderStateMixin {
  late AnimationController _heroCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _floatCtrl;

  late Animation<double> _heroFade;
  late Animation<Offset> _heroSlide;
  late Animation<double> _pulse;
  late Animation<double> _float;

  @override
  void initState() {
    super.initState();
    _heroCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _floatCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);

    _heroFade =
        CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOut);
    _heroSlide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOut));
    _pulse = Tween<double>(begin: 0.9, end: 1.0).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _float = Tween<double>(begin: -6, end: 6).animate(
        CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));

    _heroCtrl.forward();
  }

  @override
  void dispose() {
    _heroCtrl.dispose();
    _pulseCtrl.dispose();
    _floatCtrl.dispose();
    super.dispose();
  }

  void _goToLogin() {
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, a, __) => const LoginScreen(),
      transitionsBuilder: (_, a, __, child) => FadeTransition(
        opacity: a,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(
              CurvedAnimation(parent: a, curve: Curves.easeOut)),
          child: child,
        ),
      ),
      transitionDuration: const Duration(milliseconds: 380),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Hero block (gradient top) ───────────────────────
            _HeroBlock(
              heroFade: _heroFade,
              heroSlide: _heroSlide,
              pulse: _pulse,
              float: _float,
              onGetStarted: _goToLogin,
              onLogin: _goToLogin,
            ),

            // ── Trusted strip ────────────────────────────────────
            _TrustedStrip(),

            const SizedBox(height: 52),

            // ── Features ─────────────────────────────────────────
            _FeaturesSection(),

            const SizedBox(height: 52),

            // ── How it works ──────────────────────────────────────
            _HowItWorksSection(),

            const SizedBox(height: 52),

            // ── CTA banner ────────────────────────────────────────
            _CtaBanner(onGetStarted: _goToLogin),

            const SizedBox(height: 40),

            // ── Footer ─────────────────────────────────────────────
            const _Footer(),

            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HERO BLOCK
// ─────────────────────────────────────────────────────────────────────────────

class _HeroBlock extends StatelessWidget {
  final Animation<double> heroFade;
  final Animation<Offset> heroSlide;
  final Animation<double> pulse;
  final Animation<double> float;
  final VoidCallback onGetStarted;
  final VoidCallback onLogin;

  const _HeroBlock({
    required this.heroFade,
    required this.heroSlide,
    required this.pulse,
    required this.float,
    required this.onGetStarted,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A56FF), Color(0xFF0EA5E9)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            top: topPad + 20,
            right: -50,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            bottom: 60,
            left: -70,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),

          Padding(
            padding: EdgeInsets.fromLTRB(24, topPad + 16, 24, 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Navbar ──────────────────────────────────────
                FadeTransition(
                  opacity: heroFade,
                  child: Row(
                    children: [
                      // Logo
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset(
                          'assets/Lineskip.png',
                          height: 36,
                          errorBuilder: (_, __, ___) => const Text(
                            'LineSkip',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Login button top-right
                      GestureDetector(
                        onTap: onLogin,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30),
                            color: Colors.white,
                          ),
                          child: const Text(
                            'Login',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _kPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 48),

                // ── Headline ──────────────────────────────────────
                FadeTransition(
                  opacity: heroFade,
                  child: SlideTransition(
                    position: heroSlide,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Live badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ScaleTransition(
                                scale: pulse,
                                child: Container(
                                  width: 7,
                                  height: 7,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFF4ADE80),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 7),
                              const Text(
                                'Live in Bhutan hospitals',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 22),

                        const Text(
                          'Skip the Line,\nNot the Care.',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 40,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -1.2,
                            height: 1.15,
                          ),
                        ),

                        const SizedBox(height: 16),

                        Text(
                          'Book your OPD token from anywhere and track\nyour live queue — no more waiting at the hospital.',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14.5,
                            color: Colors.white.withValues(alpha: 0.82),
                            height: 1.6,
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Get Started button
                        GestureDetector(
                          onTap: onGetStarted,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 36, vertical: 17),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: const Text(
                              'Get Started — It\'s Free',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: _kPrimary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 48),

                // ── Floating feature badges ──────────────────────
                FadeTransition(
                  opacity: heroFade,
                  child: AnimatedBuilder(
                    animation: float,
                    builder: (_, child) => Transform.translate(
                      offset: Offset(0, float.value * 0.4),
                      child: child,
                    ),
                    child: Column(
                      children: [
                        _HeroBadge(
                          icon: Icons.check_circle_rounded,
                          label: 'Book OPD Token Remotely',
                          color: const Color(0xFF4ADE80),
                          delay: 0,
                        ),
                        const SizedBox(height: 10),
                        _HeroBadge(
                          icon: Icons.check_circle_rounded,
                          label: 'Live Queue Tracking',
                          color: const Color(0xFFFBBF24),
                          delay: 1,
                        ),
                        const SizedBox(height: 10),
                        _HeroBadge(
                          icon: Icons.check_circle_rounded,
                          label: 'Smart Arrival Notifications',
                          color: const Color(0xFF60A5FA),
                          delay: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final int delay;

  const _HeroBadge({
    required this.icon,
    required this.label,
    required this.color,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: _kTextDark,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TRUSTED STRIP
// ─────────────────────────────────────────────────────────────────────────────

class _TrustedStrip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 28, 24, 0),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: _kCardBg,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A56FF).withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatPill(value: '12+', label: 'Hospitals'),
          _Divider(),
          _StatPill(value: '500+', label: 'Daily Tokens'),
          _Divider(),
          _StatPill(value: '< 2 min', label: 'To Book'),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String value;
  final String label;
  const _StatPill({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: _kPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11.5,
            color: _kTextLight,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      color: const Color(0xFFE2E8F0),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FEATURES SECTION
// ─────────────────────────────────────────────────────────────────────────────

class _FeaturesSection extends StatelessWidget {
  static const _cards = [
    _FeatureItem(
      icon: Icons.smartphone_rounded,
      title: 'Book from Anywhere',
      desc: 'Reserve your OPD slot from home, work, or on the go. No more early-morning rushes to the hospital.',
      iconBg: Color(0xFFEFF6FF),
      iconColor: Color(0xFF1A56FF),
    ),
    _FeatureItem(
      icon: Icons.radar_rounded,
      title: 'Live Queue Status',
      desc: 'Watch the queue move in real time. Arrive at the hospital only when your turn is near.',
      iconBg: Color(0xFFF0FDF4),
      iconColor: Color(0xFF16A34A),
    ),
    _FeatureItem(
      icon: Icons.notifications_active_rounded,
      title: 'Arrival Alerts',
      desc: 'Get notified automatically when you\'re next in line — so you can leave at the perfect moment.',
      iconBg: Color(0xFFFFFBEB),
      iconColor: Color(0xFFD97706),
    ),
    _FeatureItem(
      icon: Icons.account_balance_rounded,
      title: 'All Major Hospitals',
      desc: 'JDWNRH, Thimphu, Paro, Punakha and more — all in one app.',
      iconBg: Color(0xFFFDF4FF),
      iconColor: Color(0xFF7C3AED),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Tag(label: 'Features'),
          const SizedBox(height: 12),
          const Text(
            'Everything you need\nto own your health.',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: _kTextDark,
              letterSpacing: -0.6,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Purpose-built for Bhutan\'s public healthcare system.',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13.5,
              color: _kTextMid,
            ),
          ),
          const SizedBox(height: 28),
          ..._cards.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _FeatureCard(item: c),
              )),
        ],
      ),
    );
  }
}

class _FeatureItem {
  final IconData icon;
  final String title;
  final String desc;
  final Color iconBg;
  final Color iconColor;
  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.desc,
    required this.iconBg,
    required this.iconColor,
  });
}

class _FeatureCard extends StatelessWidget {
  final _FeatureItem item;
  const _FeatureCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: _kCardBg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: item.iconBg,
            ),
            child: Icon(item.icon, color: item.iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: _kTextDark,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  item.desc,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12.5,
                    color: _kTextMid,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HOW IT WORKS
// ─────────────────────────────────────────────────────────────────────────────

class _HowItWorksSection extends StatelessWidget {
  static const _steps = [
    _Step(
      num: '1',
      title: 'Sign In with OTP',
      desc: 'Verify your Bhutan phone number in seconds — no passwords.',
      color: Color(0xFF1A56FF),
    ),
    _Step(
      num: '2',
      title: 'Choose a Hospital',
      desc: 'Browse hospitals, check live wait times and pick your department.',
      color: Color(0xFF0EA5E9),
    ),
    _Step(
      num: '3',
      title: 'Book Your Token',
      desc: 'Confirm your slot instantly. Your number is reserved right away.',
      color: Color(0xFF00C9A7),
    ),
    _Step(
      num: '4',
      title: 'Track & Go',
      desc: 'Monitor the queue live and head to the hospital at just the right time.',
      color: Color(0xFF7C3AED),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Tag(label: 'How It Works'),
          const SizedBox(height: 12),
          const Text(
            'Up and running\nin four steps.',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: _kTextDark,
              letterSpacing: -0.6,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 28),
          ..._steps.asMap().entries.map((e) {
            final isLast = e.key == _steps.length - 1;
            return _StepRow(step: e.value, isLast: isLast);
          }),
        ],
      ),
    );
  }
}

class _Step {
  final String num;
  final String title;
  final String desc;
  final Color color;
  const _Step(
      {required this.num,
      required this.title,
      required this.desc,
      required this.color});
}

class _StepRow extends StatelessWidget {
  final _Step step;
  final bool isLast;
  const _StepRow({required this.step, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 44,
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: step.color,
                    boxShadow: [
                      BoxShadow(
                        color: step.color.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      step.num,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            step.color.withValues(alpha: 0.4),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 28, top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.title,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _kTextDark,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    step.desc,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      color: _kTextMid,
                      height: 1.55,
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

// ─────────────────────────────────────────────────────────────────────────────
// CTA BANNER
// ─────────────────────────────────────────────────────────────────────────────

class _CtaBanner extends StatelessWidget {
  final VoidCallback onGetStarted;
  const _CtaBanner({required this.onGetStarted});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A56FF), Color(0xFF0EA5E9)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1A56FF).withValues(alpha: 0.3),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: -24,
              right: -24,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.07),
                ),
              ),
            ),
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Your health,\non your schedule.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Join patients across Bhutan who already\nskip the line with LineSkip.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13.5,
                    color: Colors.white.withValues(alpha: 0.78),
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 26),
                GestureDetector(
                  onTap: onGetStarted,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: Colors.white,
                    ),
                    child: const Text(
                      'Get Started — It\'s Free',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _kPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_rounded,
                        size: 13,
                        color: Colors.white.withValues(alpha: 0.6)),
                    const SizedBox(width: 5),
                    Text(
                      'OTP secured · No fees · Works instantly',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11.5,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FOOTER
// ─────────────────────────────────────────────────────────────────────────────

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Container(height: 1, color: const Color(0xFFE2E8F0)),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'LineSkip',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: _kPrimary,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Smarter healthcare\naccess for Bhutan.',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: _kTextLight,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _FooterLink(label: 'Privacy Policy'),
                  SizedBox(height: 8),
                  _FooterLink(label: 'Terms of Service'),
                  SizedBox(height: 8),
                  _FooterLink(label: 'Contact'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            '© 2025 LineSkip · Made with ❤️ in Bhutan',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              color: _kTextLight,
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  final String label;
  const _FooterLink({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 12,
        color: _kTextMid,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED
// ─────────────────────────────────────────────────────────────────────────────

class _Tag extends StatelessWidget {
  final String label;
  const _Tag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFFEFF6FF),
        border: Border.all(color: const Color(0xFFBFDBFE), width: 1),
      ),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: _kPrimary,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}
