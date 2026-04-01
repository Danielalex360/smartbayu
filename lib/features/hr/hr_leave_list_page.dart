// lib/features/hr/hr_leave_list_page.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/supabase_service.dart';
import '../../services/company_service.dart';
import '../../services/notification_service.dart';

class HrLeaveListPage extends StatefulWidget {
  const HrLeaveListPage({super.key});

  @override
  State<HrLeaveListPage> createState() => _HrLeaveListPageState();
}

class _HrLeaveListPageState extends State<HrLeaveListPage> {
  String _statusFilter = 'All'; // All / Pending / Approved / Rejected
  String _staffFilter = 'All staff'; // All staff / specific staffName

  List<Map<String, dynamic>> _allLeaves = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLeaves();
  }

  Future<void> _loadLeaves() async {
    try {
      final companyId = SupabaseService.instance.companyId;
      if (companyId == null) return;

      final rows = await Supabase.instance.client
          .from('leave_records')
          .select('*, staff:staff_id(id, full_name)')
          .eq('company_id', companyId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _allLeaves = List<Map<String, dynamic>>.from(rows);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      debugPrint('Error loading leave records: $e');
    }
  }

  // ───────────────── Helper: format tarikh ─────────────────
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

  String _getStaffName(Map<String, dynamic> data) {
    final staffObj = data['staff'];
    if (staffObj is Map<String, dynamic>) {
      return (staffObj['full_name'] ?? 'Unknown Staff').toString();
    }
    return (data['staff_name'] ?? 'Unknown Staff').toString();
  }

  String _getStaffId(Map<String, dynamic> data) {
    return (data['staff_id'] ?? '').toString();
  }

  // ───────────────── Update status + hantar notification ─────────────────
  Future<void> _updateStatus(
      String leaveId,
      String newStatus,
      Map<String, dynamic> data,
      ) async {
    final controller = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          newStatus == 'approved' ? 'Approve Leave' : 'Reject Leave',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'HR Comment (optional)',
            hintText: 'Example: Approved – roster adjusted',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2ECC71),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    ) ??
        false;

    if (!ok) return;

    final comment = controller.text.trim();

    // Update leave record
    await Supabase.instance.client
        .from('leave_records')
        .update({
      'status': newStatus,
      'hr_notes': comment,
      'approved_by': SupabaseService.instance.staffId,
    })
        .eq('id', leaveId);

    // Send notification to staff
    final staffId = _getStaffId(data);

    if (staffId.isNotEmpty) {
      final startStr = data['start_date']?.toString();
      final endStr = data['end_date']?.toString();
      final dateText = _dateRangeText(startStr, endStr);

      final statusWord = newStatus == 'approved' ? 'approved' : 'rejected';
      final title =
      newStatus == 'approved' ? 'Leave Approved' : 'Leave Rejected';

      final message = comment.isNotEmpty
          ? 'Your leave request ($dateText) has been $statusWord.\nHR Note: $comment'
          : 'Your leave request ($dateText) has been $statusWord.';

      await NotificationService.instance.push(
        staffId: staffId,
        title: title,
        message: message,
        type: 'leave_status',
      );
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Leave ${newStatus == 'approved' ? 'approved' : 'rejected'}.',
        ),
      ),
    );

    _loadLeaves(); // refresh
  }

  // ───────────────────────── UI ─────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        elevation: 0.8,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: Colors.black,
        centerTitle: true,
        title: const Text(
          'HR – Leave Requests',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      backgroundColor: const Color(0xFFF5F5F7),
      body: Column(
        children: [
          // ───────── Top intro card ─────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF0EA5E9),
                    Color(0xFF22C55E),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0EA5E9).withOpacity(0.25),
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
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.supervisor_account_rounded,
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
                          'Leave centre',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withOpacity(0.85),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Review and approve staff leave requests.',
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

          // ───────── Content ─────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_allLeaves.isEmpty) {
      return const Center(child: Text('No leave requests found.'));
    }

    // Collect staff names for dropdown
    final staffNameSet = <String>{};
    for (final d in _allLeaves) {
      final name = _getStaffName(d).trim();
      if (name.isNotEmpty) staffNameSet.add(name);
    }
    final staffNames = staffNameSet.toList()..sort();

    // Apply filters
    var docs = _allLeaves.toList();

    // 1) Staff filter
    if (_staffFilter != 'All staff') {
      docs = docs.where((doc) {
        final name = _getStaffName(doc).trim();
        return name == _staffFilter;
      }).toList();
    }

    // 2) Status filter
    if (_statusFilter != 'All') {
      final target = _statusFilter.toLowerCase();
      docs = docs.where((doc) {
        final status = (doc['status'] ?? '').toString().toLowerCase();
        return status == target;
      }).toList();
    }

    // Summary counts
    int pending = 0, approved = 0, rejected = 0;
    for (final d in docs) {
      final status = (d['status'] ?? 'pending').toString().toLowerCase();
      if (status == 'approved') {
        approved++;
      } else if (status == 'rejected') {
        rejected++;
      } else {
        pending++;
      }
    }

    return Column(
      children: [
        // ───────── Filter card (Staff + Status) ─────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'All staff leave',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // Staff dropdown
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: const Color(0xFFF1F1F1),
                        ),
                        child: DropdownButton<String>(
                          isExpanded: true,
                          isDense: true,
                          borderRadius: BorderRadius.circular(12),
                          dropdownColor: Colors.white,
                          underline: const SizedBox.shrink(),
                          value: _staffFilter,
                          items: [
                            const DropdownMenuItem(
                              value: 'All staff',
                              child: Text('All staff'),
                            ),
                            ...staffNames.map(
                                  (name) => DropdownMenuItem(
                                value: name,
                                child: Text(name),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _staffFilter = value);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Status dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: const Color(0xFFF1F1F1),
                      ),
                      child: DropdownButton<String>(
                        isDense: true,
                        borderRadius: BorderRadius.circular(12),
                        dropdownColor: Colors.white,
                        underline: const SizedBox.shrink(),
                        value: _statusFilter,
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
              ],
            ),
          ),
        ),

        // ───────── Summary pills ─────────
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          child: _StatusSummaryRow(
            pending: pending,
            approved: approved,
            rejected: rejected,
          ),
        ),
        const SizedBox(height: 4),

        // ───────── List leave requests ─────────
        Expanded(
          child: docs.isEmpty
              ? const Center(
            child: Text('No leave requests for this filter.'),
          )
              : RefreshIndicator(
            onRefresh: _loadLeaves,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index];
                final leaveId = data['id'].toString();

                final staffName = _getStaffName(data);
                final staffUid = _getStaffId(data);
                final leaveType = (data['leave_type'] ?? 'Leave').toString();
                final reason = (data['reason'] ?? '').toString();
                final status = (data['status'] ?? 'pending').toString().toLowerCase();
                final startStr = data['start_date']?.toString();
                final endStr = data['end_date']?.toString();
                final createdAt = data['created_at']?.toString();
                final createdStr = createdAt ?? '-';
                final statusLabel = status.isNotEmpty
                    ? status[0].toUpperCase() + status.substring(1)
                    : 'Pending';
                final hrComment = (data['hr_notes'] ?? '').toString();

                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      builder: (ctx) => LeaveDetailSheet(
                        staffName: staffName,
                        staffUid: staffUid,
                        siteName: CompanyService.instance.siteName,
                        leaveType: leaveType,
                        reason: reason,
                        statusLabel: statusLabel,
                        statusColor: _statusColor(statusLabel),
                        dateRangeText: _dateRangeText(startStr, endStr),
                        createdStr: createdStr,
                        hrComment: hrComment,
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // coloured strip on top
                        Container(
                          height: 3,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                _statusColor(statusLabel),
                                _statusColor(statusLabel).withOpacity(0.6),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          staffName,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '$leaveType • ${CompanyService.instance.siteName}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.withOpacity(0.9),
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
                                      color: _statusColor(statusLabel).withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      statusLabel,
                                      style: TextStyle(
                                        color: _statusColor(statusLabel),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              const Divider(height: 1),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_today_rounded,
                                    size: 16,
                                    color: Colors.black87,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _dateRangeText(startStr, endStr),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              if (reason.isNotEmpty)
                                Text(
                                  reason,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              const SizedBox(height: 4),
                              Text(
                                'Applied at: $createdStr',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (status == 'pending')
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () => _updateStatus(
                                          leaveId,
                                          'approved',
                                          data,
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF22C55E),
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                        ),
                                        icon: const Icon(Icons.check, size: 18),
                                        label: const Text(
                                          'Approve',
                                          style: TextStyle(fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => _updateStatus(
                                          leaveId,
                                          'rejected',
                                          data,
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(color: Color(0xFFE74C3C)),
                                          foregroundColor: const Color(0xFFE74C3C),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                        ),
                                        icon: const Icon(Icons.close, size: 18),
                                        label: const Text(
                                          'Reject',
                                          style: TextStyle(fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ───────────────── Summary pills (Pending / Approved / Rejected) ─────────────────

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

// ───────────────── Bottom sheet detail untuk leave ─────────────────

class LeaveDetailSheet extends StatelessWidget {
  final String staffName;
  final String staffUid;
  final String siteName;
  final String leaveType;
  final String reason;
  final String statusLabel;
  final Color statusColor;
  final String dateRangeText;
  final String createdStr;
  final String hrComment;

  const LeaveDetailSheet({
    super.key,
    required this.staffName,
    required this.staffUid,
    required this.siteName,
    required this.leaveType,
    required this.reason,
    required this.statusLabel,
    required this.statusColor,
    required this.dateRangeText,
    required this.createdStr,
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        staffName,
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
                    color: statusColor.withOpacity(0.12),
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
            const SizedBox(height: 12),
            Text(
              '$leaveType • $siteName',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
              ),
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

