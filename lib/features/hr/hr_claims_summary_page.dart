// lib/features/hr/hr_claims_summary_page.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/supabase_service.dart';

class HrClaimsSummaryPage extends StatefulWidget {
  const HrClaimsSummaryPage({super.key});

  @override
  State<HrClaimsSummaryPage> createState() => _HrClaimsSummaryPageState();
}

class _HrClaimsSummaryPageState extends State<HrClaimsSummaryPage> {
  String _monthFilter = 'All';
  String _staffFilter = 'All staff';

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

  // ───────────────── Helpers ─────────────────
  String _monthName(int m) {
    const names = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    if (m < 1 || m > 12) return '-';
    return names[m];
  }

  String _dateText(String? isoStr) {
    if (isoStr == null) return '-';
    try {
      final d = DateTime.parse(isoStr);
      String two(int n) => n.toString().padLeft(2, '0');
      return '${two(d.day)}/${two(d.month)}/${d.year}';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0.8,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: Colors.black,
        centerTitle: true,
        title: const Text(
          'Claims Summary',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      backgroundColor: const Color(0xFFF5F5F7),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_allClaims.isEmpty) {
      return const Center(child: Text('No claims data.'));
    }

    // Collect staff names
    final staffNameSet = <String>{};
    for (final d in _allClaims) {
      final name = _getStaffName(d).trim();
      if (name.isNotEmpty) staffNameSet.add(name);
    }
    final staffNames = staffNameSet.toList()..sort();

    // Collect months that exist
    final monthSet = <int>{};
    for (final d in _allClaims) {
      final ts = d['created_at']?.toString();
      if (ts != null) {
        final dt = DateTime.tryParse(ts);
        if (dt != null) monthSet.add(dt.month);
      }
    }
    final monthList = monthSet.toList()..sort();

    // Apply filters
    var docs = _allClaims.toList();

    // Filter month
    if (_monthFilter != 'All') {
      docs = docs.where((doc) {
        final ts = doc['created_at']?.toString();
        if (ts == null) return false;
        final dt = DateTime.tryParse(ts);
        if (dt == null) return false;
        return _monthName(dt.month) == _monthFilter;
      }).toList();
    }

    // Filter staff
    if (_staffFilter != 'All staff') {
      docs = docs.where((doc) {
        final name = _getStaffName(doc).trim();
        return name == _staffFilter;
      }).toList();
    }

    // Summary
    int total = docs.length;
    int pending = 0, approved = 0, rejected = 0;
    double totalAmountAll = 0.0;
    double pendingAmount = 0.0;
    double approvedAmount = 0.0;
    double rejectedAmount = 0.0;

    for (final d in docs) {
      final status = (d['status'] ?? 'pending').toString().toLowerCase();
      final amountRaw = d['amount'];
      double amt = 0.0;
      if (amountRaw is int) {
        amt = amountRaw.toDouble();
      } else if (amountRaw is double) {
        amt = amountRaw;
      } else if (amountRaw is String) {
        amt = double.tryParse(amountRaw) ?? 0.0;
      }

      totalAmountAll += amt;

      if (status == 'approved') {
        approved++;
        approvedAmount += amt;
      } else if (status == 'rejected') {
        rejected++;
        rejectedAmount += amt;
      } else {
        pending++;
        pendingAmount += amt;
      }
    }

    return Column(
      children: [
        // ───────── Filter by month ─────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filter by month',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: DropdownButton<String>(
                  isExpanded: true,
                  borderRadius: BorderRadius.circular(12),
                  underline: const SizedBox.shrink(),
                  value: _monthFilter,
                  items: [
                    const DropdownMenuItem(
                      value: 'All',
                      child: Text('All'),
                    ),
                    ...monthList.map(
                          (m) => DropdownMenuItem(
                        value: _monthName(m),
                        child: Text(_monthName(m)),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _monthFilter = value);
                  },
                ),
              ),
            ],
          ),
        ),

        // ───────── Staff filter card ─────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.badge_rounded,
                  size: 18,
                  color: Color(0xFF0EA5E9),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Staff:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    isDense: true,
                    dropdownColor: Colors.white,
                    borderRadius: BorderRadius.circular(12),
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
              ],
            ),
          ),
        ),

        // ───────── Summary cards ─────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _SummaryBox(
                      title: _staffFilter == 'All staff'
                          ? 'Total claim amount'
                          : 'Total for $_staffFilter',
                      value: 'RM ${totalAmountAll.toStringAsFixed(2)}',
                      subtitle: '$total claim(s) in this view',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _StatusBox(
                      label: 'Pending',
                      count: pending,
                      amount: pendingAmount,
                      dotColor: const Color(0xFFF97316),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatusBox(
                      label: 'Approved',
                      count: approved,
                      amount: approvedAmount,
                      dotColor: const Color(0xFF16A34A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _StatusBox(
                      label: 'Rejected',
                      count: rejected,
                      amount: rejectedAmount,
                      dotColor: const Color(0xFFDC2626),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(child: SizedBox()),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 4),

        // ───────── List of claims ─────────
        Expanded(
          child: docs.isEmpty
              ? const Center(child: Text('No claims for this filter.'))
              : ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index];

              final staffName = _getStaffName(data);
              final staffUid = (data['staff_id'] ?? 'unknown').toString();
              final claimType = (data['claim_type'] ?? 'Claim').toString();
              final description = (data['description'] ?? '').toString();
              final status = (data['status'] ?? 'pending').toString().toLowerCase();
              final createdAt = data['created_at']?.toString();
              final createdStr = _dateText(createdAt);

              final amountRaw = data['amount'];
              double amt = 0.0;
              if (amountRaw is int) {
                amt = amountRaw.toDouble();
              } else if (amountRaw is double) {
                amt = amountRaw;
              } else if (amountRaw is String) {
                amt = double.tryParse(amountRaw) ?? 0.0;
              }

              final statusLabel = status.isNotEmpty
                  ? status[0].toUpperCase() + status.substring(1)
                  : 'Pending';

              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      height: 3,
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
                                      '$claimType • RM ${amt.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.withValues(alpha: 0.9),
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
                                Icons.receipt_long_rounded,
                                size: 16,
                                color: Colors.black87,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  createdStr,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          if (description.isNotEmpty)
                            Text(
                              description,
                              style: const TextStyle(fontSize: 13),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ───────────────── Summary widgets ─────────────────

class _SummaryBox extends StatelessWidget {
  const _SummaryBox({
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBox extends StatelessWidget {
  const _StatusBox({
    required this.label,
    required this.count,
    required this.amount,
    required this.dotColor,
  });

  final String label;
  final int count;
  final double amount;
  final Color dotColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'RM ${amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
