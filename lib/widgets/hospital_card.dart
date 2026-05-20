import 'package:flutter/material.dart';
import '../models/hospital.dart';

class HospitalCard extends StatelessWidget {
  final Hospital hospital;
  final VoidCallback onBookTap;

  const HospitalCard({
    super.key,
    required this.hospital,
    required this.onBookTap,
  });

  Color _queueColor(int queue) {
    if (queue <= 10) return const Color(0xFF00E5C8);
    if (queue <= 20) return const Color(0xFFFFC107);
    return const Color(0xFFFF5252);
  }

  String _queueLabel(int queue) {
    if (queue <= 10) return 'Short Wait';
    if (queue <= 20) return 'Moderate';
    return 'Busy';
  }

  @override
  Widget build(BuildContext context) {
    final queueColor = _queueColor(hospital.currentQueue);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
            color: Colors.black.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Subtle accent glow top-left
            Positioned(
              top: -20,
              left: -20,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: queueColor.withOpacity(0.07),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Hospital icon badge
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: const Color(0xFF00E5C8).withOpacity(0.12),
                          border: Border.all(
                            color: const Color(0xFF00E5C8).withOpacity(0.25),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            hospital.shortName[0],
                            style: TextStyle(fontFamily: 'Poppins',
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF00E5C8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hospital.shortName,
                              style: TextStyle(fontFamily: 'Poppins',
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on_rounded,
                                  size: 12,
                                  color: Colors.white.withOpacity(0.45),
                                ),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(
                                    hospital.location,
                                    style: TextStyle(fontFamily: 'Poppins',
                                      fontSize: 11.5,
                                      color: Colors.white.withOpacity(0.45),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Open/Closed badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: hospital.isOpen
                              ? const Color(0xFF00E5C8).withOpacity(0.12)
                              : Colors.red.withOpacity(0.12),
                          border: Border.all(
                            color: hospital.isOpen
                                ? const Color(0xFF00E5C8).withOpacity(0.4)
                                : Colors.red.withOpacity(0.4),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          hospital.isOpen ? 'Open' : 'Closed',
                          style: TextStyle(fontFamily: 'Poppins',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: hospital.isOpen
                                ? const Color(0xFF00E5C8)
                                : Colors.redAccent,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Speciality
                  Text(
                    hospital.speciality,
                    style: TextStyle(fontFamily: 'Poppins',
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.5),
                      fontWeight: FontWeight.w400,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Divider
                  Container(
                    height: 1,
                    color: const Color(0xFF1E3A52),
                  ),

                  const SizedBox(height: 16),

                  // Stats + Button row
                  Row(
                    children: [
                      // Queue stat
                      _StatChip(
                        icon: Icons.people_alt_rounded,
                        label: 'In Queue',
                        value: '${hospital.currentQueue}',
                        valueColor: queueColor,
                      ),
                      const SizedBox(width: 16),
                      // Wait stat
                      _StatChip(
                        icon: Icons.schedule_rounded,
                        label: 'Est. Wait',
                        value: '~${hospital.estimatedWaitMinutes}m',
                        valueColor: Colors.white,
                      ),

                      // Queue status pill
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: queueColor.withOpacity(0.12),
                        ),
                        child: Text(
                          _queueLabel(hospital.currentQueue),
                          style: TextStyle(fontFamily: 'Poppins',
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: queueColor,
                          ),
                        ),
                      ),

                      const Spacer(),

                      // Book Token button
                      GestureDetector(
                        onTap: hospital.isOpen ? onBookTap : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: hospital.isOpen
                                ? const LinearGradient(
                                    colors: [
                                      Color(0xFF00E5C8),
                                      Color(0xFF00B8A0),
                                    ],
                                  )
                                : null,
                            color: hospital.isOpen
                                ? null
                                : Colors.white.withOpacity(0.08),
                            boxShadow: hospital.isOpen
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF00E5C8)
                                          .withOpacity(0.35),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Text(
                            'Book Token',
                            style: TextStyle(fontFamily: 'Poppins',
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: hospital.isOpen
                                  ? const Color(0xFF0D1B2A)
                                  : Colors.white.withOpacity(0.3),
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: Colors.white.withOpacity(0.35)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(fontFamily: 'Poppins',
                fontSize: 10.5,
                color: Colors.white.withOpacity(0.35),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(fontFamily: 'Poppins',
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
