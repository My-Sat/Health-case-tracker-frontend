// ignore_for_file: use_build_context_synchronously, deprecated_member_use

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
    } catch (_) {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load archived facilities')),
      );
    }
  }

  Future<void> _unarchiveFacility(String id) async {
    final token = Provider.of<AuthProvider>(context, listen: false).user!.token;
    try {
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Facility unarchived')),
        );
        Navigator.pop(context, true);
      } else {
        throw Exception();
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unarchive failed')),
      );
    }
  }

  Widget facilityCard(HealthFacility f) {
    final loc = f.location;
    final locationDetails = [
      'Community: ${loc.community}',
      'Sub-District: ${loc.subDistrict ?? "N/A"}',
      'District: ${loc.district}',
      'Region: ${loc.region}',
    ].join('\n');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.grey.shade200, blurRadius: 4, offset: const Offset(2, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(f.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(locationDetails, style: const TextStyle(fontSize: 14, height: 1.4)),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.restore, color: Colors.green),
              label: const Text('Unarchive', style: TextStyle(color: Colors.green)),
              onPressed: () => _unarchiveFacility(f.id),
            ),
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
              // Top row with back button and centered title (keeps previous visual styling)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                child: Row(
                  children: [
                    // Back button
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    // Centered title
                    const Expanded(
                      child: Center(
                        child: Text(
                          'Archived Facilities',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ),
                    // Spacer to visually balance the back button
                    SizedBox(width: 48),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha((0.95 * 255).toInt()),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: loading
                      ? const Center(child: CircularProgressIndicator())
                      : archived.isEmpty
                          ? const Center(child: Text('No archived facilities'))
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              itemCount: archived.length,
                              itemBuilder: (ctx, i) => facilityCard(archived[i]),
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
