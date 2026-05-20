import 'dart:async';
import 'package:flutter/material.dart';
import '../models/hospital.dart';
import '../services/firestore_service.dart';
import '../widgets/hospital_card.dart';
import 'token_booking_screen.dart';
import 'my_tokens_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  List<Hospital> _allHospitals = sampleHospitals;
  List<Hospital> _filtered = sampleHospitals;
  String _selectedFilter = 'All';
  StreamSubscription<List<Hospital>>? _hospitalsSubscription;

  final List<String> _filters = ['All', 'Short Wait', 'Open Now'];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _searchController.addListener(_onSearch);
    _subscribeToHospitals();
  }

  void _subscribeToHospitals() {
    _hospitalsSubscription =
        _firestoreService.getHospitals().listen((hospitals) {
      if (hospitals.isEmpty) {
        // Seed Firestore with sample data on first run
        _firestoreService.seedHospitalsIfEmpty();
      } else {
        setState(() => _allHospitals = hospitals);
        _onSearch();
      }
    }, onError: (_) {
      // Silently fall back to sample data on error
    });
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Good Morning ☀️';
    if (hour >= 12 && hour < 17) return 'Good Afternoon 🌤️';
    return 'Good Evening 🌙';
  }

  void _onSearch() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filtered = _allHospitals.where((h) {
        final matchQuery = q.isEmpty ||
            h.name.toLowerCase().contains(q) ||
            h.shortName.toLowerCase().contains(q) ||
            h.location.toLowerCase().contains(q);
        final matchFilter = _selectedFilter == 'All' ||
            (_selectedFilter == 'Open Now' && h.isOpen) ||
            (_selectedFilter == 'Short Wait' && h.currentQueue <= 10);
        return matchQuery && matchFilter;
      }).toList();
    });
  }

  void _applyFilter(String filter) {
    setState(() {
      _selectedFilter = filter;
    });
    _onSearch();
  }

  @override
  void dispose() {
    _hospitalsSubscription?.cancel();
    _pulseController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: Stack(
        children: [
          // Background radial glow
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF00E5C8).withOpacity(0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -100,
            child: Container(
              width: 260,
              height: 260,
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

          // Main content
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24, topPad + 20, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top bar
                      Row(
                        children: [
                          Text(
                            _greeting(),
                            style: TextStyle(fontFamily: 'Poppins',
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const Spacer(),
                          // Notification bell
                          Stack(
                            children: [
                              Container(
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
                                child: Icon(
                                  Icons.notifications_outlined,
                                  color: Colors.white.withOpacity(0.7),
                                  size: 20,
                                ),
                              ),
                              Positioned(
                                top: 9,
                                right: 9,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFF00E5C8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // Hero headline
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Colors.white, Color(0xFFB0D8D4)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ).createShader(bounds),
                        child: Text(
                          'LineSkip',
                          style: TextStyle(fontFamily: 'Poppins',
                            fontSize: 40,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -1,
                            height: 1.1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          ScaleTransition(
                            scale: _pulseAnimation,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF00E5C8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Skip the Wait. Own Your Day.',
                            style: TextStyle(fontFamily: 'Poppins',
                              fontSize: 14,
                              color: const Color(0xFF00E5C8),
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),

                      // Live queue summary card
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF00E5C8).withOpacity(0.15),
                              const Color(0xFF0057FF).withOpacity(0.08),
                            ],
                          ),
                          border: Border.all(
                            color: const Color(0xFF00E5C8).withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            ScaleTransition(
                              scale: _pulseAnimation,
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF00E5C8)
                                      .withOpacity(0.15),
                                ),
                                child: const Icon(
                                  Icons.local_hospital_rounded,
                                  color: Color(0xFF00E5C8),
                                  size: 22,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Live Queue Updates',
                                  style: TextStyle(fontFamily: 'Poppins',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  '${_allHospitals.length} hospitals · Thimphu active now',
                                  style: TextStyle(fontFamily: 'Poppins',
                                    fontSize: 11.5,
                                    color: Colors.white.withOpacity(0.5),
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: const Color(0xFF00E5C8).withOpacity(0.2),
                              ),
                              child: Text(
                                'LIVE',
                                style: TextStyle(fontFamily: 'Poppins',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF00E5C8),
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Search bar
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: const Color(0xFF152438),
                          border: Border.all(
                            color: const Color(0xFF1E3A52),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          style: TextStyle(fontFamily: 'Poppins',
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search hospital or clinic...',
                            hintStyle: TextStyle(fontFamily: 'Poppins',
                              color: Colors.white.withOpacity(0.3),
                              fontSize: 14,
                            ),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: const Color(0xFF00E5C8).withOpacity(0.7),
                              size: 22,
                            ),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? GestureDetector(
                                    onTap: () {
                                      _searchController.clear();
                                    },
                                    child: Icon(
                                      Icons.close_rounded,
                                      color: Colors.white.withOpacity(0.4),
                                      size: 18,
                                    ),
                                  )
                                : Icon(
                                    Icons.tune_rounded,
                                    color: Colors.white.withOpacity(0.3),
                                    size: 20,
                                  ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Filter chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _filters.map((f) {
                            final active = _selectedFilter == f;
                            return GestureDetector(
                              onTap: () => _applyFilter(f),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.only(right: 10),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(30),
                                  color: active
                                      ? const Color(0xFF00E5C8)
                                      : const Color(0xFF152438),
                                  border: Border.all(
                                    color: active
                                        ? const Color(0xFF00E5C8)
                                        : const Color(0xFF1E3A52),
                                    width: 1,
                                  ),
                                  boxShadow: active
                                      ? [
                                          BoxShadow(
                                            color: const Color(0xFF00E5C8)
                                                .withOpacity(0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Text(
                                  f,
                                  style: TextStyle(fontFamily: 'Poppins',
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: active
                                        ? const Color(0xFF0D1B2A)
                                        : Colors.white.withOpacity(0.6),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Section header
                      Row(
                        children: [
                          Text(
                            'Nearby Hospitals',
                            style: TextStyle(fontFamily: 'Poppins',
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${_filtered.length} found',
                            style: TextStyle(fontFamily: 'Poppins',
                              fontSize: 12.5,
                              color: Colors.white.withOpacity(0.4),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // Hospital cards
              if (_filtered.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 60),
                    child: Column(
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 56,
                          color: Colors.white.withOpacity(0.15),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No hospitals found',
                          style: TextStyle(fontFamily: 'Poppins',
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.3),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final hospital = _filtered[index];
                        return HospitalCard(
                          hospital: hospital,
                          onBookTap: () => _showBookingSheet(context, hospital),
                        );
                      },
                      childCount: _filtered.length,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),

      // Bottom nav bar
      bottomNavigationBar: _BottomNav(
        onMyTokensTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MyTokensScreen()),
        ),
      ),
    );
  }

  void _showBookingSheet(BuildContext context, Hospital hospital) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TokenBookingScreen(hospital: hospital),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final VoidCallback onMyTokensTap;

  const _BottomNav({required this.onMyTokensTap});

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
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
            _NavItem(icon: Icons.home_rounded, label: 'Home', active: true,
                onTap: () {}),
            _NavItem(
              icon: Icons.confirmation_number_outlined,
              label: 'My Tokens',
              active: false,
              onTap: onMyTokensTap,
            ),
            _NavItem(icon: Icons.map_outlined, label: 'Map', active: false,
                onTap: () {}),
            _NavItem(icon: Icons.person_outline_rounded, label: 'Profile',
                active: false, onTap: () {}),
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

