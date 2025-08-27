import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/health_facility.dart';

class ApiService {
  static const String baseUrl = 'https://health-case-tracker-backend-o82a.onrender.com/api';

  static Future<List<String>> fetchRegions() async {
    final uri = Uri.parse('$baseUrl/facilities/regions');
    final res = await http.get(uri);
    if (res.statusCode == 200) {
      return List<String>.from(jsonDecode(res.body));
    }
    throw Exception('Failed to load regions');
  }

  static Future<List<String>> fetchDistricts(String regionName) async {
    final uri = Uri.parse('$baseUrl/facilities/districts')
        .replace(queryParameters: {'region': regionName});
    final res = await http.get(uri);
    if (res.statusCode == 200) {
      return List<String>.from(jsonDecode(res.body));
    }
    throw Exception('Failed to load districts');
  }

  static Future<List<String>> fetchSubDistricts(String region, String district) async {
    final uri = Uri.parse('$baseUrl/facilities/subDistricts')
        .replace(queryParameters: {'region': region, 'district': district});
    final res = await http.get(uri);
    if (res.statusCode == 200) {
      return List<String>.from(jsonDecode(res.body));
    }
    throw Exception('Failed to load sub-districts');
  }

  static Future<List<HealthFacility>> fetchFacilitiesUnder({
    required String region,
    String? district,
    String? subDistrict,
  }) async {
    final qp = <String, String>{'region': region};
    if (district != null) qp['district'] = district;
    if (subDistrict != null) qp['subDistrict'] = subDistrict;

    final uri = Uri.parse('$baseUrl/facilities/under').replace(queryParameters: qp);
    final res = await http.get(uri);
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as List;
      return data.map((j) => HealthFacility.fromJson(j)).toList();
    }
    throw Exception('Failed to load facilities');
  }

  static Future<List<String>> fetchCommunities({
    required String region,
    required String district,
    String? subDistrict,
  }) async {
    final qp = <String, String>{
      'region': region,
      'district': district,
      if (subDistrict != null) 'subDistrict': subDistrict,
    };
    final uri = Uri.parse('$baseUrl/facilities/communities').replace(queryParameters: qp);
    final res = await http.get(uri);
    if (res.statusCode == 200) {
      return List<String>.from(jsonDecode(res.body));
    }
    throw Exception('Failed to load communities');
  }

  // NEW: get fully-populated facility by id (names, not ids)
  static Future<HealthFacility> fetchFacilityById({
    required String id,
    required String token,
  }) async {
    final uri = Uri.parse('$baseUrl/facilities/by-id/$id');
    final res = await http.get(uri, headers: {'Authorization': 'Bearer $token'});
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return HealthFacility.fromJson(data);
    }
    throw Exception('Failed to load facility');
  }
}
