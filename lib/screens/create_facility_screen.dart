// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class CreateFacilityScreen extends StatefulWidget {
  const CreateFacilityScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _CreateFacilityScreenState createState() => _CreateFacilityScreenState();
}

class _CreateFacilityScreenState extends State<CreateFacilityScreen> {
  final nameCtrl = TextEditingController();
  final communityCtrl = TextEditingController();
  final districtCtrl = TextEditingController();
  final regionCtrl = TextEditingController();
  bool isSubmitting = false;

  Future<void> createFacility() async {
    setState(() => isSubmitting = true);

    final token = Provider.of<AuthProvider>(context, listen: false).user!.token;

    final response = await http.post(
      Uri.parse('https://health-case-tracker-backend.onrender.com/api/facilities'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'name': nameCtrl.text,
        'location': {
          'community': communityCtrl.text,
          'district': districtCtrl.text,
          'region': regionCtrl.text,
        }
      }),
    );

    setState(() => isSubmitting = false);

    if (response.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Facility created')));
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
                  buildInput('District', Icons.map, districtCtrl),
                  SizedBox(height: 16),
                  buildInput('Region', Icons.public, regionCtrl),
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
