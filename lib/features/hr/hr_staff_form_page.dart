// lib/features/hr/hr_staff_form_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/supabase_service.dart';

class HrStaffFormPage extends StatefulWidget {
  const HrStaffFormPage({
    super.key,
    this.staffDocId,
    this.initialData,
  });

  final String? staffDocId; // null = add new
  final Map<String, dynamic>? initialData;

  bool get isEdit => staffDocId != null;

  @override
  State<HrStaffFormPage> createState() => _HrStaffFormPageState();
}

class _HrStaffFormPageState extends State<HrStaffFormPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _staffIdCtrl = TextEditingController();
  final _positionCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  String _role = 'staff'; // 'staff' / 'hr'
  String _status = 'active'; // 'active' / 'inactive'
  DateTime? _joinDate;

  String _employmentType = 'Full-time';
  static const _employmentTypeOptions = [
    'Full-time',
    'Part-time',
    'Contract',
    'Intern',
  ];

  bool _saving = false;

  String? _photoUrl; // existing photo
  File? _pickedImageFile;

  static const _roleOptions = ['staff', 'hr'];
  static const _statusOptions = ['active', 'inactive'];

  @override
  void initState() {
    super.initState();
    final data = widget.initialData ?? {};

    // ------- Text fields -------
    _nameCtrl.text = (data['full_name'] ?? data['name'] ?? '').toString();
    _emailCtrl.text = (data['email'] ?? '').toString();
    _staffIdCtrl.text = (data['staff_number'] ?? data['employeeId'] ?? '').toString();
    _positionCtrl.text = (data['position'] ?? '').toString();
    _noteCtrl.text = (data['note'] ?? '').toString();

    // ------- Role (normalise to lowercase) -------
    final rawRole = data['app_role'] ?? data['role'];
    if (rawRole is String && rawRole.isNotEmpty) {
      final r = rawRole.toLowerCase();
      _role = (r == 'hr' || r == 'admin' || r == 'manager') ? 'hr' : 'staff';
    } else if (data['department'] == 'Human Resource') {
      _role = 'hr';
    } else {
      _role = 'staff';
    }

    // ------- Status -------
    if (data['is_active'] == false) {
      _status = 'inactive';
    } else {
      _status = 'active';
    }

    // ------- Employment Type -------
    final rawEmpType = data['employment_type'] ?? data['employmentType'];
    if (rawEmpType is String &&
        rawEmpType.isNotEmpty &&
        _employmentTypeOptions.contains(rawEmpType)) {
      _employmentType = rawEmpType;
    }

    // ------- Join Date (ISO 8601 string) -------
    final jd = data['date_joined'] ?? data['joinDate'];
    if (jd is String && jd.isNotEmpty) {
      _joinDate = DateTime.tryParse(jd);
    }

    // ------- Photo -------
    _photoUrl = (data['photo_url'] ?? data['profile_photo_url'] ?? '').toString();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _staffIdCtrl.dispose();
    _positionCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (img == null) return;
    setState(() {
      _pickedImageFile = File(img.path);
    });
  }

  Future<void> _pickJoinDate() async {
    final now = DateTime.now();
    final init = _joinDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) {
      setState(() => _joinDate = picked);
    }
  }

  Future<String?> _uploadAvatar(String staffId) async {
    if (_pickedImageFile == null) return _photoUrl;

    try {
      final bytes = await _pickedImageFile!.readAsBytes();
      final path = 'profile_photos/$staffId.jpg';

      await Supabase.instance.client.storage
          .from('smartbayu')
          .uploadBinary(
        path,
        bytes,
        fileOptions: const FileOptions(
          contentType: 'image/jpeg',
          upsert: true,
        ),
      );

      final url = Supabase.instance.client.storage
          .from('smartbayu')
          .getPublicUrl(path);

      return url;
    } catch (e) {
      if (!mounted) return _photoUrl;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload photo: $e')),
      );
      return _photoUrl;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final companyId = SupabaseService.instance.companyId;
      final supabase = Supabase.instance.client;

      if (widget.isEdit) {
        // ===================== UPDATE STAFF =====================
        final docId = widget.staffDocId!;

        final photoUrl = await _uploadAvatar(docId);
        final bool isActive = _status == 'active';

        final data = <String, dynamic>{
          'full_name': _nameCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'staff_number': _staffIdCtrl.text.trim(),
          'position': _positionCtrl.text.trim(),
          'app_role': _role,
          'department': _role == 'hr'
              ? 'Human Resource'
              : (widget.initialData?['department'] ?? 'General'),
          'employment_type': _employmentType,
          'is_active': isActive,
          if (_joinDate != null)
            'date_joined': _joinDate!.toIso8601String().split('T').first,
          'note': _noteCtrl.text.trim(),
          if (photoUrl != null && photoUrl.isNotEmpty)
            'photo_url': photoUrl,
        };

        await supabase
            .from('staff')
            .update(data)
            .eq('id', docId);
      } else {
        // ===================== CREATE STAFF (NEW) =====================
        final bool isActive = _status == 'active';
        final email = _emailCtrl.text.trim();

        // 1) Sign up user in Supabase Auth (default password 123456)
        AuthResponse authResponse;
        try {
          authResponse = await supabase.auth.signUp(
            email: email,
            password: '123456',
          );
        } on AuthException catch (e) {
          String msg = 'Failed to create staff account.';
          if (e.message.contains('already registered') ||
              e.message.contains('already been registered')) {
            msg = 'Email already in use. Please use another email.';
          }
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg)),
          );
          setState(() => _saving = false);
          return;
        }

        final newUserId = authResponse.user?.id;
        if (newUserId == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to create user account.')),
          );
          setState(() => _saving = false);
          return;
        }

        // 2) Insert staff record
        final staffData = <String, dynamic>{
          'user_id': newUserId,
          'full_name': _nameCtrl.text.trim(),
          'email': email,
          'staff_number': _staffIdCtrl.text.trim(),
          'position': _positionCtrl.text.trim(),
          'app_role': _role,
          'department': _role == 'hr' ? 'Human Resource' : 'General',
          'employment_type': _employmentType,
          'is_active': isActive,
          'company_id': companyId,
          if (_joinDate != null)
            'date_joined': _joinDate!.toIso8601String().split('T').first,
          'note': _noteCtrl.text.trim(),
        };

        final insertResult = await supabase
            .from('staff')
            .insert(staffData)
            .select('id')
            .single();

        final newStaffId = insertResult['id'] as String;

        // 3) Upload avatar if picked
        if (_pickedImageFile != null) {
          final photoUrl = await _uploadAvatar(newStaffId);
          if (photoUrl != null && photoUrl.isNotEmpty) {
            await supabase
                .from('staff')
                .update({'photo_url': photoUrl})
                .eq('id', newStaffId);
          }
        }

        // 4) Sign back in as the HR user (signUp logs out the current session)
        // Re-authenticate as the current HR user
        await SupabaseService.instance.loadUserContext();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEdit ? 'Staff updated.' : 'New staff added.',
          ),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save staff: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isEdit ? 'Edit Staff' : 'Add Staff';

    final avatarWidget = GestureDetector(
      onTap: _pickAvatar,
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.blueGrey.shade100,
                backgroundImage: _pickedImageFile != null
                    ? FileImage(_pickedImageFile!) as ImageProvider
                    : (_photoUrl != null && _photoUrl!.isNotEmpty)
                    ? NetworkImage(_photoUrl!)
                    : null,
                child: (_pickedImageFile == null &&
                    (_photoUrl == null || _photoUrl!.isEmpty))
                    ? const Icon(
                  Icons.person,
                  size: 40,
                  color: Colors.white,
                )
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Tap to change photo',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );

    final safeRole =
    _roleOptions.contains(_role) ? _role : _roleOptions.first;
    final safeStatus =
    _statusOptions.contains(_status) ? _status : _statusOptions.first;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: AbsorbPointer(
        absorbing: _saving,
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    avatarWidget,
                    const SizedBox(height: 20),

                    // Full name
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Email
                    TextFormField(
                      controller: _emailCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Email is required';
                        }
                        if (!v.contains('@')) {
                          return 'Invalid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Staff ID + Position
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _staffIdCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Staff ID (optional)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _positionCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Position / Role Title',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Role + Status
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: safeRole,
                            decoration: const InputDecoration(
                              labelText: 'Role',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'staff',
                                child: Text('Staff'),
                              ),
                              DropdownMenuItem(
                                value: 'hr',
                                child: Text('HR / Manager'),
                              ),
                            ],
                            onChanged: (v) {
                              if (v != null) setState(() => _role = v);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: safeStatus,
                            decoration: const InputDecoration(
                              labelText: 'Status',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'active',
                                child: Text('Active'),
                              ),
                              DropdownMenuItem(
                                value: 'inactive',
                                child: Text('Inactive'),
                              ),
                            ],
                            onChanged: (v) {
                              if (v != null) setState(() => _status = v);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Employment Type
                    DropdownButtonFormField<String>(
                      value: _employmentType,
                      decoration: const InputDecoration(
                        labelText: 'Employment Type',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: _employmentTypeOptions
                          .map(
                            (e) => DropdownMenuItem<String>(
                          value: e,
                          child: Text(e),
                        ),
                      )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _employmentType = v);
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // Join date
                    InkWell(
                      onTap: _pickJoinDate,
                      borderRadius: BorderRadius.circular(8),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Join Date',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          _joinDate == null
                              ? 'Not set'
                              : '${_joinDate!.year}-${_joinDate!.month.toString().padLeft(2, '0')}-${_joinDate!.day.toString().padLeft(2, '0')}',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Notes
                    TextFormField(
                      controller: _noteCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Notes / Remarks (optional)',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _save,
                        icon: const Icon(Icons.save),
                        label: Text(
                          widget.isEdit ? 'Save Changes' : 'Create Staff',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (_saving)
              const Align(
                alignment: Alignment.bottomCenter,
                child: LinearProgressIndicator(minHeight: 3),
              ),
          ],
        ),
      ),
    );
  }
}
