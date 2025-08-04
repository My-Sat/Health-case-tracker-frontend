import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../screens/edit_case_screen.dart';

class CaseDetailBottomSheet extends StatelessWidget {
  final Map<String, dynamic> caseData;
  final Function(String caseId, [String? status, String? patientStatus]) onUpdate;
  final VoidCallback? onRefresh; // ✅ new optional refresh callback

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
        title: Text('Please Confirm'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel'),
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
            child: Text('Confirm'),
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
              leading: Icon(Icons.edit, color: Colors.grey),
              title: Text('Edit Case Details'),
              onTap: () {
                Navigator.pop(ctx); // close edit options bottom sheet
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => EditCaseScreen(caseData: caseData)),
                ).then((needRefresh) {
                  if (needRefresh == true) {
                    // ignore: use_build_context_synchronously
                    Navigator.pop(context);
                    onRefresh?.call(); // ✅ safe refresh after edit
                  }
                });
              },
            ),
            ListTile(
              leading: Icon(Icons.archive, color: Colors.orange),
              title: Text('Archive Case'),
              onTap: () {
                Navigator.pop(ctx);
                showConfirmationDialog(
                  context,
                  'Are you sure you want to archive this case?',
                  () {
                    Navigator.pop(context); // Close bottom sheet
                    onUpdate(caseData['_id'], 'archived');
                  },
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Colors.red),
              title: Text('Delete Case'),
              onTap: () {
                Navigator.pop(ctx);
                showConfirmationDialog(
                  context,
                  'Are you sure you want to permanently delete this case?',
                  () {
                    Navigator.pop(context); // Closes main bottom sheet
                    onUpdate(caseData['_id'], 'deleted');
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final patient = caseData['patient'];
    final caseStatus = caseData['status'];
    final patientStatus = patient['status'];
    final location = caseData['healthFacility']['location'];
    final timeline = caseData['timeline'] ?? '';
    final formattedTimeline = timeline.isNotEmpty
        ? DateFormat.yMMMMd().add_jm().format(DateTime.parse(timeline))
        : 'N/A';
    final caseType = (caseData['caseType']['name'] ?? 'UNKNOWN').toString().toUpperCase();
    final community = caseData['community']?.toString().trim().isNotEmpty == true
        ? caseData['community']
        : location['community'];

    Widget infoBox(String label, String value) {
      return Container(
        margin: EdgeInsets.symmetric(vertical: 4),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          '$label: $value',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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
              icon: Icon(Icons.close),
              tooltip: 'Close',
              onPressed: () => Navigator.pop(context),
            ),
            ],
            ),
            Center(
              child: Container(
                width: 50,
                height: 5,
                margin: EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            infoBox('Case Type', caseType),
            infoBox('Case Status', caseStatus.toUpperCase()),
            if (caseStatus == 'suspected') ...[
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  showConfirmationDialog(
                    context,
                    'Are you sure you want to mark this case as CONFIRMED?',
                    () => onUpdate(caseData['_id'], 'confirmed'),
                  );
                },
                child: Text('Confirm Case'),
              ),
              SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  showConfirmationDialog(
                    context,
                    'Are you sure this is not a valid case?',
                    () => onUpdate(caseData['_id'], 'not a case'),
                  );
                },
                child: Text('Not a Case'),
              ),
            ],
            SizedBox(height: 10),
            infoBox('Reported On', formattedTimeline),
            infoBox('Facility', caseData['healthFacility']['name']),
            infoBox('Community', community),
            if (location['subDistrict'] != null && location['subDistrict'].toString().trim().isNotEmpty)
              infoBox('Sub-District', location['subDistrict']),
            infoBox('District', location['district']),
            infoBox('Region', location['region']),
            infoBox('Patient Name', patient['name']),
            infoBox('Patient Status', patientStatus),
            if (patientStatus == 'Ongoing treatment') ...[
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  showConfirmationDialog(
                    context,
                    'Confirm patient has recovered?',
                    () => onUpdate(caseData['_id'], null, 'Recovered'),
                  );
                },
                child: Text('Mark as Recovered'),
              ),
              SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  showConfirmationDialog(
                    context,
                    'Confirm patient is deceased?',
                    () => onUpdate(caseData['_id'], null, 'Deceased'),
                  );
                },
                child: Text('Mark as Deceased'),
              ),
            ],
            infoBox('Patient Age', '${patient['age']} yrs'),
            infoBox('Patient Gender', patient['gender']),
            infoBox('Patient Phone', patient['phone']),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
