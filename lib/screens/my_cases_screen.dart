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
import 'archived_cases_screen.dart';
import 'case_types_stats.dart';
import 'dashboard_screen.dart';

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
      Uri.parse('https://health-case-tracker-backend-o82a.onrender.com/api/cases/my-cases'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      setState(() {
        myCases = jsonDecode(response.body);
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load cases')),
      );
    }
  }

  Future<void> _navigateToCreateCase() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateCaseScreen()),
    );
    await fetchMyCases();
  }

  Future<void> updateStatus(String caseId, [String? status, String? patientStatus]) async {
    final token = Provider.of<AuthProvider>(context, listen: false).user!.token;

    if (status == 'deleted') {
      final response = await http.delete(
        Uri.parse('https://health-case-tracker-backend-o82a.onrender.com/api/cases/$caseId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        setState(() => recentlyUpdatedCaseId = caseId);
        fetchMyCases();
        Future.delayed(const Duration(seconds: 6), () {
          setState(() => recentlyUpdatedCaseId = null);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Case deleted successfully'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to delete case'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      return;
    }

    if (status == 'archived') {
      final response = await http.patch(
        Uri.parse('https://health-case-tracker-backend-o82a.onrender.com/api/cases/$caseId/archive'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() => recentlyUpdatedCaseId = caseId);
        fetchMyCases();
        Future.delayed(const Duration(seconds: 6), () {
          setState(() => recentlyUpdatedCaseId = null);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Case archived'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to archive case'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final response = await http.put(
      Uri.parse('https://health-case-tracker-backend-o82a.onrender.com/api/cases/$caseId/status'),
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
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to update status'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  List<Map<String, dynamic>> getFilteredCases() {
    return myCases.where((c) {
      final caseStatus = c['status']?.toString().toLowerCase();
      final patientStatus = c['patient']?['status']?.toString().toLowerCase();

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

  Widget _buildCenterAddButton() {
    // Stylish centered circular button for users with no cases
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _navigateToCreateCase,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00796B), Color(0xFF26A69A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.teal.shade700.withOpacity(0.4),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(Icons.add, size: 68, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Report your first case',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildRightAddButton() {
    // Small circular add button placed to the right below the filter bar
    return Padding(
      padding: const EdgeInsets.only(right: 16.0, top: 8.0),
      child: Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _navigateToCreateCase,
            borderRadius: BorderRadius.circular(28),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00796B), Color(0xFF26A69A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.teal.shade700.withOpacity(0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 26),
            ),
          ),
        ),
      ),
    );
  }

  Widget caseSummaryCard(Map<String, dynamic> data) {
    String nameOf(dynamic v) {
      if (v == null) return 'N/A';
      if (v is Map) return (v['name'] ?? v['community']?['name'] ?? v['district']?['name'] ?? v['region']?['name'] ?? 'N/A').toString();
      return v.toString();
    }

    final patient = data['patient'] ?? {};
    final ct = data['caseType'];
    final caseType = (ct is Map ? (ct['name'] ?? 'UNKNOWN') : 'UNKNOWN').toString().toUpperCase();

    final caseStatus = (data['status'] ?? 'unknown').toString();
    final timeline = (data['timeline'] ?? '').toString();
    final formattedTimeline = timeline.isNotEmpty
        ? DateFormat.yMMMd().format(DateTime.tryParse(timeline) ?? DateTime.now())
        : 'N/A';

    // healthFacility can be a string id or a populated map
    final hf = data['healthFacility'];
    Map<String, dynamic>? location;
    if (hf is Map) {
      if (hf['location'] is Map) {
        location = Map<String, dynamic>.from(hf['location']);
      } else {
        // synthesize from top-level fields if available
        location = {
          'region': hf['region'],
          'district': hf['district'],
          'subDistrict': hf['subDistrict'],
          'community': hf['community'],
        };
      }
    }

    // Prefer patient community if set (case when patient is outside facility community)
    String displayLocation = 'N/A';
    final caseCommunity = data['community'];
    if (caseCommunity != null) {
      displayLocation = nameOf(caseCommunity);
    } else if (location != null) {
      displayLocation = nameOf(location['community']);
    } else if (hf is Map) {
      displayLocation = nameOf(hf['community']);
    }

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
          onRefresh: fetchMyCases,
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
                TextSpan(
                  text: '$formattedTimeline · $displayLocation',
                  style: const TextStyle(fontWeight: FontWeight.normal),
                ),
              ],
            )),
            Text.rich(TextSpan(
              text: 'Person: ',
              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700]),
              children: [
                TextSpan(
                  text:
                      '${(patient['name'] ?? 'Unknown')} · ${(patient['gender'] ?? 'n/a')}, ${(patient['age'] ?? 'n/a')}yrs',
                ),
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
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Dashboard'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const DashboardScreen()))
                    .then((_) => fetchMyCases()); // refresh when returning
              },
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
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: const Text('Archived Cases'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ArchivedCasesScreen()),
                ).then((_) => fetchMyCases()); // ✅ Refresh when coming back
              },
            ),
            ListTile(
              leading: const Icon(Icons.category),
              title: const Text('Case Types Stats'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CaseTypeStatsScreen()),
                );
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
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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

                      // If user has cases, show a small add button aligned to the right
                      if (!isLoading && myCases.isNotEmpty) _buildRightAddButton(),

                      Expanded(
                        child: isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : myCases.isEmpty
                                // User has no cases at all -> show large centered stylish "+" to create a case
                                ? _buildCenterAddButton()
                                // User has some cases -> show filtered list (existing logic intact)
                                : getFilteredCases().isEmpty
                                    ? const Center(child: Text('No cases match your filter.'))
                                    : ListView.builder(
                                        padding: const EdgeInsets.symmetric(vertical: 16),
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
