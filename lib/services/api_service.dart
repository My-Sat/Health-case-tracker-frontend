import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/health_facility.dart';

class ApiService {
  static const String baseUrl = 'https://health-case-tracker-backend.onrender.com/api';

  static Future<List<HealthFacility>> fetchFacilities() async {
    final response = await http.get(Uri.parse('$baseUrl/facilities'));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List;
      return data.map((json) => HealthFacility.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load facilities');
    }
  }
}
