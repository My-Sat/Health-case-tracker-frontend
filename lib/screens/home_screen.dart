// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'create_case_screen.dart';
import 'create_facility_screen.dart';
import 'login_screen.dart';
import 'my_cases_screen.dart';
import 'all_cases_screen.dart';
import 'package:intl/intl.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> caseList = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchCases();
  }

  Future<void> fetchCases() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.user!.token;

    final response = await http.get(
      Uri.parse('https://health-case-tracker-backend.onrender.com/api/cases'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      setState(() {
        caseList = jsonDecode(response.body);
        isLoading = false;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load cases')));
    }
  }

Widget caseCard(Map<String, dynamic> data, {bool isAdmin = false}) {
  final patient = data['patient'];
  final status = data['status'];
  final patientStatus = patient['status'];
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

    Widget caseTypeBox(String value) {
  return Container(
    margin: EdgeInsets.only(bottom: 8),
    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
      'CASE TYPE: ${value.toUpperCase()}',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    ),
  );
}


  return Card(
    margin: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(35)),
    elevation: 4,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          caseTypeBox(data['caseType']),
          infoBox('Case Status', status),
          infoBox('Reported On', formattedTimeline),
          infoBox('Facility', data['healthFacility']['name']),
          infoBox('Region', location['region']),
          infoBox('District', location['district']),
          infoBox('Community', location['community']),
          infoBox('Reported By', data['officer']['fullName']),
          infoBox('Patient Name', patient['name']),
          infoBox('Patient Age', '${patient['age']} yrs'),
          infoBox('Patient Gender', patient['gender']),
          infoBox('Patient Phone', patient['phone']),
          infoBox('Patient Status', patientStatus),
        ],
      ),
    ),
  );
}

  bool authIsAdmin(BuildContext context) =>
      Provider.of<AuthProvider>(context, listen: false).user?.role == 'admin';

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.teal),
              child: Text(
                'Health Case Tracker',
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),
            ),
            ListTile(
              leading: Icon(Icons.home),
              title: Text('Cases'),
              onTap: () => Navigator.pop(context),
            ),
            if (authIsAdmin(context)) ...[
              ListTile(
                leading: Icon(Icons.add_business),
                title: Text('Add Facility'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => CreateFacilityScreen()));
                },
              ),
            ],
            if (!authIsAdmin(context)) ...[
              ListTile(
                leading: Icon(Icons.add),
                title: Text('Report Case'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => CreateCaseScreen()));
                },
              ),
              ListTile(
                leading: Icon(Icons.assignment),
                title: Text('My Cases'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => MyCasesScreen()));
                },
                ),

              ListTile(
                leading: Icon(Icons.list),
                title: Text('All Cases'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => AllCasesScreen()));
                },
              ),
            ],
            Divider(),
            ListTile(
              leading: Icon(Icons.logout),
              title: Text('Logout'),
              onTap: () async {
                await auth.logout();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => LoginScreen()),
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),
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
          'Reported Cases',
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
                : ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: caseList.length,
                    itemBuilder: (context, index) =>
                        caseCard(caseList[index], isAdmin: true),
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
