// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/health_facility.dart';
import '../services/api_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final fullNameCtrl = TextEditingController();
  final usernameCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final contactCtrl = TextEditingController();
  List<HealthFacility> facilities = [];
  String? selectedFacilityId;
  bool isLoading = false;
  bool fetchError = false;

  @override
  void initState() {
    super.initState();
    _loadFacilities();
  }

  Future<void> _loadFacilities() async {
    setState(() => isLoading = true);
    try {
      final data = await ApiService.fetchFacilities();
      setState(() {
        facilities = data;
        isLoading = false;
        fetchError = false;
      });
    } catch (e) {
      print('Error fetching facilities: $e');
      setState(() {
        fetchError = true;
        isLoading = false;
      });
    }
  }

  Future<void> registerUser() async {
    if (selectedFacilityId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Select a health facility')));
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
          'password': passwordCtrl.text,
          'contactInfo': contactCtrl.text,
          'healthFacility': selectedFacilityId,
        }),
      );

      setState(() => isLoading = false);

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Registered successfully')));
        Navigator.pop(context);
      } else {
        final msg = jsonDecode(response.body)['message'] ?? 'Registration failed';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      setState(() => isLoading = false);
      print('Registration error: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error occurred')));
    }
  }

  Widget buildInput(String label, IconData icon, TextEditingController controller, {bool obscure = false}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              child: isLoading && facilities.isEmpty
                  ? Center(child: CircularProgressIndicator())
                  : fetchError
                      ? Column(
                          children: [
                            Text('Failed to load facilities'),
                            TextButton(onPressed: _loadFacilities, child: Text('Retry')),
                          ],
                        )
                      : Column(
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
                            buildInput('Password', Icons.lock, passwordCtrl, obscure: true),
                            SizedBox(height: 16),
                            buildInput('Contact Info', Icons.phone, contactCtrl),
                            SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              value: selectedFacilityId,
                              items: facilities
                                  .map((f) => DropdownMenuItem(value: f.id, child: Text(f.name)))
                                  .toList(),
                              onChanged: (val) => setState(() => selectedFacilityId = val),
                              decoration: InputDecoration(
                                labelText: 'Select Health Facility',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                            ),
                            SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: registerUser,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(horizontal: 50, vertical: 14),
                              ),
                              child: Text('Register'),
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
