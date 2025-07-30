class HealthFacility {
  final String id;
  final String name;
  final Map<String, dynamic>? location;

  HealthFacility({
    required this.id,
    required this.name,
    this.location,
  });

  factory HealthFacility.fromJson(Map<String, dynamic> json) {
    return HealthFacility(
      id: json['_id'],
      name: json['name'],
      location: json['location'], // include the location object
    );
  }
}
