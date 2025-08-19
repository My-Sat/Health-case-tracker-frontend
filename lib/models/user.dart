// lib/models/user.dart

import 'package:flutter/foundation.dart';
import 'health_facility.dart'; // adjust path if your file is elsewhere

class User {
  final String id;
  final String fullName;
  final String username;
  final String token;
  final String role;
  final String? facilityName; // legacy/simple name (keeps compatibility)
  final HealthFacility? healthFacility; // full facility object (may be null)

  User({
    required this.id,
    required this.fullName,
    required this.username,
    required this.token,
    required this.role,
    this.facilityName,
    this.healthFacility,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      token: json['token']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      facilityName: json['healthFacility'] != null
          ? (json['healthFacility']['name']?.toString())
          : null,
      healthFacility: json['healthFacility'] != null
          ? HealthFacility.fromJson(Map<String, dynamic>.from(json['healthFacility'] as Map))
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'fullName': fullName,
      'username': username,
      'token': token,
      'role': role,
      if (facilityName != null) 'facilityName': facilityName,
      if (healthFacility != null) 'healthFacility': {
        '_id': healthFacility!.id,
        'name': healthFacility!.name,
        // NOTE: HealthFacility has a Location object — serialize manually if needed.
      },
    };
  }
}
