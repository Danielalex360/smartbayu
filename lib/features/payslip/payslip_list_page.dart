// lib/features/payslip/payslip_list_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'payslip_pdf_helper.dart';
import 'payslip_pdf_preview_page.dart';

class PayslipListPage extends StatelessWidget {
  const PayslipListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    // Staff view: payslips bawah users/{uid}/payslips
    final payslipStream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('payslips')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        elevation: 0.8,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: Colors.black,
        title: const Text(
          'My Payslips',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: payslipStream,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snap.hasError) {
              return Center(child: Text('Error: ${snap.error}'));
            }

            final docs = snap.data?.docs ?? [];

            if (docs.isEmpty) {
              return _buildEmptyState(context);
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data() as Map<String, dynamic>;

                final monthLabel =
                (data['monthLabel'] ?? 'Unknown period').toString();

                final basic = _toDouble(data['basicSalary']);
                final allowance = _toDouble(data['allowance']);
                final overtime = _toDouble(data['overtime']);
                final deductions = _toDouble(data['deductions']);
                final kwsp = _toDouble(data['kwsp']); // NEW
                final socso = _toDouble(data['socso']); // NEW
                final netPay = _toDouble(data['netPay']);
                final pdfUrl = (data['pdfUrl'] ?? '').toString();

                final createdAt = data['createdAt'];
                DateTime? created;
                if (createdAt is Timestamp) {
                  created = createdAt.toDate();
                }

                return _PayslipCard(
                  monthLabel: monthLabel,
                  createdAt: created,
                  basic: basic,
                  allowance: allowance,
                  overtime: overtime,
                  deductions: deductions,
                  kwsp: kwsp,
                  socso: socso,
                  netPay: netPay,
                  pdfUrl: pdfUrl.isEmpty ? null : pdfUrl,
                  rawData: data, // ✅ pass full data for PDF
                );
              },
            );
          },
        ),
      ),
    );
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: const BoxDecoration(
                color: Color(0xFFE0ECFF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.picture_as_pdf_rounded,
                size: 36,
                color: Color(0xFF2563EB),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No payslips yet',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'When HR uploads your payslip, it will appear here with full breakdown.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PayslipCard extends StatelessWidget {
  const _PayslipCard({
    required this.monthLabel,
    required this.createdAt,
    required this.basic,
    required this.allowance,
    required this.overtime,
    required this.deductions,
    required this.kwsp,
    required this.socso,
    required this.netPay,
    required this.rawData,
    this.pdfUrl,
  });

  final String monthLabel;
  final DateTime? createdAt;
  final double basic;
  final double allowance;
  final double overtime;
  final double deductions;
  final double kwsp;
  final double socso;
  final double netPay;
  final String? pdfUrl;
  final Map<String, dynamic> rawData; // ✅ original Firestore data

  @override
  Widget build(BuildContext context) {
    final dateText = createdAt == null
        ? ''
        : '${createdAt!.day.toString().padLeft(2, '0')}-'
        '${createdAt!.month.toString().padLeft(2, '0')}-'
        '${createdAt!.year}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _showDetailSheet(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF38BDF8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(
                  Icons.picture_as_pdf_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      monthLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateText.isEmpty ? 'Created by HR' : 'Created: $dateText',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Net pay: RM ${netPay.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    if (pdfUrl != null && pdfUrl!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      const Text(
                        'PDF link attached',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.black45,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.keyboard_arrow_right_rounded,
                size: 22,
                color: Colors.black54,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetailSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                monthLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 12),
              _row('Basic salary', basic),
              _row('Allowance', allowance),
              _row('Overtime', overtime),
              _row('Deductions', deductions, minus: true),
              if (kwsp != 0) _row('KWSP', kwsp, minus: true),
              if (socso != 0) _row('SOCSO', socso, minus: true),
              const Divider(height: 20),
              _row('Net pay', netPay, bold: true),
              const SizedBox(height: 10),
              if (pdfUrl == null || pdfUrl!.isEmpty)
                const Text(
                  'No PDF uploaded. This is an auto-generated summary.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                )
              else
                Text(
                  'PDF link: $pdfUrl',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _openPdfPreview(context),
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  label: const Text('View / Print PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openPdfPreview(BuildContext context) async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      // Ambil info staff dari users/{uid}
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      final staffData = userDoc.data() ?? {};

      if (!context.mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PayslipPdfPreviewPage(
            staff: staffData,
            payslip: rawData,
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open payslip PDF: $e'),
          ),
        );
      }
    }
  }

  static Widget _row(
      String label,
      double value, {
        bool minus = false,
        bool bold = false,
      }) {
    final textStyle = TextStyle(
      fontSize: 14,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
    );
    final sign = minus ? '-' : '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: textStyle),
          Text(
            '$sign RM ${value.toStringAsFixed(2)}',
            style: textStyle,
          ),
        ],
      ),
    );
  }
}
