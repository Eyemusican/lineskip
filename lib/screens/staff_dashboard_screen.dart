import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/token_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/hospital.dart';

const _primaryBlue = Color(0xFF4F6BED);
const _bgColor = Color(0xFFFAFBFD);
const _cardWhite = Colors.white;
const _borderColor = Color(0xFFE5E7EB);
const _textPrimary = Color(0xFF1F2937);
const _textSecondary = Color(0xFF9CA3AF);
const _selectedBg = Color(0xFFEEF2FF);
const _successGreen = Color(0xFF10B981);
const _errorRed = Color(0xFFEF4444);
const _warningAmber = Color(0xFFD97706);

class StaffDashboardScreen extends StatefulWidget {
  const StaffDashboardScreen({super.key});

  @override
  State<StaffDashboardScreen> createState() => _StaffDashboardScreenState();
}

class _StaffDashboardScreenState extends State<StaffDashboardScreen> {
  final _service = FirestoreService();
  bool _busy = false;
  String? _hospitalId;
  bool _loadingHospital = true;

  @override
  void initState() {
    super.initState();
    _loadHospitalId();
  }

  Future<void> _loadHospitalId() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _loadingHospital = false);
      return;
    }
    final id = await _service.getStaffHospitalId(uid);
    if (mounted) {
      setState(() {
        _hospitalId = id;
        _loadingHospital = false;
      });
    }
  }

  Future<void> _run(Future<void> Function() fn) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await fn();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e',
                style: const TextStyle(fontFamily: 'Poppins')),
            backgroundColor: _errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showEmergencyDialog(BuildContext ctx, List<TokenModel> activeTokens) {
    if (activeTokens.isEmpty) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(
          content: Text('No active tokens in queue',
              style: TextStyle(fontFamily: 'Poppins')),
        ),
      );
      return;
    }
    showDialog(
      context: ctx,
      builder: (dialogCtx) => _EmergencyDialog(
        tokens: activeTokens,
        onSelect: (t) {
          Navigator.pop(dialogCtx);
          _run(() => _service.setEmergencyPriority(t, activeTokens));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingHospital) {
      return const Scaffold(
        backgroundColor: _bgColor,
        body: Center(
          child: CircularProgressIndicator(color: _primaryBlue, strokeWidth: 2),
        ),
      );
    }

    if (_hospitalId == null) {
      return _HospitalSelectorScreen(
        onSelect: (hospitalId) async {
          final uid = FirebaseAuth.instance.currentUser?.uid;
          if (uid == null) return;
          await _service.saveStaffHospitalId(uid, hospitalId);
          if (mounted) setState(() => _hospitalId = hospitalId);
        },
      );
    }

    return Scaffold(
      backgroundColor: _bgColor,
      body: StreamBuilder<List<TokenModel>>(
        stream: _service.getTodayTokensStream(_hospitalId!),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: _primaryBlue, strokeWidth: 2),
            );
          }
          final tokens = snap.data ?? [];
          final calledTokens =
              tokens.where((t) => t.status == 'called').toList();
          final activeTokens = tokens
              .where((t) => t.status == 'active')
              .toList()
            ..sort((a, b) => a.tokenPosition.compareTo(b.tokenPosition));
          final doneTokens = tokens
              .where((t) =>
                  t.status == 'served' ||
                  t.status == 'completed' ||
                  t.status == 'absent' ||
                  t.status == 'cancelled')
              .toList()
            ..sort((a, b) => b.tokenPosition.compareTo(a.tokenPosition));

          final total = tokens.length;
          final served = tokens
              .where(
                  (t) => t.status == 'served' || t.status == 'completed')
              .length;
          final absent = tokens
              .where(
                  (t) => t.status == 'absent' || t.status == 'cancelled')
              .length;
          final remaining = tokens
              .where(
                  (t) => t.status == 'active' || t.status == 'called')
              .length;

          return Column(
            children: [
              _DashboardHeader(busy: _busy, hospitalId: _hospitalId),
              Expanded(
                child: LayoutBuilder(
                  builder: (_, constraints) {
                    final wide = constraints.maxWidth > 900;
                    return SingleChildScrollView(
                      padding: EdgeInsets.all(wide ? 32 : 20),
                      child: Center(
                        child: ConstrainedBox(
                          constraints:
                              const BoxConstraints(maxWidth: 1200),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _StatsRow(
                                total: total,
                                served: served,
                                remaining: remaining,
                                absent: absent,
                              ),
                              const SizedBox(height: 20),
                              _ActionBar(
                                hasActive: activeTokens.isNotEmpty,
                                busy: _busy,
                                onCallNext: () => _run(
                                    () => _service.callNextToken(tokens)),
                                onEmergency: () =>
                                    _showEmergencyDialog(ctx, activeTokens),
                              ),
                              if (calledTokens.isNotEmpty) ...[
                                const SizedBox(height: 24),
                                _SectionLabel(
                                  title: 'Currently Being Called',
                                  color: _primaryBlue,
                                  icon: Icons.campaign_outlined,
                                ),
                                const SizedBox(height: 10),
                                ...calledTokens.map((t) => _TokenCard(
                                      token: t,
                                      onServed: _busy
                                          ? null
                                          : () => _run(() =>
                                              _service.markTokenStatus(
                                                t.id,
                                                'served',
                                                tokens,
                                                t.tokenPosition,
                                              )),
                                      onAbsent: _busy
                                          ? null
                                          : () => _run(() =>
                                              _service.markTokenStatus(
                                                t.id,
                                                'absent',
                                                tokens,
                                                t.tokenPosition,
                                              )),
                                      onSkip: null,
                                      onEmergency: null,
                                    )),
                              ],
                              if (activeTokens.isNotEmpty) ...[
                                const SizedBox(height: 24),
                                _SectionLabel(
                                  title: 'Waiting Queue',
                                  count: activeTokens.length,
                                  icon: Icons.people_outlined,
                                ),
                                const SizedBox(height: 10),
                                ...activeTokens.map((t) => _TokenCard(
                                      token: t,
                                      onServed: _busy
                                          ? null
                                          : () => _run(() =>
                                              _service.markTokenStatus(
                                                t.id,
                                                'served',
                                                tokens,
                                                t.tokenPosition,
                                              )),
                                      onAbsent: _busy
                                          ? null
                                          : () => _run(() =>
                                              _service.markTokenStatus(
                                                t.id,
                                                'absent',
                                                tokens,
                                                t.tokenPosition,
                                              )),
                                      onSkip: _busy
                                          ? null
                                          : () => _run(() =>
                                              _service.skipToken(t, tokens)),
                                      onEmergency: _busy
                                          ? null
                                          : () => _run(() =>
                                              _service
                                                  .setEmergencyPriority(
                                                      t, tokens)),
                                    )),
                              ],
                              if (activeTokens.isEmpty &&
                                  calledTokens.isEmpty) ...[
                                const SizedBox(height: 48),
                                const _EmptyQueue(),
                              ],
                              if (doneTokens.isNotEmpty) ...[
                                const SizedBox(height: 24),
                                _SectionLabel(
                                  title: 'Completed',
                                  count: doneTokens.length,
                                  icon: Icons.check_circle_outline_rounded,
                                  muted: true,
                                ),
                                const SizedBox(height: 10),
                                ...doneTokens.map(
                                    (t) => _DoneRow(token: t)),
                              ],
                              const SizedBox(height: 32),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _DashboardHeader extends StatelessWidget {
  final bool busy;
  final String? hospitalId;
  const _DashboardHeader({required this.busy, this.hospitalId});

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.of(context).size.width < 600;
    return Container(
      decoration: const BoxDecoration(
        color: _cardWhite,
        border: Border(
            bottom: BorderSide(color: _borderColor, width: 0.5)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              // Logo
              Image.asset(
                'assets/images/logo.png',
                width: 36,
                height: 36,
              ),
              Container(
                  width: 1,
                  height: 20,
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                  color: _borderColor),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Staff Dashboard',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: _textPrimary,
                    ),
                  ),
                  if (hospitalId != null)
                    Text(
                      '${hospitalId!.toUpperCase()} OPD',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        color: _primaryBlue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
              const Spacer(),
              if (busy)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: _primaryBlue),
                ),
              if (!narrow) ...[
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: _selectedBg,
                    border: Border.all(
                        color: _primaryBlue.withOpacity(0.3), width: 0.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: _successGreen,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'LIVE',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: _primaryBlue,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                TextButton.icon(
                  onPressed: () => AuthService().signOut(),
                  icon: const Icon(Icons.logout_rounded,
                      size: 15, color: _errorRed),
                  label: const Text(
                    'Sign Out',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _errorRed,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    backgroundColor: const Color(0xFFFEF2F2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                          color: _errorRed.withOpacity(0.2), width: 0.5),
                    ),
                  ),
                ),
              ] else ...[
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: _errorRed.withOpacity(0.2), width: 0.5),
                  ),
                  child: IconButton(
                    onPressed: () => AuthService().signOut(),
                    icon: const Icon(Icons.logout_rounded,
                        size: 18, color: _errorRed),
                    tooltip: 'Sign Out',
                    padding: const EdgeInsets.all(7),
                    constraints: const BoxConstraints(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Stats Row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final int total, served, remaining, absent;
  const _StatsRow({
    required this.total,
    required this.served,
    required this.remaining,
    required this.absent,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, c) {
      final narrow = c.maxWidth < 600;
      final cards = [
        _StatCard(
          label: 'Total Tokens',
          value: total,
          icon: Icons.confirmation_number_outlined,
          iconBg: _selectedBg,
          iconColor: _primaryBlue,
          valueBg: _selectedBg,
          valueColor: const Color(0xFF4338CA),
        ),
        _StatCard(
          label: 'Served',
          value: served,
          icon: Icons.check_circle_outline_rounded,
          iconBg: const Color(0xFFD1FAE5),
          iconColor: _successGreen,
          valueBg: const Color(0xFFD1FAE5),
          valueColor: const Color(0xFF065F46),
        ),
        _StatCard(
          label: 'Remaining',
          value: remaining,
          icon: Icons.hourglass_top_outlined,
          iconBg: const Color(0xFFFEF3C7),
          iconColor: _warningAmber,
          valueBg: const Color(0xFFFEF3C7),
          valueColor: const Color(0xFF92400E),
        ),
        _StatCard(
          label: 'Absent',
          value: absent,
          icon: Icons.person_off_outlined,
          iconBg: const Color(0xFFFEF2F2),
          iconColor: _errorRed,
          valueBg: const Color(0xFFFEF2F2),
          valueColor: const Color(0xFFDC2626),
        ),
      ];
      if (narrow) {
        return Column(children: [
          Row(children: [
            Expanded(child: cards[0]),
            const SizedBox(width: 10),
            Expanded(child: cards[1]),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: cards[2]),
            const SizedBox(width: 10),
            Expanded(child: cards[3]),
          ]),
        ]);
      }
      return Row(
        children: cards
            .map((c) => Expanded(
                child: Padding(
                    padding: const EdgeInsets.only(right: 10), child: c)))
            .toList(),
      );
    });
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final Color valueBg;
  final Color valueColor;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.valueBg,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              color: iconBg,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$value',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  color: valueColor,
                  height: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  color: _textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Action Bar ────────────────────────────────────────────────────────────────

class _ActionBar extends StatelessWidget {
  final bool hasActive;
  final bool busy;
  final VoidCallback onCallNext;
  final VoidCallback onEmergency;

  const _ActionBar({
    required this.hasActive,
    required this.busy,
    required this.onCallNext,
    required this.onEmergency,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, c) {
      final narrow = c.maxWidth < 600;
      final callBtn = _CallNextButton(
        hasActive: hasActive,
        busy: busy,
        onTap: onCallNext,
      );
      final emergencyBtn = _EmergencyButton(
        hasActive: hasActive,
        busy: busy,
        onTap: onEmergency,
      );
      if (narrow) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            callBtn,
            const SizedBox(height: 10),
            emergencyBtn,
          ],
        );
      }
      return Row(children: [
        Expanded(flex: 3, child: callBtn),
        const SizedBox(width: 10),
        Expanded(flex: 2, child: emergencyBtn),
      ]);
    });
  }
}

class _CallNextButton extends StatelessWidget {
  final bool hasActive;
  final bool busy;
  final VoidCallback onTap;

  const _CallNextButton({
    required this.hasActive,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = hasActive && !busy;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: enabled ? _primaryBlue : const Color(0xFFF3F4F6),
          border: enabled
              ? null
              : Border.all(color: _borderColor, width: 0.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.campaign_outlined,
              color: enabled ? Colors.white : _textSecondary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Call Next Token',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: enabled ? Colors.white : _textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmergencyButton extends StatelessWidget {
  final bool hasActive;
  final bool busy;
  final VoidCallback onTap;

  const _EmergencyButton({
    required this.hasActive,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = hasActive && !busy;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: enabled
              ? const Color(0xFFFEF2F2)
              : const Color(0xFFF9FAFB),
          border: Border.all(
            color: enabled
                ? _errorRed.withOpacity(0.3)
                : _borderColor,
            width: enabled ? 1 : 0.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.emergency_outlined,
              color: enabled ? _errorRed : _textSecondary,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              'Emergency Priority',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: enabled ? _errorRed : _textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section Label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String title;
  final int? count;
  final IconData icon;
  final Color color;
  final bool muted;

  const _SectionLabel({
    required this.title,
    this.count,
    required this.icon,
    this.color = _textPrimary,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = muted ? _textSecondary : color;
    return Row(
      children: [
        Icon(icon, color: c, size: 16),
        const SizedBox(width: 7),
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: c,
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: 7),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: c.withOpacity(0.1),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: c,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Token Card ────────────────────────────────────────────────────────────────

class _TokenCard extends StatelessWidget {
  final TokenModel token;
  final VoidCallback? onServed;
  final VoidCallback? onAbsent;
  final VoidCallback? onSkip;
  final VoidCallback? onEmergency;

  const _TokenCard({
    required this.token,
    required this.onServed,
    required this.onAbsent,
    required this.onSkip,
    this.onEmergency,
  });

  @override
  Widget build(BuildContext context) {
    final isCalled = token.status == 'called';
    final timeStr = _formatTime(token.issuedAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isCalled ? const Color(0xFFF0FDF4) : _cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCalled
              ? _successGreen.withOpacity(0.4)
              : _borderColor,
          width: isCalled ? 1 : 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(7),
                  color: isCalled ? _successGreen.withOpacity(0.1) : _selectedBg,
                  border: Border.all(
                    color: isCalled
                        ? _successGreen.withOpacity(0.3)
                        : _primaryBlue.withOpacity(0.2),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  token.tokenNumber,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isCalled ? _successGreen : _primaryBlue,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _StatusBadge(status: token.status),
              const Spacer(),
              Row(
                children: [
                  const Icon(Icons.access_time_outlined,
                      size: 12, color: _textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    timeStr,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      color: _textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _ActionChip(
                label: 'SERVED',
                icon: Icons.check_rounded,
                color: _successGreen,
                onTap: onServed,
              ),
              _ActionChip(
                label: 'ABSENT',
                icon: Icons.person_off_outlined,
                color: _errorRed,
                onTap: onAbsent,
              ),
              if (onSkip != null)
                _ActionChip(
                  label: 'SKIP',
                  icon: Icons.skip_next_rounded,
                  color: _warningAmber,
                  onTap: onSkip,
                ),
              if (onEmergency != null)
                _ActionChip(
                  label: 'PRIORITY',
                  icon: Icons.emergency_outlined,
                  color: _errorRed,
                  onTap: onEmergency,
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final hour = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$hour:$m $period';
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color, bg) = switch (status) {
      'called' => ('CALLED', _primaryBlue, _selectedBg),
      'served' || 'completed' => (
          'SERVED',
          _successGreen,
          const Color(0xFFD1FAE5)
        ),
      'absent' || 'cancelled' => (
          'ABSENT',
          _errorRed,
          const Color(0xFFFEF2F2)
        ),
      _ => ('WAITING', _warningAmber, const Color(0xFFFEF3C7)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        color: bg,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 9,
          fontWeight: FontWeight.w500,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _ActionChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(7),
          color: enabled ? color.withOpacity(0.08) : const Color(0xFFF9FAFB),
          border: Border.all(
            color:
                enabled ? color.withOpacity(0.3) : _borderColor,
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 13,
                color: enabled ? color : _textSecondary),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: enabled ? color : _textSecondary,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Done Row ──────────────────────────────────────────────────────────────────

class _DoneRow extends StatelessWidget {
  final TokenModel token;
  const _DoneRow({required this.token});

  @override
  Widget build(BuildContext context) {
    final isServed =
        token.status == 'served' || token.status == 'completed';
    final color = isServed ? _successGreen : _errorRed;
    final h = token.issuedAt.hour;
    final m = token.issuedAt.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final hour = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    final timeStr = '$hour:$m $period';

    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _cardWhite,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: _borderColor, width: 0.5),
      ),
      child: Row(
        children: [
          Icon(
            isServed
                ? Icons.check_circle_outline_rounded
                : Icons.cancel_outlined,
            size: 15,
            color: color.withOpacity(0.7),
          ),
          const SizedBox(width: 9),
          Text(
            token.tokenNumber,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _textSecondary,
            ),
          ),
          const SizedBox(width: 9),
          _StatusBadge(status: token.status),
          const Spacer(),
          Text(
            timeStr,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              color: _textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyQueue extends StatelessWidget {
  const _EmptyQueue();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFD1FAE5),
            ),
            child: const Icon(Icons.done_all_rounded,
                color: _successGreen, size: 32),
          ),
          const SizedBox(height: 16),
          const Text(
            'Queue is clear!',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'All patients have been attended to.',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              color: _textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hospital Selector ─────────────────────────────────────────────────────────

class _HospitalSelectorScreen extends StatelessWidget {
  final Future<void> Function(String hospitalId) onSelect;
  const _HospitalSelectorScreen({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: _bgColor,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(20, topPad + 20, 20, 20),
            decoration: const BoxDecoration(
              color: _cardWhite,
              border: Border(bottom: BorderSide(color: _borderColor, width: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(11),
                        color: _selectedBg,
                      ),
                      child: const Icon(Icons.local_hospital_outlined,
                          color: _primaryBlue, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Select your hospital',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: _textPrimary,
                          ),
                        ),
                        Text(
                          'This will be saved to your account',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: _textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => AuthService().signOut(),
                      child: const Text('Sign Out',
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: _errorRed)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Hospital>>(
              stream: FirestoreService().getHospitals(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                        color: _primaryBlue, strokeWidth: 2),
                  );
                }
                final hospitals = snap.data ?? [];
                if (hospitals.isEmpty) {
                  return const Center(
                    child: Text(
                      'No hospitals found in database.',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          color: _textSecondary),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: hospitals.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final h = hospitals[i];
                    return _HospitalOption(
                      hospital: h,
                      onTap: () => onSelect(h.id),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HospitalOption extends StatelessWidget {
  final Hospital hospital;
  final VoidCallback onTap;
  const _HospitalOption({required this.hospital, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _borderColor, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: _selectedBg,
              ),
              child: const Icon(Icons.local_hospital_outlined,
                  color: _primaryBlue, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hospital.shortName,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hospital.location,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: _textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: hospital.isOpen
                    ? _successGreen.withOpacity(0.1)
                    : const Color(0xFFFEF2F2),
              ),
              child: Text(
                hospital.isOpen ? 'Open' : 'Closed',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color:
                      hospital.isOpen ? _successGreen : _errorRed,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: _textSecondary),
          ],
        ),
      ),
    );
  }
}

// ── Emergency Dialog ──────────────────────────────────────────────────────────

class _EmergencyDialog extends StatelessWidget {
  final List<TokenModel> tokens;
  final void Function(TokenModel) onSelect;

  const _EmergencyDialog({
    required this.tokens,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints:
            const BoxConstraints(maxWidth: 440, maxHeight: 520),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: _errorRed.withOpacity(0.2), width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 32,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(11),
                      color: const Color(0xFFFEF2F2),
                    ),
                    child: const Icon(Icons.emergency_outlined,
                        color: _errorRed, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Emergency Priority',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: _textPrimary,
                        ),
                      ),
                      Text(
                        'Select patient to move to front',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          color: _textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close_rounded,
                        color: _textSecondary, size: 18),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(height: 0.5, color: _borderColor),
            Flexible(
              child: ListView.separated(
                padding: const EdgeInsets.all(14),
                itemCount: tokens.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (_, i) {
                  final t = tokens[i];
                  final h = t.issuedAt.hour;
                  final m =
                      t.issuedAt.minute.toString().padLeft(2, '0');
                  final period = h >= 12 ? 'PM' : 'AM';
                  final hour =
                      h > 12 ? h - 12 : (h == 0 ? 12 : h);
                  return GestureDetector(
                    onTap: () => onSelect(t),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: _borderColor, width: 0.5),
                      ),
                      child: Row(
                        children: [
                          Text(
                            t.tokenNumber,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: _textPrimary,
                            ),
                          ),
                          const SizedBox(width: 9),
                          Text(
                            'Position #${t.tokenPosition}',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              color: _textSecondary,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '$hour:$m $period',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              color: _textSecondary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Icon(Icons.arrow_forward_ios_rounded,
                              size: 12, color: _errorRed),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
