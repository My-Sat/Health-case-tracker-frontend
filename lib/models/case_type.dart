class CaseType {
  final String id;
  final String name;

  CaseType({required this.id, required this.name});

  factory CaseType.fromJson(Map<String, dynamic> json) {
    return CaseType(
      id: json['_id'],
      name: json['name'],
    );
  }
}
