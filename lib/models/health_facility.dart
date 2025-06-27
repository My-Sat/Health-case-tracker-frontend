class HealthFacility {
  final String id;
  final String name;

  HealthFacility({required this.id, required this.name});

  factory HealthFacility.fromJson(Map<String, dynamic> json) {
    return HealthFacility(
      id: json['_id'],
      name: json['name'],
    );
  }
}
