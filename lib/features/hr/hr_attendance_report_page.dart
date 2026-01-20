// lib/features/hr/hr_attendance_report_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/attendance_service.dart';
import '../attendance/attendance_history_page.dart';

class HrAttendanceReportPage extends StatefulWidget {
  const HrAttendanceReportPage({super.key});

  @override
  State<HrAttendanceReportPage> createState() =>
      _HrAttendanceReportPageState();
}

class _HrAttendanceReportPageState extends State<HrAttendanceReportPage> {
  String? _selectedStaffUid;
  String? _selectedMonth;

  final months = [
    'All',
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HR Attendance Report'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select Staff',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) return const CircularProgressIndicator();
                final docs = snap.data!.docs;
                return DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: _selectedStaffUid,
                  items: docs.map((d) {
                    final name = d['name'] ?? d['displayName'] ?? 'Unknown';
                    return DropdownMenuItem(value: d.id, child: Text(name));
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedStaffUid = v),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            const Text('Select Month',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: _selectedMonth,
              items: months
                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedMonth = v),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Generate Attendance Report',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: _selectedStaffUid == null
                    ? null
                    : () => _openStaffReport(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openStaffReport(BuildContext context) async {
    final uid = _selectedStaffUid!;
    final month = _selectedMonth;

    // Determine month filter
    int? filterMonth;
    if (month != null && month != 'All') {
      filterMonth = months.indexOf(month); // Jan=1, Feb=2, etc.
    }

    // Use AttendanceService — returns DayRecord with full punches
    final records = await AttendanceService.instance.fetchAttendance(
      uid,
      filterMonth: filterMonth,
    );

    // Get staff details
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final staffName = userDoc['name'] ?? userDoc['displayName'] ?? 'Staff';
    final staffEmail = userDoc['email'] ?? '';

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AttendancePdfPreviewPage(
          staffName: staffName,
          staffEmail: staffEmail,
          rangeLabel: month ?? 'All',
          records: records,
        ),
      ),
    );
  }
}
