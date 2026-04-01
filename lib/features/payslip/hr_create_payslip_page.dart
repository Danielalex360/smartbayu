// lib/features/payslip/hr_create_payslip_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/notification_service.dart';
import '../../services/supabase_service.dart';

class HrCreatePayslipPage extends StatefulWidget {
  const HrCreatePayslipPage({super.key});

  @override
  State<HrCreatePayslipPage> createState() => _HrCreatePayslipPageState();
}

class _HrCreatePayslipPageState extends State<HrCreatePayslipPage> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedStaffId;
  String? _selectedStaffName;

  // Controllers
  final _monthController = TextEditingController(); // e.g. November 2025
  final _basicController = TextEditingController();
  final _allowanceController = TextEditingController();
  final _overtimeController = TextEditingController();
  final _deductController = TextEditingController();
  final _kwspController = TextEditingController();
  final _socsoController = TextEditingController();
  final _pdfUrlController = TextEditingController();

  bool _saving = false;
  late Future<List<_StaffOption>> _staffFuture;

  @override
  void initState() {
    super.initState();
    _staffFuture = _fetchStaffList();
  }

  @override
  void dispose() {
    _monthController.dispose();
    _basicController.dispose();
    _allowanceController.dispose();
    _overtimeController.dispose();
    _deductController.dispose();
    _kwspController.dispose();
    _socsoController.dispose();
    _pdfUrlController.dispose();
    super.dispose();
  }

  // ────────────────────────────────────────────────────────────────────────────
  //  Fetch staff list from Supabase `staff` table
  // ────────────────────────────────────────────────────────────────────────────
  Future<List<_StaffOption>> _fetchStaffList() async {
    final companyId = SupabaseService.instance.companyId;
    if (companyId == null) return [];

    final rows = await Supabase.instance.client
        .from('staff')
        .select('id, full_name, email, department')
        .eq('company_id', companyId)
        .order('full_name');

    return (rows as List)
        .map((d) {
      final name = (d['full_name'] ??
          d['email'] ??
          'Unknown')
          .toString();

      return _StaffOption(
        uid: d['id'] as String,
        name: name,
        site: (d['department'] ?? '').toString(),
      );
    })
        .toList();
  }

  // ────────────────────────────────────────────────────────────────────────────
  //  Calculate Net Pay (live preview)
  // ────────────────────────────────────────────────────────────────────────────
  double _calculateNetPay() {
    final basic = double.tryParse(_basicController.text) ?? 0;
    final allowance = double.tryParse(_allowanceController.text) ?? 0;
    final overtime = double.tryParse(_overtimeController.text) ?? 0;
    final deductions = double.tryParse(_deductController.text) ?? 0;
    final kwsp = double.tryParse(_kwspController.text) ?? 0;
    final socso = double.tryParse(_socsoController.text) ?? 0;

    return basic + allowance + overtime - deductions - kwsp - socso;
  }

  // ────────────────────────────────────────────────────────────────────────────
  //  Save payslip to Supabase `payslips` table + send notification
  // ────────────────────────────────────────────────────────────────────────────
  Future<void> _savePayslip() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedStaffId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a staff first.')),
      );
      return;
    }

    final basic = double.tryParse(_basicController.text) ?? 0;
    final allowance = double.tryParse(_allowanceController.text) ?? 0;
    final overtime = double.tryParse(_overtimeController.text) ?? 0;
    final deductions = double.tryParse(_deductController.text) ?? 0;
    final kwsp = double.tryParse(_kwspController.text) ?? 0;
    final socso = double.tryParse(_socsoController.text) ?? 0;
    final netPay = _calculateNetPay();
    final grossPay = basic + allowance + overtime;
    final monthLabel = _monthController.text.trim();
    final pdfUrl = _pdfUrlController.text.trim();
    final companyId = SupabaseService.instance.companyId;

    setState(() => _saving = true);

    try {
      // Derive period_start and period_end from month label (e.g. "March 2026")
      String? periodStart;
      String? periodEnd;
      try {
        final parts = monthLabel.split(' ');
        if (parts.length == 2) {
          const months = ['january','february','march','april','may','june',
            'july','august','september','october','november','december'];
          final mi = months.indexOf(parts[0].toLowerCase()) + 1;
          final yr = int.parse(parts[1]);
          if (mi > 0) {
            periodStart = '$yr-${mi.toString().padLeft(2, '0')}-01';
            final lastDay = DateTime(yr, mi + 1, 0).day;
            periodEnd = '$yr-${mi.toString().padLeft(2, '0')}-$lastDay';
          }
        }
      } catch (_) {}

      // 1) Insert payslip into Supabase
      await Supabase.instance.client.from('payslips').insert({
        'staff_id': _selectedStaffId,
        'company_id': companyId,
        'month_label': monthLabel,
        if (periodStart != null) 'period_start': periodStart,
        if (periodEnd != null) 'period_end': periodEnd,
        'basic_salary': basic,
        'total_allowances': allowance,
        'allowances': {'overtime': overtime},
        'total_deductions': deductions + kwsp + socso,
        'deductions': {'other': deductions},
        'epf_employee': kwsp,
        'socso_employee': socso,
        'gross_pay': grossPay,
        'net_pay': netPay,
        if (pdfUrl.isNotEmpty) 'pdf_url': pdfUrl,
      });

      // 2) Send notification to staff
      if (_selectedStaffId != null && _selectedStaffId!.isNotEmpty) {
        final prettyNetPay = netPay.toStringAsFixed(2);

        await NotificationService.instance.push(
          staffId: _selectedStaffId!,
          title: 'Payslip Ready',
          message:
          'Your payslip for $monthLabel is now available.\nNet Pay: RM $prettyNetPay.',
          type: 'payslip',
        );
      }

      // 3) Local notification for HR (confirmation)
      await NotificationService.instance.showLocal(
        title: 'Payslip Created',
        body:
        'Payslip for ${_selectedStaffName ?? 'staff'} ($monthLabel) has been created and sent.',
        data: const {
          'type': 'payslip',
        },
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payslip saved successfully.')),
      );

      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving payslip: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  //  UI
  // ────────────────────────────────────────────────────────────────────────────
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
          'Create Payslip',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: FutureBuilder<List<_StaffOption>>(
          future: _staffFuture,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(child: Text('Error: ${snap.error}'));
            }

            final staffList = snap.data ?? [];
            if (staffList.isEmpty) {
              return const Center(
                child: Text('No staff found.'),
              );
            }

            final netPay = _calculateNetPay();

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Card: Staff & period
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x14000000),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Staff & period',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Select staff',
                              border: OutlineInputBorder(),
                            ),
                            selectedItemBuilder: (context) {
                              return staffList.map((s) {
                                return Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    s.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                );
                              }).toList();
                            },
                            items: staffList.map((s) {
                              return DropdownMenuItem(
                                value: s.uid,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      s.name,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    if (s.site.isNotEmpty)
                                      Text(
                                        s.site,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.black54,
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            }).toList(),
                            value: _selectedStaffId,
                            onChanged: (val) {
                              if (val == null) return;
                              setState(() {
                                _selectedStaffId = val;
                                final staff = staffList.firstWhere(
                                      (s) => s.uid == val,
                                  orElse: () => staffList.first,
                                );
                                _selectedStaffName = staff.name;
                              });
                            },
                            validator: (val) =>
                            val == null ? 'Please choose a staff' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _monthController,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Month / Period label',
                              hintText: 'e.g. November 2025',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Please enter a month label'
                                : null,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Card: Salary breakdown
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x14000000),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Salary breakdown',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _moneyField(
                            label: 'Basic salary (RM)',
                            controller: _basicController,
                            requiredField: true,
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 8),
                          _moneyField(
                            label: 'Allowance (RM)',
                            controller: _allowanceController,
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 8),
                          _moneyField(
                            label: 'Overtime (RM)',
                            controller: _overtimeController,
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 8),
                          _moneyField(
                            label: 'Deductions (RM)',
                            controller: _deductController,
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 8),
                          _moneyField(
                            label: 'KWSP (RM)',
                            controller: _kwspController,
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 8),
                          _moneyField(
                            label: 'SOCSO (RM)',
                            controller: _socsoController,
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Estimated Net Pay',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'RM ${netPay.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Optional PDF URL
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x14000000),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextFormField(
                        controller: _pdfUrlController,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: 'PDF URL (optional)',
                          hintText: 'https://...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Save button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _saving ? null : _savePayslip,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                            : const Text(
                          'Save Payslip',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  //  Reusable money field
  // ────────────────────────────────────────────────────────────────────────────
  Widget _moneyField({
    required String label,
    required TextEditingController controller,
    bool requiredField = false,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      onChanged: onChanged,
      validator: !requiredField
          ? null
          : (v) {
        if (v == null || v.trim().isEmpty) {
          return 'Required';
        }
        if (double.tryParse(v) == null) {
          return 'Enter a valid number';
        }
        return null;
      },
    );
  }
}

class _StaffOption {
  final String uid;
  final String name;
  final String site;

  _StaffOption({
    required this.uid,
    required this.name,
    required this.site,
  });
}
