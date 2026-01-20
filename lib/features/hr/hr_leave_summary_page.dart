import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class HrLeaveSummaryPage extends StatefulWidget {
  const HrLeaveSummaryPage({super.key});

  @override
  State<HrLeaveSummaryPage> createState() => _HrLeaveSummaryPageState();
}

class _HrLeaveSummaryPageState extends State<HrLeaveSummaryPage> {
  String _selectedMonth = 'All';
  String _selectedStaffUid = 'All'; // 🔥 staff filter: All / specific uid

  final List<String> _months = const [
    'All',
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  Stream<QuerySnapshot<Map<String, dynamic>>> _leaveStream() {
    // Sama macam HrLeaveListPage: baca semua leaveRequests (all staff)
    return FirebaseFirestore.instance
        .collectionGroup('leaveRequests')
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF102A43),
        centerTitle: true,
        title: const Text(
          'Leave Summary',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filter by month',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),

            // ───── Month dropdown ─────
            DropdownButtonFormField<String>(
              value: _selectedMonth,
              isExpanded: true,
              items: _months
                  .map(
                    (m) => DropdownMenuItem<String>(
                  value: m,
                  child: Text(m),
                ),
              )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _selectedMonth = value);
              },
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                  const BorderSide(color: Color(0xFFE5E7EB), width: 1),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ───── Main content (staff filter + summary + list) ─────
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _leaveStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Error: ${snapshot.error}'),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text('No leave data available.'),
                    );
                  }

                  final allDocs = snapshot.data!.docs;

                  // 🔥 Build staff list from existing leave docs
                  final Map<String, String> staffMap = {}; // uid -> name
                  for (final d in allDocs) {
                    final data = d.data();
                    final uid = (data['staffUid'] ?? '').toString();
                    if (uid.isEmpty) continue;
                    final name =
                    (data['staffName'] ?? 'Unknown Staff').toString();
                    staffMap[uid] = name;
                  }

                  // Staff dropdown items
                  final staffEntries = staffMap.entries.toList()
                    ..sort((a, b) => a.value.compareTo(b.value));

                  // Pastikan selected staff masih valid
                  if (_selectedStaffUid != 'All' &&
                      !staffMap.containsKey(_selectedStaffUid)) {
                    _selectedStaffUid = 'All';
                  }

                  // ───── Filter docs by month + staff ─────
                  final filteredDocs = allDocs.where((doc) {
                    final data = doc.data();

                    // Month filter
                    if (_selectedMonth != 'All') {
                      final startTs = data['startDate'] as Timestamp?;
                      final createdTs = data['createdAt'] as Timestamp?;
                      final baseDate =
                          startTs?.toDate() ?? createdTs?.toDate();
                      if (baseDate == null) return false;

                      final targetMonthIndex =
                      _months.indexOf(_selectedMonth); // Jan = 1
                      if (baseDate.month != targetMonthIndex) return false;
                    }

                    // Staff filter
                    if (_selectedStaffUid != 'All') {
                      final uid = (data['staffUid'] ?? '').toString();
                      if (uid != _selectedStaffUid) return false;
                    }

                    return true;
                  }).toList();

                  if (filteredDocs.isEmpty) {
                    return Column(
                      children: [
                        // Staff filter card tetap tunjuk walaupun kosong
                        _buildStaffFilterCard(staffEntries),
                        const SizedBox(height: 16),
                        const Expanded(
                          child: Center(
                            child: Text('No leave requests for this filter.'),
                          ),
                        ),
                      ],
                    );
                  }

                  // ───── Kira summary (ikut filter) ─────
                  int total = filteredDocs.length;
                  int approved = 0;
                  int pending = 0;
                  int rejected = 0;

                  for (final d in filteredDocs) {
                    final status =
                    (d.data()['status'] ?? 'pending').toString().toLowerCase();
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
                      // 🔥 Staff filter card
                      _buildStaffFilterCard(staffEntries),
                      const SizedBox(height: 12),

                      // ───── Summary cards ─────
                      Row(
                        children: [
                          Expanded(
                            child: _summaryCard(
                              label: 'Total',
                              value: total,
                              color: const Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _summaryCard(
                              label: 'Approved',
                              value: approved,
                              color: const Color(0xFF16A34A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _summaryCard(
                              label: 'Pending',
                              value: pending,
                              color: const Color(0xFF2563EB),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _summaryCard(
                              label: 'Rejected',
                              value: rejected,
                              color: const Color(0xFFDC2626),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // ───── List leave ─────
                      Expanded(
                        child: ListView.builder(
                          itemCount: filteredDocs.length,
                          itemBuilder: (context, index) {
                            final doc = filteredDocs[index];
                            final data = doc.data();

                            final staffName =
                            (data['staffName'] ?? 'Unknown Staff').toString();
                            final leaveType =
                            (data['leaveType'] ?? 'Leave').toString();
                            final status =
                            (data['status'] ?? 'pending').toString().toLowerCase();
                            final startTs = data['startDate'] as Timestamp?;
                            final endTs = data['endDate'] as Timestamp?;
                            final createdAt = data['createdAt'] as Timestamp?;

                            final startDate =
                                startTs?.toDate() ?? DateTime.now();
                            final endDate = endTs?.toDate() ?? startDate;
                            final createdStr = createdAt != null
                                ? _prettyDateTime(createdAt.toDate())
                                : '-';

                            final statusColor = _statusColor(status);
                            final statusLabel = status.isNotEmpty
                                ? status[0].toUpperCase() + status.substring(1)
                                : 'Pending';

                            String dateRange;
                            if (startDate.year == endDate.year &&
                                startDate.month == endDate.month &&
                                startDate.day == endDate.day) {
                              dateRange = _prettyDate(startDate);
                            } else {
                              dateRange =
                              '${_prettyDate(startDate)}  –  ${_prettyDate(endDate)}';
                            }

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFE5E7EB),
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x0F000000),
                                    blurRadius: 8,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Top row: name + status
                                  Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          staffName,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF111827),
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                          statusColor.withOpacity(0.10),
                                          borderRadius:
                                          BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          statusLabel,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: statusColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    leaveType,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF4B5563),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    dateRange,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Applied at: $createdStr',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF9CA3AF),
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
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───── Staff filter card (dropdown All staff / specific staff) ─────
  Widget _buildStaffFilterCard(List<MapEntry<String, String>> staffEntries) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.person_search_rounded,
            size: 18,
            color: Color(0xFF4B5563),
          ),
          const SizedBox(width: 8),
          const Text(
            'Staff:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _selectedStaffUid,
              borderRadius: BorderRadius.circular(12),
              underline: const SizedBox.shrink(),
              items: [
                const DropdownMenuItem(
                  value: 'All',
                  child: Text('All staff'),
                ),
                ...staffEntries.map(
                      (e) => DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value),
                  ),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _selectedStaffUid = value);
              },
            ),
          ),
        ],
      ),
    );
  }

  // ───── Helper widgets & functions ─────

  Widget _summaryCard({
    required String label,
    required int value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Icon(
              Icons.circle,
              size: 10,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$value',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    final s = status.toLowerCase();
    if (s == 'approved') return const Color(0xFF16A34A);
    if (s == 'rejected') return const Color(0xFFDC2626);
    return const Color(0xFF2563EB); // pending / others
  }

  String _prettyDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  String _prettyDateTime(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final date = _prettyDate(d);
    final time = '${two(d.hour)}:${two(d.minute)}';
    return '$date $time';
  }
}
