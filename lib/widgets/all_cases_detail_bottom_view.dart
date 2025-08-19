import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CaseViewBottomSheet extends StatelessWidget {
  final Map<String, dynamic> caseData;

  const CaseViewBottomSheet({required this.caseData, super.key});

  // Safe extractor for "name" whether value is a Map or a raw string/id.
  String _nameOf(dynamic v, [String fallback = 'Unknown']) {
    if (v == null) return fallback;
    if (v is Map) return (v['name'] ?? fallback).toString();
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    final patient = caseData['patient'] ?? {};
    final caseStatus = (caseData['status'] ?? 'unknown').toString();

    // healthFacility may be an id (string) or a populated map
    final hf = caseData['healthFacility'];
    Map<String, dynamic>? location;
    if (hf is Map) {
      if (hf['location'] is Map) {
        location = Map<String, dynamic>.from(hf['location']);
      } else {
        // synthesize location from top-level fields if available
        location = {
          'region': hf['region'],
          'district': hf['district'],
          'subDistrict': hf['subDistrict'],
          'community': hf['community'],
        };
      }
    }

    final timeline = (caseData['timeline'] ?? '').toString();
    final formattedTimeline = timeline.isNotEmpty
        ? DateFormat.yMMMMd().add_jm().format(DateTime.tryParse(timeline) ?? DateTime.now())
        : 'N/A';

    final ct = caseData['caseType'];
    final caseType = (ct is Map ? (ct['name'] ?? 'UNKNOWN') : 'UNKNOWN').toString().toUpperCase();

    // Prefer the case-level patient community if set (outside facility flow),
    // otherwise fall back to facility location/community (or facility.community).
    final caseCommunity = caseData['community'];
    final communityName = caseCommunity != null
        ? _nameOf(caseCommunity, 'Unknown')
        : _nameOf(location?['community'] ?? (hf is Map ? hf['community'] : null), 'Unknown');

    final officer = caseData['officer'];
    final reporterName = officer is Map ? (officer['fullName'] ?? 'Unknown').toString() : 'Unknown';

    final facilityName = hf is Map ? (hf['name'] ?? 'Unknown facility').toString() : 'Unknown facility';

    Widget infoBox(String label, String value) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          '$label: $value',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 20,
        left: 16,
        right: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Center(
              child: Container(
                width: 50,
                height: 5,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            infoBox('Case Type', caseType),
            infoBox('Case Status', caseStatus.toUpperCase()),
            infoBox('Reported On', formattedTimeline),
            infoBox('Facility', facilityName),
            infoBox('Community', communityName),
            if ((location?['subDistrict'] ?? '').toString().trim().isNotEmpty)
              infoBox('Sub-District', _nameOf(location?['subDistrict'])),
            infoBox('District', _nameOf(location?['district'])),
            infoBox('Region', _nameOf(location?['region'])),
            infoBox('Reported By', reporterName),
            infoBox('Patient Age', '${patient['age'] ?? 'n/a'} yrs'),
            infoBox('Patient Gender', (patient['gender'] ?? 'n/a').toString()),
            infoBox('Patient Status', (patient['status'] ?? 'Ongoing treatment').toString()),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
