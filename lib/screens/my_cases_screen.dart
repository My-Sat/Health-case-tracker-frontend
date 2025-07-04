// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'create_case_screen.dart';
import 'all_cases_screen.dart';
import 'login_screen.dart';
import 'package:intl/intl.dart'; // This import is required for DateFormat
import '../widgets/my_cases_detail_bottom_view.dart'; // Import your bottom sheet widget


class MyCasesScreen extends StatefulWidget {
  const MyCasesScreen({super.key});

  @override
  _MyCasesScreenState createState() => _MyCasesScreenState();
}

class _MyCasesScreenState extends State<MyCasesScreen> { 
  List<dynamic> myCases = [];
  bool isLoading = true;
  String? recentlyUpdatedCaseId;


  @override
  void initState() {
    super.initState();
    fetchMyCases();
  }

  Future<void> fetchMyCases() async {
    final token = Provider.of<AuthProvider>(context, listen: false).user!.token;

    final response = await http.get(
      Uri.parse('https://health-case-tracker-backend.onrender.com/api/cases/my-cases'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      setState(() {
        myCases = jsonDecode(response.body);
        isLoading = false;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load cases')));
    }
  }

Future<void> updateStatus(String caseId, [String? status, String? patientStatus]) async {
  final token = Provider.of<AuthProvider>(context, listen: false).user!.token;

  final response = await http.put(
    Uri.parse('https://health-case-tracker-backend.onrender.com/api/cases/$caseId/status'),
    headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      if (status != null) 'status': status,
      if (patientStatus != null) 'patientStatus': patientStatus,
    }),
  );

  if (response.statusCode == 200) {
    setState(() {
      recentlyUpdatedCaseId = caseId; // 🔥 Highlight this one
    });

    fetchMyCases(); // Refresh list with new data

    // Auto-clear highlight after 3 seconds
    Future.delayed(Duration(seconds: 6), () {
      setState(() {
        recentlyUpdatedCaseId = null;
      });
    });

    String message = '';
    if (status != null) {
      message = 'Case successfully marked as ${status.toUpperCase()}';
    } else if (patientStatus != null) {
      message = 'Patient status updated to $patientStatus';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Failed to update status'),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 3),
      ),
    );
  }
}

  Widget statusActionButtons(String id) {
    return Row(
      children: [
        TextButton(
          onPressed: () => updateStatus(id, 'confirmed'),
          child: Text('Confirm'),
        ),
        TextButton(
          onPressed: () => updateStatus(id, 'not a case'),
          child: Text('Not a Case'),
        ),
      ],
    );
  }

  Widget patientStatusButtons(String caseId) {
  return Row(
    children: [
      TextButton(
        onPressed: () => updateStatus(caseId, null, 'Recovered'),
        child: Text('Mark Recovered'),
      ),
      TextButton(
        onPressed: () => updateStatus(caseId, null, 'Deceased'),
        child: Text('Mark Deceased'),
      ),
    ],
  );
}


Widget caseSummaryCard(Map<String, dynamic> data) {
  final patient = data['patient'];
  final caseType = data['caseType'].toString().toUpperCase();
  final caseStatus = data['status'];
  final timeline = data['timeline'] ?? '';
  final formattedTimeline = timeline.isNotEmpty
      ? DateFormat.yMMMd().format(DateTime.parse(timeline))
      : 'N/A';
  final location = data['healthFacility']['location'];
  final String displayLocation = location['community'] ?? 'N/A';
  final isRecentlyUpdated = data['_id'] == recentlyUpdatedCaseId;

  Color statusColor = Colors.grey;
  if (caseStatus == 'suspected') statusColor = Colors.orange;
  if (caseStatus == 'confirmed') statusColor = Colors.red;
  if (caseStatus == 'not a case') statusColor = Colors.green;

  return GestureDetector(
    onTap: () {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        builder: (context) => CaseDetailBottomSheet(
          caseData: data,
          onUpdate: updateStatus,
        ),
      );
    },
    child: AnimatedContainer(
      duration: Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      margin: EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isRecentlyUpdated ? Colors.yellow.shade100 : Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 3,
            offset: Offset(2, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(caseType,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text(caseStatus.toUpperCase(),
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: statusColor)),
            ],
          ),
          SizedBox(height: 4),
          Text.rich(TextSpan(
              text: 'Reported: ',
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: Colors.grey[700]),
              children: [
                TextSpan(
                  text: '$formattedTimeline · $displayLocation',
                  style: TextStyle(
                      fontWeight: FontWeight.normal, color: Colors.black87),
                )
              ])),
          Text.rich(TextSpan(
              text: 'Person: ',
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: Colors.grey[700]),
              children: [
                TextSpan(
                  text:
                      '${patient['name']} · ${patient['gender']}, ${patient['age']}yrs',
                  style: TextStyle(color: Colors.black87),
                )
              ])),
        ],
      ),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
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
          leading: Icon(Icons.assignment),
          title: Text('My Cases'),
          onTap: () => Navigator.pop(context),
        ),
        ListTile(
          leading: Icon(Icons.add),
          title: Text('Report Case'),
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => CreateCaseScreen()),
            ).then((_) => fetchMyCases()); 
          },
        ),
          ListTile(
            leading: Icon(Icons.list),
            title: Text('All Cases'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AllCasesScreen()),
              ).then((_) => AllCasesScreen());
            },
          ),
        Divider(),
        ListTile(
          leading: Icon(Icons.logout),
          title: Text('Logout'),
          onTap: () async {
            final auth = Provider.of<AuthProvider>(context, listen: false);
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
          'My Reported Cases (${myCases.length})',
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
                : myCases.isEmpty
                    ? Center(child: Text('You have not reported any cases yet.'))
                    : ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: myCases.length,
                        itemBuilder: (context, index) => caseSummaryCard(myCases[index]),

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