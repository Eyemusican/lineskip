import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/token_model.dart';
import '../services/firestore_service.dart';
import 'profile_screen.dart';
import 'queue_tracking_screen.dart';

const _primaryBlue = Color(0xFF4F6BED);
const _lightBlue = Color(0xFF6C8BF5);
const _bgColor = Color(0xFFFAFBFD);
const _textPrimary = Color(0xFF1F2937);
const _textSecondary = Color(0xFF9CA3AF);
const _borderColor = Color(0xFFE5E7EB);
const _selectedBg = Color(0xFFEEF2FF);

class MyTokensScreen extends StatelessWidget {
  const MyTokensScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: _bgColor,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top bar ────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(20, topPad + 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'My Tokens',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    color: _textPrimary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Your booking history',
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

          // ── Body ───────────────────────────────────────────────────
          Expanded(
            child: uid == null
                ? _EmptyState(onBook: () => Navigator.pop(context))
                : StreamBuilder<List<TokenModel>>(
                    stream: FirestoreService().getUserTokens(uid),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: _primaryBlue,
                            strokeWidth: 2,
                          ),
                        );
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 40),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.cloud_off_outlined,
                                    size: 44, color: Color(0xFFC4C9D4)),
                                SizedBox(height: 14),
                                Text(
                                  'Could not load tokens',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: _textSecondary,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Check your connection or create the\nFirestore index for the tokens collection.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 12,
                                    color: _textSecondary,
                                    height: 1.6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      final tokens = snapshot.data ?? [];
                      if (tokens.isEmpty) {
                        return _EmptyState(
                            onBook: () => Navigator.pop(context));
                      }
                      return _TokenList(
                        tokens: tokens,
                        bottomPad: bottomPad,
                      );
                    },
                  ),
          ),
        ],
      ),

      // ── Bottom nav ──────────────────────────────────────────────────
      bottomNavigationBar: _MyTokensNav(bottomPad: bottomPad),
    );
  }
}

// ── Token list ────────────────────────────────────────────────────────────────

class _TokenList extends StatelessWidget {
  final List<TokenModel> tokens;
  final double bottomPad;

  const _TokenList({required this.tokens, required this.bottomPad});

  IconData _sessionIcon(String session) {
    final s = session.toLowerCase();
    if (s.contains('morning')) return Icons.wb_sunny_outlined;
    if (s.contains('afternoon')) return Icons.wb_cloudy_outlined;
    return Icons.wb_twilight_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day);
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPad + 24),
      itemCount: tokens.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final token = tokens[index];
        final isToday = !token.issuedAt.isBefore(dayStart);
        return _TokenCard(
          tokenId: token.id,
          tokenNumber: token.tokenNumber,
          hospitalShort: token.hospitalShort,
          hospitalFull: token.hospitalName,
          session: token.session,
          sessionIcon: _sessionIcon(token.session),
          peopleAhead: token.peopleAhead,
          waitMinutes: token.estimatedWaitMinutes,
          totalQueue: token.tokenPosition,
          isActive: token.isActive,
          isToday: isToday,
          issuedAt: token.issuedAt,
          onTrack: token.isActive
              ? () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => QueueTrackingScreen(
                        tokenId: token.id,
                        tokenNumber: token.tokenNumber,
                        hospitalShort: token.hospitalShort,
                        hospitalFull: token.hospitalName,
                        hospitalId: token.hospitalId,
                        session: token.session,
                        sessionIcon: _sessionIcon(token.session),
                        initialPeopleAhead: token.peopleAhead,
                        totalQueue: token.tokenPosition,
                        waitMinutes: token.estimatedWaitMinutes,
                      ),
                    ),
                  )
              : null,
        );
      },
    );
  }
}

// ── Individual token card ──────────────────────────────────────────────────────

class _TokenCard extends StatelessWidget {
  final String tokenId;
  final String tokenNumber;
  final String hospitalShort;
  final String hospitalFull;
  final String session;
  final IconData sessionIcon;
  final int peopleAhead;
  final int waitMinutes;
  final int totalQueue;
  final bool isActive;
  final bool isToday;
  final DateTime issuedAt;
  final VoidCallback? onTrack;

  const _TokenCard({
    required this.tokenId,
    required this.tokenNumber,
    required this.hospitalShort,
    required this.hospitalFull,
    required this.session,
    required this.sessionIcon,
    required this.peopleAhead,
    required this.waitMinutes,
    required this.totalQueue,
    required this.isActive,
    required this.isToday,
    required this.issuedAt,
    this.onTrack,
  });

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isActive ? 1.0 : 0.7,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? _primaryBlue.withOpacity(0.25) : _borderColor,
            width: isActive ? 1 : 0.5,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: _primaryBlue.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              // Gradient header (active tokens)
              if (isActive)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_primaryBlue, _lightBlue],
                    ),
                  ),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'YOUR TOKEN',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 10,
                              color: Colors.white.withOpacity(0.75),
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tokenNumber,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 22,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: Colors.white.withOpacity(0.2),
                        ),
                        child: const Text(
                          'Active',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Card body
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isActive)
                      Row(
                        children: [
                          Text(
                            tokenNumber,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: _textSecondary,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              color: const Color(0xFFF3F4F6),
                            ),
                            child: Text(
                              isToday ? 'Completed' : _formatDate(issuedAt),
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 10,
                                color: _textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),

                    if (!isActive) const SizedBox(height: 8),

                    Text(
                      hospitalFull,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: _textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 10),

                    Container(height: 0.5, color: _borderColor),

                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: const Color(0xFFF3F4F6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(sessionIcon,
                                  size: 12, color: _textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                session,
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 10,
                                  color: _textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.people_alt_outlined,
                            size: 12, color: _textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          '$peopleAhead ahead',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            color: _textSecondary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.schedule_outlined,
                            size: 12, color: _textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          '~$waitMinutes min',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            color: _textSecondary,
                          ),
                        ),
                      ],
                    ),

                    if (isActive) ...[
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: onTrack,
                        child: Container(
                          width: double.infinity,
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: _selectedBg,
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.track_changes_rounded,
                                  color: _primaryBlue, size: 16),
                              SizedBox(width: 6),
                              Text(
                                'Track Queue',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: _primaryBlue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
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

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onBook;
  const _EmptyState({required this.onBook});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _selectedBg,
              ),
              child: const Icon(
                Icons.confirmation_number_outlined,
                color: _primaryBlue,
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No tokens yet',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Book your first OPD token\nand skip the queue',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: _textSecondary,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: onBook,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 13),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: _primaryBlue,
                ),
                child: const Text(
                  'Book Now',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bottom nav (My Tokens active) ────────────────────────────────────────────

class _MyTokensNav extends StatelessWidget {
  final double bottomPad;
  const _MyTokensNav({required this.bottomPad});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 62 + bottomPad,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _borderColor, width: 0.5)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomPad),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: Icons.home_outlined,
              activeIcon: Icons.home_rounded,
              label: 'Home',
              active: false,
              onTap: () => Navigator.pop(context),
            ),
            _NavItem(
              icon: Icons.confirmation_number_rounded,
              activeIcon: Icons.confirmation_number_rounded,
              label: 'My Tokens',
              active: true,
              onTap: () {},
            ),
            _NavItem(
              icon: Icons.map_outlined,
              activeIcon: Icons.map_rounded,
              label: 'Map',
              active: false,
              onTap: () => _showMapComingSoon(context),
            ),
            _NavItem(
              icon: Icons.person_outline_rounded,
              activeIcon: Icons.person_rounded,
              label: 'Profile',
              active: false,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _showMapComingSoon(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _borderColor, width: 0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: _selectedBg,
            ),
            child: const Icon(Icons.map_outlined, color: _primaryBlue, size: 28),
          ),
          const SizedBox(height: 16),
          const Text(
            'Map Coming Soon',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Hospital directions and live navigation\nwill be available in the next update.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              color: _textSecondary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xFFF3F4F6),
              ),
              child: const Center(
                child: Text(
                  'Got it',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              active ? activeIcon : icon,
              color: active ? _primaryBlue : const Color(0xFFC4C9D4),
              size: 22,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                fontWeight: active ? FontWeight.w500 : FontWeight.w400,
                color: active ? _primaryBlue : const Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
