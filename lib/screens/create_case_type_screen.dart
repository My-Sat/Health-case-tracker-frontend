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
      Uri.parse('https://health-case-tracker-backend.onrender.com/api/casetypes'),
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
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
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
              ),
              child: Text(isSubmitting ? 'Submitting...' : 'Submit'),
            ),
          ],
        ),
      ),
    );
  }
}
