// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../models/health_facility.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'edit_facility_screen.dart';

class FacilityListScreen extends StatefulWidget {
  const FacilityListScreen({super.key});

  @override
  State<FacilityListScreen> createState() => _FacilityListScreenState();
}

class _FacilityListScreenState extends State<FacilityListScreen> {
  List<HealthFacility> facilities = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadFacilities();
  }

  Future<void> _loadFacilities() async {
    try {
      final res = await http.get(Uri.parse('${ApiService.baseUrl}/facilities'));
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        setState(() {
          facilities = data.map((j) => HealthFacility.fromJson(j)).toList();
          loading = false;
        });
      } else {
        throw Exception();
      }
    } catch (_) {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading facilities')),
      );
    }
  }

  Future<void> _archiveFacility(String id) async {
    final token = Provider.of<AuthProvider>(context, listen: false).user!.token;
    final confirmed = await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Archive Facility?'),
        content: Text('This will hide the facility and all its cases.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Archive', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final res = await http.patch(
        Uri.parse('${ApiService.baseUrl}/facilities/$id/archive'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        await _loadFacilities();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Facility archived')));
      } else {
        throw Exception();
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Archive failed')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(child: Text('Facilities')),
      ),
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
            : facilities.isEmpty
                ? Center(child: Text('No facilities found.', style: TextStyle(color: Colors.white)))
                : SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        margin: EdgeInsets.all(12),
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
                        ),
                        child: ListView.separated(
                          itemCount: facilities.length,
                          separatorBuilder: (_, __) => Divider(),
                          itemBuilder: (ctx, i) {
                            final f = facilities[i];
                            return ListTile(
                              contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                              title: Text(f.name, style: TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(f.location.community),
                              trailing: Wrap(
                                spacing: 4,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.edit, color: Colors.blue),
                                    onPressed: () async {
                                      final updated = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => EditFacilityScreen(facility: f),
                                        ),
                                      );
                                      if (updated == true) _loadFacilities();
                                    },
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.archive, color: Colors.orange),
                                    onPressed: () => _archiveFacility(f.id),
                                  ),
                                ],
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
