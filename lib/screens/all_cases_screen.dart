// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'package:intl/intl.dart';
import '../widgets/all_cases_detail_bottom_view.dart';

class AllCasesScreen extends StatefulWidget {
  const AllCasesScreen({super.key});

  @override
  _AllCasesScreenState createState() => _AllCasesScreenState();
}

class _AllCasesScreenState extends State<AllCasesScreen> {
  List<dynamic> allCases = [];
  bool isLoading = true;

  String selectedFilter = 'All';
  List<String> filterOptions = ['All'];
  Set<String> regions = {};
  Set<String> districts = {};
  Set<String> communities = {};

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
      allCases = jsonDecode(response.body);
      _populateFilters(); // Dynamically gather all filter categories
      setState(() => isLoading = false);
    } else {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load cases')));
    }
  }

  void _populateFilters() {
    regions = allCases.map((c) => c['healthFacility']['location']['region'] as String).toSet();
    districts = allCases.map((c) => c['healthFacility']['location']['district'] as String).toSet();
    communities = allCases.map((c) => c['healthFacility']['location']['community'] as String).toSet();

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
    if (selectedFilter == 'All') return allCases;

    final f = selectedFilter.toLowerCase();
    return allCases.where((c) {
      final cs = (c['status'] as String).toLowerCase();
      final ps = (c['patient']['status'] as String).toLowerCase();
      final g = (c['patient']['gender'] as String).toLowerCase();
      final loc = c['healthFacility']['location'];
      final region = (loc['region'] as String).toLowerCase();
      final district = (loc['district'] as String).toLowerCase();
      final community = (loc['community'] as String).toLowerCase();

      return cs == f ||
        ps == f ||
        g == f ||
        region == f ||
        district == f ||
        community == f;
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
  final community = location['community'];

  Color statusColor = Colors.grey;
  if (status == 'suspected') statusColor = Colors.orange;
  if (status == 'confirmed') statusColor = Colors.red;
  if (status == 'not a case') statusColor = Colors.green;

  return GestureDetector(
    onTap: () {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        builder: (_) => CaseViewBottomSheet(caseData: data),
      );
    },
    child: Container(
      margin: EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      padding: const EdgeInsets.all(12),
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(caseType, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text(status.toUpperCase(), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: statusColor)),
        ]),
        SizedBox(height: 4),
        Text.rich(TextSpan(
          text: 'Reported: ',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700]),
          children: [TextSpan(text: '$formattedTimeline · $community', style: TextStyle(fontWeight: FontWeight.normal, color: Colors.black87))],
        )),
        Text.rich(TextSpan(
          text: 'Patient: ',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700]),
          children: [TextSpan(text: '${patient['gender']}, ${patient['age']}yrs · ${patient['status']}', style: TextStyle(color: Colors.black87))],
        )),
      ]),
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
          child: Column(children: [
            SizedBox(height: 16),
            Text(
              'All Reported Cases (${allCases.length})',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            SizedBox(height: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha((0.95 * 255).toInt()),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: DropdownButtonFormField<String>(
                      value: selectedFilter,
                      onChanged: (v) => setState(() => selectedFilter = v!),
                      items: filterOptions.map((label) =>
                        DropdownMenuItem(value: label, child: Text(label))
                      ).toList(),
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
                      : getFilteredCases().isEmpty
                          ? Center(child: Text('No cases match your filter.'))
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              itemCount: getFilteredCases().length,
                              itemBuilder: (ctx, i) => caseSummaryCard(getFilteredCases()[i]),
                            ),
                  ),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
