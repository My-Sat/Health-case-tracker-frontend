import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../screens/edit_case_screen.dart';

class CaseDetailBottomSheet extends StatelessWidget {
  final Map<String, dynamic> caseData;
  final Function(String caseId, [String? status, String? patientStatus]) onUpdate;
  final VoidCallback? onRefresh;

  const CaseDetailBottomSheet({
    required this.caseData,
    required this.onUpdate,
    this.onRefresh,
    super.key,
  });

  void showConfirmationDialog(BuildContext context, String message, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Please Confirm'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void showEditOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.grey),
              title: const Text('Edit Case Details'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => EditCaseScreen(caseData: caseData)),
                ).then((needRefresh) {
                  if (needRefresh == true) {
                    // ignore: use_build_context_synchronously
                    Navigator.pop(context);
                    onRefresh?.call();
                  }
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.archive, color: Colors.orange),
              title: const Text('Archive Case'),
              onTap: () {
                Navigator.pop(ctx);
                showConfirmationDialog(
                  context,
                  'Are you sure you want to archive this case?',
                  () {
                    Navigator.pop(context); // close main bottom sheet
                    onUpdate(caseData['_id'], 'archived');
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // Robust extractor for human-friendly name from various shapes
  String _nameOf(dynamic v, [String fallback = 'Unknown']) {
    if (v == null) return fallback;

    // plain string: return unless it's an ObjectId-like string
    if (v is String) {
      final s = v.trim();
      if (s.isEmpty) return fallback;
      if (RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(s)) return fallback;
      return s;
    }

    // Map: prefer common name keys
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
      // nested common containers
      if (v['_doc'] is Map) {
        final inner = v['_doc'] as Map;
        if (inner.containsKey('name') && inner['name'] != null && inner['name'].toString().trim().isNotEmpty) {
          return inner['name'].toString();
        }
        if (inner.containsKey('fullName') && inner['fullName'] != null && inner['fullName'].toString().trim().isNotEmpty) {
          return inner['fullName'].toString();
        }
      }
      // Sometimes the map itself contains nested objects like { district: { name: 'X' } }
      for (final key in ['name', 'community', 'subDistrict', 'district', 'region']) {
        if (v[key] is Map) {
          final nested = v[key] as Map;
          if (nested['name'] != null && nested['name'].toString().trim().isNotEmpty) {
            return nested['name'].toString();
          }
        }
        if (v[key] is String && v[key].toString().trim().isNotEmpty) {
          final s = v[key].toString().trim();
          if (!RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(s)) return s;
        }
      }
      // fallback: first non-id string value
      for (final val in v.values) {
        if (val is String && val.trim().isNotEmpty && !RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(val.trim())) {
          return val;
        }
      }
      return fallback;
    }

    final s = v.toString().trim();
    if (s.isEmpty) return fallback;
    if (RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(s)) return fallback;
    return s;
  }

  // Resolve a normalized location map with priority:
  // 1) caseData['location'] (synthesized on server) -> best
  // 2) caseData['community'] (populated community may include parents)
  // 3) healthFacility.location (synthesized HF location) or HF top-level fields
  Map<String, String> _resolveLocation() {
    // 1) case-level location (server synthesizes this as strings or populated refs)
    final dynamic caseLocRaw = caseData['location'];
    if (caseLocRaw is Map) {
      final region = _nameOf(caseLocRaw['region'], '');
      final district = _nameOf(caseLocRaw['district'], '');
      final subDistrict = _nameOf(caseLocRaw['subDistrict'], '');
      final community = _nameOf(caseLocRaw['community'], '');
      if (region.isNotEmpty || district.isNotEmpty || subDistrict.isNotEmpty || community.isNotEmpty) {
        return {
          'region': region,
          'district': district,
          'subDistrict': subDistrict,
          'community': community,
        };
      }
    }

    // 2) community-level information (populated community may carry parent refs)
    final dynamic comRaw = caseData['community'];
    if (comRaw is Map) {
      final community = _nameOf(comRaw, '');
      final region = _nameOf(comRaw['region'], '');
      final district = _nameOf(comRaw['district'], '');
      final subDistrict = _nameOf(comRaw['subDistrict'], '');
      if (community.isNotEmpty || region.isNotEmpty || district.isNotEmpty || subDistrict.isNotEmpty) {
        return {
          'region': region,
          'district': district,
          'subDistrict': subDistrict,
          'community': community,
        };
      }
    }

    // 3) healthFacility location
    final hf = caseData['healthFacility'];
    if (hf is Map) {
      // prefer explicit hf.location if present
      if (hf['location'] is Map) {
        final loc = Map<String, dynamic>.from(hf['location']);
        final region = _nameOf(loc['region'], '');
        final district = _nameOf(loc['district'], '');
        final subDistrict = _nameOf(loc['subDistrict'], '');
        final community = _nameOf(loc['community'], '');
        return {
          'region': region,
          'district': district,
          'subDistrict': subDistrict,
          'community': community,
        };
      }

      // fallback to top-level hf fields (could be populated refs or strings)
      final region = _nameOf(hf['region'], '');
      final district = _nameOf(hf['district'], '');
      final subDistrict = _nameOf(hf['subDistrict'], '');
      final community = _nameOf(hf['community'], '');
      return {
        'region': region,
        'district': district,
        'subDistrict': subDistrict,
        'community': community,
      };
    }

    // Default empty
    return {'region': '', 'district': '', 'subDistrict': '', 'community': ''};
  }

  @override
  Widget build(BuildContext context) {
    final patient = caseData['patient'] ?? {};
    final caseStatus = (caseData['status'] ?? 'unknown').toString();
    final patientStatus = (patient['status'] ?? 'Ongoing treatment').toString();

    // Resolve best-available location map
    final location = _resolveLocation();

    final timeline = (caseData['timeline'] ?? '').toString();
    final formattedTimeline = timeline.isNotEmpty
        ? DateFormat.yMMMMd().add_jm().format(DateTime.tryParse(timeline) ?? DateTime.now())
        : 'N/A';

    final ct = caseData['caseType'];
    final caseType = (ct is Map ? (ct['name'] ?? 'UNKNOWN') : 'UNKNOWN').toString().toUpperCase();

    // Determine community display: prefer case-level location.community, then case.community, then HF
    final caseLevelCommunity = (caseData['location'] is Map) ? _nameOf(caseData['location']['community'], '') : '';
    final caseCommunity = caseLevelCommunity.isNotEmpty
        ? caseLevelCommunity
        : (caseData['community'] != null ? _nameOf(caseData['community']) : '');

    final hf = caseData['healthFacility'];
    final facilityName = (hf is Map) ? (_nameOf(hf['name'], 'Unknown facility')) : 'Unknown facility';

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

    final subDistrictName = location['subDistrict'] ?? '';
    final districtName = location['district'] ?? '';
    final regionName = location['region'] ?? '';
    final communityName = caseCommunity.isNotEmpty ? caseCommunity : (location['community'] ?? '');

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
            // header row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => showEditOptions(context),
                  child: Text(
                    'EDIT',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade800,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            // grab handle
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

            // content
            infoBox('Case Type', caseType),
            infoBox('Case Status', caseStatus.toUpperCase()),

            if (caseStatus.toLowerCase() == 'suspected') ...[
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  showConfirmationDialog(
                    context,
                    'Are you sure you want to mark this case as CONFIRMED?',
                    () => onUpdate(caseData['_id'], 'confirmed'),
                  );
                },
                child: const Text('Confirm Case'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  showConfirmationDialog(
                    context,
                    'Are you sure this is not a valid case?',
                    () => onUpdate(caseData['_id'], 'not a case'),
                  );
                },
                child: const Text('Not a Case'),
              ),
            ],

            const SizedBox(height: 10),
            infoBox('Reported On', formattedTimeline),
            infoBox('Facility', facilityName),
            infoBox('Community', communityName.isNotEmpty ? communityName : 'Unknown'),

            if (subDistrictName.trim().isNotEmpty) infoBox('Sub-District', subDistrictName),

            infoBox('District', districtName.isNotEmpty ? districtName : 'Unknown'),
            infoBox('Region', regionName.isNotEmpty ? regionName : 'Unknown'),

            infoBox('Patient Name', (patient['name'] ?? 'Unknown').toString()),
            infoBox('Patient Status', patientStatus),

            if (patientStatus.toLowerCase() == 'ongoing treatment') ...[
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  showConfirmationDialog(
                    context,
                    'Confirm patient has recovered?',
                    () => onUpdate(caseData['_id'], null, 'Recovered'),
                  );
                },
                child: const Text('Mark as Recovered'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  showConfirmationDialog(
                    context,
                    'Confirm patient is deceased?',
                    () => onUpdate(caseData['_id'], null, 'Deceased'),
                  );
                },
                child: const Text('Mark as Deceased'),
              ),
            ],

            infoBox('Patient Age', '${patient['age'] ?? 'n/a'} yrs'),
            infoBox('Patient Gender', (patient['gender'] ?? 'n/a').toString()),
            infoBox('Patient Phone', (patient['phone'] ?? 'n/a').toString()),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
