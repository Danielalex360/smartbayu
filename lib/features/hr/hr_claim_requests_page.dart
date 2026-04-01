// lib/features/hr/hr_claim_requests_page.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/supabase_service.dart';
import '../../services/notification_service.dart';

class HrClaimRequestsPage extends StatefulWidget {
  const HrClaimRequestsPage({super.key});

  @override
  State<HrClaimRequestsPage> createState() => _HrClaimRequestsPageState();
}

class _HrClaimRequestsPageState extends State<HrClaimRequestsPage> {
  String _statusFilter = 'All';

  List<Map<String, dynamic>> _allClaims = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadClaims();
  }

  Future<void> _loadClaims() async {
    try {
      final companyId = SupabaseService.instance.companyId;
      if (companyId == null) return;

      final rows = await Supabase.instance.client
          .from('staff_claims')
          .select('*, staff:staff_id(id, full_name)')
          .eq('company_id', companyId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _allClaims = List<Map<String, dynamic>>.from(rows);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      debugPrint('Error loading claims: $e');
    }
  }

  Color _statusColor(String status) {
    final s = status.toLowerCase();
    if (s == 'pending') return const Color(0xFFF59E0B);
    if (s == 'approved') return const Color(0xFF16A34A);
    if (s == 'rejected') return const Color(0xFFDC2626);
    return Colors.blueGrey;
  }

  String _formatDate(String? isoStr) {
    if (isoStr == null) return '-';
    try {
      final d = DateTime.parse(isoStr);
      String two(int n) => n.toString().padLeft(2, '0');
      return '${two(d.day)}/${two(d.month)}/${d.year}';
    } catch (_) {
      return '-';
    }
  }

  String _formatDateTime(String? isoStr) {
    if (isoStr == null) return '-';
    try {
      final d = DateTime.parse(isoStr);
      String two(int n) => n.toString().padLeft(2, '0');
      final date = '${two(d.day)}/${two(d.month)}/${d.year}';
      final time = '${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
      return '$date $time';
    } catch (_) {
      return '-';
    }
  }

  String _getStaffName(Map<String, dynamic> data) {
    final staffObj = data['staff'];
    if (staffObj is Map<String, dynamic>) {
      return (staffObj['full_name'] ?? 'Unknown Staff').toString();
    }
    return (data['staff_name'] ?? 'Unknown Staff').toString();
  }

  Future<void> _updateStatus(
      String claimId,
      String newStatus,
      Map<String, dynamic> data,
      ) async {
    final controller = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          newStatus == 'approved' ? 'Approve Claim' : 'Reject Claim',
        ),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'HR Comment (optional)',
            hintText: 'Example: Approved – within policy',
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
            child: const Text('Confirm'),
          ),
        ],
      ),
    ) ??
        false;

    if (!ok) return;

    final comment = controller.text.trim();

    // 1) Update status in Supabase
    await Supabase.instance.client
        .from('staff_claims')
        .update({
      'status': newStatus,
      'hr_notes': comment,
      'approved_by': SupabaseService.instance.staffId,
    })
        .eq('id', claimId);

    // 2) Send notification to staff
    try {
      final staffId = (data['staff_id'] ?? '').toString();
      final claimType = (data['claim_type'] ?? 'Claim').toString();

      final num amountRaw = (data['amount'] ?? 0) as num;
      final amountStr = amountRaw.toStringAsFixed(2);

      final claimDateStr = data['claim_date']?.toString();
      final dateText = _formatDate(claimDateStr);

      final statusText = newStatus == 'approved' ? 'approved' : 'rejected';

      if (staffId.isNotEmpty) {
        final msgBuffer = StringBuffer()
          ..write(
              'Your $claimType claim (RM $amountStr) on $dateText has been $statusText by HR.');
        if (comment.isNotEmpty) {
          msgBuffer.write(' HR Note: $comment');
        }

        final messageText = msgBuffer.toString();

        await NotificationService.instance.push(
          staffId: staffId,
          type: 'claim',
          title: newStatus == 'approved' ? 'Claim Approved' : 'Claim Rejected',
          message: messageText,
        );

        await NotificationService.instance.showLocal(
          title: newStatus == 'approved' ? 'Claim Approved' : 'Claim Rejected',
          body: messageText,
          data: {
            'screen': 'claims',
            'staffId': staffId,
          },
        );
      }
    } catch (e, st) {
      debugPrint('[HR Claim] Failed to send claim notification: $e');
      debugPrint(st.toString());
    }

    // 3) SnackBar feedback
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Claim ${newStatus == 'approved' ? 'approved' : 'rejected'}.',
        ),
      ),
    );

    _loadClaims(); // refresh
  }

  void _showClaimDetailSheet(Map<String, dynamic> data) {
    final staffName = _getStaffName(data);
    final staffUid = (data['staff_id'] ?? '').toString();
    final claimType = (data['claim_type'] ?? 'Claim').toString();
    final num amountRaw = (data['amount'] ?? 0) as num;
    final amountStr = amountRaw.toStringAsFixed(2);
    final note = (data['description'] ?? data['note'] ?? '').toString();
    final status = (data['status'] ?? 'pending').toString().toLowerCase();
    final statusLabel =
    status.isNotEmpty ? status[0].toUpperCase() + status.substring(1) : '';
    final claimDateStr = data['claim_date']?.toString();
    final createdAtStr = data['created_at']?.toString();
    final receiptUrl = (data['receipt_url'] ?? '').toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          builder: (_, controller) {
            return Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 20).copyWith(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.receipt_long_rounded,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                      const SizedBox(width: 12),
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
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _statusColor(statusLabel).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _statusColor(statusLabel),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '$claimType • RM $amountStr',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView(
                      controller: controller,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 18, color: Colors.black87),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Claim date', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                Text(_formatDate(claimDateStr), style: const TextStyle(fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            const Icon(Icons.schedule_rounded, size: 18, color: Colors.black87),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Submitted at', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                Text(_formatDateTime(createdAtStr), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.notes_rounded, size: 18, color: Colors.black87),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Description', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                  const SizedBox(height: 2),
                                  Text(note.isEmpty ? '-' : note, style: const TextStyle(fontSize: 14)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (receiptUrl.isNotEmpty) ...[
                          const Text('Receipt', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: AspectRatio(
                              aspectRatio: 4 / 3,
                              child: Image.network(
                                receiptUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Colors.grey.shade100,
                                  alignment: Alignment.center,
                                  child: const Text('Failed to load receipt image', style: TextStyle(fontSize: 12)),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ───────────────── UI ─────────────────

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
          'HR – Claim Requests',
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
            // overview banner
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.25),
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
                      child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Claims overview',
                            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.85)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Review & approve all staff claims here.',
                            style: theme.textTheme.titleSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // filter bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'All staff claims',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                      icon: const Icon(Icons.expand_more_rounded, size: 18),
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All')),
                        DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                        DropdownMenuItem(value: 'Approved', child: Text('Approved')),
                        DropdownMenuItem(value: 'Rejected', child: Text('Rejected')),
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

            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildClaimsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClaimsList() {
    if (_allClaims.isEmpty) {
      return const Center(child: Text('No claim requests found.'));
    }

    var docs = _allClaims.toList();

    if (_statusFilter != 'All') {
      final target = _statusFilter.toLowerCase();
      docs = docs.where((doc) {
        final status = (doc['status'] ?? '').toString().toLowerCase();
        return status == target;
      }).toList();
    }

    if (docs.isEmpty) {
      return const Center(child: Text('No claims for this filter.'));
    }

    return RefreshIndicator(
      onRefresh: _loadClaims,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        itemCount: docs.length,
        itemBuilder: (context, index) {
          final data = docs[index];
          final claimId = data['id'].toString();

          final staffName = _getStaffName(data);
          final staffUid = (data['staff_id'] ?? 'unknown').toString();
          final claimType = (data['claim_type'] ?? 'Claim').toString();
          final num amountRaw = (data['amount'] ?? 0) as num;
          final amountStr = amountRaw.toStringAsFixed(2);
          final status = (data['status'] ?? 'pending').toString().toLowerCase();
          final note = (data['description'] ?? data['note'] ?? '').toString();
          final claimDateStr = data['claim_date']?.toString();
          final createdAtStr = data['created_at']?.toString();

          final statusLabel = status.isNotEmpty
              ? status[0].toUpperCase() + status.substring(1)
              : 'Pending';

          return InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _showClaimDetailSheet(data),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Column(
                  children: [
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _statusColor(statusLabel),
                            _statusColor(statusLabel).withValues(alpha: 0.6),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2563EB).withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.person_rounded, size: 20, color: Color(0xFF2563EB)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(staffName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 4),
                                    Text(claimType, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _statusColor(statusLabel).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  statusLabel,
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _statusColor(statusLabel)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today_rounded, size: 16, color: Colors.black87),
                                  const SizedBox(width: 6),
                                  Text('Claim: ${_formatDate(claimDateStr)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                                ],
                              ),
                              Text('RM $amountStr', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                            ],
                          ),
                          if (note.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(note, style: const TextStyle(fontSize: 13)),
                          ],
                          const SizedBox(height: 6),
                          Text(
                            'Submitted at: ${_formatDateTime(createdAtStr)}',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                          const SizedBox(height: 10),
                          if (status == 'pending')
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _updateStatus(claimId, 'approved', data),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF16A34A),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    ),
                                    icon: const Icon(Icons.check_rounded),
                                    label: const Text('Approve'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _updateStatus(claimId, 'rejected', data),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      side: const BorderSide(color: Color(0xFFDC2626), width: 1.3),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    ),
                                    icon: const Icon(Icons.close_rounded, color: Color(0xFFDC2626)),
                                    label: const Text('Reject', style: TextStyle(color: Color(0xFFDC2626))),
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
            ),
          );
        },
      ),
    );
  }
}
