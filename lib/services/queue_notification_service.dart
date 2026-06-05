import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/token_model.dart';
import '../services/firestore_service.dart';
import '../utils/audio_helper.dart';

class QueueNotificationService {
  QueueNotificationService._();
  static final QueueNotificationService instance = QueueNotificationService._();

  GlobalKey<NavigatorState>? _navigatorKey;
  StreamSubscription<TokenModel?>? _tokenSub;
  OverlayEntry? _bannerEntry;

  // Alert flags — all reset on each attach()
  bool _initialLoadComplete = false;
  bool _earlyAlertShown = false;
  bool _fiveAheadShown = false;
  bool _twoAheadShown = false;
  bool _absentAlertShown = false;
  bool _turnAlertShown = false;
  bool _servedAlertShown = false;
  bool _skippedAlertShown = false;
  int _prevTokenPosition = 0;
  int _prevPeopleAheadTrack = 0;
  String? _prevTokenStatus;
  int _initialPeopleAhead = 0;

  /// Set to true by QueueTrackingScreen on mount, false on dispose.
  /// While true, global overlays are suppressed — the screen's own banners handle display.
  bool isQueueScreenActive = false;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  void init(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  /// Called immediately after booking — starts listening to the new token.
  void attach({required String tokenId, required int initialPeopleAhead}) {
    _reset();
    _initialPeopleAhead = initialPeopleAhead;
    _startListening(tokenId);
  }

  /// Called on login — queries Firestore for any active/called token today,
  /// then attaches to it if found.
  Future<void> checkAndAttach(String userId) async {
    final db = FirebaseFirestore.instance;
    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day);
    try {
      final snap = await db
          .collection('tokens')
          .where('user_id', isEqualTo: userId)
          .get();
      for (final doc in snap.docs) {
        final data = doc.data();
        final status = data['status'] as String? ?? '';
        if (status != 'active' && status != 'called') continue;
        final issuedAt = (data['issued_at'] as Timestamp?)?.toDate();
        if (issuedAt == null || issuedAt.isBefore(dayStart)) continue;
        final peopleAhead = data['people_ahead'] as int? ?? 0;
        attach(tokenId: doc.id, initialPeopleAhead: peopleAhead);
        return;
      }
    } catch (_) {}
  }

  /// Called on logout — cancels listener and clears all state.
  void detach() {
    _reset();
    _removeBanner();
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  void _reset() {
    _tokenSub?.cancel();
    _tokenSub = null;
    _initialLoadComplete = false;
    _earlyAlertShown = false;
    _fiveAheadShown = false;
    _twoAheadShown = false;
    _absentAlertShown = false;
    _turnAlertShown = false;
    _servedAlertShown = false;
    _skippedAlertShown = false;
    _prevTokenPosition = 0;
    _prevPeopleAheadTrack = 0;
    _prevTokenStatus = null;
    _initialPeopleAhead = 0;
  }

  void _startListening(String tokenId) {
    _tokenSub =
        FirestoreService().getTokenStream(tokenId).listen((token) {
      if (token == null) return;
      _handleTokenUpdate(token);
    });
  }

  void _handleTokenUpdate(TokenModel token) {
    // First event — capture baseline, never fire alerts.
    if (!_initialLoadComplete) {
      _initialLoadComplete = true;
      _prevTokenStatus = token.status;
      _prevTokenPosition = token.tokenPosition;
      _prevPeopleAheadTrack = token.peopleAhead;
      return;
    }

    final ahead = token.peopleAhead;

    // ── Status-based alerts ─────────────────────────────────────────────────

    if (token.status == 'called' &&
        _prevTokenStatus != 'called' &&
        !_turnAlertShown) {
      _turnAlertShown = true;
      _twoAheadShown = true;
      _fiveAheadShown = true;
      _earlyAlertShown = true;
      if (!isQueueScreenActive) {
        AudioHelper.instance.playChimeTimes(3);
        HapticFeedback.heavyImpact();
        _showGlobalDialog(_TurnDialog(tokenNumber: token.tokenNumber));
      }
    }

    if (token.status == 'absent' &&
        _prevTokenStatus != 'absent' &&
        !_absentAlertShown) {
      _absentAlertShown = true;
      if (!isQueueScreenActive) {
        AudioHelper.instance.playChime();
        _showGlobalDialog(const _AbsentDialog());
      }
    }

    if (token.status == 'served' &&
        _prevTokenStatus != 'served' &&
        !_servedAlertShown) {
      _servedAlertShown = true;
      if (!isQueueScreenActive) {
        AudioHelper.instance.playChime();
        _showGlobalBanner(
          '✅ Consultation complete. Thank you for using LineSkip!',
          const Color(0xFF10B981),
        );
      }
    }

    if (token.status == 'skipped' &&
        _prevTokenStatus != 'skipped' &&
        !_skippedAlertShown) {
      _skippedAlertShown = true;
      if (!isQueueScreenActive) {
        AudioHelper.instance.playChime();
        _showGlobalBanner(
          '⚠️ You were skipped. You have been moved to the end of the queue and will be called again soon.',
          const Color(0xFFD97706),
        );
      }
    }

    // ── Position-change alerts ──────────────────────────────────────────────

    final posJumped = token.tokenPosition > _prevTokenPosition + 2 &&
        (token.status == 'active' || token.status == 'called');
    final pushForward = ahead == _prevPeopleAheadTrack + 1 &&
        token.tokenPosition == _prevTokenPosition + 1 &&
        (token.status == 'active' || token.status == 'called');

    if (!isQueueScreenActive) {
      if (posJumped) {
        _showGlobalBanner(
          'You\'ve been moved back in the queue. New position: ${token.tokenPosition}',
          const Color(0xFF4F6BED),
        );
      } else if (pushForward) {
        final waitEst = ahead * 4;
        AudioHelper.instance.playChime();
        _showGlobalBanner(
          'A patient has been given emergency priority. '
          'Your new position: ${token.tokenPosition}. '
          'Est. wait: ~$waitEst min',
          const Color(0xFFD97706),
        );
      }
    }

    // ── Proximity alerts (most urgent first) ───────────────────────────────

    if (token.status == 'active' || token.status == 'called') {
      if (!_twoAheadShown && ahead <= 2) {
        _twoAheadShown = true;
        _fiveAheadShown = true;
        _earlyAlertShown = true;
        if (!isQueueScreenActive) {
          AudioHelper.instance.playChime();
          _showGlobalBanner(
            'You\'re almost up! Please be at the counter.',
            const Color(0xFFEF4444),
            persistent: true,
          );
        }
      } else if (!_fiveAheadShown && ahead <= 5) {
        _fiveAheadShown = true;
        _earlyAlertShown = true;
        final waitEst = ahead * 4;
        if (!isQueueScreenActive) {
          AudioHelper.instance.playChime();
          _showGlobalBanner(
            '5 people ahead — approximately $waitEst minutes. Start heading back.',
            const Color(0xFFD97706),
          );
        }
      } else if (!_earlyAlertShown) {
        final earlyThreshold = (_initialPeopleAhead * 0.3).ceil();
        if (_initialPeopleAhead > 10 &&
            ahead <= earlyThreshold &&
            ahead > 5) {
          _earlyAlertShown = true;
          final waitEst = ahead * 4;
          if (!isQueueScreenActive) {
            _showGlobalBanner(
              'You have some time — don\'t go too far (~$waitEst min remaining)',
              const Color(0xFF4F6BED),
            );
          }
        }
      }
    }

    _prevTokenStatus = token.status;
    _prevTokenPosition = token.tokenPosition;
    _prevPeopleAheadTrack = ahead;
  }

  // ── Overlay helpers ────────────────────────────────────────────────────────

  void _showGlobalBanner(
    String message,
    Color color, {
    bool persistent = false,
  }) {
    _removeBanner();
    final overlay = _navigatorKey?.currentState?.overlay;
    if (overlay == null) return;

    _bannerEntry = OverlayEntry(
      builder: (_) => _GlobalBanner(
        message: message,
        color: color,
        persistent: persistent,
        onDismiss: _removeBanner,
      ),
    );
    overlay.insert(_bannerEntry!);

    if (!persistent) {
      Future.delayed(const Duration(seconds: 6), _removeBanner);
    }
  }

  void _removeBanner() {
    _bannerEntry?.remove();
    _bannerEntry = null;
  }

  void _showGlobalDialog(Widget child) {
    final context = _navigatorKey?.currentContext;
    if (context == null) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => child,
    );
  }
}

// ── Global slide-in banner ─────────────────────────────────────────────────────

class _GlobalBanner extends StatefulWidget {
  final String message;
  final Color color;
  final bool persistent;
  final VoidCallback onDismiss;

  const _GlobalBanner({
    required this.message,
    required this.color,
    required this.persistent,
    required this.onDismiss,
  });

  @override
  State<_GlobalBanner> createState() => _GlobalBannerState();
}

class _GlobalBannerState extends State<_GlobalBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slide,
        child: Material(
          color: Colors.transparent,
          child: Container(
            color: widget.color,
            padding: EdgeInsets.fromLTRB(16, topPad + 10, 16, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.notifications_active_outlined,
                    color: Colors.white70, size: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                      height: 1.4,
                    ),
                  ),
                ),
                if (!widget.persistent) ...[
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: widget.onDismiss,
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white70, size: 18),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Your Turn dialog ───────────────────────────────────────────────────────────

const _successGreen = Color(0xFF10B981);
const _textPrimary = Color(0xFF1F2937);
const _textSecondary = Color(0xFF9CA3AF);

class _TurnDialog extends StatelessWidget {
  final String tokenNumber;
  const _TurnDialog({required this.tokenNumber});

  @override
  Widget build(BuildContext context) {
    return Dialog(
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
              'Token $tokenNumber is now being called.\nPlease proceed to the counter.',
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
                    "I'm here",
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
    );
  }
}

// ── Absent dialog ──────────────────────────────────────────────────────────────

class _AbsentDialog extends StatelessWidget {
  const _AbsentDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
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
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFFEF2F2),
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
    );
  }
}
