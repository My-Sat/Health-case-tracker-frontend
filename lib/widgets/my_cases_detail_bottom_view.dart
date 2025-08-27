// lib/widgets/my_cases_detail_bottom_view.dart
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
    final patientStatus = (patient['status'] ?? 'Ongoing treatment').toString();

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
            infoBox('Facility', hf is Map ? (hf['name'] ?? 'Unknown facility').toString() : 'Unknown facility'),
            infoBox('Community', communityName),

            if ((location?['subDistrict'] ?? '').toString().trim().isNotEmpty)
              infoBox('Sub-District', _nameOf(location?['subDistrict'])),

            infoBox('District', _nameOf(location?['district'])),
            infoBox('Region', _nameOf(location?['region'])),

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
