// lib/features/leave/my_leave_list_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/supabase_service.dart';

class MyLeaveListPage extends StatefulWidget {
  const MyLeaveListPage({super.key});

  @override
  State<MyLeaveListPage> createState() => _MyLeaveListPageState();
}

class _MyLeaveListPageState extends State<MyLeaveListPage> {
  String _statusFilter = 'All'; // All / Pending / Approved / Rejected

  // ───────────── Helpers ─────────────

  String _dateRangeText(String? startStr, String? endStr) {
    if (startStr == null || endStr == null) return '-';
    try {
      final s = DateTime.parse(startStr);
      final e = DateTime.parse(endStr);
      String two(int n) => n.toString().padLeft(2, '0');
      String d(DateTime d) => '${two(d.day)}/${two(d.month)}/${d.year}';
      return '${d(s)}  →  ${d(e)}';
    } catch (_) {
      return '-';
    }
  }

  Color _statusColor(String status) {
    final s = status.toLowerCase();
    if (s == 'pending') return Colors.orange;
    if (s == 'approved') return const Color(0xFF00A86B);
    if (s == 'rejected') return Colors.red;
    return Colors.blueGrey;
  }

  Stream<List<Map<String, dynamic>>> _myLeaveStream() {
    final staffId = SupabaseService.instance.staffId;
    if (staffId == null) {
      return const Stream<List<Map<String, dynamic>>>.empty();
    }

    return Supabase.instance.client
        .from('leave_records')
        .stream(primaryKey: ['id'])
        .eq('staff_id', staffId)
        .order('created_at', ascending: false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        elevation: 0.8,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: Colors.black,
        title: const Text(
          'My Leave',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ───── Top summary card (static intro) ─────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF00A86B),
                      Color(0xFF03C98B),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00A86B).withValues(alpha: 0.25),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.beach_access_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Leave overview',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Track all your leave requests here.',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ───── Filter bar (iOS vibe: chip in pill) ─────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'My requests',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: DropdownButton<String>(
                      isDense: true,
                      borderRadius: BorderRadius.circular(16),
                      underline: const SizedBox.shrink(),
                      value: _statusFilter,
                      icon: const Icon(
                        Icons.expand_more_rounded,
                        size: 18,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'All',
                          child: Text('All'),
                        ),
                        DropdownMenuItem(
                          value: 'Pending',
                          child: Text('Pending'),
                        ),
                        DropdownMenuItem(
                          value: 'Approved',
                          child: Text('Approved'),
                        ),
                        DropdownMenuItem(
                          value: 'Rejected',
                          child: Text('Rejected'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _statusFilter = value);
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 4),

            // ───── List + dynamic summary ─────
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _myLeaveStream(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(
                      child: Text('Error: ${snap.error}'),
                    );
                  }
                  if (!snap.hasData || snap.data!.isEmpty) {
                    return _EmptyStateWidget(onApplyTap: () {
                      Navigator.of(context)
                          .pop(); // balik, user boleh tekan Apply Leave di home
                    });
                  }

                  final allDocs = snap.data!;

                  // Kira summary status
                  int pending = 0, approved = 0, rejected = 0;
                  for (final d in allDocs) {
                    final status =
                    (d['status'] ?? 'pending').toString().toLowerCase();
                    if (status == 'approved') {
                      approved++;
                    } else if (status == 'rejected') {
                      rejected++;
                    } else {
                      pending++;
                    }
                  }

                  var docs = allDocs.toList();

                  // Filter ikut status
                  if (_statusFilter != 'All') {
                    final target = _statusFilter.toLowerCase();
                    docs = docs.where((data) {
                      final status =
                      (data['status'] ?? '').toString().toLowerCase();
                      return status == target;
                    }).toList();
                  }

                  if (docs.isEmpty) {
                    return const Center(
                      child: Text('No leave requests for this filter.'),
                    );
                  }

                  return Column(
                    children: [
                      // small iOS-style summary bar
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        child: _StatusSummaryRow(
                          pending: pending,
                          approved: approved,
                          rejected: rejected,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final data = docs[index];

                            final leaveType =
                            (data['leave_type'] ?? 'Leave').toString();
                            final status =
                            (data['status'] ?? 'pending').toString().toLowerCase();
                            final reason = (data['reason'] ?? '').toString();
                            final startStr = data['start_date']?.toString();
                            final endStr = data['end_date']?.toString();
                            final createdAt = data['created_at']?.toString();
                            final createdStr = createdAt != null
                                ? DateTime.tryParse(createdAt)
                                    ?.toLocal()
                                    .toString()
                                    .substring(0, 19) ?? '-'
                                : '-';
                            final hrComment =
                            (data['hr_notes'] ?? '').toString();

                            final statusLabel = status.isNotEmpty
                                ? status[0].toUpperCase() + status.substring(1)
                                : 'Pending';

                            // ───── Card + onTap → bottom sheet ─────
                            return InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(20),
                                    ),
                                  ),
                                  builder: (ctx) => MyLeaveDetailSheet(
                                    leaveType: leaveType,
                                    statusLabel: statusLabel,
                                    statusColor: _statusColor(statusLabel),
                                    dateRangeText:
                                    _dateRangeText(startStr, endStr),
                                    createdStr: createdStr,
                                    reason: reason,
                                    hrComment: hrComment,
                                  ),
                                );
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                      Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(18),
                                  child: Column(
                                    children: [
                                      // top coloured strip
                                      Container(
                                        height: 4,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              _statusColor(statusLabel),
                                              _statusColor(statusLabel)
                                                  .withValues(alpha: 0.6),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                            14, 12, 14, 14),
                                        child: Column(
                                          crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                          children: [
                                            // header row
                                            Row(
                                              crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                              children: [
                                                Container(
                                                  padding:
                                                  const EdgeInsets.all(8),
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                        0xFF00A86B)
                                                        .withValues(
                                                        alpha: 0.06),
                                                    borderRadius:
                                                    BorderRadius.circular(
                                                        12),
                                                  ),
                                                  child: const Icon(
                                                    Icons.event_note_rounded,
                                                    size: 20,
                                                    color: Color(0xFF00A86B),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                    CrossAxisAlignment
                                                        .start,
                                                    children: [
                                                      Text(
                                                        leaveType,
                                                        style: const TextStyle(
                                                          fontSize: 15,
                                                          fontWeight:
                                                          FontWeight.w700,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 10,
                                                    vertical: 4,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: _statusColor(
                                                        statusLabel)
                                                        .withValues(
                                                        alpha: 0.12),
                                                    borderRadius:
                                                    BorderRadius.circular(
                                                        999),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                    MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        status == 'approved'
                                                            ? Icons
                                                            .check_circle
                                                            : status ==
                                                            'rejected'
                                                            ? Icons
                                                            .cancel_rounded
                                                            : Icons
                                                            .schedule_rounded,
                                                        size: 14,
                                                        color: _statusColor(
                                                            statusLabel),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        statusLabel,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                          FontWeight.w600,
                                                          color: _statusColor(
                                                              statusLabel),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),

                                            const SizedBox(height: 10),
                                            const Divider(height: 1),
                                            const SizedBox(height: 8),

                                            // date range
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons
                                                      .calendar_today_rounded,
                                                  size: 16,
                                                  color: Colors.black87,
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    _dateRangeText(
                                                        startStr, endStr),
                                                    style: const TextStyle(
                                                      fontWeight:
                                                      FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),

                                            if (reason.isNotEmpty) ...[
                                              const SizedBox(height: 6),
                                              Text(
                                                reason,
                                                style: const TextStyle(
                                                    fontSize: 13),
                                              ),
                                            ],

                                            const SizedBox(height: 6),
                                            Text(
                                              'Applied at: $createdStr',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty state bila user belum pernah apply cuti
class _EmptyStateWidget extends StatelessWidget {
  final VoidCallback onApplyTap;
  const _EmptyStateWidget({required this.onApplyTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: const Color(0xFF00A86B).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.free_cancellation_rounded,
                size: 48,
                color: Color(0xFF00A86B),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No leave requests yet',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'When you apply for leave, it will appear here so you can track the status easily.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onApplyTap,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF00A86B),
                padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: const Text(
                'Apply Leave',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Summary row (Pending / Approved / Rejected) - iOS style pills
class _StatusSummaryRow extends StatelessWidget {
  const _StatusSummaryRow({
    required this.pending,
    required this.approved,
    required this.rejected,
  });

  final int pending;
  final int approved;
  final int rejected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _SummaryPill(
          label: 'Pending',
          count: pending,
          bg: const Color(0xFFFFF7ED),
          fg: const Color(0xFFF97316),
          icon: Icons.hourglass_bottom_rounded,
        ),
        const SizedBox(width: 8),
        _SummaryPill(
          label: 'Approved',
          count: approved,
          bg: const Color(0xFFECFDF3),
          fg: const Color(0xFF16A34A),
          icon: Icons.check_circle_rounded,
        ),
        const SizedBox(width: 8),
        _SummaryPill(
          label: 'Rejected',
          count: rejected,
          bg: const Color(0xFFFEF2F2),
          fg: const Color(0xFFDC2626),
          icon: Icons.cancel_rounded,
        ),
      ],
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({
    required this.label,
    required this.count,
    required this.bg,
    required this.fg,
    required this.icon,
  });

  final String label;
  final int count;
  final Color bg;
  final Color fg;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: fg,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet detail untuk "My Leave" (staff view)
class MyLeaveDetailSheet extends StatelessWidget {
  final String leaveType;
  final String statusLabel;
  final Color statusColor;
  final String dateRangeText;
  final String createdStr;
  final String reason;
  final String hrComment;

  const MyLeaveDetailSheet({
    super.key,
    required this.leaveType,
    required this.statusLabel,
    required this.statusColor,
    required this.dateRangeText,
    required this.createdStr,
    required this.reason,
    required this.hrComment,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // drag handle
            Center(
              child: Container(
                width: 50,
                height: 5,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

            // status + type
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        leaveType,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.calendar_month, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    dateRangeText,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.access_time, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Applied at: $createdStr',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Text(
              'Reason',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              reason.isEmpty ? '-' : reason,
              style: const TextStyle(fontSize: 13),
            ),

            if (hrComment.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'HR Comment',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                hrComment,
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
