import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CaseAdminViewBottomSheet extends StatelessWidget {
  final Map<String, dynamic> caseData;

  const CaseAdminViewBottomSheet({required this.caseData, super.key});

  /// Safely extract a human readable name/string from various shapes:
  /// - null => fallback
  /// - String => value
  /// - Map with common keys (name, fullName) => that value
  /// - otherwise -> toString()
  String _nameOf(dynamic v, [String fallback = 'Unknown']) {
    if (v == null) return fallback;
    if (v is String) {
      final s = v.trim();
      if (s.isEmpty) return fallback;
      return s;
    }
    if (v is Map) {
      if (v.containsKey('name') && v['name'] != null && v['name'].toString().trim().isNotEmpty) {
        return v['name'].toString();
      }
      if (v.containsKey('fullName') && v['fullName'] != null && v['fullName'].toString().trim().isNotEmpty) {
        return v['fullName'].toString();
      }
      if (v.containsKey('full_name') && v['full_name'] != null && v['full_name'].toString().trim().isNotEmpty) {
        return v['full_name'].toString();
      }
      if (v.containsKey('fullname') && v['fullname'] != null && v['fullname'].toString().trim().isNotEmpty) {
        return v['fullname'].toString();
      }
      // fallback to first non-empty string value in the map (avoids showing raw object-id values)
      for (final val in v.values) {
        if (val is String && val.trim().isNotEmpty && !RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(val)) {
          return val;
        }
      }
      return fallback;
    }
    final s = v.toString().trim();
    return s.isEmpty ? fallback : s;
  }

  /// More exhaustive officer name extractor that:
  /// - prefers explicit name keys
  /// - checks common nested containers (e.g. _doc, user, profile)
  /// - falls back to a plain string if it's not a 24-hex ObjectId
  String _extractOfficerName(dynamic officer) {
    if (officer == null) return 'Unknown';

    // If it's a plain string, it may be either a name or an ObjectId.
    if (officer is String) {
      final s = officer.trim();
      // heuristic: ObjectId is 24 hex chars
      if (RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(s)) return 'Unknown';
      return s.isNotEmpty ? s : 'Unknown';
    }

    // If it's a map/object, check common keys
    if (officer is Map) {
      // direct keys to try
      final keys = [
        'fullName',
        'full_name',
        'fullname',
        'name',
        'displayName',
        'display_name',
        'username',
        'userName',
        'firstName',
        'first_name',
        'givenName',
        'given_name'
      ];

      for (final k in keys) {
        final val = officer[k];
        if (val != null && val.toString().trim().isNotEmpty) return val.toString().trim();
      }

      // sometimes Mongoose objects or other wrappers keep data under _doc
      if (officer['_doc'] is Map) {
        final inner = officer['_doc'] as Map;
        for (final k in keys) {
          final val = inner[k];
          if (val != null && val.toString().trim().isNotEmpty) return val.toString().trim();
        }
      }

      // nested common containers
      final nestedCandidates = ['user', 'profile', 'person', 'data'];
      for (final nk in nestedCandidates) {
        if (officer[nk] is Map) {
          final nestedResult = _extractOfficerName(officer[nk]);
          if (nestedResult != 'Unknown') return nestedResult;
        } else if (officer[nk] is String) {
          final s = officer[nk].toString().trim();
          if (s.isNotEmpty && !RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(s)) return s;
        }
      }

      // fallback: pick first non-id string value
      for (final val in officer.values) {
        if (val is String && val.trim().isNotEmpty && !RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(val)) {
          return val.trim();
        }
      }

      return 'Unknown';
    }

    // other types: convert to string if meaningful
    final s = officer.toString().trim();
    if (s.isNotEmpty && !RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(s)) return s;
    return 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    final patient = caseData['patient'] ?? <String, dynamic>{};

    // status might be String or something else
    final status = _nameOf(caseData['status'], 'Unknown').toLowerCase();

    // healthFacility may be an id, or a populated object
    final hf = caseData['healthFacility'];
    Map<String, dynamic> location = {};
    if (hf is Map) {
      if (hf['location'] is Map) {
        location = Map<String, dynamic>.from(hf['location']);
      } else {
        // synthesize from top-level props (could be populated refs or ids)
        location = {
          'region': hf['region'],
          'district': hf['district'],
          'subDistrict': hf['subDistrict'],
          'community': hf['community'],
        };
      }
    }

    // timeline might be a String, DateTime, or missing
    final timelineRaw = caseData['timeline'];
    String formattedTimeline = 'N/A';
    if (timelineRaw != null) {
      try {
        DateTime? dt;
        if (timelineRaw is DateTime) {
          dt = timelineRaw;
        } else {
          dt = DateTime.tryParse(timelineRaw.toString()) ?? DateTime.tryParse(timelineRaw as String? ?? '');
        }
        formattedTimeline = dt != null
            ? DateFormat.yMMMMd().add_jm().format(dt)
            : timelineRaw.toString();
      } catch (_) {
        formattedTimeline = timelineRaw.toString();
      }
    }

    final caseType = _nameOf(
      caseData['caseType'] is Map ? caseData['caseType']['name'] : caseData['caseType'],
      'UNKNOWN',
    ).toUpperCase();

    // Prefer case-level community if provided; otherwise use facility location community
    final communityName = (_nameOf(caseData['community']).trim().isNotEmpty)
        ? _nameOf(caseData['community'])
        : _nameOf(location['community']);

    // Use robust officer name extraction
    final reporterName = _extractOfficerName(caseData['officer']);

    final facilityName = hf is Map ? _nameOf(hf['name'], 'Unknown facility') : 'Unknown facility';

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

    // small helper to only show sub-district when present
    final subDistrictName = _nameOf(location['subDistrict']);
    final districtName = _nameOf(location['district']);
    final regionName = _nameOf(location['region']);

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
            infoBox('Case Status', status.toUpperCase()),
            infoBox('Reported On', formattedTimeline),
            infoBox('Facility', facilityName),
            infoBox('Community', communityName),
            if (subDistrictName.trim().isNotEmpty) infoBox('Sub-District', subDistrictName),
            infoBox('District', districtName),
            infoBox('Region', regionName),
            infoBox('Reported By', reporterName),
            infoBox('Patient Name', _nameOf(patient['name'])),
            infoBox('Patient Age', '${patient['age'] ?? 'n/a'} yrs'),
            infoBox('Patient Gender', _nameOf(patient['gender'], 'n/a')),
            infoBox('Patient Phone', _nameOf(patient['phone'], 'n/a')),
            infoBox('Patient Status', _nameOf(patient['status'], 'Ongoing treatment')),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
