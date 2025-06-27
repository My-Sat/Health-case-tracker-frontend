// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'package:intl/intl.dart'; // This import is required for DateFormat

class AllCasesScreen extends StatefulWidget {
  const AllCasesScreen({super.key});

  @override
  _AllCasesScreenState createState() => _AllCasesScreenState();
}

class _AllCasesScreenState extends State<AllCasesScreen> {
  List<dynamic> allCases = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchAllCases();
  }

  Future<void> fetchAllCases() async {
    final token = Provider.of<AuthProvider>(context, listen: false).user!.token;

    final response = await http.get(
      Uri.parse('http://172.20.10.3:5000/api/cases'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      setState(() {
        allCases = jsonDecode(response.body);
        isLoading = false;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load cases')));
    }
  }

  Widget caseCard(Map<String, dynamic> data) {
    final patient = data['patient'];
    final status = data['status'];
    final location = data['healthFacility']['location'];
    final String timeline = data['timeline'] ?? '';
    final String formattedTimeline = timeline.isNotEmpty
    ? DateFormat.yMMMMd().add_jm().format(DateTime.parse(timeline))
    : 'N/A';


    Widget infoBox(String label, String value) {
      return Container(
        margin: EdgeInsets.symmetric(vertical: 4),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade300,
              offset: Offset(2, 2),
              blurRadius: 4,
            ),
          ],
        ),
        child: Text(
          '$label: $value',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      );
    }

    return Card(
      margin: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            infoBox('Case Type', data['caseType']),
            infoBox('Case Status', status),
            infoBox('Reported On', formattedTimeline),
            infoBox('Facility', data['healthFacility']['name']),
            infoBox('Region', location['region']),
            infoBox('District', location['district']),
            infoBox('Community', location['community']),
            infoBox('Reported By', data['officer']['fullName']),
            infoBox('Patient Age', '${patient['age']} yrs'),
            infoBox('Patient Gender', patient['gender']),
            infoBox('Patient Status', patient['status']),

          ],
        ),
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
  child: SafeArea(
    child: Column(
      children: [
        SizedBox(height: 16),
        Text(
          'All Reported Cases',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 16),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withAlpha((0.95 * 255).toInt()),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: isLoading
                ? Center(child: CircularProgressIndicator())
                : allCases.isEmpty
                    ? Center(child: Text('No cases reported yet.'))
                    : ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: allCases.length,
                        itemBuilder: (context, index) => caseCard(allCases[index]),
                      ),
          ),
        ),
      ],
    ),
  ),
),

    );
  }
}
