// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/health_facility.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';
import 'edit_facility_screen.dart';

class FacilityListScreen extends StatefulWidget {
  const FacilityListScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _FacilityListScreenState createState() => _FacilityListScreenState();
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
      final res = await http.get(
        Uri.parse('${ApiService.baseUrl}/facilities'),
      );
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        setState(() {
          facilities = data.map((j) => HealthFacility.fromJson(j)).toList();
          loading = false;
        });
      } else {
        throw Exception();
      }
    } catch (e) {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading facilities')),
      );
    }
  }

  Future<void> _deleteFacility(String facilityId) async {
    final token = Provider.of<AuthProvider>(context, listen: false).user!.token;
    try {
      final resp = await http.delete(
        Uri.parse('${ApiService.baseUrl}/facilities/$facilityId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (resp.statusCode == 200) {
        setState(() {
          facilities.removeWhere((f) => f.id == facilityId);
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Deleted facility')));
      } else {
        throw Exception();
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Delete failed')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Facilities')),
      body: loading
          ? Center(child: CircularProgressIndicator())
          : facilities.isEmpty
              ? Center(child: Text('No facilities found.'))
              : ListView.builder(
                  itemCount: facilities.length,
                  itemBuilder: (ctx, i) {
                    final f = facilities[i];
                    return ListTile(
                      title: Text(f.name),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
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
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: Text('Delete?'),
                              content: Text('Delete facility "${f.name}" and all related cases?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _deleteFacility(f.id);
                                  },
                                  child: Text('Delete', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                        },
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
