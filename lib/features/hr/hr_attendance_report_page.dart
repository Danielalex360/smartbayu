// lib/features/hr/hr_attendance_report_page.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/supabase_service.dart';
import '../../services/attendance_service.dart';
import '../attendance/attendance_history_page.dart';

class HrAttendanceReportPage extends StatefulWidget {
  const HrAttendanceReportPage({super.key});

  @override
  State<HrAttendanceReportPage> createState() =>
      _HrAttendanceReportPageState();
}

class _HrAttendanceReportPageState extends State<HrAttendanceReportPage> {
  String? _selectedStaffId;
  String? _selectedMonth;

  List<Map<String, dynamic>> _staffList = [];
  bool _loadingStaff = true;

  final months = [
    'All',
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  @override
  void initState() {
    super.initState();
    _loadStaffList();
  }

  Future<void> _loadStaffList() async {
    try {
      final companyId = SupabaseService.instance.companyId;
      if (companyId == null) return;

      final rows = await Supabase.instance.client
          .from('staff')
          .select('id, full_name, email')
          .eq('company_id', companyId)
          .order('full_name', ascending: true);

      if (mounted) {
        setState(() {
          _staffList = List<Map<String, dynamic>>.from(rows);
          _loadingStaff = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingStaff = false);
      debugPrint('Error loading staff list: $e');
    }
  }

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
            _loadingStaff
                ? const CircularProgressIndicator()
                : DropdownButtonFormField<String>(
              isExpanded: true,
              value: _selectedStaffId,
              items: _staffList.map((d) {
                final name = d['full_name'] ?? 'Unknown';
                return DropdownMenuItem(
                    value: d['id'] as String, child: Text(name));
              }).toList(),
              onChanged: (v) => setState(() => _selectedStaffId = v),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
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
                onPressed: _selectedStaffId == null
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
    final staffId = _selectedStaffId!;
    final month = _selectedMonth;

    // Determine month filter
    int? filterMonth;
    if (month != null && month != 'All') {
      filterMonth = months.indexOf(month); // Jan=1, Feb=2, etc.
    }

    // Use AttendanceService — returns DayRecord with full punches
    final records = await AttendanceService.instance.fetchAttendance(
      staffId,
      filterMonth: filterMonth,
    );

    // Get staff details from the list
    final staffData = _staffList.firstWhere(
          (s) => s['id'] == staffId,
      orElse: () => {'full_name': 'Staff', 'email': ''},
    );
    final staffName = staffData['full_name'] ?? 'Staff';
    final staffEmail = staffData['email'] ?? '';

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
