// lib/features/attendance/attendance_history_page.dart
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/attendance_models.dart';
import '../../services/attendance_service.dart';
import '../../services/supabase_service.dart';

class AttendanceHistoryPage extends StatefulWidget {
  const AttendanceHistoryPage({super.key});

  @override
  State<AttendanceHistoryPage> createState() => _AttendanceHistoryPageState();
}

class _AttendanceHistoryPageState extends State<AttendanceHistoryPage> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final staffId = SupabaseService.instance.staffId;

    if (staffId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Attendance')),
        body: const Center(child: Text('You are not logged in.')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        elevation: 0.8,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: Colors.black,
        title: const Text('My Attendance',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        centerTitle: true,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: AttendanceService.instance.attendanceStream(staffId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          if (!snap.hasData || snap.data!.isEmpty) {
            return const Center(child: Text('No attendance record yet.'));
          }

          final allRows = snap.data!;
          final now = DateTime.now();
          final filteredRows = allRows.where((row) {
            if (_filter == 'All') return true;
            final dateStr = row['attendance_date'] as String? ??
                row['check_in_time'] as String? ??
                row['check_out_time'] as String?;
            if (dateStr == null) return false;
            final d = DateTime.tryParse(dateStr);
            if (d == null) return false;
            return d.year == now.year && d.month == now.month;
          }).toList();

          // Build DayRecords
          final records = filteredRows
              .map((d) => DayRecord.fromSupabase(d))
              .toList();

          int presentCount = 0;
          int absentCount = 0;
          int noRecordCount = 0;
          for (final r in records) {
            final s = r.status.toLowerCase();
            if (s.contains('present')) {
              presentCount++;
            } else if (s.contains('absent')) {
              absentCount++;
            } else if (s.contains('no record')) {
              noRecordCount++;
            }
          }

          return Column(
            children: [
              // Summary + filter + PDF
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Column(
                  children: [
                    _SummaryRow(
                      present: presentCount,
                      absent: absentCount,
                      noRecord: noRecordCount,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _FilterDropdown(
                            value: _filter,
                            onChanged: (v) => setState(() => _filter = v),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          height: 44,
                          child: ElevatedButton.icon(
                            onPressed: records.isEmpty
                                ? null
                                : () => _openPdf(context, records),
                            icon: const Icon(Icons.picture_as_pdf_rounded,
                                size: 18),
                            label: const Text('View / Print PDF',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),

              // Record list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: records.length,
                  itemBuilder: (context, index) {
                    final record = records[index];
                    return _DayCard(
                      record: record,
                      onTap: () => _openDetail(context, record),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openPdf(BuildContext context, List<DayRecord> records) {
    final svc = SupabaseService.instance;
    final staffName = svc.fullName.isNotEmpty ? svc.fullName : 'SmartBayu User';
    final staffEmail = svc.email;
    final rangeLabel = _filter == 'All' ? 'All records' : 'This month only';

    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AttendancePdfPreviewPage(
        staffName: staffName,
        staffEmail: staffEmail,
        rangeLabel: rangeLabel,
        records: records,
      ),
    ));
  }

  void _openDetail(BuildContext context, DayRecord record) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => _DayDetailSheet(record: record),
    );
  }
}

// ═══════════════════════ Widgets ═══════════════════════

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.present,
    required this.absent,
    required this.noRecord,
  });
  final int present, absent, noRecord;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        boxShadow: const [
          BoxShadow(
              color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Summary',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          Row(
            children: [
              _chip('Present', present, Colors.green),
              const SizedBox(width: 6),
              _chip('Absent', absent, Colors.red),
              const SizedBox(width: 6),
              _chip('No record', noRecord, Colors.orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.10),
      ),
      child: Row(
        children: [
          Text('$value',
              style: TextStyle(
                  fontWeight: FontWeight.w700, color: color, fontSize: 12)),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: color.withValues(alpha: 0.9))),
        ],
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        boxShadow: const [
          BoxShadow(
              color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: DropdownButton<String>(
        isExpanded: true,
        value: value,
        underline: const SizedBox.shrink(),
        icon: const Icon(Icons.expand_more),
        items: const [
          DropdownMenuItem(value: 'All', child: Text('All records')),
          DropdownMenuItem(
              value: 'This Month', child: Text('This month only')),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.record, required this.onTap});
  final DayRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(record.status);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Card(
        color: Colors.white,
        margin: const EdgeInsets.only(bottom: 12),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        elevation: 3,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: date + status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_prettyDate(record.workDate),
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: statusColor.withValues(alpha: 0.12),
                    ),
                    child: Text(record.status,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: statusColor)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),

              // First In / Last Out
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _TimeItem(
                    label: 'First In',
                    icon: Icons.login,
                    value: record.firstIn != null
                        ? _prettyTime(record.firstIn!)
                        : '-',
                  ),
                  _TimeItem(
                    label: 'Last Out',
                    icon: Icons.logout,
                    value: record.lastOut != null
                        ? _prettyTime(record.lastOut!)
                        : '-',
                  ),
                ],
              ),

              // Punch count badge
              if (record.punches.length > 2)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0EA5E9).withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${record.punches.length} punches (includes breaks)',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0EA5E9),
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 6),
              Text(record.geoText, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayDetailSheet extends StatelessWidget {
  const _DayDetailSheet({required this.record});
  final DayRecord record;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(record.status);

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.8,
      expand: false,
      builder: (ctx, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: ListView(
            controller: scrollController,
            children: [
              Text(_prettyDate(record.workDate),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 18)),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: statusColor.withValues(alpha: 0.12),
                ),
                child: Text(record.status,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: statusColor)),
              ),
              const SizedBox(height: 12),

              // Summary row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _TimeItem(
                    label: 'First In',
                    icon: Icons.login,
                    value: record.firstIn != null
                        ? _prettyTime(record.firstIn!)
                        : '-',
                  ),
                  _TimeItem(
                    label: 'Last Out',
                    icon: Icons.logout,
                    value: record.lastOut != null
                        ? _prettyTime(record.lastOut!)
                        : '-',
                  ),
                ],
              ),

              if (record.totalWorkMinutes != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Total work: ${_formatDuration(record.totalWorkMinutes!)} '
                  '(Break: ${_formatDuration(record.totalBreakMinutes)})',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],

              const SizedBox(height: 16),

              // Punch timeline
              if (record.punches.isNotEmpty) ...[
                const Text('Punch Timeline',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 8),
                ...List.generate(record.punches.length, (i) {
                  final p = record.punches[i];
                  final color = _punchTypeColor(p.type);
                  final icon = _punchTypeIcon(p.type);
                  final label = p.displayLabel(i);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle, color: color),
                        ),
                        const SizedBox(width: 10),
                        Icon(icon, size: 16, color: color),
                        const SizedBox(width: 6),
                        Text(label,
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: color)),
                        const SizedBox(width: 10),
                        Text(
                          p.time != null ? _prettyTime(p.time!) : '--:--',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        const SizedBox(width: 10),
                        Icon(
                          p.geoOk ? Icons.location_on : Icons.location_off,
                          size: 14,
                          color: p.geoOk ? Colors.green : Colors.red,
                        ),
                      ],
                    ),
                  );
                }),
              ] else ...[
                const SizedBox(height: 8),
                Text(record.geoText, style: const TextStyle(fontSize: 12)),
              ],

              const SizedBox(height: 12),
              const Text(
                'Tap "View / Print PDF" at the top for full reports.',
                style: TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TimeItem extends StatelessWidget {
  const _TimeItem(
      {required this.label, required this.icon, required this.value});
  final String label;
  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Text(value,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }
}

// ═══════════════════════ PDF ═══════════════════════

class AttendancePdfPreviewPage extends StatelessWidget {
  const AttendancePdfPreviewPage({
    super.key,
    required this.staffName,
    required this.staffEmail,
    required this.rangeLabel,
    required this.records,
  });

  final String staffName;
  final String? staffEmail;
  final String rangeLabel;
  final List<DayRecord> records;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Report',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: PdfPreview(
        build: (format) => generateAttendancePdf(
          staffName: staffName,
          staffEmail: staffEmail,
          rangeLabel: rangeLabel,
          records: records,
        ),
        pdfFileName: 'smartbayu_attendance.pdf',
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        maxPageWidth: 700,
      ),
    );
  }
}

Future<Uint8List> generateAttendancePdf({
  required String staffName,
  required String? staffEmail,
  required String rangeLabel,
  required List<DayRecord> records,
}) async {
  int presentCount = 0;
  int absentCount = 0;
  int noRecordCount = 0;

  for (final r in records) {
    final s = r.status.toLowerCase();
    if (s.contains('present')) {
      presentCount++;
    } else if (s.contains('absent')) {
      absentCount++;
    } else if (s.contains('no record')) {
      noRecordCount++;
    }
  }

  final smartBytes = await rootBundle.load('assets/logos/smartbayu_logo.png');
  final bayuBytes = await rootBundle.load('assets/logos/bayu_lestari_logo.png');
  final smartLogo = pw.MemoryImage(smartBytes.buffer.asUint8List());
  final bayuLogo = pw.MemoryImage(bayuBytes.buffer.asUint8List());

  final pdf = pw.Document();

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (ctx) {
        final rows = <pw.TableRow>[];

        rows.add(pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey800),
          children: [
            _pdfHeaderCell('Date'),
            _pdfHeaderCell('First In'),
            _pdfHeaderCell('Last Out'),
            _pdfHeaderCell('Punches'),
            _pdfHeaderCell('Work Hrs'),
            _pdfHeaderCell('Status'),
          ],
        ));

        for (final r in records) {
          final workMins = r.totalWorkMinutes;
          final workStr = workMins != null ? _formatDuration(workMins) : '-';

          rows.add(pw.TableRow(
            children: [
              _pdfCell(_prettyDate(r.workDate)),
              _pdfCell(r.firstIn != null ? _prettyTime(r.firstIn!) : '-'),
              _pdfCell(r.lastOut != null ? _prettyTime(r.lastOut!) : '-'),
              _pdfCell('${r.punches.length}'),
              _pdfCell(workStr),
              _pdfCell(r.status),
            ],
          ));
        }

        return [
          pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey500, width: 0.8),
            ),
            padding: const pw.EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Image(bayuLogo, height: 40),
                    pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.Text('ATTENDANCE REPORT',
                            style: pw.TextStyle(
                                fontSize: 16,
                                fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 2),
                        pw.Text('Bayu Lestari Resort',
                            style: const pw.TextStyle(fontSize: 10)),
                        pw.Text('Generated by SmartBayu',
                            style: pw.TextStyle(
                                fontSize: 9, color: PdfColors.grey700)),
                      ],
                    ),
                    pw.Image(smartLogo, height: 40),
                  ],
                ),
                pw.SizedBox(height: 12),
                pw.Divider(thickness: 0.8),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Employee Information',
                            style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 4),
                        pw.Text('Name      : $staffName',
                            style: const pw.TextStyle(fontSize: 9)),
                        if (staffEmail != null)
                          pw.Text('Email     : $staffEmail',
                              style: const pw.TextStyle(fontSize: 9)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Report Details',
                            style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 4),
                        pw.Text('Range     : $rangeLabel',
                            style: const pw.TextStyle(fontSize: 9)),
                        pw.Text(
                            'Generated : ${_prettyDate(DateTime.now())}',
                            style: const pw.TextStyle(fontSize: 9)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  'Summary   : Present $presentCount   -   Absent $absentCount   -   No record $noRecordCount',
                  style: pw.TextStyle(
                      fontSize: 9, color: PdfColors.grey800),
                ),
                pw.SizedBox(height: 14),
                pw.Table(
                  border: const pw.TableBorder(
                    horizontalInside: pw.BorderSide(
                        width: 0.25, color: PdfColors.grey300),
                    bottom: pw.BorderSide(
                        width: 0.5, color: PdfColors.grey400),
                  ),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2.0),
                    1: const pw.FlexColumnWidth(1.2),
                    2: const pw.FlexColumnWidth(1.2),
                    3: const pw.FlexColumnWidth(1.0),
                    4: const pw.FlexColumnWidth(1.2),
                    5: const pw.FlexColumnWidth(2.0),
                  },
                  children: rows,
                ),
                pw.SizedBox(height: 18),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    'This attendance report is generated automatically by SmartBayu.',
                    style: const pw.TextStyle(
                        fontSize: 8, color: PdfColors.grey600),
                  ),
                ),
              ],
            ),
          ),
        ];
      },
    ),
  );

  return pdf.save();
}

// ═══════════════════════ Helpers ═══════════════════════

String _prettyDate(DateTime d) {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} ${d.year}';
}

String _prettyTime(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.hour)}:${two(d.minute)}';
}

String _formatDuration(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h > 0 && m > 0) return '${h}h ${m}m';
  if (h > 0) return '${h}h';
  return '${m}m';
}

Color _statusColor(String status) {
  final s = status.toLowerCase();
  if (s.contains('present')) return Colors.green;
  if (s.contains('absent') || s.contains('no record')) return Colors.red;
  if (s.contains('break')) return Colors.orange;
  if (s.contains('late')) return Colors.orange;
  return Colors.blueGrey;
}

Color _punchTypeColor(PunchType type) {
  switch (type) {
    case PunchType.checkin:
      return Colors.green;
    case PunchType.breakStart:
      return Colors.orange;
    case PunchType.checkout:
      return Colors.red;
  }
}

IconData _punchTypeIcon(PunchType type) {
  switch (type) {
    case PunchType.checkin:
      return Icons.login_rounded;
    case PunchType.breakStart:
      return Icons.free_breakfast_rounded;
    case PunchType.checkout:
      return Icons.logout_rounded;
  }
}

pw.Widget _pdfHeaderCell(String text) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(5),
    child: pw.Text(text,
        style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white)),
  );
}

pw.Widget _pdfCell(String text) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(5),
    child: pw.Text(text, style: const pw.TextStyle(fontSize: 9)),
  );
}
