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
        SnackBar(content: Text('Failed to load archived case types')),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Case type unarchived')));
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unarchive failed')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Center(child: Text('Archived Case Types'))),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.teal.shade800, Colors.teal.shade300],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: loading
            ? Center(child: CircularProgressIndicator())
            : archived.isEmpty
                ? Center(child: Text('No archived case types', style: TextStyle(color: Colors.white)))
                : SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        margin: EdgeInsets.all(12),
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          // ignore: deprecated_member_use
                          color: Colors.white.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
                        ),
                        child: ListView.separated(
                          itemCount: archived.length,
                          separatorBuilder: (_, __) => Divider(),
                          itemBuilder: (ctx, i) {
                            final t = archived[i];
                            return ListTile(
                              contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                              title: Text(t.name, style: TextStyle(fontWeight: FontWeight.bold)),
                              trailing: IconButton(
                                icon: Icon(Icons.restore, color: Colors.green),
                                onPressed: () => _unarchiveType(t.id),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
      ),
    );
  }
}
