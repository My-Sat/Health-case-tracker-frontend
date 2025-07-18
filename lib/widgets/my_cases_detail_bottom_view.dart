import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CaseDetailBottomSheet extends StatelessWidget {
  final Map<String, dynamic> caseData;
  final Function(String caseId, [String? status, String? patientStatus]) onUpdate;

  const CaseDetailBottomSheet({
    required this.caseData,
    required this.onUpdate,
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
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
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
            infoBox('Community', location['community']),
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
