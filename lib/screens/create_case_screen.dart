// ignore_for_file: use_build_context_synchronously, library_private_types_in_public_api

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../providers/auth_provider.dart';

class CreateCaseScreen extends StatefulWidget {
  const CreateCaseScreen({super.key});

  @override
  _CreateCaseScreenState createState() => _CreateCaseScreenState();
}

class _CreateCaseScreenState extends State<CreateCaseScreen> {
  final nameCtrl = TextEditingController();
  final ageCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final communityCtrl = TextEditingController();

  List<dynamic> caseTypes = [];
  dynamic selectedCaseType;

  String gender = 'male';
  String patientStatus = 'Ongoing treatment';
  bool isSubmitting = false;
  bool useFacilityCommunity = true;

  @override
  void initState() {
    super.initState();
    loadCaseTypes();
  }

  Future<void> loadCaseTypes() async {
    final token = Provider.of<AuthProvider>(context, listen: false).user!.token;

    final res = await http.get(
      Uri.parse('https://health-case-tracker-backend.onrender.com/api/casetypes'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (res.statusCode == 200) {
      final list = jsonDecode(res.body);
      setState(() {
        caseTypes = list;
        selectedCaseType = list.isNotEmpty ? list[0] : null;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load case types')));
    }
  }

  Future<void> submitCase() async {
    if (selectedCaseType == null) return;

    setState(() => isSubmitting = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.user!.token;

    final body = {
      'caseType': selectedCaseType['_id'],
      'community': useFacilityCommunity ? null : communityCtrl.text.trim(),
      'patient': {
        'name': nameCtrl.text,
        'age': int.tryParse(ageCtrl.text) ?? 0,
        'gender': gender,
        'phone': phoneCtrl.text,
        'status': patientStatus,
      }
    };

    final response = await http.post(
      Uri.parse('https://health-case-tracker-backend.onrender.com/api/cases'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    setState(() => isSubmitting = false);

    if (response.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Case reported')));
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to report case')));
    }
  }

  Widget buildInput(String label, IconData icon, TextEditingController controller,
      {TextInputType type = TextInputType.text}) {
    return TextField(
      controller: controller,
      keyboardType: type,
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
                    'Report New Case',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade800,
                    ),
                  ),
                  SizedBox(height: 20),
                  DropdownButtonFormField<dynamic>(
                    value: selectedCaseType,
                    items: caseTypes
                        .map((ct) => DropdownMenuItem(
                              value: ct,
                              child: Text(ct['name']),
                            ))
                        .toList(),
                    onChanged: (val) => setState(() => selectedCaseType = val),
                    decoration: InputDecoration(
                      labelText: 'Case Type',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                  ),
                  SizedBox(height: 16),
                  buildInput('Patient Name', Icons.person, nameCtrl),
                  SizedBox(height: 16),
                  buildInput('Patient Age', Icons.numbers, ageCtrl, type: TextInputType.number),
                  SizedBox(height: 16),
                  buildInput('Patient Phone', Icons.phone, phoneCtrl, type: TextInputType.phone),
                  SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: gender,
                    items: ['male', 'female', 'other']
                        .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                        .toList(),
                    onChanged: (val) => setState(() => gender = val!),
                    decoration: InputDecoration(
                      labelText: 'Gender',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                  ),
                  SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: patientStatus,
                    items: ['Ongoing treatment', 'Recovered', 'Deceased']
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (val) => setState(() => patientStatus = val!),
                    decoration: InputDecoration(
                      labelText: 'Patient Status',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                  ),
                  SizedBox(height: 16),
                  SwitchListTile(
                    value: useFacilityCommunity,
                    onChanged: (val) => setState(() => useFacilityCommunity = val),
                    title: Text("Use Facility Community"),
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (!useFacilityCommunity)
                    buildInput('Community', Icons.location_city, communityCtrl),
                  SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: isSubmitting ? null : submitCase,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 50, vertical: 14),
                    ),
                    child: Text(isSubmitting ? 'Submitting...' : 'Submit Case'),
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
