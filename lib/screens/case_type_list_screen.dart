// lib/screens/case_type_list_screen.dart
// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class CaseType {
  final String id;
  final String name;

  CaseType({required this.id, required this.name});

  factory CaseType.fromJson(Map<String, dynamic> json) {
    return CaseType(
      id: json['_id'],
      name: json['name'],
    );
  }
}

class CaseTypeListScreen extends StatefulWidget {
  const CaseTypeListScreen({super.key});
  @override
  State<CaseTypeListScreen> createState() => _CaseTypeListScreenState();
}

class _CaseTypeListScreenState extends State<CaseTypeListScreen> {
  List<CaseType> types = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadTypes();
  }

  Future<void> _loadTypes() async {
    try {
      final token = Provider.of<AuthProvider>(context, listen: false).user!.token;
      final res = await http.get(
        Uri.parse('${ApiService.baseUrl}/casetypes'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final data = List<Map<String, dynamic>>.from(jsonDecode(res.body));
        setState(() {
          types = data.map((f) => CaseType.fromJson(f)).toList();
          loading = false;
        });
      } else {
        throw Exception();
      }
    } catch (_) {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load case types')),
      );
    }
  }

  Future<void> _deleteType(int index) async {
    final token = Provider.of<AuthProvider>(context, listen: false).user!.token;
    final type = types[index];
    final confirmed = await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete Case Type?'),
        content: Text('This will delete "${type.name}" and all associated cases.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final res = await http.delete(
        Uri.parse('${ApiService.baseUrl}/casetypes/${type.id}'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        setState(() => types.removeAt(index));
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Deleted case type')));
      } else {
        throw Exception();
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed')));
    }
  }

  Future<void> _editType(int index) async {
    final token = Provider.of<AuthProvider>(context, listen: false).user!.token;
    final current = types[index];
    final ctrl = TextEditingController(text: current.name);

    final updated = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Edit Case Type'),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(labelText: 'Case Type Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: Text('Save'),
          ),
        ],
      ),
    );

    if (updated == null || updated.isEmpty || updated == current.name) return;

    try {
      final res = await http.put(
        Uri.parse('${ApiService.baseUrl}/casetypes/${current.id}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'name': updated}),
      );
      if (res.statusCode == 200) {
        setState(() => types[index] = CaseType(id: current.id, name: updated));
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Case type updated')));
      } else {
        throw Exception();
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed')));
    }
  }

  Future<void> _archiveType(int index) async {
  final token = Provider.of<AuthProvider>(context, listen: false).user!.token;
  final type = types[index];

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text('Archive Case Type?'),
      content: Text('This will archive "${type.name}" and all its cases.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Archive', style: TextStyle(color: Colors.orange))),
      ],
    ),
  );

  if (confirmed != true) return;

  final res = await http.patch(
    Uri.parse('${ApiService.baseUrl}/casetypes/${type.id}/archive'),
    headers: {'Authorization': 'Bearer $token'},
  );

  if (res.statusCode == 200) {
    setState(() => types.removeAt(index));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Case type archived')));
    Navigator.pop(context, true); // notify HomeScreen to refresh
  } else {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Archive failed')));
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Center(child: Text('Case Types'))),
      body: loading
          ? Center(child: CircularProgressIndicator())
          : types.isEmpty
              ? Center(child: Text('No case types available', style: TextStyle(color: Colors.white)))
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
                        itemCount: types.length,
                        separatorBuilder: (_, __) => Divider(),
                        itemBuilder: (ctx, i) {
                          final t = types[i];
                          return ListTile(
                            title: Text(t.name, style: TextStyle(fontWeight: FontWeight.bold)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.edit, color: Colors.blue),
                                  onPressed: () => _editType(i),
                                ),
                                IconButton(
                                  icon: Icon(Icons.archive, color: Colors.orange),
                                  onPressed: () => _archiveType(i),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deleteType(i),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
    );
  }
}
