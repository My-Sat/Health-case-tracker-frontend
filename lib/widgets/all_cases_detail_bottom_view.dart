import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CaseViewBottomSheet extends StatelessWidget {
  final Map<String, dynamic> caseData;

  const CaseViewBottomSheet({required this.caseData, super.key});

  @override
  Widget build(BuildContext context) {
    final patient = caseData['patient'];
    final status = caseData['status'];
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
            infoBox('Case Status', status.toUpperCase()),
            infoBox('Reported On', formattedTimeline),
            infoBox('Facility', caseData['healthFacility']['name']),
            infoBox('Community', location['community']),
            if (location['subDistrict'] != null && location['subDistrict'].toString().trim().isNotEmpty)
              infoBox('Sub-District', location['subDistrict']),
            infoBox('District', location['district']),
            infoBox('Region', location['region']),
            infoBox('Reported By', caseData['officer']['fullName']),
            infoBox('Patient Age', '${patient['age']} yrs'),
            infoBox('Patient Gender', patient['gender']),
            infoBox('Patient Status', patient['status']),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
