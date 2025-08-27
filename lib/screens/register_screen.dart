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
  // Controllers
  final fullNameCtrl = TextEditingController();
  final usernameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final confirmPasswordCtrl = TextEditingController();
  final contactCtrl = TextEditingController();

  // Form
  final _formKey = GlobalKey<FormState>();
  bool _autoValidate = false;

  // Location selections
  String? selectedRegion;
  String? selectedDistrict;
  String? selectedSubDistrict;
  String? selectedFacilityId;

  // Data lists
  List<String> regions = [];
  List<String> districts = [];
  List<String> subDistricts = [];
  List<HealthFacility> facilities = [];

  // UI state
  bool isLoading = false;
  bool fetchError = false;
  bool passwordVisible = false;
  bool confirmPasswordVisible = false;

  final _emailRegExp = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  @override
  void initState() {
    super.initState();
    _loadRegions();
  }

  @override
  void dispose() {
    fullNameCtrl.dispose();
    usernameCtrl.dispose();
    emailCtrl.dispose();
    passwordCtrl.dispose();
    confirmPasswordCtrl.dispose();
    contactCtrl.dispose();
    super.dispose();
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
    // Validate all fields before hitting the API
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      setState(() => _autoValidate = true);
      // Show a concise banner; per-field messages appear under the fields.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fix the errors highlighted above.')),
      );
      return;
    }

    // Extra guard in case facilities list is empty but we still need a facility
    if (selectedFacilityId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Health facility is required')),
      );
      return;
    }

    setState(() => isLoading = true);
    final url = Uri.parse('https://health-case-tracker-backend-o82a.onrender.com/api/users/register');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fullName': fullNameCtrl.text.trim(),
          'username': usernameCtrl.text.trim(),
          'email': emailCtrl.text.trim(),
          'password': passwordCtrl.text,
          'contactInfo': contactCtrl.text.trim(),
          'healthFacility': selectedFacilityId,
        }),
      );

      setState(() => isLoading = false);

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registered successfully')),
        );
        Navigator.pop(context);
      } else {
        final decoded = jsonDecode(response.body);
        final msg = (decoded is Map && decoded['message'] is String)
            ? decoded['message'] as String
            : 'Registration failed';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (_) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An error occurred')),
      );
    }
  }

  // ---------- Widgets with validators ----------

  Widget buildInput(
    String label,
    IconData icon,
    TextEditingController controller, {
    bool obscure = false,
    VoidCallback? toggle,
    bool showToggle = false,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      autovalidateMode:
          _autoValidate ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
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
    String? Function(T?)? validator,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items
          .map((item) => DropdownMenuItem<T>(value: item, child: Text(item.toString())))
          .toList(),
      onChanged: onChanged,
      validator: validator,
      autovalidateMode:
          _autoValidate ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }

  // ---------- Build ----------

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
            padding: const EdgeInsets.all(20),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha((0.95 * 255).toInt()),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                autovalidateMode:
                    _autoValidate ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
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
                    const SizedBox(height: 20),

                    // Full name
                    buildInput(
                      'Full Name',
                      Icons.person,
                      fullNameCtrl,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Full name is required';
                        if (v.trim().length < 2) return 'Full name is too short';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Username
                    buildInput(
                      'Username',
                      Icons.account_circle,
                      usernameCtrl,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Username is required';
                        if (!RegExp(r'^[a-zA-Z0-9._-]{3,}$').hasMatch(v.trim())) {
                          return 'Username must be 3+ chars (letters, digits, . _ -)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Email
                    buildInput(
                      'Email',
                      Icons.email,
                      emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        final value = v?.trim() ?? '';
                        if (value.isEmpty) return 'Email is required';
                        if (!_emailRegExp.hasMatch(value)) return 'Enter a valid email address';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Password
                    buildInput(
                      'Password',
                      Icons.lock,
                      passwordCtrl,
                      obscure: !passwordVisible,
                      showToggle: true,
                      toggle: () => setState(() => passwordVisible = !passwordVisible),
                      validator: (v) {
                        final value = v ?? '';
                        if (value.isEmpty) return 'Password is required';
                        if (value.length < 8) return 'Password must be at least 8 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Confirm Password
                    buildInput(
                      'Confirm Password',
                      Icons.lock_outline,
                      confirmPasswordCtrl,
                      obscure: !confirmPasswordVisible,
                      showToggle: true,
                      toggle: () => setState(() => confirmPasswordVisible = !confirmPasswordVisible),
                      validator: (v) {
                        final value = v ?? '';
                        if (value.isEmpty) return 'Please confirm your password';
                        if (value != passwordCtrl.text) return 'Passwords do not match';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Contact
                    buildInput(
                      'Contact Info',
                      Icons.phone,
                      contactCtrl,
                      keyboardType: TextInputType.phone,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Contact info is required';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    if (fetchError)
                      const Text(
                        'Failed to load data. Please retry.',
                        style: TextStyle(color: Colors.red),
                      ),

                    // Region
                    buildDropdown<String>(
                      label: 'Select Region',
                      value: selectedRegion,
                      items: regions,
                      onChanged: (val) {
                        setState(() => selectedRegion = val);
                        if (val != null) _loadDistricts(val);
                      },
                      validator: (val) {
                        if (regions.isNotEmpty && (val == null || val.isEmpty)) {
                          return 'Region is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // District
                    if (districts.isNotEmpty)
                      buildDropdown<String>(
                        label: 'Select District',
                        value: selectedDistrict,
                        items: districts,
                        onChanged: (val) {
                          setState(() => selectedDistrict = val);
                          if (val != null) _loadSubDistricts(val);
                        },
                        validator: (val) {
                          if (districts.isNotEmpty &&
                              (val == null || val.isEmpty)) {
                            return 'District is required';
                          }
                          return null;
                        },
                      ),
                    if (districts.isNotEmpty) const SizedBox(height: 16),

                    // Sub-District (only when present)
                    if (subDistricts.isNotEmpty)
                      buildDropdown<String>(
                        label: 'Select Sub-District',
                        value: selectedSubDistrict,
                        items: subDistricts,
                        onChanged: (val) {
                          setState(() => selectedSubDistrict = val);
                          if (val != null) _loadFacilitiesUnderSubDistrict(val);
                        },
                        validator: (val) {
                          if (subDistricts.isNotEmpty &&
                              (val == null || val.isEmpty)) {
                            return 'Sub-district is required';
                          }
                          return null;
                        },
                      ),
                    if (subDistricts.isNotEmpty) const SizedBox(height: 16),

                    // Facility
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
                        validator: (val) {
                          if (facilities.isNotEmpty && (val == null || val.isEmpty)) {
                            return 'Health facility is required';
                          }
                          return null;
                        },
                        autovalidateMode: _autoValidate
                            ? AutovalidateMode.onUserInteraction
                            : AutovalidateMode.disabled,
                        decoration: InputDecoration(
                          labelText: 'Select Facility',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                      ),
                    if (facilities.isNotEmpty) const SizedBox(height: 24),

                    // Submit
                    ElevatedButton(
                      onPressed: isLoading ? null : registerUser,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 14),
                      ),
                      child: Text(isLoading ? 'Submitting...' : 'Register'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
