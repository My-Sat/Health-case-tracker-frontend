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
            infoBox('Case Type', caseData['caseType'].toString().toUpperCase()),
            infoBox('Case Status', caseStatus.toUpperCase()),
            if (caseStatus == 'suspected') ...[
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  onUpdate(caseData['_id'], 'confirmed');
                },
                child: Text('Confirm Case'),
              ),
              SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  onUpdate(caseData['_id'], 'rule-out');
                },
                child: Text('Rule Out Case'),
              ),
            ],
            SizedBox(height: 10),
            infoBox('Reported On', formattedTimeline),
            infoBox('Facility', caseData['healthFacility']['name']),
            infoBox('Region', location['region']),
            infoBox('District', location['district']),
            infoBox('Community', location['community']),
            infoBox('Patient Name', patient['name']),
            infoBox('Patient Status', patientStatus),
            if (patientStatus == 'Ongoing treatment') ...[
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  onUpdate(caseData['_id'], null, 'Recovered');
                },
                child: Text('Mark as Recovered'),
              ),
              SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  onUpdate(caseData['_id'], null, 'Deceased');
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
