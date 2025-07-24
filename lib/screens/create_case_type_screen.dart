// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../providers/auth_provider.dart';

class CreateCaseTypeScreen extends StatefulWidget {
  const CreateCaseTypeScreen({super.key});

  @override
  State<CreateCaseTypeScreen> createState() => _CreateCaseTypeScreenState();
}

class _CreateCaseTypeScreenState extends State<CreateCaseTypeScreen> {
  final caseTypeCtrl = TextEditingController();
  bool isSubmitting = false;

  Future<void> submitCaseType() async {
    final typeName = caseTypeCtrl.text.trim();
    if (typeName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please enter a case type name')));
      return;
    }

    setState(() => isSubmitting = true);
    final token = Provider.of<AuthProvider>(context, listen: false).user!.token;

    final res = await http.post(
      Uri.parse('http://172.20.10.3:5000/api/casetypes'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'name': typeName}),
    );

    setState(() => isSubmitting = false);

    if (res.statusCode == 201) {
      caseTypeCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Case type created')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create case type')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Add Case Type')),
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
            padding: EdgeInsets.all(24),
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
                  Icon(Icons.medical_services, size: 60, color: Colors.teal),
                  SizedBox(height: 16),
                  TextField(
                    controller: caseTypeCtrl,
                    decoration: InputDecoration(
                      labelText: 'Case Type Name',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      prefixIcon: Icon(Icons.local_hospital),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: isSubmitting ? null : submitCaseType,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                      textStyle: TextStyle(fontSize: 16),
                    ),
                    child: Text(isSubmitting ? 'Submitting...' : 'Submit'),
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
