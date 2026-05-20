import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/hospital.dart';
import '../services/firestore_service.dart';

class TokenBookingScreen extends StatefulWidget {
  final Hospital hospital;

  const TokenBookingScreen({super.key, required this.hospital});

  @override
  State<TokenBookingScreen> createState() => _TokenBookingScreenState();
}

class _TimeSlot {
  final String label;
  final String range;
  final IconData icon;
  final int spotsLeft;
  final bool isLunchBreak;
  // Hour (24h) after which this slot is considered closed. 0 = not applicable.
  final int closeAfterHour;

  const _TimeSlot({
    required this.label,
    required this.range,
    required this.icon,
    required this.spotsLeft,
    this.isLunchBreak = false,
    this.closeAfterHour = 0,
  });
}

class _TokenBookingScreenState extends State<TokenBookingScreen>
    with SingleTickerProviderStateMixin {
  int _selectedSlot = -1;
  late AnimationController _shimmerController;

  final List<_TimeSlot> _slots = const [
    _TimeSlot(
      label: 'Morning Session',
      range: '9:00 AM – 1:00 PM',
      icon: Icons.wb_sunny_rounded,
      spotsLeft: 8,
      closeAfterHour: 13,
    ),
    _TimeSlot(
      label: 'Lunch Break',
      range: '1:00 PM – 2:00 PM',
      icon: Icons.restaurant_rounded,
      spotsLeft: 0,
      isLunchBreak: true,
    ),
    _TimeSlot(
      label: 'Afternoon Session',
      range: '2:00 PM – 5:00 PM',
      icon: Icons.wb_cloudy_rounded,
      spotsLeft: 14,
      closeAfterHour: 17,
    ),
  ];

  bool _isDisabled(int i) {
    final slot = _slots[i];
    if (slot.isLunchBreak) return true;
    if (slot.closeAfterHour == 0) return false;
    return DateTime.now().hour >= slot.closeAfterHour;
  }

  String _slotStatus(int i) {
    final slot = _slots[i];
    if (slot.isLunchBreak) return 'Break';
    return _isDisabled(i) ? 'Closed' : 'Open';
  }

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  String _generateToken() {
    final n = 40 + Random().nextInt(60);
    return 'OPD-${n.toString().padLeft(3, '0')}';
  }

  void _onConfirm() {
    if (_selectedSlot == -1) return;
    HapticFeedback.mediumImpact();
    final token = _generateToken();
    _saveTokenToFirestore(token);
    _showSuccessSheet(token);
  }

  Future<void> _saveTokenToFirestore(String tokenNumber) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirestoreService().bookToken(
        userId: user.uid,
        hospitalId: widget.hospital.id,
        hospitalName: widget.hospital.name,
        hospitalShort: widget.hospital.shortName,
        session: _slots[_selectedSlot].label,
        currentQueue: widget.hospital.currentQueue,
        estimatedWaitMinutes: widget.hospital.estimatedWaitMinutes,
        tokenNumber: tokenNumber,
      );
    } catch (e) {
      debugPrint('Firestore bookToken error: $e');
    }
  }

  void _showSuccessSheet(String token) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => _SuccessSheet(
        token: token,
        hospital: widget.hospital,
        slot: _slots[_selectedSlot],
        onDone: () {
          Navigator.of(context)
            ..pop() // close sheet
            ..pop(); // back to home
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hospital = widget.hospital;
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: Stack(
        children: [
          // Background glows
          Positioned(
            top: -60,
            left: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF00E5C8).withOpacity(0.10),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 160,
            right: -80,
            child: Container(
              width: 200,
              height: 200,
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

          Column(
            children: [
              // ── App bar ──────────────────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(20, topPad + 16, 20, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(13),
                          color: const Color(0xFF152438),
                          border: Border.all(
                            color: const Color(0xFF1E3A52),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Book OPD Token',
                      style: TextStyle(fontFamily: 'Poppins',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Hospital info card ───────────────────────
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF152438),
                              const Color(0xFF0F1E30),
                            ],
                          ),
                          border: Border.all(
                            color: const Color(0xFF1E3A52),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(15),
                                color:
                                    const Color(0xFF00E5C8).withOpacity(0.12),
                                border: Border.all(
                                  color:
                                      const Color(0xFF00E5C8).withOpacity(0.25),
                                  width: 1,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  hospital.shortName[0],
                                  style: TextStyle(fontFamily: 'Poppins',
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF00E5C8),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    hospital.shortName,
                                    style: TextStyle(fontFamily: 'Poppins',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.location_on_rounded,
                                        size: 12,
                                        color: Colors.white.withOpacity(0.4),
                                      ),
                                      const SizedBox(width: 3),
                                      Expanded(
                                        child: Text(
                                          hospital.location,
                                          style: TextStyle(fontFamily: 'Poppins',
                                            fontSize: 12,
                                            color:
                                                Colors.white.withOpacity(0.4),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    hospital.speciality,
                                    style: TextStyle(fontFamily: 'Poppins',
                                      fontSize: 11,
                                      color: Colors.white.withOpacity(0.35),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── Live queue stats ─────────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              icon: Icons.people_alt_rounded,
                              label: 'In Queue',
                              value: '${hospital.currentQueue}',
                              valueColor: hospital.currentQueue <= 10
                                  ? const Color(0xFF00E5C8)
                                  : hospital.currentQueue <= 20
                                      ? const Color(0xFFFFC107)
                                      : const Color(0xFFFF5252),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _StatCard(
                              icon: Icons.schedule_rounded,
                              label: 'Est. Wait',
                              value: '~${hospital.estimatedWaitMinutes} min',
                              valueColor: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _StatCard(
                              icon: Icons.calendar_today_rounded,
                              label: 'Date',
                              value: _todayLabel(),
                              valueColor: Colors.white,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),

                      // ── Time slot section ────────────────────────
                      Text(
                        'Select Time Slot',
                        style: TextStyle(fontFamily: 'Poppins',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Choose your preferred OPD session for today',
                        style: TextStyle(fontFamily: 'Poppins',
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.4),
                        ),
                      ),
                      const SizedBox(height: 16),

                      ..._slots.asMap().entries.map((entry) {
                        final i = entry.key;
                        final slot = entry.value;
                        final disabled = _isDisabled(i);
                        final selected = !disabled && _selectedSlot == i;
                        final status = _slotStatus(i);

                        // Pill colors
                        final Color pillBg;
                        final Color pillText;
                        if (slot.isLunchBreak) {
                          pillBg = Colors.white.withOpacity(0.07);
                          pillText = Colors.white.withOpacity(0.35);
                        } else if (disabled) {
                          pillBg = Colors.red.withOpacity(0.12);
                          pillText = Colors.redAccent;
                        } else {
                          pillBg = const Color(0xFF00E5C8).withOpacity(0.12);
                          pillText = const Color(0xFF00E5C8);
                        }

                        return GestureDetector(
                          onTap: disabled
                              ? null
                              : () => setState(() => _selectedSlot = i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOut,
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              color: slot.isLunchBreak
                                  ? const Color(0xFF0F1A25)
                                  : selected
                                      ? const Color(0xFF00E5C8)
                                          .withOpacity(0.10)
                                      : disabled
                                          ? const Color(0xFF111D29)
                                          : const Color(0xFF152438),
                              border: Border.all(
                                color: selected
                                    ? const Color(0xFF00E5C8)
                                    : const Color(0xFF1E3A52)
                                        .withOpacity(disabled ? 0.5 : 1),
                                width: selected ? 1.5 : 1,
                              ),
                              boxShadow: selected
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFF00E5C8)
                                            .withOpacity(0.18),
                                        blurRadius: 16,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              children: [
                                // Icon circle
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 220),
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: selected
                                        ? const Color(0xFF00E5C8)
                                            .withOpacity(0.18)
                                        : Colors.white
                                            .withOpacity(disabled ? 0.03 : 0.05),
                                    border: Border.all(
                                      color: selected
                                          ? const Color(0xFF00E5C8)
                                              .withOpacity(0.4)
                                          : Colors.white
                                              .withOpacity(disabled ? 0.05 : 0.08),
                                      width: 1,
                                    ),
                                  ),
                                  child: Icon(
                                    slot.icon,
                                    color: selected
                                        ? const Color(0xFF00E5C8)
                                        : Colors.white
                                            .withOpacity(disabled ? 0.18 : 0.35),
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Labels
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        slot.label,
                                        style: TextStyle(fontFamily: 'Poppins',
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: selected
                                              ? Colors.white
                                              : Colors.white.withOpacity(
                                                  disabled ? 0.3 : 0.7),
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        slot.range,
                                        style: TextStyle(fontFamily: 'Poppins',
                                          fontSize: 12,
                                          color: selected
                                              ? const Color(0xFF00E5C8)
                                              : Colors.white.withOpacity(
                                                  disabled ? 0.2 : 0.35),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Right side: spots + status pill + radio
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    // Status pill
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(20),
                                        color: pillBg,
                                        border: Border.all(
                                          color: pillText.withOpacity(0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        status,
                                        style: TextStyle(fontFamily: 'Poppins',
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color: pillText,
                                        ),
                                      ),
                                    ),
                                    if (!slot.isLunchBreak) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        disabled
                                            ? '–'
                                            : '${slot.spotsLeft} left',
                                        style: TextStyle(fontFamily: 'Poppins',
                                          fontSize: 11,
                                          color: Colors.white
                                              .withOpacity(disabled ? 0.2 : 0.4),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                // Radio indicator (only on bookable slots)
                                if (!slot.isLunchBreak) ...[
                                  const SizedBox(width: 12),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 220),
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: selected
                                          ? const Color(0xFF00E5C8)
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: selected
                                            ? const Color(0xFF00E5C8)
                                            : const Color(0xFF1E3A52)
                                                .withOpacity(
                                                    disabled ? 0.4 : 1),
                                        width: 2,
                                      ),
                                    ),
                                    child: selected
                                        ? const Icon(Icons.check_rounded,
                                            size: 12,
                                            color: Color(0xFF0D1B2A))
                                        : null,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }),

                      const SizedBox(height: 8),

                      // ── Notice ───────────────────────────────────
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: const Color(0xFF0057FF).withOpacity(0.07),
                          border: Border.all(
                            color: const Color(0xFF0057FF).withOpacity(0.18),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 16,
                              color: const Color(0xFF6EA8FF),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Please arrive 10 minutes before your slot. '
                                'Token expires if not checked in within 30 minutes.',
                                style: TextStyle(fontFamily: 'Poppins',
                                  fontSize: 11.5,
                                  color: const Color(0xFF6EA8FF),
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),

              // ── Confirm button ───────────────────────────────────
              Container(
                padding: EdgeInsets.fromLTRB(20, 16, 20, bottomPad + 20),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1B2A),
                  border: const Border(
                    top: BorderSide(color: Color(0xFF1E3A52), width: 1),
                  ),
                ),
                child: GestureDetector(
                  onTap: _selectedSlot == -1 ? null : _onConfirm,
                  child: AnimatedBuilder(
                    animation: _shimmerController,
                    builder: (_, __) {
                      final active = _selectedSlot != -1;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: active
                              ? LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: const [
                                    Color(0xFF00E5C8),
                                    Color(0xFF00CFBA),
                                    Color(0xFF00E5C8),
                                  ],
                                  stops: [
                                    0.0,
                                    _shimmerController.value,
                                    1.0,
                                  ],
                                )
                              : null,
                          color: active ? null : const Color(0xFF152438),
                          border: active
                              ? null
                              : Border.all(
                                  color: const Color(0xFF1E3A52), width: 1),
                          boxShadow: active
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF00E5C8)
                                        .withOpacity(0.40),
                                    blurRadius: 20,
                                    offset: const Offset(0, 6),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.confirmation_number_rounded,
                              color: active
                                  ? const Color(0xFF0D1B2A)
                                  : Colors.white.withOpacity(0.25),
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              active
                                  ? 'Confirm Token'
                                  : 'Select a slot to continue',
                              style: TextStyle(fontFamily: 'Poppins',
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: active
                                    ? const Color(0xFF0D1B2A)
                                    : Colors.white.withOpacity(0.25),
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _todayLabel() {
    final now = DateTime.now();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${now.day} ${months[now.month - 1]}';
  }
}

// ── Stat card widget ─────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF152438),
        border: Border.all(color: const Color(0xFF1E3A52), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: Colors.white.withOpacity(0.35)),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontFamily: 'Poppins',
              fontSize: 10,
              color: Colors.white.withOpacity(0.35),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Success bottom sheet ─────────────────────────────────────────────────────

class _SuccessSheet extends StatefulWidget {
  final String token;
  final Hospital hospital;
  final _TimeSlot slot;
  final VoidCallback onDone;

  const _SuccessSheet({
    required this.token,
    required this.hospital,
    required this.slot,
    required this.onDone,
  });

  @override
  State<_SuccessSheet> createState() => _SuccessSheetState();
}

class _SuccessSheetState extends State<_SuccessSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _entryController;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnim = CurvedAnimation(
      parent: _entryController,
      curve: Curves.elasticOut,
    );
    _fadeAnim = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );
    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: EdgeInsets.fromLTRB(24, 28, 24, bottomPad + 20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1E30),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF1E3A52), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5C8).withOpacity(0.08),
            blurRadius: 40,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Success icon with scale-in
          ScaleTransition(
            scale: _scaleAnim,
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00E5C8), Color(0xFF00B8A0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00E5C8).withOpacity(0.4),
                      blurRadius: 24,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Color(0xFF0D1B2A),
                  size: 40,
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          Text(
            'Token Booked!',
            style: TextStyle(fontFamily: 'Poppins',
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.hospital.shortName,
            style: TextStyle(fontFamily: 'Poppins',
              fontSize: 13,
              color: const Color(0xFF00E5C8),
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 24),

          // Token number display
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF00E5C8).withOpacity(0.12),
                  const Color(0xFF0057FF).withOpacity(0.06),
                ],
              ),
              border: Border.all(
                color: const Color(0xFF00E5C8).withOpacity(0.25),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Text(
                  'Your Token Number',
                  style: TextStyle(fontFamily: 'Poppins',
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.45),
                  ),
                ),
                const SizedBox(height: 8),
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF00E5C8), Color(0xFF00CFFF)],
                  ).createShader(bounds),
                  child: Text(
                    widget.token,
                    style: TextStyle(fontFamily: 'Poppins',
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Details row
          Row(
            children: [
              Expanded(
                child: _DetailTile(
                  icon: Icons.schedule_rounded,
                  label: 'Slot',
                  value: widget.slot.label,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DetailTile(
                  icon: Icons.access_time_filled_rounded,
                  label: 'Time',
                  value: widget.slot.range.split('–').first.trim(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DetailTile(
                  icon: Icons.people_alt_rounded,
                  label: 'Ahead',
                  value: '${widget.hospital.currentQueue}',
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Done button
          GestureDetector(
            onTap: widget.onDone,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
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
              child: Center(
                child: Text(
                  'Done',
                  style: TextStyle(fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0D1B2A),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withOpacity(0.04),
        border: Border.all(color: Colors.white.withOpacity(0.07), width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, size: 15, color: const Color(0xFF00E5C8)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontFamily: 'Poppins',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontFamily: 'Poppins',
              fontSize: 10,
              color: Colors.white.withOpacity(0.35),
            ),
          ),
        ],
      ),
    );
  }
}
