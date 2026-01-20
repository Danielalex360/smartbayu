// lib/features/payslip/hr_create_payslip_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/notification_service.dart'; // 🔔 IMPORT

class HrCreatePayslipPage extends StatefulWidget {
  const HrCreatePayslipPage({super.key});

  @override
  State<HrCreatePayslipPage> createState() => _HrCreatePayslipPageState();
}

class _HrCreatePayslipPageState extends State<HrCreatePayslipPage> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedStaffUid;
  String? _selectedStaffName;

  // ─── Controllers ────────────────────────────────────────────────────────────
  final _monthController = TextEditingController(); // e.g. November 2025
  final _basicController = TextEditingController();
  final _allowanceController = TextEditingController();
  final _overtimeController = TextEditingController();
  final _deductController = TextEditingController();
  final _kwspController = TextEditingController(); // NEW
  final _socsoController = TextEditingController(); // NEW
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
  //  Fetch senarai staff (termasuk HR) dari collection "users"
  // ────────────────────────────────────────────────────────────────────────────
  Future<List<_StaffOption>> _fetchStaffList() async {
    final snap = await FirebaseFirestore.instance.collection('users').get();

    return snap.docs
        .map((d) {
      final data = d.data();
      final name = (data['displayName'] ??
          data['name'] ??
          data['email'] ??
          'Unknown')
          .toString();

      return _StaffOption(
        uid: d.id,
        name: name,
        site: (data['siteName'] ?? '').toString(),
      );
    })
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  // ────────────────────────────────────────────────────────────────────────────
  //  Kira Net Pay – juga digunakan untuk live preview
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
  //  Save payslip ke Firestore + create notification
  //  Path: users/{staffUid}/payslips/{autoId}
  // ────────────────────────────────────────────────────────────────────────────
  Future<void> _savePayslip() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedStaffUid == null) {
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
    final monthLabel = _monthController.text.trim();
    final pdfUrl = _pdfUrlController.text.trim();

    setState(() => _saving = true);

    try {
      // ── 1) Simpan payslip ke Firestore ────────────────────────────────
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_selectedStaffUid)
          .collection('payslips')
          .add({
        'monthLabel': monthLabel,
        'basicSalary': basic,
        'allowance': allowance,
        'overtime': overtime,
        'deductions': deductions,
        'kwsp': kwsp,
        'socso': socso,
        'netPay': netPay,
        'pdfUrl': pdfUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'staffName': _selectedStaffName,
        'staffUid': _selectedStaffUid, // optional, senang query HR
      });

      // ── 2) Hantar notification kepada staff (bell + popup jika listener on) ─
      if (_selectedStaffUid != null && _selectedStaffUid!.isNotEmpty) {
        final prettyNetPay = netPay.toStringAsFixed(2);

        await NotificationService.instance.push(
          userId: _selectedStaffUid!,
          title: 'Payslip Ready',
          message:
          'Your payslip for $monthLabel is now available.\nNet Pay: RM $prettyNetPay.',
          type: 'payslip',
        );
      }

      // ── 3) Popup local untuk HR sendiri (confirmation) ─────────────────
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

      Navigator.of(context).pop(); // balik ke HR panel
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
                child: Text('No staff found in users collection.'),
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
                    // ─── Card: Staff & period ───────────────────────────────
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
                            value: _selectedStaffUid,
                            onChanged: (val) {
                              if (val == null) return;
                              setState(() {
                                _selectedStaffUid = val;
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

                    // ─── Card: Salary breakdown ─────────────────────────────
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

                    // ─── Optional PDF URL ───────────────────────────────────
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

                    // ─── Save button ────────────────────────────────────────
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
