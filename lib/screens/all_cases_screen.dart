// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'package:intl/intl.dart'; // This import is required for DateFormat
import '../widgets/all_cases_detail_bottom_view.dart';

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
      Uri.parse('https://health-case-tracker-backend.onrender.com/api/cases'),
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

Widget caseSummaryCard(Map<String, dynamic> data) {
  final patient = data['patient'];
  final caseType = data['caseType'].toString().toUpperCase();
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
  if (status == 'Not a Case') statusColor = Colors.green;

  return GestureDetector(
    onTap: () {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        builder: (context) => CaseViewBottomSheet(caseData: data),
      );
    },
    child: Container(
      margin: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(caseType,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text(status.toUpperCase(),
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: statusColor)),
            ],
          ),
          SizedBox(height: 4),
          Text.rich(TextSpan(
              text: 'Reported: ',
              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700]),
              children: [
                TextSpan(
                  text: '$formattedTimeline · $displayLocation',
                  style: TextStyle(
                      fontWeight: FontWeight.normal, color: Colors.black87),
                )
              ])),
          Text.rich(TextSpan(
              text: 'Patient: ',
              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700]),
              children: [
                TextSpan(
                  text:
                      '${patient['gender']}, ${patient['age']}yrs · ${patient['status']}',
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
          'All Reported Cases (${allCases.length})',
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
                        itemBuilder: (context, index) => caseSummaryCard(allCases[index]),

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
