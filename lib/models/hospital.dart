import 'package:cloud_firestore/cloud_firestore.dart';

class Hospital {
  final String id;
  final String name;
  final String shortName;
  final String location;
  final int currentQueue;
  final int estimatedWaitMinutes;
  final String speciality;
  final bool isOpen;
  final Map<String, String> operatingHours;

  const Hospital({
    required this.id,
    required this.name,
    required this.shortName,
    required this.location,
    required this.currentQueue,
    required this.estimatedWaitMinutes,
    required this.speciality,
    required this.isOpen,
    this.operatingHours = const {},
  });

  factory Hospital.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Hospital(
      id: doc.id,
      name: data['name'] ?? '',
      shortName: data['short_name'] ?? '',
      location: data['location'] ?? '',
      currentQueue: data['current_queue'] ?? 0,
      estimatedWaitMinutes: data['estimated_wait_minutes'] ?? 0,
      speciality: data['speciality'] ?? '',
      isOpen: data['is_active'] ?? false,
      operatingHours:
          Map<String, String>.from(data['operating_hours'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'short_name': shortName,
        'location': location,
        'current_queue': currentQueue,
        'estimated_wait_minutes': estimatedWaitMinutes,
        'speciality': speciality,
        'is_active': isOpen,
        'operating_hours': operatingHours,
      };
}

// Seed data — used as offline fallback and for initial Firestore population.
final List<Hospital> sampleHospitals = [
  const Hospital(
    id: 'jdwnrh',
    name: 'Jigme Dorji Wangchuck National Referral Hospital',
    shortName: 'JDWNRH',
    location: 'Gongphel Lam, Thimphu',
    currentQueue: 24,
    estimatedWaitMinutes: 48,
    speciality: 'General OPD · Specialist Clinics',
    isOpen: true,
    operatingHours: {
      'weekdays': '8:00 AM – 5:00 PM',
      'saturday': '9:00 AM – 1:00 PM',
      'sunday': 'Closed',
    },
  ),
  const Hospital(
    id: 'lingkana',
    name: 'Lingkana Hospital',
    shortName: 'Lingkana',
    location: 'Lingkana, Thimphu',
    currentQueue: 11,
    estimatedWaitMinutes: 22,
    speciality: 'General OPD · Dental · Eye Care',
    isOpen: true,
    operatingHours: {
      'weekdays': '9:00 AM – 5:00 PM',
      'saturday': '9:00 AM – 12:00 PM',
      'sunday': 'Closed',
    },
  ),
  const Hospital(
    id: 'kgumsb',
    name: 'Khesar Gyalpo University Medical Sciences',
    shortName: 'KGUMSB',
    location: 'Taba, Thimphu',
    currentQueue: 6,
    estimatedWaitMinutes: 12,
    speciality: 'Teaching Hospital · General OPD',
    isOpen: false,
    operatingHours: {
      'weekdays': '9:00 AM – 4:00 PM',
      'saturday': 'Closed',
      'sunday': 'Closed',
    },
  ),
];
