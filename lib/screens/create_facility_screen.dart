// lib/screens/create_facility_screen.dart
// ignore_for_file: use_build_context_synchronously, library_private_types_in_public_api

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class CreateFacilityScreen extends StatefulWidget {
  const CreateFacilityScreen({super.key});

  @override
  _CreateFacilityScreenState createState() => _CreateFacilityScreenState();
}

class _CreateFacilityScreenState extends State<CreateFacilityScreen> {
  final nameCtrl = TextEditingController();
  final communityCtrl = TextEditingController();
  final newRegionCtrl = TextEditingController();
  final newDistrictCtrl = TextEditingController();
  final newSubDistrictCtrl = TextEditingController();

  String? selectedRegion;
  String? selectedDistrict;
  String? selectedSubDistrict;

  List<String> regions = [];
  List<String> districts = [];
  List<String> subDistricts = [];

  bool isSubmitting = false;
  bool isAddingRegion = false;
  bool isAddingDistrict = false;
  bool isAddingSubDistrict = false;

  @override
  void initState() {
    super.initState();
    _loadRegions();
  }

  Future<void> _loadRegions() async {
    try {
      regions = await ApiService.fetchRegions();
      setState(() {});
    } catch (_) {}
  }

  Future<void> _loadDistricts(String region) async {
    districts = [];
    subDistricts = [];
    selectedDistrict = null;
    selectedSubDistrict = null;

    try {
      districts = await ApiService.fetchDistricts(region);
      setState(() {});
    } catch (_) {}
  }

  Future<void> _loadSubDistricts(String region, String district) async {
    subDistricts = [];
    selectedSubDistrict = null;

    try {
      subDistricts = await ApiService.fetchSubDistricts(region, district);
      setState(() {});
    } catch (_) {}
  }

  Future<void> createFacility() async {
    setState(() => isSubmitting = true);
    final token = Provider.of<AuthProvider>(context, listen: false).user!.token;

    final region = isAddingRegion ? newRegionCtrl.text.trim() : selectedRegion;
    final district = isAddingDistrict ? newDistrictCtrl.text.trim() : selectedDistrict;
    final subDistrict = isAddingSubDistrict
        ? newSubDistrictCtrl.text.trim()
        : selectedSubDistrict?.trim();

    if ([region, district].any((v) => v == null || v.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Region and District are required')));
      setState(() => isSubmitting = false);
      return;
    }

    final body = {
      'name': nameCtrl.text.trim(),
      'location': {
        'community': communityCtrl.text.trim(),
        'region': region,
        'district': district,
        if (subDistrict != null && subDistrict.isNotEmpty)
          'subDistrict': subDistrict,
      }
    };

    final response = await http.post(
      Uri.parse('https://health-case-tracker-backend.onrender.com/api/facilities'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    setState(() => isSubmitting = false);

    if (response.statusCode == 201) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Facility created')));
      Navigator.pop(context);
    } else {
      final msg = jsonDecode(response.body)['message'] ?? 'Creation failed';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Widget buildInput(String label, IconData icon, TextEditingController controller) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }

  Widget buildToggleRow({
    required String label,
    required bool isAdding,
    required VoidCallback onToggle,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        TextButton(
          onPressed: onToggle,
          child: Text(isAdding ? 'Select Existing' : 'Add New'),
        ),
      ],
    );
  }

  Widget buildDropdownField({
    required String label,
    required String? value,
    required List<String> options,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      items: options
          .map((v) => DropdownMenuItem(value: v, child: Text(v)))
          .toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.teal.shade800, Colors.teal.shade300],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(20),
            child: Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha((0.95 * 255).toInt()),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Create Health Facility',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade800,
                    ),
                  ),
                  SizedBox(height: 20),
                  buildInput('Facility Name', Icons.local_hospital, nameCtrl),
                  SizedBox(height: 16),
                  buildInput('Community', Icons.location_city, communityCtrl),
                  SizedBox(height: 16),

                  // Region
                  buildToggleRow(
                    label: 'Region',
                    isAdding: isAddingRegion,
                    onToggle: () {
                      setState(() {
                        isAddingRegion = !isAddingRegion;
                        selectedRegion = null;
                        newRegionCtrl.clear();
                        districts = [];
                        subDistricts = [];
                      });
                    },
                  ),
                  isAddingRegion
                      ? buildInput('New Region', Icons.map, newRegionCtrl)
                      : buildDropdownField(
                          label: 'Select Region',
                          value: selectedRegion,
                          options: regions,
                          onChanged: (val) {
                            selectedRegion = val;
                            _loadDistricts(val!);
                          },
                        ),
                  SizedBox(height: 16),

                  // District
                  buildToggleRow(
                    label: 'District',
                    isAdding: isAddingDistrict,
                    onToggle: () {
                      setState(() {
                        isAddingDistrict = !isAddingDistrict;
                        selectedDistrict = null;
                        newDistrictCtrl.clear();
                        subDistricts = [];
                      });
                    },
                  ),
                  isAddingDistrict
                      ? buildInput('New District', Icons.map_outlined, newDistrictCtrl)
                      : buildDropdownField(
                          label: 'Select District',
                          value: selectedDistrict,
                          options: districts,
                          onChanged: (val) {
                            selectedDistrict = val;
                            _loadSubDistricts(selectedRegion!, val!);
                          },
                        ),
                  SizedBox(height: 16),

                  // Sub-District (Optional)
                  buildToggleRow(
                    label: 'Sub-district (Optional)',
                    isAdding: isAddingSubDistrict,
                    onToggle: () {
                      setState(() {
                        isAddingSubDistrict = !isAddingSubDistrict;
                        selectedSubDistrict = null;
                        newSubDistrictCtrl.clear();
                      });
                    },
                  ),
                  isAddingSubDistrict
                      ? buildInput('New Sub-district', Icons.location_on, newSubDistrictCtrl)
                      : buildDropdownField(
                          label: 'Select Sub-district',
                          value: selectedSubDistrict,
                          options: subDistricts,
                          onChanged: (val) {
                            selectedSubDistrict = val;
                          },
                        ),

                  SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: isSubmitting ? null : createFacility,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 50, vertical: 14),
                    ),
                    child: Text(isSubmitting ? 'Submitting...' : 'Create Facility'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
