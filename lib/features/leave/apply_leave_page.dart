// lib/features/leave/apply_leave_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/notification_service.dart'; // 🔔 NOTIFICATION SERVICE

class ApplyLeavePage extends StatefulWidget {
  const ApplyLeavePage({super.key});

  @override
  State<ApplyLeavePage> createState() => _ApplyLeavePageState();
}

class _ApplyLeavePageState extends State<ApplyLeavePage> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();

  String _leaveType = 'Annual Leave';
  DateTime? _startDate;
  DateTime? _endDate;
  bool _submitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  // ───────────────── UI HELPERS ─────────────────

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final initial =
    isStart ? (_startDate ?? now) : (_endDate ?? _startDate ?? now);

    final firstDate = DateTime(now.year - 1);
    final lastDate = DateTime(now.year + 2);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF00A86B),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return;

    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(_startDate!)) {
          _endDate = null;
        }
      } else {
        _endDate = picked;
      }
    });
  }

  String _formatDate(DateTime? d) {
    if (d == null) return 'Select date';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }

  int get _totalDays {
    if (_startDate == null || _endDate == null) return 0;
    return _endDate!.difference(_startDate!).inDays + 1;
  }

  // ───────────────── FIRESTORE SUBMIT ─────────────────

  Future<void> _submit() async {
    if (_submitting) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select start & end date.')),
      );
      return;
    }

    if (_endDate!.isBefore(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End date cannot be before start date.')),
      );
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not logged in.');
      }

      final staffUid = user.uid;

      // STEP 1: Baca profile staff daripada Firestore
      final profileSnap =
      await FirebaseFirestore.instance.collection('users').doc(staffUid).get();

      final profile = profileSnap.data() ?? {};

      // STEP 2: Ambil nama & site daripada profile
      final staffName = (profile['name'] ??
          profile['fullName'] ??
          user.displayName ??
          'Unknown Staff')
          .toString();

      final siteName =
      (profile['siteName'] ?? profile['site'] ?? 'Unknown Site').toString();

      final startTs = Timestamp.fromDate(
        DateTime(_startDate!.year, _startDate!.month, _startDate!.day),
      );
      final endTs = Timestamp.fromDate(
        DateTime(_endDate!.year, _endDate!.month, _endDate!.day),
      );

      // STEP 3: Simpan dalam subcollection leaveRequests di bawah users/{uid}
      final leaveRef = await FirebaseFirestore.instance
          .collection('users')
          .doc(staffUid)
          .collection('leaveRequests')
          .add({
        'staffUid': staffUid,
        'staffName': staffName,
        'siteName': siteName,
        'leaveType': _leaveType,
        'startDate': startTs,
        'endDate': endTs,
        'reason': _reasonController.text.trim(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // TEXT TARIKH UNTUK NOTI
      final startText = _formatDate(_startDate);
      final endText = _formatDate(_endDate);
      final rangeText = '$startText to $endText';

      // ── STEP 4A: NOTI UNTUK STAFF SENDIRI (BELL + POPUP LOCAL) ──
      await NotificationService.instance.push(
        userId: staffUid,
        type: 'leave_request', // rekod untuk bell staff
        title: 'Leave request submitted',
        message:
        'Your $_leaveType from $rangeText has been sent to HR for approval.',
      );

      // popup terus di phone staff (walaupun dia tengah dalam page ni)
      await NotificationService.instance.showLocal(
        title: 'Leave request submitted',
        body:
        'Your $_leaveType from $rangeText has been sent to HR for approval.',
        data: {
          'type': 'leave',
          'screen': 'leave',
          'docId': leaveRef.id,
        },
      );

      // ── STEP 4B: NOTI UNTUK SEMUA HR (BELL + FCM POPUP) ──
      final hrSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'hr')
          .get();

      final hrTokens = <String>[];

      for (final doc in hrSnap.docs) {
        final hrUid = doc.id;
        final hrData = doc.data();
        final token = (hrData['fcmToken'] ?? '').toString();

        // rekod dalam bell HR
        await NotificationService.instance.push(
          userId: hrUid,
          type: 'leave_request',
          title: 'New leave request',
          message:
          '$staffName requested $_leaveType ($rangeText) from $siteName.',
        );

        if (token.isNotEmpty) {
          hrTokens.add(token);
        }
      }

      // Hantar FCM ke device HR (kalau ada token)
      if (hrTokens.isNotEmpty) {
        await NotificationService.instance.sendSmartBayuEvent(
          targetTokens: hrTokens,
          title: 'New leave request',
          body: '$staffName requested $_leaveType ($rangeText) from $siteName.',
          type: 'leave', // untuk routing / tab leave HR
          docId: leaveRef.id,
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Leave request submitted for approval.'),
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  // ───────────────── MAIN BUILD ─────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFC),
      appBar: AppBar(
        elevation: 0.8,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: Colors.black,
        centerTitle: true,
        title: const Text(
          'Apply Leave',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Intro / highlight card ───
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF00A86B),
                        Color(0xFF22C55E),
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
                          color: Colors.white.withValues(alpha: 0.18),
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
                              'Apply for time off',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Select your leave type, dates and reason. HR will review this request.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // ─── Main form card ───
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Leave type
                      Text(
                        'Leave type',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _LeaveTypeChip(
                            label: 'Annual Leave',
                            isSelected: _leaveType == 'Annual Leave',
                            onTap: () =>
                                setState(() => _leaveType = 'Annual Leave'),
                          ),
                          _LeaveTypeChip(
                            label: 'Sick Leave',
                            isSelected: _leaveType == 'Sick Leave',
                            onTap: () =>
                                setState(() => _leaveType = 'Sick Leave'),
                          ),
                          _LeaveTypeChip(
                            label: 'Emergency Leave',
                            isSelected: _leaveType == 'Emergency Leave',
                            onTap: () =>
                                setState(() => _leaveType = 'Emergency Leave'),
                          ),
                          _LeaveTypeChip(
                            label: 'Unpaid Leave',
                            isSelected: _leaveType == 'Unpaid Leave',
                            onTap: () =>
                                setState(() => _leaveType = 'Unpaid Leave'),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Dates row
                      Text(
                        'Date range',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _DatePickerTile(
                              label: 'From',
                              value: _formatDate(_startDate),
                              onTap: () => _pickDate(isStart: true),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _DatePickerTile(
                              label: 'To',
                              value: _formatDate(_endDate),
                              onTap: () => _pickDate(isStart: false),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Summary row
                      if (_totalDays > 0)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color:
                            const Color(0xFF00A86B).withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_rounded,
                                size: 16,
                                color: Color(0xFF00A86B),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '$_totalDays day${_totalDays > 1 ? 's' : ''} selected',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 20),

                      // Reason
                      Text(
                        'Reason',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _reasonController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Example: Fever & doctor appointment',
                          filled: true,
                          fillColor: const Color(0xFFF7F7F7),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: Colors.grey.shade300,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: Colors.grey.shade300,
                            ),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderRadius:
                            BorderRadius.all(Radius.circular(14)),
                            borderSide: BorderSide(
                              color: Color(0xFF00A86B),
                              width: 1.2,
                            ),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter a short reason.';
                          }
                          if (val.trim().length < 5) {
                            return 'Reason is too short.';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _submitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF00A86B),
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: _submitting
                        ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                        : const Text(
                      'Submit Leave Request',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────── SMALL WIDGETS ─────────────

class _LeaveTypeChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _LeaveTypeChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF00A86B);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primary : const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected ? primary : Colors.grey.shade300,
            width: 1.1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              const Icon(
                Icons.check_rounded,
                size: 16,
                color: Colors.white,
              ),
            if (isSelected) const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DatePickerTile extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _DatePickerTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isPlaceholder = value == 'Select date';

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isPlaceholder ? Colors.grey.shade300 : const Color(0xFF00A86B),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.event_rounded,
                  size: 18,
                  color: isPlaceholder
                      ? Colors.grey.shade500
                      : const Color(0xFF00A86B),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                      isPlaceholder ? FontWeight.w400 : FontWeight.w600,
                      color: isPlaceholder
                          ? Colors.grey.shade600
                          : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
