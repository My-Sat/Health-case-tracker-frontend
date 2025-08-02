// ignore_for_file: use_build_context_synchronously, library_private_types_in_public_api

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class EditCaseScreen extends StatefulWidget {
  final Map<String, dynamic> caseData;
  const EditCaseScreen({super.key, required this.caseData});

  @override
  _EditCaseScreenState createState() => _EditCaseScreenState();
}

class _EditCaseScreenState extends State<EditCaseScreen> {
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
  String caseStatus = 'suspected';


  @override
  void initState() {
    super.initState();
    loadCaseTypes();
    prefillFields();
  }

void prefillFields() {
  final Map<String, dynamic> c = widget.caseData; // ✅ explicitly type 'c'
  final patient = c['patient'];
  nameCtrl.text = patient['name'] ?? '';
  ageCtrl.text = (patient['age'] ?? '').toString();
  phoneCtrl.text = patient['phone'] ?? '';
  gender = patient['gender'] ?? gender;
  patientStatus = patient['status'] ?? patientStatus;
  caseStatus = c['status'] ?? caseStatus; // ✅ now works correctly

  final communityField = c['community'];
  final location = c['healthFacility']['location'];
  if (communityField != null && communityField.trim().isNotEmpty && communityField != location['community']) {
    useFacilityCommunity = false;
    communityCtrl.text = communityField;
  }
}

  Future<void> loadCaseTypes() async {
    final token = Provider.of<AuthProvider>(context, listen: false).user!.token;
    final res = await http.get(
      Uri.parse('${ApiService.baseUrl}/casetypes'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body);
      setState(() {
        caseTypes = list;
        selectedCaseType = list.firstWhere((ct) => ct['_id'] == widget.caseData['caseType']['_id'], orElse: () => list[0]);
      });
    }
  }

  Future<void> submitUpdate() async {
    setState(() => isSubmitting = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.user!.token;

    final body = {
      'caseType': selectedCaseType['_id'],
      'status': caseStatus, // ✅ include general case status
      'community': useFacilityCommunity ? null : communityCtrl.text.trim(),
      'patient': {
        'name': nameCtrl.text,
        'age': int.tryParse(ageCtrl.text) ?? 0,
        'gender': gender,
        'phone': phoneCtrl.text,
        'status': patientStatus, // ✅ include patient status
      }
    };

    final response = await http.put(
      Uri.parse('${ApiService.baseUrl}/cases/${widget.caseData['_id']}/edit'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    setState(() => isSubmitting = false);

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Case updated successfully')),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update case')),
      );
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
      appBar: AppBar(title: Text('Edit Case')),
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
                    'Edit Case',
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
                    value: caseStatus,
                    items: ['suspected', 'confirmed', 'not a case']
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (val) => setState(() => caseStatus = val!),
                    decoration: InputDecoration(
                      labelText: 'Case Status',
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
                    onPressed: isSubmitting ? null : submitUpdate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 50, vertical: 14),
                    ),
                    child: Text(isSubmitting ? 'Updating...' : 'Update Case'),
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
