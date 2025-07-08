// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'create_case_screen.dart';
import 'all_cases_screen.dart';
import 'login_screen.dart';
import 'package:intl/intl.dart';
import '../widgets/my_cases_detail_bottom_view.dart';

class MyCasesScreen extends StatefulWidget {
  const MyCasesScreen({super.key});

  @override
  _MyCasesScreenState createState() => _MyCasesScreenState();
}

class _MyCasesScreenState extends State<MyCasesScreen> {
  List<dynamic> myCases = [];
  bool isLoading = true;
  String? recentlyUpdatedCaseId;
  String selectedFilter = 'All';

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load cases')),
      );
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
      setState(() => recentlyUpdatedCaseId = caseId);
      fetchMyCases();
      Future.delayed(const Duration(seconds: 6), () {
        setState(() => recentlyUpdatedCaseId = null);
      });

      final message = status != null
          ? 'Case successfully marked as ${status.toUpperCase()}'
          : 'Patient status updated to $patientStatus';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to update status'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  List<Map<String, dynamic>> getFilteredCases() {
    return myCases.where((c) {
      final caseStatus = c['status']?.toString().toLowerCase();
      final patientStatus = c['patient']['status']?.toString().toLowerCase();

      switch (selectedFilter.toLowerCase()) {
        case 'suspected':
        case 'confirmed':
        case 'not a case':
          return caseStatus == selectedFilter.toLowerCase();
        case 'recovered':
        case 'ongoing treatment':
        case 'deceased':
          return patientStatus == selectedFilter.toLowerCase();
        default:
          return true;
      }
    }).cast<Map<String, dynamic>>().toList();
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
    final displayLocation = location['community'] ?? 'N/A';
    final isRecently = data['_id'] == recentlyUpdatedCaseId;

    Color statusColor = Colors.grey;
    switch (caseStatus.toLowerCase()) {
      case 'suspected':
        statusColor = Colors.orange;
        break;
      case 'confirmed':
        statusColor = Colors.red;
        break;
      case 'not a case':
        statusColor = Colors.green;
        break;
    }

    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        builder: (_) => CaseDetailBottomSheet(
          caseData: data,
          onUpdate: updateStatus,
        ),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isRecently ? Colors.yellow.shade100 : Colors.white,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 3,
              offset: const Offset(2, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(caseType, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(caseStatus.toUpperCase(),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    )),
              ],
            ),
            const SizedBox(height: 4),
            Text.rich(TextSpan(
              text: 'Reported: ',
              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700]),
              children: [
                TextSpan(text: '$formattedTimeline · $displayLocation', style: const TextStyle(fontWeight: FontWeight.normal)),
              ],
            )),
            Text.rich(TextSpan(
              text: 'Person: ',
              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700]),
              children: [
                TextSpan(text: '${patient['name']} · ${patient['gender']}, ${patient['age']}yrs'),
              ],
            )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredCases = getFilteredCases();

    return Scaffold(
      appBar: AppBar(),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.teal),
              child: const Text('Health Case Tracker', style: TextStyle(color: Colors.white, fontSize: 20)),
            ),
            ListTile(leading: const Icon(Icons.assignment), title: const Text('My Cases'), onTap: () => Navigator.pop(context)),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Report Case'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateCaseScreen()))
                    .then((_) => fetchMyCases());
              },
            ),
            ListTile(
              leading: const Icon(Icons.list),
              title: const Text('All Cases'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AllCasesScreen()));
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                final auth = Provider.of<AuthProvider>(context, listen: false);
                await auth.logout();
                Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => LoginScreen()), (route) => false);
              },
            ),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Colors.teal.shade800, Colors.teal.shade300], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 16),
              Text('My Reported Cases (${filteredCases.length})',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 16),
             Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha((0.95 * 255).toInt()),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          decoration: const BoxDecoration(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                          ),
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: DropdownButtonFormField<String>(
                            value: selectedFilter,
                            onChanged: (v) => setState(() => selectedFilter = v!),
                            items: [
                              'All',
                              'Suspected',
                              'Confirmed',
                              'Not a Case',
                              'Ongoing Treatment',
                              'Recovered',
                              'Deceased',
                            ].map((label) => DropdownMenuItem(value: label, child: Text(label))).toList(),
                            decoration: InputDecoration(
                              labelText: 'Filter',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                          ),
                        ),
                        Expanded(
                          child: isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : getFilteredCases().isEmpty
                                  ? const Center(child: Text('No cases match your filter.'))
                                  : ListView.builder(
                                      padding: const EdgeInsets.all(16),
                                      itemCount: getFilteredCases().length,
                                      itemBuilder: (ctx, i) => caseSummaryCard(getFilteredCases()[i]),
                                    ),
                        ),
                      ],
                    ),
                  ),
                )

            ],
          ),
        ),
      ),
    );
  }
}
