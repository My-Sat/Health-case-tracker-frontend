// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../models/case_type.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class ArchivedCaseTypeScreen extends StatefulWidget {
  const ArchivedCaseTypeScreen({super.key});

  @override
  State<ArchivedCaseTypeScreen> createState() => _ArchivedCaseTypeScreenState();
}

class _ArchivedCaseTypeScreenState extends State<ArchivedCaseTypeScreen> {
  List<CaseType> archived = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadArchivedTypes();
  }

  Future<void> _loadArchivedTypes() async {
    final token = Provider.of<AuthProvider>(context, listen: false).user!.token;
    try {
      final res = await http.get(
        Uri.parse('${ApiService.baseUrl}/casetypes/archived'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final data = List<Map<String, dynamic>>.from(jsonDecode(res.body));
        setState(() {
          archived = data.map((f) => CaseType.fromJson(f)).toList();
          loading = false;
        });
      } else {
        throw Exception();
      }
    } catch (_) {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load archived case types')),
      );
    }
  }

  Future<void> _unarchiveType(String id) async {
    final token = Provider.of<AuthProvider>(context, listen: false).user!.token;
    final res = await http.patch(
      Uri.parse('${ApiService.baseUrl}/casetypes/$id/unarchive'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) {
      await _loadArchivedTypes();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Case type unarchived')),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unarchive failed')),
      );
    }
  }

  Widget typeCard(CaseType type) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        // ignore: deprecated_member_use
        color: Colors.white.withOpacity(0.95),
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.grey.shade200, blurRadius: 4, offset: const Offset(2, 2)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(type.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          IconButton(
            icon: const Icon(Icons.restore, color: Colors.green),
            onPressed: () => _unarchiveType(type.id),
          ),
        ],
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
                  'Archived Case Types',
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
                  child: loading
                      ? const Center(child: CircularProgressIndicator())
                      : archived.isEmpty
                          ? const Center(child: Text('No archived case types'))
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              itemCount: archived.length,
                              itemBuilder: (ctx, i) => typeCard(archived[i]),
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
