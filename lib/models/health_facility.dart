class HealthFacility {
  final String id;
  final String name;
  final Location location;

  HealthFacility({
    required this.id,
    required this.name,
    required this.location,
  });

  factory HealthFacility.fromJson(Map<String, dynamic> json) {
    // Prefer nested `location` if present; otherwise read fields from root
    final locSource = (json['location'] is Map<String, dynamic>)
        ? Map<String, dynamic>.from(json['location'] as Map)
        : json;

    return HealthFacility(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      location: Location.fromJson(locSource),
    );
  }
}

class Location {
  final String region;
  final String district;
  final String? subDistrict;
  final String community;

  Location({
    required this.region,
    required this.district,
    this.subDistrict,
    required this.community,
  });

  factory Location.fromJson(Map<String, dynamic> json) {
    String nameOf(dynamic v) {
      if (v == null) return '';
      if (v is Map) return (v['name'] ?? '').toString();
      return v.toString();
    }

    return Location(
      region: nameOf(json['region']),
      district: nameOf(json['district']),
      subDistrict: json['subDistrict'] == null ? null : nameOf(json['subDistrict']),
      community: nameOf(json['community']),
    );
  }
}
