// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/health_facility.dart';
import '../services/api_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final fullNameCtrl = TextEditingController();
  final usernameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final confirmPasswordCtrl = TextEditingController();
  final contactCtrl = TextEditingController();

  String? selectedRegion;
  String? selectedDistrict;
  String? selectedSubDistrict;
  String? selectedFacilityId;

  List<String> regions = [];
  List<String> districts = [];
  List<String> subDistricts = [];
  List<HealthFacility> facilities = [];

  bool isLoading = false;
  bool fetchError = false;
  bool passwordVisible = false;
  bool confirmPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _loadRegions();
  }

  Future<void> _loadRegions() async {
    setState(() => isLoading = true);
    try {
      regions = await ApiService.fetchRegions();
      setState(() {
        fetchError = false;
        isLoading = false;
      });
    } catch (_) {
      setState(() {
        fetchError = true;
        isLoading = false;
      });
    }
  }

  Future<void> _loadDistricts(String region) async {
    setState(() {
      selectedDistrict = null;
      selectedSubDistrict = null;
      selectedFacilityId = null;
      districts = [];
      subDistricts = [];
      facilities = [];
      isLoading = true;
    });

    try {
      districts = await ApiService.fetchDistricts(region);
      facilities = await ApiService.fetchFacilitiesUnder(region: region);
      setState(() => isLoading = false);
    } catch (_) {
      setState(() {
        fetchError = true;
        isLoading = false;
      });
    }
  }

  Future<void> _loadSubDistricts(String district) async {
    setState(() {
      selectedSubDistrict = null;
      selectedFacilityId = null;
      subDistricts = [];
      facilities = [];
      isLoading = true;
    });

    try {
      subDistricts = await ApiService.fetchSubDistricts(selectedRegion!, district);
      if (subDistricts.isEmpty) {
        facilities = await ApiService.fetchFacilitiesUnder(
          region: selectedRegion!,
          district: district,
        );
      }
      setState(() => isLoading = false);
    } catch (_) {
      setState(() {
        fetchError = true;
        isLoading = false;
      });
    }
  }

  Future<void> _loadFacilitiesUnderSubDistrict(String subDistrict) async {
    setState(() {
      selectedFacilityId = null;
      facilities = [];
      isLoading = true;
    });

    try {
      facilities = await ApiService.fetchFacilitiesUnder(
        region: selectedRegion!,
        district: selectedDistrict!,
        subDistrict: subDistrict,
      );
      setState(() => isLoading = false);
    } catch (_) {
      setState(() {
        fetchError = true;
        isLoading = false;
      });
    }
  }

  Future<void> registerUser() async {
    if (selectedFacilityId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a health facility')),
      );
      return;
    }

    if (passwordCtrl.text != confirmPasswordCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    setState(() => isLoading = true);
    final url = Uri.parse('https://health-case-tracker-backend.onrender.com/api/users/register');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fullName': fullNameCtrl.text,
          'username': usernameCtrl.text,
          'email': emailCtrl.text,
          'password': passwordCtrl.text,
          'contactInfo': contactCtrl.text,
          'healthFacility': selectedFacilityId,
        }),
      );

      setState(() => isLoading = false);

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registered successfully')),
        );
        Navigator.pop(context);
      } else {
        final msg = jsonDecode(response.body)['message'] ?? 'Registration failed';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (_) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred')),
      );
    }
  }

  Widget buildInput(String label, IconData icon, TextEditingController controller,
      {bool obscure = false, VoidCallback? toggle, bool showToggle = false}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: showToggle
            ? IconButton(
                icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                onPressed: toggle,
              )
            : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }

  Widget buildDropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items
          .map((item) => DropdownMenuItem<T>(value: item, child: Text(item.toString())))
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
                    'Register Officer',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade800,
                    ),
                  ),
                  SizedBox(height: 20),
                  buildInput('Full Name', Icons.person, fullNameCtrl),
                  SizedBox(height: 16),
                  buildInput('Username', Icons.account_circle, usernameCtrl),
                  SizedBox(height: 16),
                  buildInput('Email', Icons.email, emailCtrl),
                  SizedBox(height: 16),
                  buildInput(
                    'Password',
                    Icons.lock,
                    passwordCtrl,
                    obscure: !passwordVisible,
                    showToggle: true,
                    toggle: () => setState(() => passwordVisible = !passwordVisible),
                  ),
                  SizedBox(height: 16),
                  buildInput(
                    'Confirm Password',
                    Icons.lock_outline,
                    confirmPasswordCtrl,
                    obscure: !confirmPasswordVisible,
                    showToggle: true,
                    toggle: () => setState(() => confirmPasswordVisible = !confirmPasswordVisible),
                  ),
                  SizedBox(height: 16),
                  buildInput('Contact Info', Icons.phone, contactCtrl),
                  SizedBox(height: 16),
                  if (fetchError)
                    Text('Failed to load data. Please retry.', style: TextStyle(color: Colors.red)),
                  buildDropdown(
                    label: 'Select Region',
                    value: selectedRegion,
                    items: regions,
                    onChanged: (val) {
                      selectedRegion = val;
                      _loadDistricts(val!);
                    },
                  ),
                  SizedBox(height: 16),
                  if (districts.isNotEmpty)
                    buildDropdown(
                      label: 'Select District',
                      value: selectedDistrict,
                      items: districts,
                      onChanged: (val) {
                        selectedDistrict = val;
                        _loadSubDistricts(val!);
                      },
                    ),
                  SizedBox(height: 16),
                  if (subDistricts.isNotEmpty)
                    buildDropdown(
                      label: 'Select Sub-District',
                      value: selectedSubDistrict,
                      items: subDistricts,
                      onChanged: (val) {
                        selectedSubDistrict = val;
                        _loadFacilitiesUnderSubDistrict(val!);
                      },
                    ),
                  SizedBox(height: 16),
                  if (facilities.isNotEmpty)
                    DropdownButtonFormField<String>(
                      value: selectedFacilityId,
                      items: facilities
                          .map((f) => DropdownMenuItem(
                                value: f.id,
                                child: Text(f.name),
                              ))
                          .toList(),
                      onChanged: (val) => setState(() => selectedFacilityId = val),
                      decoration: InputDecoration(
                        labelText: 'Select Facility',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                    ),
                  SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: isLoading ? null : registerUser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 50, vertical: 14),
                    ),
                    child: Text(isLoading ? 'Submitting...' : 'Register'),
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
