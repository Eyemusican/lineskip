import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/staff_dashboard_screen.dart';
import 'services/queue_notification_service.dart';

final _navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  QueueNotificationService.instance.init(_navigatorKey);
  runApp(const LineSkipApp());
}

class LineSkipApp extends StatelessWidget {
  const LineSkipApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'LineSkip',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF4F6BED),
          surface: Color(0xFFFAFBFD),
        ),
        scaffoldBackgroundColor: const Color(0xFFFAFBFD),
        textTheme: ThemeData.light().textTheme.apply(fontFamily: 'Poppins'),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  User? _user;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Always sign out on startup — no persisted sessions, fresh login required.
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    setState(() => _ready = true);

    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!mounted) return;
      if (user != null) {
        // Start global queue listener for any active token this patient has today.
        QueueNotificationService.instance.checkAndAttach(user.uid);
        setState(() => _user = user);
      } else {
        // Stop global listener on sign-out.
        QueueNotificationService.instance.detach();
        // reCAPTCHA fires transient nulls — debounce before treating as sign-out.
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted) return;
          setState(() => _user = FirebaseAuth.instance.currentUser);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const _SplashScreen();
    if (_user == null) return const LoginScreen();
    return _RoleRouter(key: ValueKey(_user!.uid), user: _user!);
  }
}

class _RoleRouter extends StatefulWidget {
  final User user;
  const _RoleRouter({required this.user, super.key});

  @override
  State<_RoleRouter> createState() => _RoleRouterState();
}

class _RoleRouterState extends State<_RoleRouter> {
  String? _role;

  @override
  void initState() {
    super.initState();
    debugPrint('=== _RoleRouter initState, uid=${widget.user.uid} ===');
    _fetchRole();
  }

  Future<void> _fetchRole() async {
    String? found;

    debugPrint('=== _fetchRole START ===');
    debugPrint('Auth UID: ${widget.user.uid}');
    debugPrint('Auth phone: ${widget.user.phoneNumber}');

    try {
      final q = await FirebaseFirestore.instance
          .collection('users')
          .where('uid', isEqualTo: widget.user.uid)
          .limit(1)
          .get(const GetOptions(source: Source.server));
      debugPrint('UID query docs found: ${q.docs.length}');
      if (q.docs.isNotEmpty) {
        final data = q.docs.first.data();
        debugPrint('UID query doc data: $data');
        found = data['role'] as String? ?? 'patient';
      }
    } catch (e) {
      debugPrint('UID query error: $e');
    }

    if (found == null) {
      final phone = widget.user.phoneNumber;
      if (phone != null && phone.isNotEmpty) {
        try {
          final q = await FirebaseFirestore.instance
              .collection('users')
              .where('phone', isEqualTo: phone)
              .limit(1)
              .get(const GetOptions(source: Source.server));
          debugPrint('Phone query docs found: ${q.docs.length}');
          if (q.docs.isNotEmpty) {
            final data = q.docs.first.data();
            debugPrint('Phone query doc data: $data');
            found = data['role'] as String? ?? 'patient';
          }
        } catch (e) {
          debugPrint('Phone query error: $e');
        }
      }
    }

    debugPrint('Final role resolved: ${found ?? 'patient'}');
    debugPrint('=== _fetchRole END ===');

    if (mounted) setState(() => _role = found ?? 'patient');
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('=== _RoleRouter build, _role=$_role ===');
    if (_role == null) return const _SplashScreen();
    if (_role == 'staff') {
      debugPrint('=== Routing to StaffDashboardScreen ===');
      return const StaffDashboardScreen();
    }
    debugPrint('=== Routing to HomeScreen ===');
    return const HomeScreen();
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFD),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 160,
              height: 160,
            ),
            const SizedBox(height: 28),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF4F6BED),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
