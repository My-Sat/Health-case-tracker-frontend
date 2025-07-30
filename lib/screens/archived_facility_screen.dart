// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../models/health_facility.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class ArchivedFacilityScreen extends StatefulWidget {
  const ArchivedFacilityScreen({super.key});

  @override
  State<ArchivedFacilityScreen> createState() => _ArchivedFacilityScreenState();
}

class _ArchivedFacilityScreenState extends State<ArchivedFacilityScreen> {
  List<HealthFacility> archived = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadArchivedFacilities();
  }

  Future<void> _loadArchivedFacilities() async {
    final token = Provider.of<AuthProvider>(context, listen: false).user!.token;
    try {
      final res = await http.get(
        Uri.parse('${ApiService.baseUrl}/facilities/archived'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          archived = List<Map<String, dynamic>>.from(data)
              .map((f) => HealthFacility.fromJson(f))
              .toList();
          loading = false;
        });
      } else {
        throw Exception();
      }
    } catch (e) {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load archived facilities')),
      );
    }
  }

  Future<void> _unarchiveFacility(String id) async {
    final token = Provider.of<AuthProvider>(context, listen: false).user!.token;
    final res = await http.patch(
      Uri.parse('${ApiService.baseUrl}/facilities/$id'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'archived': false}),
    );
    if (res.statusCode == 200) {
      await _loadArchivedFacilities();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Facility unarchived')));
      Navigator.pop(context, true); // return success
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Unarchive failed')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Archived Facilities')),
      body: loading
          ? Center(child: CircularProgressIndicator())
          : archived.isEmpty
              ? Center(child: Text('No archived facilities'))
              : ListView.builder(
                  itemCount: archived.length,
                  itemBuilder: (ctx, i) {
                    final f = archived[i];
                    return ListTile(
                      title: Text(f.name),
                      subtitle: Text('${f.location?['community'] ?? 'Unknown'}'),
                      trailing: IconButton(
                        icon: Icon(Icons.restore, color: Colors.green),
                        onPressed: () => _unarchiveFacility(f.id),
                      ),
                    );
                  },
                ),
    );
  }
}
