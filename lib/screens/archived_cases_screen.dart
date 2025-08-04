// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/my_cases_detail_bottom_view.dart';

class ArchivedCasesScreen extends StatefulWidget {
  const ArchivedCasesScreen({super.key});

  @override
  State<ArchivedCasesScreen> createState() => _ArchivedCasesScreenState();
}

class _ArchivedCasesScreenState extends State<ArchivedCasesScreen> {
  List<dynamic> archivedCases = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchArchivedCases();
  }

  Future<void> fetchArchivedCases() async {
    final token = Provider.of<AuthProvider>(context, listen: false).user!.token;

    final response = await http.get(
      Uri.parse('http://172.20.10.3:5000/api/cases/archived'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      setState(() {
        archivedCases = jsonDecode(response.body);
        isLoading = false;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load archived cases')),
      );
    }
  }

  Future<void> unarchiveCase(String caseId) async {
    final token = Provider.of<AuthProvider>(context, listen: false).user!.token;

    final response = await http.patch(
      Uri.parse('http://172.20.10.3:5000/api/cases/$caseId/unarchive'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      Navigator.pop(context, true); // Return to refresh parent if needed
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Case unarchived successfully')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to unarchive case')),
      );
    }
  }

  Widget caseCard(Map<String, dynamic> data) {
    final patient = data['patient'];
    final caseStatus = data['status'];
    final caseType = data['caseType']['name']?.toString().toUpperCase() ?? 'UNKNOWN';
    final facility = data['healthFacility']['name'];

    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        builder: (_) => CaseDetailBottomSheet(
          caseData: data,
          onUpdate: (caseId, [_, __]) => fetchArchivedCases(),
        ),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
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
              Text(caseStatus.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 4),
            Text('Patient: ${patient['name']} (${patient['gender']}, ${patient['age']} yrs)'),
            Text('Facility: $facility'),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.restore, color: Colors.green),
                label: const Text('Unarchive', style: TextStyle(color: Colors.green)),
                onPressed: () => unarchiveCase(data['_id']),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              const Center(
                child: Text(
                  'Archived Cases',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha((0.95 * 255).toInt()),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : archivedCases.isEmpty
                          ? const Center(child: Text('No archived cases'))
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              itemCount: archivedCases.length,
                              itemBuilder: (ctx, i) => caseCard(archivedCases[i]),
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
