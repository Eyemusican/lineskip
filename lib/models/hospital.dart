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

  factory Hospital.fromMap(Map<String, dynamic> data, String id) {
    return Hospital(
      id: id,
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

  factory Hospital.fromFirestore(DocumentSnapshot doc) {
    return Hospital.fromMap(doc.data() as Map<String, dynamic>, doc.id);
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
