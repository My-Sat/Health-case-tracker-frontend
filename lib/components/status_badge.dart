import 'package:flutter/material.dart';


Widget statusBadge(String label, Color bgColor) {
  return Container(
    padding: EdgeInsets.symmetric(vertical: 4, horizontal: 10),
    margin: EdgeInsets.only(top: 6),
    decoration: BoxDecoration(
      color: bgColor.withOpacity(0.1),
      border: Border.all(color: bgColor),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(
      label.toUpperCase(),
      style: TextStyle(color: bgColor, fontWeight: FontWeight.bold),
    ),
  );
}


Color getStatusColor(String status) {
  switch (status.toLowerCase()) {
    case 'suspected':
      return Colors.blue;
    case 'confirmed':
      return Colors.red;
    case 'not a case':
      return Colors.green;
    case 'recovered':
      return Colors.green;
    case 'ongoing treatment':
      return Colors.orange;
    case 'deceased':
      return Colors.black;
    default:
      return Colors.grey;
  }
}
