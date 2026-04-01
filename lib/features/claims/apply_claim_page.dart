// lib/features/claims/apply_claim_page.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/notification_service.dart';
import '../../services/supabase_service.dart';

class ApplyClaimPage extends StatefulWidget {
  const ApplyClaimPage({super.key});

  @override
  State<ApplyClaimPage> createState() => _ApplyClaimPageState();
}

class _ApplyClaimPageState extends State<ApplyClaimPage> {
  final _formKey = GlobalKey<FormState>();

  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  DateTime? _selectedDate;
  String _claimType = 'Meal';
  Uint8List? _receiptBytes;

  bool _saving = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
      initialDate: _selectedDate ?? now,
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _submit() async {
    final svc = SupabaseService.instance;
    final staffId = svc.staffId;
    final companyId = svc.companyId;

    if (staffId == null || companyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You are not logged in.')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose claim date.')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final amountText = _amountCtrl.text.trim();
      final double amount = double.tryParse(amountText) ?? 0.0;

      final claimDateIso = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
      ).toIso8601String().substring(0, 10);

      // Upload receipt if picked
      String? receiptUrl;
      if (_receiptBytes != null) {
        try {
          final bytes = _receiptBytes!;
          final path = 'receipts/$staffId/${DateTime.now().millisecondsSinceEpoch}.jpg';
          await Supabase.instance.client.storage
              .from('smartbayu')
              .uploadBinary(path, bytes,
                  fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true));
          receiptUrl = Supabase.instance.client.storage
              .from('smartbayu')
              .getPublicUrl(path);
        } catch (e) {
          debugPrint('Receipt upload failed: $e');
        }
      }

      // Insert into staff_claims table
      final inserted = await Supabase.instance.client
          .from('staff_claims')
          .insert({
            'staff_id': staffId,
            'company_id': companyId,
            'claim_type': _claimType,
            'claim_date': claimDateIso,
            'amount': amount,
            'description': _noteCtrl.text.trim(),
            'status': 'pending',
            if (receiptUrl != null) 'receipt_url': receiptUrl,
          })
          .select('id')
          .single();

      final recordId = inserted['id'].toString();

      // SIMPAN REKOD NOTIFICATION UNTUK STAFF (NOTIFICATION CENTER)
      await NotificationService.instance.push(
        staffId: staffId,
        title: 'Claim submitted',
        message:
        '$_claimType claim RM${amount.toStringAsFixed(2)} is pending approval.',
        type: 'claim',
        docId: recordId,
      );

      // POPUP LOCAL NOTI PADA DEVICE SEKARANG (STAFF NAMPAK TERUS)
      await NotificationService.instance.showLocal(
        title: 'Claim submitted',
        body:
        'RM${amount.toStringAsFixed(2)} $_claimType claim sent for approval.',
        data: {
          'screen': 'claims',
          'claimId': recordId,
        },
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Claim submitted successfully.')),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'New Claim',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      backgroundColor: const Color(0xFFF5F5F7),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Intro card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF22C55E)],
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
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
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
                          'Claim submission',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Submit your work-related claim here.',
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

            const SizedBox(height: 16),

            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Claim type
                  const Text(
                    'Claim type',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: DropdownButton<String>(
                      isExpanded: true,
                      underline: const SizedBox.shrink(),
                      value: _claimType,
                      items: const [
                        DropdownMenuItem(
                          value: 'Meal',
                          child: Text('Meal'),
                        ),
                        DropdownMenuItem(
                          value: 'Transport',
                          child: Text('Transport'),
                        ),
                        DropdownMenuItem(
                          value: 'Tools',
                          child: Text('Tools'),
                        ),
                        DropdownMenuItem(
                          value: 'Others',
                          child: Text('Others'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _claimType = value);
                      },
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Amount
                  const Text(
                    'Amount (RM)',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _amountCtrl,
                    keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      hintText: 'e.g. 50.00',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Please enter amount';
                      }
                      final value = double.tryParse(v.trim());
                      if (value == null || value <= 0) {
                        return 'Invalid amount';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 14),

                  // Claim date
                  const Text(
                    'Claim date',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedDate == null
                                  ? 'Tap to choose date'
                                  : '${_selectedDate!.day.toString().padLeft(2, '0')}/${_selectedDate!.month.toString().padLeft(2, '0')}/${_selectedDate!.year}',
                              style: TextStyle(
                                color: _selectedDate == null
                                    ? Colors.grey
                                    : Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Note
                  const Text(
                    'Description / note',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _noteCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'e.g. hotel parking, tools purchase, etc.',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Receipt upload
                  const Text(
                    'Receipt (optional)',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () async {
                      final img = await ImagePicker().pickImage(
                        source: ImageSource.camera,
                        imageQuality: 80,
                      );
                      if (img != null) {
                        final bytes = await img.readAsBytes();
                        setState(() => _receiptBytes = bytes);
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _receiptBytes != null
                              ? const Color(0xFF22C55E)
                              : Colors.grey.shade300,
                          width: _receiptBytes != null ? 2 : 1,
                        ),
                      ),
                      child: _receiptBytes != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(13),
                              child: Image.memory(_receiptBytes!, fit: BoxFit.cover),
                            )
                          : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.camera_alt_rounded, size: 32, color: Colors.grey),
                                SizedBox(height: 6),
                                Text('Tap to take receipt photo',
                                    style: TextStyle(color: Colors.grey, fontSize: 13)),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF22C55E),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: _saving
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
                        'Submit claim',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
