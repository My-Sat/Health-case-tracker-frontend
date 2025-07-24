import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/health_facility.dart';

class ApiService {
  static const String baseUrl = 'http://172.20.10.3:5000/api';

  static Future<List<String>> fetchRegions() async {
    final res = await http.get(Uri.parse('$baseUrl/facilities/regions'));
    if (res.statusCode == 200) return List<String>.from(jsonDecode(res.body));
    throw Exception('Failed to load regions');
  }

  static Future<List<String>> fetchDistricts(String region) async {
    final res = await http.get(Uri.parse('$baseUrl/facilities/districts?region=$region'));
    if (res.statusCode == 200) return List<String>.from(jsonDecode(res.body));
    throw Exception('Failed to load districts');
  }

  static Future<List<String>> fetchSubDistricts(String region, String district) async {
    final res = await http.get(Uri.parse('$baseUrl/facilities/subDistricts?region=$region&district=$district'));
    if (res.statusCode == 200) return List<String>.from(jsonDecode(res.body));
    throw Exception('Failed to load sub-districts');
  }

  static Future<List<HealthFacility>> fetchFacilitiesUnder({
    required String region,
    String? district,
    String? subDistrict,
  }) async {
    final params = [
      'region=$region',
      if (district != null) 'district=$district',
      if (subDistrict != null) 'subDistrict=$subDistrict'
    ].join('&');
    final res = await http.get(Uri.parse('$baseUrl/facilities/under?$params'));
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
  final params = [
    'region=$region',
    'district=$district',
    if (subDistrict != null) 'subDistrict=$subDistrict'
  ].join('&');

  final res = await http.get(Uri.parse('$baseUrl/facilities/communities?$params'));
  if (res.statusCode == 200) {
    return List<String>.from(jsonDecode(res.body));
  }
  throw Exception('Failed to load communities');
}


}


