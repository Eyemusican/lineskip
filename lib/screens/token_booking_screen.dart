import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/hospital.dart';
import '../services/firestore_service.dart';
import '../services/queue_notification_service.dart';

const _primaryBlue = Color(0xFF4F6BED);
const _bgColor = Color(0xFFFAFBFD);
const _textPrimary = Color(0xFF1F2937);
const _textSecondary = Color(0xFF9CA3AF);
const _borderColor = Color(0xFFE5E7EB);
const _selectedBg = Color(0xFFEEF2FF);
const _successGreen = Color(0xFF10B981);

// Maximum bookings allowed per session
const _sessionCapacity = 50;

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
  final bool isLunchBreak;
  final int closeAfterHour;

  const _TimeSlot({
    required this.label,
    required this.range,
    required this.icon,
    this.isLunchBreak = false,
    this.closeAfterHour = 0,
  });
}

class _TokenBookingScreenState extends State<TokenBookingScreen>
    with SingleTickerProviderStateMixin {
  int _selectedSlot = -1;
  bool _saving = false;
  late AnimationController _shimmerController;

  // Live session booked counts from Firestore
  Map<String, int> _sessionBookedCounts = {};
  StreamSubscription<Map<String, int>>? _countsSubscription;

  // Live active queue count for this hospital today
  int _activeCount = 0;
  StreamSubscription<int>? _activeCountSubscription;

  final List<_TimeSlot> _slots = const [
    _TimeSlot(
      label: 'Morning Session',
      range: '9:00 AM – 1:00 PM',
      icon: Icons.wb_sunny_outlined,
      closeAfterHour: 13,
    ),
    _TimeSlot(
      label: 'Lunch Break',
      range: '1:00 PM – 2:00 PM',
      icon: Icons.coffee_outlined,
      isLunchBreak: true,
    ),
    _TimeSlot(
      label: 'Afternoon Session',
      range: '2:00 PM – 5:00 PM',
      icon: Icons.wb_cloudy_outlined,
      closeAfterHour: 17,
    ),
  ];

  bool _isDisabled(int i) {
    final slot = _slots[i];
    if (slot.isLunchBreak) return true;
    if (slot.closeAfterHour > 0 && DateTime.now().hour >= slot.closeAfterHour) {
      return true;
    }
    final booked = _sessionBookedCounts[slot.label] ?? 0;
    return booked >= _sessionCapacity;
  }

  String _slotStatus(int i) {
    final slot = _slots[i];
    if (slot.isLunchBreak) return 'Break';
    if (slot.closeAfterHour > 0 && DateTime.now().hour >= slot.closeAfterHour) {
      return 'Closed';
    }
    final booked = _sessionBookedCounts[slot.label] ?? 0;
    if (booked >= _sessionCapacity) return 'Full';
    return 'Open';
  }

  int _spotsLeft(int i) {
    final slot = _slots[i];
    if (slot.isLunchBreak) return 0;
    final booked = _sessionBookedCounts[slot.label] ?? 0;
    return max(0, _sessionCapacity - booked);
  }

  String _todayDateStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    final svc = FirestoreService();

    _countsSubscription = svc
        .getSessionTokenCounts(widget.hospital.id, _todayDateStr())
        .listen((counts) {
      if (mounted) setState(() => _sessionBookedCounts = counts);
    });

    _activeCountSubscription = svc
        .getActiveTokenCountStream(widget.hospital.id)
        .listen((count) {
      if (mounted) setState(() => _activeCount = count);
    });
  }

  @override
  void dispose() {
    _countsSubscription?.cancel();
    _activeCountSubscription?.cancel();
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _onConfirm() async {
    if (_selectedSlot == -1 || _saving) return;
    HapticFeedback.mediumImpact();
    setState(() => _saving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final (tokenId, tokenNumber) = await FirestoreService().bookToken(
        userId: user.uid,
        hospitalId: widget.hospital.id,
        hospitalName: widget.hospital.name,
        hospitalShort: widget.hospital.shortName,
        session: _slots[_selectedSlot].label,
        minutesPerPatient: widget.hospital.estimatedWaitMinutes > 0
            ? widget.hospital.estimatedWaitMinutes
            : 5,
      );
      // Start the global notification listener for the newly booked token.
      QueueNotificationService.instance.attach(
        tokenId: tokenId,
        initialPeopleAhead: _activeCount,
      );
      if (mounted) _showSuccessSheet(tokenId, tokenNumber);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Booking failed. Please check your connection and try again.'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSuccessSheet(String tokenId, String tokenNumber) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => _SuccessSheet(
        tokenId: tokenId,
        token: tokenNumber,
        hospital: widget.hospital,
        slot: _slots[_selectedSlot],
        peopleAhead: _activeCount,
        onDone: () {
          Navigator.of(context)
            ..pop()
            ..pop();
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
      backgroundColor: _bgColor,
      body: Column(
        children: [
          // ── App bar ────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(20, topPad + 16, 20, 0),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: const Color(0xFFF3F4F6),
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: _textPrimary,
                      size: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Book token',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: _textPrimary,
                      ),
                    ),
                    Text(
                      '${hospital.shortName} • General OPD',
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
          ),

          const SizedBox(height: 20),

          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Hospital info mini card ────────────────────────
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
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
                            color: _selectedBg,
                          ),
                          child: const Icon(
                            Icons.local_hospital_outlined,
                            color: _primaryBlue,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                hospital.shortName,
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: _textPrimary,
                                ),
                              ),
                              Text(
                                hospital.location,
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 11,
                                  color: _textSecondary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            color: hospital.isOpen
                                ? _successGreen.withOpacity(0.1)
                                : const Color(0xFFFEF2F2),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: hospital.isOpen
                                      ? _successGreen
                                      : const Color(0xFFEF4444),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                hospital.isOpen ? 'Open' : 'Closed',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: hospital.isOpen
                                      ? _successGreen
                                      : const Color(0xFFEF4444),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Live stats row
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.people_alt_outlined,
                          label: 'In Queue',
                          value: '$_activeCount',
                          valueColor: _activeCount <= 10
                              ? _successGreen
                              : _activeCount <= 20
                                  ? const Color(0xFFD97706)
                                  : const Color(0xFFEF4444),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.schedule_outlined,
                          label: 'Est. Wait',
                          value:
                              '~${_activeCount * (hospital.estimatedWaitMinutes > 0 ? hospital.estimatedWaitMinutes : 5)} min',
                          valueColor: _textPrimary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.calendar_today_outlined,
                          label: 'Date',
                          value: _todayLabel(),
                          valueColor: _textPrimary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ── Time slot section ──────────────────────────────
                  const Text(
                    'Select time slot',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Choose your preferred OPD session for today',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: _textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),

                  ..._slots.asMap().entries.map((entry) {
                    final i = entry.key;
                    final slot = entry.value;
                    final disabled = _isDisabled(i);
                    final selected = !disabled && _selectedSlot == i;
                    final status = _slotStatus(i);
                    final spotsLeft = _spotsLeft(i);

                    Color pillBg;
                    Color pillText;
                    if (slot.isLunchBreak) {
                      pillBg = const Color(0xFFF3F4F6);
                      pillText = _textSecondary;
                    } else if (disabled) {
                      pillBg = const Color(0xFFFEF2F2);
                      pillText = const Color(0xFFEF4444);
                    } else {
                      pillBg = _successGreen.withOpacity(0.1);
                      pillText = _successGreen;
                    }

                    return GestureDetector(
                      onTap: disabled
                          ? null
                          : () => setState(() => _selectedSlot = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: selected
                              ? _selectedBg
                              : slot.isLunchBreak
                                  ? const Color(0xFFF9FAFB)
                                  : Colors.white,
                          border: Border.all(
                            color: selected ? _primaryBlue : _borderColor,
                            width: selected ? 1.5 : 0.5,
                          ),
                        ),
                        child: Opacity(
                          opacity: disabled ? 0.55 : 1.0,
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(11),
                                  color: selected
                                      ? _primaryBlue.withOpacity(0.12)
                                      : const Color(0xFFF3F4F6),
                                ),
                                child: Icon(
                                  slot.icon,
                                  color:
                                      selected ? _primaryBlue : _textSecondary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      slot.label,
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: selected
                                            ? _primaryBlue
                                            : _textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      slot.range,
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 11,
                                        color: _textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(6),
                                      color: pillBg,
                                    ),
                                    child: Text(
                                      status,
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: pillText,
                                      ),
                                    ),
                                  ),
                                  if (!slot.isLunchBreak) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      disabled
                                          ? '–'
                                          : '$spotsLeft left',
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 10,
                                        color: _textSecondary,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (!slot.isLunchBreak) ...[
                                const SizedBox(width: 10),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: selected
                                        ? _primaryBlue
                                        : Colors.transparent,
                                    border: Border.all(
                                      color: selected
                                          ? _primaryBlue
                                          : _borderColor,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: selected
                                      ? const Icon(Icons.check_rounded,
                                          size: 11, color: Colors.white)
                                      : null,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 8),

                  // ── Wait time info bar ─────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: const Color(0xFFFFFBEB),
                      border: Border.all(
                          color: const Color(0xFFFDE68A), width: 0.5),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time_outlined,
                            size: 15, color: Color(0xFF92400E)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Est. wait: ~${_activeCount * (hospital.estimatedWaitMinutes > 0 ? hospital.estimatedWaitMinutes : 5)} min · Please arrive 10 min early',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              color: Color(0xFF92400E),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),

          // ── Confirm button ─────────────────────────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(20, 14, 20, bottomPad + 20),
            decoration: BoxDecoration(
              color: Colors.white,
              border:
                  const Border(top: BorderSide(color: _borderColor, width: 0.5)),
            ),
            child: Column(
              children: [
                GestureDetector(
                  onTap: (_selectedSlot == -1 || _saving) ? null : _onConfirm,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: _selectedSlot != -1
                          ? _primaryBlue
                          : const Color(0xFFF3F4F6),
                    ),
                    child: _saving
                        ? const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.confirmation_number_outlined,
                                color: _selectedSlot != -1
                                    ? Colors.white
                                    : _textSecondary,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _selectedSlot != -1
                                    ? 'Confirm booking'
                                    : 'Select a slot to continue',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: _selectedSlot != -1
                                      ? Colors.white
                                      : _textSecondary,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "You'll receive a token number after confirmation",
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    color: _textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
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

// ── Stat card ──────────────────────────────────────────────────────────────────

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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: _textSecondary),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: valueColor,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 10,
              color: _textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Success bottom sheet ───────────────────────────────────────────────────────

class _SuccessSheet extends StatefulWidget {
  final String tokenId;
  final String token;
  final Hospital hospital;
  final _TimeSlot slot;
  final int peopleAhead;
  final VoidCallback onDone;

  const _SuccessSheet({
    required this.tokenId,
    required this.token,
    required this.hospital,
    required this.slot,
    required this.peopleAhead,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _borderColor, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: _scaleAnim,
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _successGreen.withOpacity(0.1),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: _successGreen,
                  size: 36,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          const Text(
            'Token Booked!',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.hospital.shortName,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              color: _primaryBlue,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 20),

          // Token number display
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: _selectedBg,
              border:
                  Border.all(color: _primaryBlue.withOpacity(0.2), width: 0.5),
            ),
            child: Column(
              children: [
                const Text(
                  'Your Token Number',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: _textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.token,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 36,
                    fontWeight: FontWeight.w500,
                    color: _primaryBlue,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: _DetailTile(
                  icon: Icons.schedule_outlined,
                  label: 'Slot',
                  value: widget.slot.label.split(' ').first,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DetailTile(
                  icon: Icons.access_time_outlined,
                  label: 'Time',
                  value: widget.slot.range.split('–').first.trim(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DetailTile(
                  icon: Icons.people_alt_outlined,
                  label: 'Ahead',
                  value: '${widget.peopleAhead}',
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          GestureDetector(
            onTap: widget.onDone,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: _primaryBlue,
              ),
              child: const Center(
                child: Text(
                  'Done',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
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
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: const Color(0xFFF9FAFB),
        border: Border.all(color: _borderColor, width: 0.5),
      ),
      child: Column(
        children: [
          Icon(icon, size: 14, color: _primaryBlue),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 10,
              color: _textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
