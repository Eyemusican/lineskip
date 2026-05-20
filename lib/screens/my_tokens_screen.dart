import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/token_model.dart';
import '../services/firestore_service.dart';
import 'queue_tracking_screen.dart';

class MyTokensScreen extends StatelessWidget {
  const MyTokensScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: Stack(
        children: [
          // Background glows
          Positioned(
            top: -60,
            right: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF00E5C8).withOpacity(0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 140,
            left: -80,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF0057FF).withOpacity(0.06),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top bar ───────────────────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(24, topPad + 20, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My Tokens',
                      style: TextStyle(fontFamily: 'Poppins',
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF00E5C8),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          'Your active bookings today',
                          style: TextStyle(fontFamily: 'Poppins',
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.45),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Body ──────────────────────────────────────────────
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
                                color: Color(0xFF00E5C8),
                                strokeWidth: 2.5,
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
        ],
      ),

      // ── Bottom nav ────────────────────────────────────────────────
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
    if (s.contains('morning')) return Icons.wb_sunny_rounded;
    if (s.contains('afternoon')) return Icons.wb_cloudy_rounded;
    return Icons.wb_twilight_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPad + 24),
      itemCount: tokens.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final token = tokens[index];
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
          onTrack: token.isActive
              ? () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => QueueTrackingScreen(
                        tokenId: token.id,
                        tokenNumber: token.tokenNumber,
                        hospitalShort: token.hospitalShort,
                        hospitalFull: token.hospitalName,
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

// ── Individual token card ─────────────────────────────────────────────────────

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
    this.onTrack,
  });

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF00E5C8);

    return Opacity(
      opacity: isActive ? 1.0 : 0.6,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isActive
                ? [const Color(0xFF152438), const Color(0xFF0F1E30)]
                : [const Color(0xFF111C27), const Color(0xFF0C1720)],
          ),
          border: Border.all(
            color: isActive
                ? teal.withOpacity(0.45)
                : const Color(0xFF1E3A52).withOpacity(0.5),
            width: isActive ? 1.5 : 1,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: teal.withOpacity(0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            children: [
              // Active glow accent strip
              if (isActive)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 3,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [teal, Color(0xFF00CFFF)],
                      ),
                    ),
                  ),
                ),

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Row 1: badge + token + status pill ──────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Hospital initial badge
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(13),
                            color: isActive
                                ? teal.withOpacity(0.12)
                                : Colors.white.withOpacity(0.05),
                            border: Border.all(
                              color: isActive
                                  ? teal.withOpacity(0.3)
                                  : Colors.white.withOpacity(0.08),
                              width: 1,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              hospitalShort[0],
                              style: TextStyle(fontFamily: 'Poppins',
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: isActive
                                    ? teal
                                    : Colors.white.withOpacity(0.35),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Token number
                              ShaderMask(
                                shaderCallback: (bounds) => LinearGradient(
                                  colors: isActive
                                      ? [teal, const Color(0xFF00CFFF)]
                                      : [
                                          Colors.white.withOpacity(0.4),
                                          Colors.white.withOpacity(0.4),
                                        ],
                                ).createShader(bounds),
                                child: Text(
                                  tokenNumber,
                                  style: TextStyle(fontFamily: 'Poppins',
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                hospitalFull,
                                style: TextStyle(fontFamily: 'Poppins',
                                  fontSize: 12,
                                  color: Colors.white
                                      .withOpacity(isActive ? 0.5 : 0.3),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        // Status pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: isActive
                                ? teal.withOpacity(0.12)
                                : Colors.white.withOpacity(0.06),
                            border: Border.all(
                              color: isActive
                                  ? teal.withOpacity(0.4)
                                  : Colors.white.withOpacity(0.12),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            isActive ? 'Active' : 'Completed',
                            style: TextStyle(fontFamily: 'Poppins',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isActive
                                  ? teal
                                  : Colors.white.withOpacity(0.35),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Divider
                    Container(
                      height: 1,
                      color: Colors.white.withOpacity(0.06),
                    ),

                    const SizedBox(height: 16),

                    // ── Row 2: session + stats ───────────────────────
                    Row(
                      children: [
                        // Session chip
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: Colors.white.withOpacity(0.05),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.08),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                sessionIcon,
                                size: 13,
                                color: Colors.white
                                    .withOpacity(isActive ? 0.5 : 0.25),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                session,
                                style: TextStyle(fontFamily: 'Poppins',
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white
                                      .withOpacity(isActive ? 0.55 : 0.3),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const Spacer(),

                        // People ahead
                        _MiniStat(
                          icon: Icons.people_alt_rounded,
                          label: '$peopleAhead ahead',
                          isActive: isActive,
                        ),
                        const SizedBox(width: 14),
                        // Wait time
                        _MiniStat(
                          icon: Icons.schedule_rounded,
                          label: '~$waitMinutes min',
                          isActive: isActive,
                        ),
                      ],
                    ),

                    // ── Track Queue button (active only) ─────────────
                    if (isActive) ...[
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: onTrack,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: const LinearGradient(
                              colors: [teal, Color(0xFF00B8A0)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: teal.withOpacity(0.30),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.track_changes_rounded,
                                color: Color(0xFF0D1B2A),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Track Queue',
                                style: TextStyle(fontFamily: 'Poppins',
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0D1B2A),
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

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;

  const _MiniStat({
    required this.icon,
    required this.label,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 12,
          color: Colors.white.withOpacity(isActive ? 0.4 : 0.2),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontFamily: 'Poppins',
            fontSize: 11.5,
            color: Colors.white.withOpacity(isActive ? 0.5 : 0.25),
          ),
        ),
      ],
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
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00E5C8).withOpacity(0.10),
                border: Border.all(
                  color: const Color(0xFF00E5C8).withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.confirmation_number_rounded,
                color: Color(0xFF00E5C8),
                size: 38,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No tokens yet',
              style: TextStyle(fontFamily: 'Poppins',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Book your first OPD token\nand skip the queue',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Poppins',
                fontSize: 13.5,
                color: Colors.white.withOpacity(0.4),
                height: 1.6,
              ),
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: onBook,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 36, vertical: 15),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00E5C8), Color(0xFF00B8A0)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00E5C8).withOpacity(0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Text(
                  'Book Now',
                  style: TextStyle(fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0D1B2A),
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

// ── Bottom nav (My Tokens active) ─────────────────────────────────────────────

class _MyTokensNav extends StatelessWidget {
  final double bottomPad;

  const _MyTokensNav({required this.bottomPad});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72 + bottomPad,
      decoration: BoxDecoration(
        color: const Color(0xFF0F1E30),
        border: const Border(
          top: BorderSide(color: Color(0xFF1E3A52), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomPad),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: Icons.home_rounded,
              label: 'Home',
              active: false,
              onTap: () => Navigator.pop(context),
            ),
            _NavItem(
              icon: Icons.confirmation_number_rounded,
              label: 'My Tokens',
              active: true,
              onTap: () {},
            ),
            _NavItem(
              icon: Icons.map_outlined,
              label: 'Map',
              active: false,
              onTap: () {},
            ),
            _NavItem(
              icon: Icons.person_outline_rounded,
              label: 'Profile',
              active: false,
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: active
                  ? const Color(0xFF00E5C8)
                  : Colors.white.withOpacity(0.3),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontFamily: 'Poppins',
                fontSize: 10.5,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                color: active
                    ? const Color(0xFF00E5C8)
                    : Colors.white.withOpacity(0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
