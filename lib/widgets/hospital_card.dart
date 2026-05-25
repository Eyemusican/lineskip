import 'package:flutter/material.dart';
import '../models/hospital.dart';

const _primaryBlue = Color(0xFF4F6BED);
const _borderColor = Color(0xFFE5E7EB);
const _textPrimary = Color(0xFF1F2937);
const _textSecondary = Color(0xFF9CA3AF);

class HospitalCard extends StatelessWidget {
  final Hospital hospital;
  final int activeCount;
  final VoidCallback onBookTap;

  const HospitalCard({
    super.key,
    required this.hospital,
    required this.activeCount,
    required this.onBookTap,
  });

  Color _queueColor(int queue) {
    if (queue <= 10) return const Color(0xFF10B981);
    if (queue <= 20) return const Color(0xFFD97706);
    return const Color(0xFFEF4444);
  }

  String _queueLabel(int queue) {
    if (queue <= 10) return 'Short Wait';
    if (queue <= 20) return 'Moderate';
    return 'Busy';
  }

  @override
  Widget build(BuildContext context) {
    final queueColor = _queueColor(activeCount);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Placeholder image area ─────────────────────────────
            Container(
              width: double.infinity,
              height: 96,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFE0E7FF), Color(0xFFC7D2FE)],
                ),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Icon(
                      Icons.local_hospital_outlined,
                      size: 40,
                      color: _primaryBlue.withOpacity(0.4),
                    ),
                  ),
                  // Open / Closed badge
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: hospital.isOpen
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            hospital.isOpen ? 'Open' : 'Closed',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Card body ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + location
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
                    hospital.name,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      color: _textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 12, color: _textSecondary),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          hospital.location,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            color: _textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  Container(height: 0.5, color: _borderColor),
                  const SizedBox(height: 12),

                  // Stats + book button
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: queueColor,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$activeCount in queue',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: _textSecondary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          color: queueColor.withOpacity(0.1),
                        ),
                        child: Text(
                          _queueLabel(activeCount),
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: queueColor,
                          ),
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: hospital.isOpen ? onBookTap : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: hospital.isOpen
                                ? _primaryBlue
                                : const Color(0xFFF3F4F6),
                          ),
                          child: Text(
                            'Book token',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: hospital.isOpen
                                  ? Colors.white
                                  : _textSecondary,
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
