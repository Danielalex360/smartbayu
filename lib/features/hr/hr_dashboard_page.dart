// lib/features/hr/hr_dashboard_page.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/supabase_service.dart';
import '../hr/hr_leave_list_page.dart';
import '../hr/hr_claim_requests_page.dart';
import '../payslip/hr_create_payslip_page.dart';
import 'hr_staff_management_page.dart';
import '../hr/hr_reports_page.dart';
import 'hr_company_settings_page.dart';

class HrDashboardPage extends StatelessWidget {
  const HrDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF102A43),
        title: const Text(
          'HR Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ───────── Small intro chip ─────────
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(
                    Icons.admin_panel_settings,
                    size: 18,
                    color: Color(0xFF0369A1),
                  ),
                  SizedBox(width: 6),
                  Text(
                    'HR – manage staff & approvals',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0369A1),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ───────── Overview stats row ─────────
            const _HrStatsRow(),

            const SizedBox(height: 20),

            // ───────── Leave Requests card ─────────
            _HrMenuCard(
              icon: Icons.event_available_rounded,
              iconBg: const Color(0xFFEEF2FF),
              iconColor: const Color(0xFF4C6FFF),
              title: 'Leave Requests',
              subtitle: 'Approve / reject staff leave',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const HrLeaveListPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // ───────── Claims Requests card ─────────
            _HrMenuCard(
              icon: Icons.receipt_long_rounded,
              iconBg: const Color(0xFFE0F2FE),
              iconColor: const Color(0xFF0284C7),
              title: 'Claims Requests',
              subtitle: 'Review & approve claims',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const HrClaimRequestsPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // ───────── Create Payslip card ─────────
            _HrMenuCard(
              icon: Icons.payments_rounded,
              iconBg: const Color(0xFFFDE68A),
              iconColor: const Color(0xFFCA8A04),
              title: 'Create Payslip',
              subtitle: 'Generate payslip for staff',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const HrCreatePayslipPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // ───────── Reports card ─────────
            _HrMenuCard(
              icon: Icons.insert_chart_outlined_rounded,
              iconBg: const Color(0xFFE0F2FE),
              iconColor: const Color(0xFF0284C7),
              title: 'Reports',
              subtitle: 'Attendance, leave, claims summaries',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const HrReportsPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),


            // ───────── Staff Management card ─────────
            _HrMenuCard(
              icon: Icons.groups_rounded,
              iconBg: const Color(0xFFDCFCE7),
              iconColor: const Color(0xFF16A34A),
              title: 'Staff Management',
              subtitle: 'View, add, edit staff profiles',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const HrStaffManagementPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // ───────── Company Settings card ─────────
            _HrMenuCard(
              icon: Icons.settings_rounded,
              iconBg: const Color(0xFFF3E8FF),
              iconColor: const Color(0xFF7C3AED),
              title: 'Company Settings',
              subtitle: 'Logo, details, geofence config',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const HrCompanySettingsPage(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ============================= HR Stats Row =============================

class _HrStatsRow extends StatelessWidget {
  const _HrStatsRow();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: const [
          _StatChip(
            label: 'Total Staff',
            icon: Icons.groups_rounded,
            color: Color(0xFF4C6FFF),
            statType: _StatType.allStaff,
          ),
          SizedBox(width: 8),
          _StatChip(
            label: 'Active Staff',
            icon: Icons.verified_user_rounded,
            color: Color(0xFF16A34A),
            statType: _StatType.activeStaff,
          ),
        ],
      ),
    );
  }
}

enum _StatType { allStaff, activeStaff }

class _StatChip extends StatefulWidget {
  const _StatChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.statType,
  });

  final String label;
  final IconData icon;
  final Color color;
  final _StatType statType;

  @override
  State<_StatChip> createState() => _StatChipState();
}

class _StatChipState extends State<_StatChip> {
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _loadCount();
  }

  Future<void> _loadCount() async {
    try {
      final companyId = SupabaseService.instance.companyId;
      if (companyId == null) return;

      var query = Supabase.instance.client
          .from('staff')
          .select('id')
          .eq('company_id', companyId);

      if (widget.statType == _StatType.activeStaff) {
        query = query.eq('is_active', true);
      }

      final result = await query;
      if (mounted) {
        setState(() => _count = (result as List).length);
      }
    } catch (e) {
      debugPrint('HR stats error (${widget.label}): $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E7FF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: widget.color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              widget.icon,
              size: 20,
              color: widget.color,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_count',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================= HR Menu Card =============================

class _HrMenuCard extends StatelessWidget {
  const _HrMenuCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFE0E7FF),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF9CA3AF),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
