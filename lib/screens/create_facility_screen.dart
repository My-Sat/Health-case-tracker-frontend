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
  final newCommunityCtrl = TextEditingController();
  final newRegionCtrl = TextEditingController();
  final newDistrictCtrl = TextEditingController();
  final newSubDistrictCtrl = TextEditingController();

  String? selectedRegion;
  String? selectedDistrict;
  String? selectedSubDistrict;
  String? selectedCommunity;
  String typedRegion = '';
  String typedDistrict = '';


  List<String> regions = [];
  List<String> districts = [];
  List<String> subDistricts = [];
  List<String> communities = [];

  bool isSubmitting = false;
  bool isAddingRegion = false;
  bool isAddingDistrict = false;
  bool isAddingSubDistrict = false;
  bool isAddingCommunity = false;

@override
void initState() {
  super.initState();
  _loadRegions();

  newRegionCtrl.addListener(() {
    setState(() => typedRegion = newRegionCtrl.text.trim());
  });

  newDistrictCtrl.addListener(() {
    setState(() => typedDistrict = newDistrictCtrl.text.trim());
  });
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
    communities = [];
    selectedDistrict = null;
    selectedSubDistrict = null;
    selectedCommunity = null;

    try {
      districts = await ApiService.fetchDistricts(region);
      setState(() {});
    } catch (_) {}
  }

  Future<void> _loadSubDistricts(String region, String district) async {
    subDistricts = [];
    communities = [];
    selectedSubDistrict = null;
    selectedCommunity = null;

    try {
      subDistricts = await ApiService.fetchSubDistricts(region, district);
      setState(() {});
    } catch (_) {}
  }

Future<void> _loadCommunities({
  required String region,
  required String district,
  String? subDistrict,
}) async {
  communities = [];
  selectedCommunity = null;

  try {
    communities = await ApiService.fetchCommunities(
      region: region,
      district: district,
      subDistrict: subDistrict,
    );
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
  final community = isAddingCommunity
      ? newCommunityCtrl.text.trim()
      : selectedCommunity;

  if ([region, district, community].any((v) => v == null || v.isEmpty)) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Region, District, and Community are required')));
    setState(() => isSubmitting = false);
    return;
  }

  if (isAddingRegion &&
    region != null &&
    regions.any((r) => r.toLowerCase() == region.toLowerCase())) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Region "$region" already exists')));
    setState(() => isSubmitting = false);
    return;
  }

  if (isAddingDistrict &&
    district != null &&
    districts.any((d) => d.toLowerCase() == district.toLowerCase())) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('District "$district" already exists')));
    setState(() => isSubmitting = false);
    return;
  }

  if (isAddingCommunity &&
    community != null &&
    communities.any((c) => c.toLowerCase() == community.toLowerCase())) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Community "$community" already exists')));
    setState(() => isSubmitting = false);
    return;
  }

  final Map<String, dynamic> locationPayload = {
    'community': community,
    'region': region,
    'district': district,
  };

  if (subDistrict != null && subDistrict.isNotEmpty) {
    locationPayload['subDistrict'] = subDistrict;
  }

  final body = {
    'name': nameCtrl.text.trim(),
    'location': locationPayload,
  };
    final response = await http.post(
      Uri.parse('http://172.20.10.3:5000/api/facilities'),
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
                        communities = [];
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
                        communities = [];
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
                            if (!isAddingCommunity) {
                              _loadCommunities(
                                region: selectedRegion!,
                                district: val,
                                subDistrict: selectedSubDistrict,
                              );
                            }
                          },
                        ),
                  SizedBox(height: 16),

                  // Sub-District
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
                            if (!isAddingCommunity) {
                              _loadCommunities(
                                region: selectedRegion!,
                                district: selectedDistrict!,
                                subDistrict: val,
                              );
                            }
                          }
                        ),
                  SizedBox(height: 16),

                  // Community
                  if (
                    (!isAddingRegion && selectedRegion != null || isAddingRegion && typedRegion.isNotEmpty) &&
                    (!isAddingDistrict && selectedDistrict != null || isAddingDistrict && typedDistrict.isNotEmpty)
                  )
                    ...[
                      buildToggleRow(
                        label: 'Community',
                        isAdding: isAddingCommunity,
                        onToggle: () {
                          setState(() {
                            isAddingCommunity = !isAddingCommunity;
                            selectedCommunity = null;
                            newCommunityCtrl.clear();
                            if (!isAddingCommunity) {
                              _loadCommunities(
                                region: selectedRegion!,
                                district: selectedDistrict!,
                                subDistrict: selectedSubDistrict,
                              );
                            }
                          });
                        },
                      ),
                      isAddingCommunity
                          ? buildInput('New Community', Icons.place, newCommunityCtrl)
                          : buildDropdownField(
                              label: 'Select Community',
                              value: selectedCommunity,
                              options: communities,
                              onChanged: (val) {
                                selectedCommunity = val;
                              },
                            ),
                      SizedBox(height: 16),
                    ],

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
