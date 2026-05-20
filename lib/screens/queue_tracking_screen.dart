import 'dart:async';
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../models/token_model.dart';

class QueueTrackingScreen extends StatefulWidget {
  final String tokenNumber;
  final String hospitalShort;
  final String hospitalFull;
  final String session;
  final IconData sessionIcon;
  final int initialPeopleAhead;
  final int totalQueue;
  final int waitMinutes;
  // When provided, real-time updates come from Firestore instead of simulation.
  final String? tokenId;

  const QueueTrackingScreen({
    super.key,
    required this.tokenNumber,
    required this.hospitalShort,
    required this.hospitalFull,
    required this.session,
    required this.sessionIcon,
    required this.initialPeopleAhead,
    required this.totalQueue,
    required this.waitMinutes,
    this.tokenId,
  });

  @override
  State<QueueTrackingScreen> createState() => _QueueTrackingScreenState();
}

class _QueueTrackingScreenState extends State<QueueTrackingScreen>
    with TickerProviderStateMixin {
  late int _peopleAhead;
  late int _waitMinutes;
  late int _totalQueue;
  bool _notifyEnabled = false;
  Timer? _refreshTimer;
  StreamSubscription<TokenModel?>? _tokenSubscription;

  // Animation controllers
  late AnimationController _arcController;
  late AnimationController _pulseController;
  late AnimationController _countController;
  late Animation<double> _arcAnimation;
  late Animation<double> _pulseAnimation;

  int _secondsUntilRefresh = 30;
  late Timer _countdownTimer;

  @override
  void initState() {
    super.initState();
    _peopleAhead = widget.initialPeopleAhead;
    _waitMinutes = widget.waitMinutes;
    _totalQueue = widget.totalQueue;

    _arcController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _countController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _pulseAnimation = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _arcAnimation = CurvedAnimation(
      parent: _arcController,
      curve: Curves.easeOutCubic,
    );
    _arcController.forward();

    if (widget.tokenId != null) {
      // Real-time updates from Firestore
      _tokenSubscription = FirestoreService()
          .getTokenStream(widget.tokenId!)
          .listen((token) {
        if (token != null && mounted) {
          setState(() {
            _peopleAhead = token.peopleAhead;
            _waitMinutes = token.estimatedWaitMinutes;
            _secondsUntilRefresh = 30;
          });
          _arcController
            ..reset()
            ..forward();
        }
      });
    } else {
      // Fallback: simulate live queue updates every 30 seconds
      _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (!mounted) return;
        setState(() {
          if (_peopleAhead > 0) {
            _peopleAhead = (_peopleAhead - 1).clamp(0, _totalQueue);
            _waitMinutes = (_waitMinutes - 2).clamp(0, 999);
          }
          _secondsUntilRefresh = 30;
        });
        _arcController
          ..reset()
          ..forward();
      });
    }

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_secondsUntilRefresh > 0) _secondsUntilRefresh--;
      });
    });
  }

  @override
  void dispose() {
    _tokenSubscription?.cancel();
    _refreshTimer?.cancel();
    _arcController.dispose();
    _pulseController.dispose();
    _countController.dispose();
    _countdownTimer.cancel();
    super.dispose();
  }

  double get _progress =>
      _totalQueue == 0 ? 0 : (_totalQueue - _peopleAhead) / _totalQueue;

  int get _yourPosition => _peopleAhead + 1;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: Stack(
        children: [
          // Background glows
          Positioned(
            top: -40,
            right: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF00E5C8).withOpacity(0.09),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 160,
            left: -80,
            child: Container(
              width: 220,
              height: 220,
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
              // ── Top bar ─────────────────────────────────────────────
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
                              color: const Color(0xFF1E3A52), width: 1),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 16),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Queue Tracker',
                          style: TextStyle(fontFamily: 'Poppins',
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          widget.hospitalShort,
                          style: TextStyle(fontFamily: 'Poppins',
                            fontSize: 12,
                            color: const Color(0xFF00E5C8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Live badge
                    ScaleTransition(
                      scale: _pulseAnimation,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color:
                              const Color(0xFF00E5C8).withOpacity(0.12),
                          border: Border.all(
                            color: const Color(0xFF00E5C8).withOpacity(0.35),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF00E5C8),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'LIVE',
                              style: TextStyle(fontFamily: 'Poppins',
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF00E5C8),
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPad + 24),
                  child: Column(
                    children: [
                      // ── Circular progress ────────────────────────────
                      AnimatedBuilder(
                        animation: _arcAnimation,
                        builder: (_, __) => _CircularQueueIndicator(
                          progress: _arcAnimation.value * _progress,
                          peopleAhead: _peopleAhead,
                          totalQueue: _totalQueue,
                          tokenNumber: widget.tokenNumber,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── Hospital + session ───────────────────────────
                      Text(
                        widget.hospitalFull,
                        style: TextStyle(fontFamily: 'Poppins',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: Colors.white.withOpacity(0.05),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.09),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(widget.sessionIcon,
                                size: 14,
                                color: Colors.white.withOpacity(0.5)),
                            const SizedBox(width: 6),
                            Text(
                              widget.session,
                              style: TextStyle(fontFamily: 'Poppins',
                                fontSize: 12.5,
                                color: Colors.white.withOpacity(0.5),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ── Three stat cards ─────────────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              icon: Icons.people_alt_rounded,
                              label: 'People Ahead',
                              value: '$_peopleAhead',
                              valueColor: _peopleAhead <= 5
                                  ? const Color(0xFF00E5C8)
                                  : _peopleAhead <= 15
                                      ? const Color(0xFFFFC107)
                                      : const Color(0xFFFF6B6B),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              icon: Icons.schedule_rounded,
                              label: 'Est. Wait',
                              value: '~$_waitMinutes m',
                              valueColor: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              icon: Icons.confirmation_number_rounded,
                              label: 'Your Position',
                              value: '#$_yourPosition',
                              valueColor: const Color(0xFF00E5C8),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // ── Live update notice ───────────────────────────
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 13),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: const Color(0xFF152438),
                          border: Border.all(
                              color: const Color(0xFF1E3A52), width: 1),
                        ),
                        child: Row(
                          children: [
                            ScaleTransition(
                              scale: _pulseAnimation,
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFF00E5C8),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                widget.tokenId != null
                                    ? 'Listening for real-time updates'
                                    : 'Queue updates every 30 seconds',
                                style: TextStyle(fontFamily: 'Poppins',
                                  fontSize: 13,
                                  color: Colors.white.withOpacity(0.7),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Text(
                              widget.tokenId != null
                                  ? 'LIVE'
                                  : '${_secondsUntilRefresh}s',
                              style: TextStyle(fontFamily: 'Poppins',
                                fontSize: 12,
                                color: const Color(0xFF00E5C8),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // ── Notification toggle card ──────────────────────
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 18),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF152438),
                              const Color(0xFF0F1E30),
                            ],
                          ),
                          border: Border.all(
                            color: _notifyEnabled
                                ? const Color(0xFF00E5C8).withOpacity(0.35)
                                : const Color(0xFF1E3A52),
                            width: 1,
                          ),
                          boxShadow: _notifyEnabled
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF00E5C8)
                                        .withOpacity(0.08),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  )
                                ]
                              : null,
                        ),
                        child: Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(13),
                                color: _notifyEnabled
                                    ? const Color(0xFF00E5C8).withOpacity(0.15)
                                    : Colors.white.withOpacity(0.05),
                                border: Border.all(
                                  color: _notifyEnabled
                                      ? const Color(0xFF00E5C8).withOpacity(0.4)
                                      : Colors.white.withOpacity(0.08),
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                _notifyEnabled
                                    ? Icons.notifications_active_rounded
                                    : Icons.notifications_outlined,
                                color: _notifyEnabled
                                    ? const Color(0xFF00E5C8)
                                    : Colors.white.withOpacity(0.35),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Notify me when 5 people ahead',
                                    style: TextStyle(fontFamily: 'Poppins',
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _notifyEnabled
                                        ? 'You\'ll be alerted in time to arrive'
                                        : 'Get notified before your turn',
                                    style: TextStyle(fontFamily: 'Poppins',
                                      fontSize: 11.5,
                                      color: Colors.white.withOpacity(0.4),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            _TealSwitch(
                              value: _notifyEnabled,
                              onChanged: (v) =>
                                  setState(() => _notifyEnabled = v),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // ── Queue position timeline ──────────────────────
                      _QueueTimeline(
                        peopleAhead: _peopleAhead,
                        yourPosition: _yourPosition,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Circular queue indicator ──────────────────────────────────────────────────

class _CircularQueueIndicator extends StatelessWidget {
  final double progress;
  final int peopleAhead;
  final int totalQueue;
  final String tokenNumber;

  const _CircularQueueIndicator({
    required this.progress,
    required this.peopleAhead,
    required this.totalQueue,
    required this.tokenNumber,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      height: 210,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer glow ring
          Container(
            width: 210,
            height: 210,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00E5C8).withOpacity(0.10),
                  blurRadius: 32,
                  spreadRadius: 4,
                ),
              ],
            ),
          ),
          // Track ring
          CustomPaint(
            size: const Size(210, 210),
            painter: _ArcPainter(
              progress: progress,
              trackColor: const Color(0xFF1E3A52),
              arcColor: const Color(0xFF00E5C8),
              strokeWidth: 12,
            ),
          ),
          // Inner content
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Position',
                style: TextStyle(fontFamily: 'Poppins',
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.4),
                ),
              ),
              const SizedBox(height: 4),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF00E5C8), Color(0xFF00CFFF)],
                ).createShader(bounds),
                child: Text(
                  tokenNumber,
                  style: TextStyle(fontFamily: 'Poppins',
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$peopleAhead of $totalQueue',
                style: TextStyle(fontFamily: 'Poppins',
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.55),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'ahead of you',
                style: TextStyle(fontFamily: 'Poppins',
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color arcColor;
  final double strokeWidth;

  _ArcPainter({
    required this.progress,
    required this.trackColor,
    required this.arcColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    const startAngle = -2.356; // -135 degrees
    const sweepTotal = 4.712;  // 270 degrees

    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final arcPaint = Paint()
      ..shader = SweepGradient(
        colors: const [Color(0xFF00E5C8), Color(0xFF00CFFF), Color(0xFF00E5C8)],
        stops: const [0.0, 0.5, 1.0],
        startAngle: startAngle,
        endAngle: startAngle + sweepTotal,
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepTotal,
      false,
      trackPaint,
    );

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepTotal * progress,
        false,
        arcPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.progress != progress;
}

// ── Stat card ─────────────────────────────────────────────────────────────────

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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF152438),
        border: Border.all(color: const Color(0xFF1E3A52), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: Colors.white.withOpacity(0.35)),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.w800,
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

// ── Teal custom switch ────────────────────────────────────────────────────────

class _TealSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _TealSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 48,
        height: 27,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: value
              ? const Color(0xFF00E5C8)
              : const Color(0xFF1E3A52),
          boxShadow: value
              ? [
                  BoxShadow(
                    color: const Color(0xFF00E5C8).withOpacity(0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          alignment:
              value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 21,
            height: 21,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Queue position timeline ───────────────────────────────────────────────────

class _QueueTimeline extends StatelessWidget {
  final int peopleAhead;
  final int yourPosition;

  const _QueueTimeline({
    required this.peopleAhead,
    required this.yourPosition,
  });

  @override
  Widget build(BuildContext context) {
    // Show at most 5 slots: last 2 served, your position, next 2 waiting
    final slots = <_TimelineSlot>[
      if (yourPosition > 2)
        _TimelineSlot(label: '#${yourPosition - 2}', state: _SlotState.served),
      if (yourPosition > 1)
        _TimelineSlot(label: '#${yourPosition - 1}', state: _SlotState.served),
      _TimelineSlot(label: '#$yourPosition', state: _SlotState.you),
      _TimelineSlot(
          label: '#${yourPosition + 1}', state: _SlotState.waiting),
      _TimelineSlot(
          label: '#${yourPosition + 2}', state: _SlotState.waiting),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xFF152438),
        border: Border.all(color: const Color(0xFF1E3A52), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Queue Position',
                style: TextStyle(fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Text(
                '$peopleAhead people ahead',
                style: TextStyle(fontFamily: 'Poppins',
                  fontSize: 11.5,
                  color: Colors.white.withOpacity(0.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: slots.asMap().entries.map((e) {
              final isLast = e.key == slots.length - 1;
              return Expanded(
                child: Row(
                  children: [
                    Expanded(child: _TimelineNode(slot: e.value)),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: e.value.state == _SlotState.served
                              ? const Color(0xFF00E5C8).withOpacity(0.4)
                              : const Color(0xFF1E3A52),
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Legend(
                  color: const Color(0xFF00E5C8), label: 'Served'),
              const SizedBox(width: 20),
              _Legend(color: const Color(0xFFFFC107), label: 'You'),
              const SizedBox(width: 20),
              _Legend(
                  color: const Color(0xFF1E3A52), label: 'Waiting'),
            ],
          ),
        ],
      ),
    );
  }
}

enum _SlotState { served, you, waiting }

class _TimelineSlot {
  final String label;
  final _SlotState state;

  const _TimelineSlot({required this.label, required this.state});
}

class _TimelineNode extends StatelessWidget {
  final _TimelineSlot slot;

  const _TimelineNode({required this.slot});

  @override
  Widget build(BuildContext context) {
    final Color fill;
    final Color border;
    final Color textColor;

    switch (slot.state) {
      case _SlotState.served:
        fill = const Color(0xFF00E5C8).withOpacity(0.15);
        border = const Color(0xFF00E5C8).withOpacity(0.5);
        textColor = const Color(0xFF00E5C8);
      case _SlotState.you:
        fill = const Color(0xFFFFC107).withOpacity(0.15);
        border = const Color(0xFFFFC107);
        textColor = const Color(0xFFFFC107);
      case _SlotState.waiting:
        fill = Colors.transparent;
        border = const Color(0xFF1E3A52);
        textColor = Colors.white.withOpacity(0.3);
    }

    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: fill,
            border: Border.all(color: border, width: 1.5),
          ),
          child: slot.state == _SlotState.served
              ? const Icon(Icons.check_rounded,
                  size: 16, color: Color(0xFF00E5C8))
              : null,
        ),
        const SizedBox(height: 6),
        Text(
          slot.state == _SlotState.you ? 'You' : slot.label,
          style: TextStyle(fontFamily: 'Poppins',
            fontSize: 10,
            fontWeight: slot.state == _SlotState.you
                ? FontWeight.w700
                : FontWeight.w400,
            color: textColor,
          ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;

  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontFamily: 'Poppins',
            fontSize: 11,
            color: Colors.white.withOpacity(0.4),
          ),
        ),
      ],
    );
  }
}
