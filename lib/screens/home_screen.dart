// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'create_case_screen.dart';
import 'create_facility_screen.dart';
import 'login_screen.dart';
import 'my_cases_screen.dart';
import 'all_cases_screen.dart';
import '../widgets/admin_cases_detail_bottom_view.dart';
import 'create_case_type_screen.dart';
import 'facility_list_screen.dart';
import 'archived_facility_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> caseList = [];
  bool isLoading = true;

  String selectedFilter = 'All';
  List<String> filterOptions = ['All'];
  Set<String> regions = {}, districts = {}, communities = {};

  @override
  void initState() {
    super.initState();
    fetchCases();
  }

  Future<void> fetchCases() async {
    final token = Provider.of<AuthProvider>(context, listen: false).user!.token;

    final response = await http.get(
      Uri.parse('http://172.20.10.3:5000/api/cases'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      caseList = jsonDecode(response.body);
      _populateFilters();
      setState(() => isLoading = false);
    } else {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to load cases')));
    }
  }

  void _populateFilters() {
    regions = caseList.map((e) => e['healthFacility']['location']['region'] as String).toSet();
    districts = caseList.map((e) => e['healthFacility']['location']['district'] as String).toSet();
    communities = caseList.map((e) => e['healthFacility']['location']['community'] as String).toSet();

    filterOptions = [
      'All',
      'Suspected',
      'Confirmed',
      'Not a Case',
      'Ongoing Treatment',
      'Recovered',
      'Deceased',
      'Male',
      'Female',
      'Other',
      ...regions,
      ...districts,
      ...communities,
    ];
  }

  List<dynamic> getFilteredCases() {
    if (selectedFilter == 'All') return caseList;

    final filter = selectedFilter.toLowerCase();
    return caseList.where((c) {
      final loc = c['healthFacility']['location'];
      final cs = (c['status'] ?? '').toString().toLowerCase();
      final ps = (c['patient']['status'] ?? '').toString().toLowerCase();
      final g = (c['patient']['gender'] ?? '').toString().toLowerCase();
      final region = (loc['region'] ?? '').toString().toLowerCase();
      final district = (loc['district'] ?? '').toString().toLowerCase();
      final community = (loc['community'] ?? '').toString().toLowerCase();

      return cs == filter || ps == filter || g == filter || region == filter || district == filter || community == filter;
    }).toList();
  }

Widget caseSummaryCard(Map<String, dynamic> data) {
  final patient = data['patient'];
  final caseType = (data['caseType']['name'] ?? 'UNKNOWN').toString().toUpperCase();
  final status = data['status'];
  final timeline = data['timeline'] ?? '';
  final formattedTimeline = timeline.isNotEmpty
      ? DateFormat.yMMMd().format(DateTime.parse(timeline))
      : 'N/A';
  final location = data['healthFacility']['location'];
  final String displayLocation = location['community'] ?? 'N/A';

  Color statusColor = Colors.grey;
  if (status == 'suspected') statusColor = Colors.orange;
  if (status == 'confirmed') statusColor = Colors.red;
  if (status == 'not a case') statusColor = Colors.green;

  return GestureDetector(
    onTap: () {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        builder: (context) => CaseAdminViewBottomSheet(caseData: data),
      );
    },
    child: Container(
      margin: EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
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
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(caseType, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(status.toUpperCase(), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: statusColor)),
          ]),
          SizedBox(height: 4),
          Text.rich(TextSpan(
            text: 'Reported: ',
            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700]),
            children: [
              TextSpan(
                text: '$formattedTimeline · $displayLocation',
                style: TextStyle(fontWeight: FontWeight.normal, color: Colors.black87),
              )
            ],
          )),
          Text.rich(TextSpan(
            text: 'Patient: ',
            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700]),
            children: [
              TextSpan(
                text: '${patient['name']} · ${patient['gender']}, ${patient['age']}yrs',
                style: TextStyle(color: Colors.black87),
              )
            ],
          )),
        ],
      ),
    ),
  );
}

  bool authIsAdmin(BuildContext context) =>
      Provider.of<AuthProvider>(context, listen: false).user?.role == 'admin';

  @override
  Widget build(BuildContext context) {
    final filtered = getFilteredCases();
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.teal),
              child: Text('Health Case Tracker', style: TextStyle(color: Colors.white, fontSize: 20)),
            ),
            ListTile(
              leading: Icon(Icons.home),
              title: Text('Cases'),
              onTap: () => Navigator.pop(context),
            ),
            if (authIsAdmin(context))
             ExpansionTile(
                leading: Icon(Icons.business),
                title: Text('Facility'),
                children: [
                  ListTile(
                    leading: Icon(Icons.add_business),
                    title: Text('Add Facility'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => CreateFacilityScreen()));
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.list),
                    title: Text('Facility List'),
                    onTap: () async {
                      Navigator.pop(context); // close drawer first
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => FacilityListScreen()),
                      );
                      await fetchCases(); // refresh after returning
                    },
                  ),
                ],
              ),
              ListTile(
                leading: Icon(Icons.add_box),
                title: Text('Add Case Type'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => CreateCaseTypeScreen()));
                },
              ),
              ListTile(
                leading: Icon(Icons.archive_outlined),
                title: Text('Archived Facilities'),
                onTap: () async {
                  Navigator.pop(context);
                  final changed = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ArchivedFacilityScreen()),
                  );
                  if (changed == true) await fetchCases(); // refresh if unarchived
                },
              ),
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
                'Reported Cases (${filtered.length})',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              SizedBox(height: 16),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha((0.95 * 255).toInt()),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: DropdownButtonFormField<String>(
                          value: selectedFilter,
                          onChanged: (val) => setState(() => selectedFilter = val!),
                          items: filterOptions.map((label) {
                            return DropdownMenuItem(
                              value: label,
                              child: Text(label, overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          decoration: InputDecoration(
                            labelText: 'Filter by',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                        ),
                      ),
                      Expanded(
                        child: isLoading
                            ? Center(child: CircularProgressIndicator())
                            : filtered.isEmpty
                                ? Center(child: Text('No matching cases.'))
                                : ListView.builder(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    itemCount: filtered.length,
                                    itemBuilder: (ctx, i) => caseSummaryCard(filtered[i]),
                                  ),
                      ),
                    ],
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
