import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/firestore_service.dart';
import '../models/token_model.dart';
import '../utils/audio_helper.dart';
import '../services/queue_notification_service.dart';

const _primaryBlue = Color(0xFF4F6BED);
const _lightBlue = Color(0xFF6C8BF5);
const _bgColor = Color(0xFFFAFBFD);
const _textPrimary = Color(0xFF1F2937);
const _textSecondary = Color(0xFF9CA3AF);
const _borderColor = Color(0xFFE5E7EB);
const _selectedBg = Color(0xFFEEF2FF);
const _successGreen = Color(0xFF10B981);

class QueueTrackingScreen extends StatefulWidget {
  final String tokenNumber;
  final String hospitalShort;
  final String hospitalFull;
  final String hospitalId;
  final String session;
  final IconData sessionIcon;
  final int initialPeopleAhead;
  final int totalQueue;
  final int waitMinutes;
  final String? tokenId;

  const QueueTrackingScreen({
    super.key,
    required this.tokenNumber,
    required this.hospitalShort,
    required this.hospitalFull,
    required this.hospitalId,
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
  String? _nowServing;
  String? _prevTokenStatus;
  bool _notifyEnabled = false;
  bool _turnAlertShown = false;
  StreamSubscription<TokenModel?>? _tokenSubscription;
  StreamSubscription<String?>? _nowServingSubscription;
  StreamSubscription<int>? _totalQueueSubscription;

  // Alert state
  bool _initialLoadComplete = false;
  bool _earlyAlertShown = false;
  bool _fiveAheadShown = false;
  bool _twoAheadShown = false;
  bool _absentAlertShown = false;
  int _prevTokenPosition = 0;
  int _prevPeopleAheadTrack = 0;

  // Banner state
  String? _bannerMessage;
  Color _bannerColor = const Color(0xFF4F6BED);
  bool _bannerPersistent = false;
  bool _bannerVisible = false;

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
    // Suppress global overlays while this screen is active — it shows its own banners.
    QueueNotificationService.instance.isQueueScreenActive = true;
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

    final svc = FirestoreService();

    // Live "Now serving" token number
    _nowServingSubscription =
        svc.getNowServingStream(widget.hospitalId).listen((tokenNum) {
      if (mounted) setState(() => _nowServing = tokenNum);
    });

    // Live total queue count (active + called)
    _totalQueueSubscription =
        svc.getActiveTokenCountStream(widget.hospitalId).listen((count) {
      if (mounted) setState(() => _totalQueue = count);
    });

    // Live token status updates
    if (widget.tokenId != null) {
      _tokenSubscription =
          svc.getTokenStream(widget.tokenId!).listen((token) {
        if (token == null || !mounted) return;

        // First event: capture baseline, don't fire any alerts.
        if (!_initialLoadComplete) {
          _initialLoadComplete = true;
          _prevTokenStatus = token.status;
          _prevTokenPosition = token.tokenPosition;
          _prevPeopleAheadTrack = token.peopleAhead;
          setState(() {
            _peopleAhead = token.peopleAhead;
            _waitMinutes = token.estimatedWaitMinutes;
            _secondsUntilRefresh = 30;
          });
          _arcController
            ..reset()
            ..forward();
          return;
        }

        final ahead = token.peopleAhead;

        // ── Status-based alerts ───────────────────────────────────────

        // Your turn
        if (token.status == 'called' &&
            _prevTokenStatus != 'called' &&
            !_turnAlertShown) {
          _turnAlertShown = true;
          _twoAheadShown = true;
          _fiveAheadShown = true;
          _earlyAlertShown = true;
          AudioHelper.instance.playChimeTimes(3);
          HapticFeedback.heavyImpact();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _showTurnAlert();
          });
        }

        // Marked absent
        if (token.status == 'absent' &&
            _prevTokenStatus != 'absent' &&
            !_absentAlertShown) {
          _absentAlertShown = true;
          AudioHelper.instance.playChime();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _showAbsentDialog();
          });
        }

        // ── Position-change alerts (active tokens only) ───────────────

        final posJumped =
            token.tokenPosition > _prevTokenPosition + 2 &&
            (token.status == 'active' || token.status == 'called');
        final pushForward =
            ahead == _prevPeopleAheadTrack + 1 &&
            token.tokenPosition == _prevTokenPosition + 1 &&
            (token.status == 'active' || token.status == 'called');

        if (posJumped) {
          // Skipped to back of queue
          _showBanner(
            'You\'ve been moved back in the queue. New position: ${token.tokenPosition}',
            color: const Color(0xFF4F6BED),
          );
        } else if (pushForward) {
          // Emergency patient inserted ahead
          final waitEst = ahead * 4;
          AudioHelper.instance.playChime();
          _showBanner(
            'A patient has been given emergency priority. '
            'Your new position: ${token.tokenPosition}. '
            'Estimated wait: ~$waitEst min',
            color: const Color(0xFFD97706),
          );
        }

        // ── Proximity alerts (most urgent first) ─────────────────────

        if (token.status == 'active' || token.status == 'called') {
          if (!_twoAheadShown && ahead <= 2) {
            _twoAheadShown = true;
            _fiveAheadShown = true;
            _earlyAlertShown = true;
            AudioHelper.instance.playChime();
            _showBanner(
              'You\'re almost up! Please be at the counter.',
              color: const Color(0xFFEF4444),
              persistent: true,
            );
          } else if (!_fiveAheadShown && ahead <= 5) {
            _fiveAheadShown = true;
            _earlyAlertShown = true;
            final waitEst = ahead * 4;
            AudioHelper.instance.playChime();
            _showBanner(
              '5 people ahead — approximately $waitEst minutes. Start heading back.',
              color: const Color(0xFFD97706),
            );
          } else if (!_earlyAlertShown) {
            final earlyThreshold =
                (widget.initialPeopleAhead * 0.3).ceil();
            if (widget.initialPeopleAhead > 10 &&
                ahead <= earlyThreshold &&
                ahead > 5) {
              _earlyAlertShown = true;
              final waitEst = ahead * 4;
              _showBanner(
                'You have some time — don\'t go too far (~$waitEst min remaining)',
                color: const Color(0xFF4F6BED),
              );
            }
          }
        }

        _prevTokenStatus = token.status;
        _prevTokenPosition = token.tokenPosition;
        _prevPeopleAheadTrack = ahead;

        setState(() {
          _peopleAhead = ahead;
          _waitMinutes = token.estimatedWaitMinutes;
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

  void _showBanner(
    String message, {
    required Color color,
    bool persistent = false,
  }) {
    if (!mounted) return;
    setState(() {
      _bannerMessage = message;
      _bannerColor = color;
      _bannerPersistent = persistent;
      _bannerVisible = true;
    });
    if (!persistent) {
      Future.delayed(const Duration(seconds: 6), () {
        if (mounted && !_bannerPersistent) {
          setState(() => _bannerVisible = false);
        }
      });
    }
  }

  void _showAbsentDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: const Color(0xFFEF4444).withOpacity(0.3), width: 1),
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
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFEF2F2),
                ),
                child: const Icon(Icons.person_off_outlined,
                    color: Color(0xFFEF4444), size: 30),
              ),
              const SizedBox(height: 16),
              const Text(
                'Marked Absent',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'You were marked absent. Please contact the OPD desk to rejoin the queue.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: _textSecondary,
                  height: 1.5,
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
                      'Understood',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTurnAlert() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: _successGreen.withOpacity(0.3), width: 1),
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
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _successGreen.withOpacity(0.1),
                ),
                child: const Icon(Icons.notifications_active_rounded,
                    color: _successGreen, size: 32),
              ),
              const SizedBox(height: 16),
              const Text(
                "It's Your Turn!",
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Token ${widget.tokenNumber} is now being called.\nPlease proceed to the counter.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: _textSecondary,
                  height: 1.5,
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
                    color: _successGreen,
                  ),
                  child: const Center(
                    child: Text(
                      'I\'m here',
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
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Re-enable global overlays now that this screen is leaving.
    QueueNotificationService.instance.isQueueScreenActive = false;
    _tokenSubscription?.cancel();
    _nowServingSubscription?.cancel();
    _totalQueueSubscription?.cancel();
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
      backgroundColor: _bgColor,
      body: Column(
        children: [
          // ── Top bar ──────────────────────────────────────────────────
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
                      'Queue status',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: _textPrimary,
                      ),
                    ),
                    Text(
                      widget.hospitalShort,
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
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                            color: _primaryBlue,
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Text(
                          'LIVE',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: _primaryBlue,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Proximity / status alert banner ───────────────────────────
          _ProximityBanner(
            visible: _bannerVisible,
            message: _bannerMessage ?? '',
            color: _bannerColor,
            persistent: _bannerPersistent,
            onDismiss: () => setState(() => _bannerVisible = false),
          ),

          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPad + 24),
              child: Column(
                children: [
                  // ── Token hero card ───────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [_primaryBlue, _lightBlue],
                      ),
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          top: -15,
                          right: -15,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.07),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: -20,
                          right: 30,
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.05),
                            ),
                          ),
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'YOUR TOKEN',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 11,
                                      color: Colors.white.withOpacity(0.7),
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.tokenNumber,
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 32,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      const Icon(
                                          Icons.local_hospital_outlined,
                                          size: 12,
                                          color: Colors.white70),
                                      const SizedBox(width: 4),
                                      Text(
                                        widget.hospitalShort,
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 11,
                                          color: Colors.white.withOpacity(0.8),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Icon(widget.sessionIcon,
                                          size: 12, color: Colors.white70),
                                      const SizedBox(width: 4),
                                      Text(
                                        widget.session.split(' ').first,
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 11,
                                          color: Colors.white.withOpacity(0.8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Now serving box
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.white.withOpacity(0.15),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    'Now serving',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 10,
                                      color: Colors.white.withOpacity(0.7),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _nowServing ?? '---',
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Circular progress ─────────────────────────────────
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

                  // ── Stats grid (2 columns) ────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.schedule_outlined,
                          iconColor: const Color(0xFFD97706),
                          value: '~$_waitMinutes',
                          label: 'min wait',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.people_alt_outlined,
                          iconColor: _primaryBlue,
                          value: '$_totalQueue',
                          label: 'total in queue',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // ── Live update notice ────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 13),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: _borderColor, width: 0.5),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: _primaryBlue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Listening for real-time updates',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              color: _textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const Text(
                          'LIVE',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: _primaryBlue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Notification toggle ───────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _notifyEnabled
                            ? _primaryBlue.withOpacity(0.3)
                            : _borderColor,
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(11),
                            color: _notifyEnabled
                                ? _selectedBg
                                : const Color(0xFFF3F4F6),
                          ),
                          child: Icon(
                            _notifyEnabled
                                ? Icons.notifications_active_outlined
                                : Icons.notifications_outlined,
                            color: _notifyEnabled
                                ? _primaryBlue
                                : _textSecondary,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Notify me when it\'s my turn',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: _textPrimary,
                            ),
                          ),
                        ),
                        _BlueSwitch(
                          value: _notifyEnabled,
                          onChanged: (v) =>
                              setState(() => _notifyEnabled = v),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Queue position timeline ───────────────────────────
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
    );
  }
}

// ── Circular queue indicator ───────────────────────────────────────────────────

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
      width: 160,
      height: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(160, 160),
            painter: _ArcPainter(
              progress: progress,
              trackColor: const Color(0xFFE5E7EB),
              arcColor: _primaryBlue,
              strokeWidth: 10,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$peopleAhead',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 36,
                  fontWeight: FontWeight.w500,
                  color: _textPrimary,
                  height: 1,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'people ahead',
                style: TextStyle(
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
    const startAngle = -2.356;
    const sweepTotal = 4.712;

    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final arcPaint = Paint()
      ..color = arcColor
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

// ── Stat card ──────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor, width: 0.5),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 22,
              fontWeight: FontWeight.w500,
              color: _textPrimary,
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
    );
  }
}

// ── Blue custom switch ────────────────────────────────────────────────────────

class _BlueSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _BlueSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 44,
        height: 24,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: value ? _primaryBlue : const Color(0xFFE5E7EB),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          alignment:
              value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 18,
            height: 18,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
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
    final slots = <_TimelineSlot>[
      if (yourPosition > 2)
        _TimelineSlot(label: '#${yourPosition - 2}', state: _SlotState.served),
      if (yourPosition > 1)
        _TimelineSlot(label: '#${yourPosition - 1}', state: _SlotState.served),
      _TimelineSlot(label: '#$yourPosition', state: _SlotState.you),
      _TimelineSlot(label: '#${yourPosition + 1}', state: _SlotState.waiting),
      _TimelineSlot(label: '#${yourPosition + 2}', state: _SlotState.waiting),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Queue position',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '$peopleAhead people ahead',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  color: _textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
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
                          height: 1.5,
                          color: e.value.state == _SlotState.served
                              ? _primaryBlue.withOpacity(0.35)
                              : _borderColor,
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              _Legend(color: _primaryBlue, label: 'Served'),
              SizedBox(width: 18),
              _Legend(color: Color(0xFFD97706), label: 'You'),
              SizedBox(width: 18),
              _Legend(color: Color(0xFFE5E7EB), label: 'Waiting'),
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
        fill = _selectedBg;
        border = _primaryBlue;
        textColor = _primaryBlue;
      case _SlotState.you:
        fill = const Color(0xFFFEF3C7);
        border = const Color(0xFFD97706);
        textColor = const Color(0xFFD97706);
      case _SlotState.waiting:
        fill = Colors.transparent;
        border = _borderColor;
        textColor = _textSecondary;
    }

    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: fill,
            border: Border.all(color: border, width: 1.5),
          ),
          child: slot.state == _SlotState.served
              ? const Icon(Icons.check_rounded,
                  size: 14, color: _primaryBlue)
              : null,
        ),
        const SizedBox(height: 5),
        Text(
          slot.state == _SlotState.you ? 'You' : slot.label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 10,
            fontWeight: slot.state == _SlotState.you
                ? FontWeight.w500
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
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 10,
            color: _textSecondary,
          ),
        ),
      ],
    );
  }
}

// ── Proximity alert banner ────────────────────────────────────────────────────

class _ProximityBanner extends StatelessWidget {
  final bool visible;
  final String message;
  final Color color;
  final bool persistent;
  final VoidCallback onDismiss;

  const _ProximityBanner({
    required this.visible,
    required this.message,
    required this.color,
    required this.persistent,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      height: visible ? 60.0 : 0.0,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(color: color),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                  height: 1.35,
                ),
              ),
            ),
            if (!persistent)
              GestureDetector(
                onTap: onDismiss,
                child: const Padding(
                  padding: EdgeInsets.only(left: 12),
                  child: Icon(Icons.close_rounded,
                      color: Colors.white70, size: 18),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
