import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/hospital.dart';
import '../services/firestore_service.dart';
import '../widgets/hospital_card.dart';
import 'token_booking_screen.dart';
import 'my_tokens_screen.dart';
import 'profile_screen.dart';

const _primaryBlue = Color(0xFF4F6BED);
const _lightBlue = Color(0xFF6C8BF5);
const _bgColor = Color(0xFFFAFBFD);
const _textPrimary = Color(0xFF1F2937);
const _textSecondary = Color(0xFF9CA3AF);
const _borderColor = Color(0xFFE5E7EB);
const _selectedBg = Color(0xFFEEF2FF);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();
  List<Hospital> _allHospitals = [];
  List<Hospital> _filtered = [];
  String _selectedFilter = 'All';
  Map<String, int> _activeCounts = {};
  StreamSubscription<List<Hospital>>? _hospitalsSubscription;
  StreamSubscription<Map<String, int>>? _countsSubscription;

  final List<String> _filters = ['All', 'Short Wait', 'Open Now'];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearch);
    _subscribeToHospitals();
    _countsSubscription =
        _firestoreService.getTodayActiveCountsStream().listen((counts) {
      setState(() => _activeCounts = counts);
      _onSearch();
    }, onError: (_) {});
  }

  void _subscribeToHospitals() {
    _hospitalsSubscription =
        _firestoreService.getHospitals().listen((hospitals) {
      setState(() => _allHospitals = hospitals);
      _onSearch();
    }, onError: (_) {});
  }

  void _onSearch() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filtered = _allHospitals.where((h) {
        final matchQuery = q.isEmpty ||
            h.name.toLowerCase().contains(q) ||
            h.shortName.toLowerCase().contains(q) ||
            h.location.toLowerCase().contains(q);
        final liveCount = _activeCounts[h.id] ?? 0;
        final matchFilter = _selectedFilter == 'All' ||
            (_selectedFilter == 'Open Now' && h.isOpen) ||
            (_selectedFilter == 'Short Wait' && liveCount <= 10);
        return matchQuery && matchFilter;
      }).toList();
    });
  }

  void _applyFilter(String filter) {
    setState(() => _selectedFilter = filter);
    _onSearch();
  }

  @override
  void dispose() {
    _hospitalsSubscription?.cancel();
    _countsSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final user = FirebaseAuth.instance.currentUser;
    final displayName = (user?.displayName != null && user!.displayName!.isNotEmpty)
        ? user.displayName!
        : (user?.phoneNumber ?? 'Patient');

    return Scaffold(
      backgroundColor: _bgColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, topPad + 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header row ───────────────────────────────────
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Welcome back',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: _textSecondary,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            '$displayName 👋',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                              color: _textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Stack(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _selectedBg,
                            ),
                            child: const Icon(
                              Icons.notifications_outlined,
                              color: _primaryBlue,
                              size: 20,
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFFEF4444),
                                border:
                                    Border.all(color: Colors.white, width: 1.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── Hero banner card ─────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        begin: Alignment(0.0, -1.0),
                        end: Alignment(1.0, 1.0),
                        colors: [_primaryBlue, _lightBlue],
                      ),
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Decorative circles
                        Positioned(
                          top: -20,
                          right: -10,
                          child: Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.08),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: -30,
                          right: 40,
                          child: Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.06),
                            ),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Image.asset(
                              'assets/images/logo.png',
                              width: 80,
                              height: 80,
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Skip the wait.\nOwn your day.',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Book your OPD token digitally',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.75),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 7),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: Colors.white,
                              ),
                              child: const Text(
                                'Book now',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: _primaryBlue,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Search bar ───────────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _borderColor, width: 0.5),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        color: _textPrimary,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search hospital or department...',
                        hintStyle: const TextStyle(
                          fontFamily: 'Poppins',
                          color: Color(0xFFC4C9D4),
                          fontSize: 13,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: _textSecondary,
                          size: 20,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? GestureDetector(
                                onTap: () => _searchController.clear(),
                                child: const Icon(
                                  Icons.close_rounded,
                                  color: _textSecondary,
                                  size: 18,
                                ),
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── OPD Departments (informational only) ─────────
                  Row(
                    children: [
                      const Text(
                        'OPD departments',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: _textPrimary,
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        'See all',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          color: _primaryBlue,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: const [
                        _DeptIcon(
                          label: 'General',
                          icon: Icons.favorite_outline,
                          bgColor: Color(0xFFFEF3C7),
                          iconColor: Color(0xFFD97706),
                        ),
                        SizedBox(width: 12),
                        _DeptIcon(
                          label: 'Eye',
                          icon: Icons.visibility_outlined,
                          bgColor: Color(0xFFDBEAFE),
                          iconColor: Color(0xFF2563EB),
                        ),
                        SizedBox(width: 12),
                        _DeptIcon(
                          label: 'Ortho',
                          icon: Icons.accessible_outlined,
                          bgColor: Color(0xFFFCE7F3),
                          iconColor: Color(0xFFDB2777),
                        ),
                        SizedBox(width: 12),
                        _DeptIcon(
                          label: 'ENT',
                          icon: Icons.hearing_outlined,
                          bgColor: Color(0xFFD1FAE5),
                          iconColor: Color(0xFF059669),
                        ),
                        SizedBox(width: 12),
                        _DeptIcon(
                          label: 'Dental',
                          icon: Icons.medical_services_outlined,
                          bgColor: Color(0xFFEDE9FE),
                          iconColor: Color(0xFF7C3AED),
                        ),
                        SizedBox(width: 12),
                        _DeptIcon(
                          label: 'Pediatrics',
                          icon: Icons.child_care_outlined,
                          bgColor: Color(0xFFFFEDD5),
                          iconColor: Color(0xFFEA580C),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Filter chips ─────────────────────────────────
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _filters.map((f) {
                        final active = _selectedFilter == f;
                        return GestureDetector(
                          onTap: () => _applyFilter(f),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: active ? _primaryBlue : Colors.white,
                              border: Border.all(
                                color: active ? _primaryBlue : _borderColor,
                                width: active ? 1 : 0.5,
                              ),
                            ),
                            child: Text(
                              f,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: active ? Colors.white : _textSecondary,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Nearby hospitals header ───────────────────────
                  Row(
                    children: [
                      const Text(
                        'Nearby hospital',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: _textPrimary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_filtered.length} found',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: _textSecondary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),
                ],
              ),
            ),
          ),

          // ── Hospital cards ─────────────────────────────────────────
          if (_filtered.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 60),
                child: Column(
                  children: const [
                    Icon(
                      Icons.search_off_rounded,
                      size: 48,
                      color: Color(0xFFC4C9D4),
                    ),
                    SizedBox(height: 14),
                    Text(
                      'No hospitals found',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        color: _textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final hospital = _filtered[index];
                    return HospitalCard(
                      hospital: hospital,
                      activeCount: _activeCounts[hospital.id] ?? 0,
                      onBookTap: () => _showBookingSheet(context, hospital),
                    );
                  },
                  childCount: _filtered.length,
                ),
              ),
            ),
        ],
      ),

      bottomNavigationBar: _BottomNav(
        activeIndex: 0,
        onMyTokensTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MyTokensScreen()),
        ),
        onMapTap: () => _showMapComingSoon(context),
        onProfileTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProfileScreen()),
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

// ── OPD Department icon widget ─────────────────────────────────────────────────

class _DeptIcon extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color bgColor;
  final Color iconColor;

  const _DeptIcon({
    required this.label,
    required this.icon,
    required this.bgColor,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: bgColor,
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 10,
            color: Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }
}

// ── Map coming soon modal ──────────────────────────────────────────────────────

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
        border: Border.all(color: const Color(0xFFE5E7EB), width: 0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFEEF2FF),
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
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Hospital directions and live navigation\nwill be available in the next update.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              color: Color(0xFF9CA3AF),
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

// ── Bottom navigation bar ──────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final int activeIndex;
  final VoidCallback onMyTokensTap;
  final VoidCallback onMapTap;
  final VoidCallback onProfileTap;

  const _BottomNav({
    required this.activeIndex,
    required this.onMyTokensTap,
    required this.onMapTap,
    required this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      height: 62 + bottomPad,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE5E7EB), width: 0.5),
        ),
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
              active: activeIndex == 0,
              onTap: () {},
            ),
            _NavItem(
              icon: Icons.confirmation_number_outlined,
              activeIcon: Icons.confirmation_number_rounded,
              label: 'My Tokens',
              active: activeIndex == 1,
              onTap: onMyTokensTap,
            ),
            _NavItem(
              icon: Icons.map_outlined,
              activeIcon: Icons.map_rounded,
              label: 'Map',
              active: activeIndex == 2,
              onTap: onMapTap,
            ),
            _NavItem(
              icon: Icons.person_outline_rounded,
              activeIcon: Icons.person_rounded,
              label: 'Profile',
              active: activeIndex == 3,
              onTap: onProfileTap,
            ),
          ],
        ),
      ),
    );
  }
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
