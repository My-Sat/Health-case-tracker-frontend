import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CaseViewBottomSheet extends StatelessWidget {
  final Map<String, dynamic> caseData;

  const CaseViewBottomSheet({required this.caseData, super.key});

  // Resolve best-available location map
  Map<String, String> _resolveLocation() {
    String nameOfLocal(dynamic v) {
      if (v == null) return '';
      if (v is Map) return (v['name'] ?? '').toString();
      return v.toString();
    }

    final result = {'region': '', 'district': '', 'subDistrict': '', 'community': ''};

    // 1) server-synthesized case.location (preferred)
    final caseLoc = caseData['location'];
    if (caseLoc is Map) {
      result['region'] = nameOfLocal(caseLoc['region']);
      result['district'] = nameOfLocal(caseLoc['district']);
      result['subDistrict'] = nameOfLocal(caseLoc['subDistrict']);
      result['community'] = nameOfLocal(caseLoc['community']);
      if (result.values.any((s) => s.isNotEmpty)) return result;
    }

    // 2) case.community (populated)
    final caseCommunity = caseData['community'];
    if (caseCommunity is Map) {
      result['community'] = nameOfLocal(caseCommunity['name']);
      result['region'] = nameOfLocal(caseCommunity['region']);
      result['district'] = nameOfLocal(caseCommunity['district']);
      result['subDistrict'] = nameOfLocal(caseCommunity['subDistrict']);
      if (result.values.any((s) => s.isNotEmpty)) return result;
    } else if (caseCommunity is String && caseCommunity.trim().isNotEmpty) {
      result['community'] = caseCommunity;
      return result;
    }

    // 3) healthFacility.location or top-level hf fields
    final hf = caseData['healthFacility'];
    if (hf is Map) {
      final hfLoc = hf['location'];
      if (hfLoc is Map) {
        result['region'] = nameOfLocal(hfLoc['region']);
        result['district'] = nameOfLocal(hfLoc['district']);
        result['subDistrict'] = nameOfLocal(hfLoc['subDistrict']);
        result['community'] = nameOfLocal(hfLoc['community']);
        if (result.values.any((s) => s.isNotEmpty)) return result;
      }

      // fallback to direct fields
      result['region'] = nameOfLocal(hf['region']);
      result['district'] = nameOfLocal(hf['district']);
      result['subDistrict'] = nameOfLocal(hf['subDistrict']);
      result['community'] = nameOfLocal(hf['community']);
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final patient = caseData['patient'] ?? {};
    final caseStatus = (caseData['status'] ?? 'unknown').toString();

    final loc = _resolveLocation();
    final communityName = loc['community']?.isNotEmpty == true ? loc['community']! : 'Unknown';
    final subDistrictName = loc['subDistrict'] ?? '';
    final districtName = loc['district'] ?? '';
    final regionName = loc['region'] ?? '';

    final timeline = (caseData['timeline'] ?? '').toString();
    final formattedTimeline = timeline.isNotEmpty
        ? DateFormat.yMMMMd().add_jm().format(DateTime.tryParse(timeline) ?? DateTime.now())
        : 'N/A';

    final ct = caseData['caseType'];
    final caseType = (ct is Map ? (ct['name'] ?? 'UNKNOWN') : 'UNKNOWN').toString().toUpperCase();

    final officer = caseData['officer'];
    final reporterName = officer is Map ? (officer['fullName'] ?? 'Unknown').toString() : 'Unknown';

    final hf = caseData['healthFacility'];
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
            if (subDistrictName.trim().isNotEmpty) infoBox('Sub-District', subDistrictName),
            infoBox('District', districtName.isNotEmpty ? districtName : 'Unknown'),
            infoBox('Region', regionName.isNotEmpty ? regionName : 'Unknown'),
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
