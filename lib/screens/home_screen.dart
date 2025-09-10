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
import 'case_type_list_screen.dart';
import 'archived_case_type_screen.dart';

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
  Set<String> regions = <String>{}, districts = <String>{}, communities = <String>{};

  @override
  void initState() {
    super.initState();
    fetchCases();
  }

  Future<void> fetchCases() async {
    final token = Provider.of<AuthProvider>(context, listen: false).user!.token;

    final response = await http.get(
      Uri.parse('https://health-case-tracker-backend-o82a.onrender.com/api/cases'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      caseList = jsonDecode(response.body);
      _populateFilters();
      setState(() => isLoading = false);
    } else {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Failed to load cases')));
    }
  }

  /// Returns an effective location map for a case:
  /// { 'region', 'district', 'subDistrict', 'community' } (strings, may be empty)
  Map<String, String> _effectiveLocation(dynamic c) {
    // helper to read either Map or String -> String
    String nameOf(dynamic v) {
      if (v == null) return '';
      if (v is Map) return (v['name'] ?? '').toString();
      return v.toString();
    }

    final result = {
      'region': '',
      'district': '',
      'subDistrict': '',
      'community': '',
    };

    // 1) If case-level location was supplied (client could have sent a 'location' object),
    //    prefer that. It may contain string or nested objects.
    final caseLoc = c['location'];
    if (caseLoc != null) {
      result['region'] = nameOf(caseLoc['region']);
      result['district'] = nameOf(caseLoc['district']);
      result['subDistrict'] = nameOf(caseLoc['subDistrict']);
      // community often comes as c['community'] (populated) or caseLoc['community']
      final caseCom = c['community'];
      if (caseCom != null && (caseCom is Map || caseCom is String)) {
        result['community'] = nameOf(caseCom is Map ? caseCom['name'] ?? caseCom : caseCom);
      } else {
        result['community'] = nameOf(caseLoc['community']);
      }
      return result;
    }

    // 2) If the case's populated community exists and is not the facility's community,
    //    use that (it means the officer supplied a community different from their facility).
    final caseCommunity = c['community'];
    final hfLocation = c['healthFacility']?['location'] ?? {};
    final hfCommunityName = nameOf(hfLocation['community']);

    final caseCommunityName = (caseCommunity != null) ? nameOf(caseCommunity is Map ? caseCommunity['name'] ?? caseCommunity : caseCommunity) : '';

    if (caseCommunityName.isNotEmpty && caseCommunityName.toLowerCase() != hfCommunityName.toLowerCase()) {
      // try to read parent fields from the community doc if available
      String district = '';
      String subDistrict = '';
      String region = '';

      if (caseCommunity is Map) {
        district = nameOf(caseCommunity['district']);
        subDistrict = nameOf(caseCommunity['subDistrict']);
        region = nameOf(caseCommunity['region']); // sometimes present if you populated deeply
      }

      result['community'] = caseCommunityName;
      result['district'] = district;
      result['subDistrict'] = subDistrict;
      result['region'] = region;
      return result;
    }

    // 3) Fallback -> use the healthFacility's synthesized location
    result['region'] = nameOf(hfLocation['region']);
    result['district'] = nameOf(hfLocation['district']);
    result['subDistrict'] = nameOf(hfLocation['subDistrict']);
    result['community'] = nameOf(hfLocation['community']);
    return result;
  }

  void _populateFilters() {
    regions.clear();
    districts.clear();
    communities.clear();

    for (final e in caseList) {
      final loc = _effectiveLocation(e);
      if (loc['region'] != null && loc['region']!.isNotEmpty) regions.add(loc['region']!);
      if (loc['district'] != null && loc['district']!.isNotEmpty) districts.add(loc['district']!);
      if (loc['community'] != null && loc['community']!.isNotEmpty) communities.add(loc['community']!);
    }

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
      final loc = _effectiveLocation(c);
      final cs = (c['status'] ?? '').toString().toLowerCase();
      final ps = (c['patient']?['status'] ?? '').toString().toLowerCase();
      final g = (c['patient']?['gender'] ?? '').toString().toLowerCase();
      final region = (loc['region'] ?? '').toString().toLowerCase();
      final district = (loc['district'] ?? '').toString().toLowerCase();
      final community = (loc['community'] ?? '').toString().toLowerCase();

      return cs == filter ||
          ps == filter ||
          g == filter ||
          region == filter ||
          district == filter ||
          community == filter;
    }).toList();
  }

  Widget caseSummaryCard(Map<String, dynamic> data) {
    final patient = data['patient'] ?? {};
    final caseType = (data['caseType']?['name'] ?? 'UNKNOWN').toString().toUpperCase();
    final status = data['status'];
    final timeline = data['timeline'] ?? '';
    final formattedTimeline = timeline.toString().isNotEmpty
        ? DateFormat.yMMMd().format(DateTime.parse(timeline.toString()))
        : 'N/A';

    final loc = _effectiveLocation(data);
    String displayLocation = loc['community']?.isNotEmpty == true
        ? loc['community']!
        : (loc['district']?.isNotEmpty == true
            ? loc['district']!
            : (loc['region']?.isNotEmpty == true ? loc['region']! : 'N/A'));

    if (loc['district'] != null &&
        loc['district']!.isNotEmpty &&
        (loc['community'] == null || loc['community']!.isEmpty)) {
      // if community not available but district is, show district (already handled),
      // otherwise we keep community primary.
    }

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
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
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
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(caseType, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text(status.toString().toUpperCase(),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: statusColor)),
            ]),
            const SizedBox(height: 4),
            Text.rich(TextSpan(
              text: 'Reported: ',
              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700]),
              children: [
                TextSpan(
                  text: '$formattedTimeline · $displayLocation',
                  style: const TextStyle(fontWeight: FontWeight.normal, color: Colors.black87),
                )
              ],
            )),
            Text.rich(TextSpan(
              text: 'Patient: ',
              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700]),
              children: [
                TextSpan(
                  text: '${patient['name'] ?? ''} · ${patient['gender'] ?? ''}, ${patient['age'] ?? ''}yrs',
                  style: const TextStyle(color: Colors.black87),
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
              decoration: const BoxDecoration(color: Colors.teal),
              child: const Text('Health Case Tracker', style: TextStyle(color: Colors.white, fontSize: 20)),
            ),
            if (authIsAdmin(context))
              ExpansionTile(
                leading: const Icon(Icons.business),
                title: const Text('Facility'),
                children: [
                  ListTile(
                    leading: const Icon(Icons.add_business),
                    title: const Text('Add Facility'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateFacilityScreen()));
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.list),
                    title: const Text('Facility List'),
                    onTap: () async {
                      Navigator.pop(context); // close drawer first
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const FacilityListScreen()),
                      );
                      await fetchCases(); // refresh after returning
                    },
                  ),
                ],
              ),
            ExpansionTile(
              leading: const Icon(Icons.category),
              title: const Text('Cases'),
              children: [
                ListTile(
                  leading: const Icon(Icons.home),
                  title: const Text('Reported Cases'),
                  onTap: () => Navigator.pop(context),
                ),
                ListTile(
                  leading: const Icon(Icons.add),
                  title: const Text('Add Case Type'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateCaseTypeScreen()));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.list),
                  title: const Text('Update Case Type'),
                  onTap: () async {
                    Navigator.pop(context);
                    final updated = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CaseTypeListScreen()),
                    );
                    if (updated == true) {
                      await fetchCases(); // re-fetch to reflect deletions
                    }
                  },
                ),
              ],
            ),
            ExpansionTile(
              leading: const Icon(Icons.archive),
              title: const Text('Archives'),
              children: [
                ListTile(
                  leading: const Icon(Icons.archive_outlined),
                  title: const Text('Archived Facilities'),
                  onTap: () async {
                    Navigator.pop(context);
                    final changed = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ArchivedFacilityScreen()),
                    );
                    if (changed == true) await fetchCases(); // refresh if unarchived
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.archive_outlined),
                  title: const Text('Archived Case Types'),
                  onTap: () async {
                    Navigator.pop(context);
                    final changed = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ArchivedCaseTypeScreen()),
                    );
                    if (changed == true) await fetchCases();
                  },
                ),
              ],
            ),
            if (!authIsAdmin(context)) ...[
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('Report Case'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateCaseScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.assignment),
                title: const Text('My Cases'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const MyCasesScreen()));
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
            ],
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                await auth.logout();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
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
              const SizedBox(height: 16),
              Text(
                'Reported Cases (${filtered.length})',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha((0.95 * 255).toInt()),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
                            ? const Center(child: CircularProgressIndicator())
                            : filtered.isEmpty
                                ? const Center(child: Text('No matching cases.'))
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
