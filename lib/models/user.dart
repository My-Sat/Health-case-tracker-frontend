class User {
  final String id;
  final String fullName;
  final String username;
  final String token;
  final String role;
  final String? facilityName;

  User({
    required this.id,
    required this.fullName,
    required this.username,
    required this.token,
    required this.role,
    this.facilityName,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id'],
      fullName: json['fullName'],
      username: json['username'],
      token: json['token'],
      role: json['role'],
      facilityName: json['healthFacility'] != null
          ? json['healthFacility']['name']
          : null,
    );
  }
}
