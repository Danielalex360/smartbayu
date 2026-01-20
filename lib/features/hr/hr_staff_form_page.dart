// lib/features/hr/hr_staff_form_page.dart
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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
  final _siteCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  String _role = 'staff'; // 'staff' / 'hr'
  String _status = 'active'; // 'active' / 'inactive'
  DateTime? _joinDate;

  // 🔹 Employment Type – HR sahaja yang set
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
    _nameCtrl.text = (data['fullName'] ?? data['name'] ?? '').toString();
    _emailCtrl.text = (data['email'] ?? '').toString();
    _staffIdCtrl.text =
        (data['staffId'] ?? data['employeeId'] ?? '').toString();
    _positionCtrl.text =
        (data['position'] ?? data['roleTitle'] ?? '').toString();
    _siteCtrl.text = (data['siteName'] ?? data['site'] ?? '').toString();
    _noteCtrl.text = (data['note'] ?? '').toString();

    // ------- Role (normalise to lowercase) -------
    final rawRole = data['role'];
    if (rawRole is String && rawRole.isNotEmpty) {
      _role = rawRole.toLowerCase();
    } else if (data['department'] == 'Human Resource' ||
        data['isHr'] == true) {
      _role = 'hr';
    } else {
      _role = 'staff';
    }

    // ------- Status (normalise to lowercase) -------
    final rawStatus = data['status'];
    if (rawStatus is String && rawStatus.isNotEmpty) {
      _status = rawStatus.toLowerCase();
    } else if (data['active'] == false) {
      _status = 'inactive';
    } else {
      _status = 'active';
    }

    // ------- Employment Type (HR set) -------
    final rawEmpType = data['employmentType'];
    if (rawEmpType is String &&
        rawEmpType.isNotEmpty &&
        _employmentTypeOptions.contains(rawEmpType)) {
      _employmentType = rawEmpType;
    }

    // ------- Join Date (Timestamp atau String "dd.MM.yyyy") -------
    final jd = data['joinDate'];
    if (jd is Timestamp) {
      _joinDate = jd.toDate();
    } else if (jd is String) {
      _joinDate = _parseJoinDateString(jd);
    } else if (data['joinDateString'] != null) {
      _joinDate =
          _parseJoinDateString(data['joinDateString'].toString());
    }

    // ------- Photo -------
    _photoUrl = (data['photoUrl'] ?? data['faceImageUrl'] ?? '').toString();
  }

  DateTime? _parseJoinDateString(String s) {
    try {
      final parts = s.split('.');
      if (parts.length == 3) {
        final d = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        final y = int.tryParse(parts[2]);
        if (d != null && m != null && y != null) {
          return DateTime(y, m, d);
        }
      }
    } catch (_) {}
    return null;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _staffIdCtrl.dispose();
    _positionCtrl.dispose();
    _siteCtrl.dispose();
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

  Future<String?> _uploadAvatar(String docId) async {
    if (_pickedImageFile == null) return _photoUrl;

    try {
      final ref =
      FirebaseStorage.instance.ref('profile_photos/$docId.jpg');
      await ref.putFile(
        _pickedImageFile!,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final url = await ref.getDownloadURL();
      return url;
    } catch (e) {
      if (!mounted) return _photoUrl;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload photo: $e')),
      );
      return _photoUrl;
    }
  }

  String? _joinDateString() {
    if (_joinDate == null) return null;
    final d = _joinDate!;
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yy = d.year.toString();
    return '$dd.$mm.$yy';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final usersRef = FirebaseFirestore.instance.collection('users');

      if (widget.isEdit) {
        // ===================== UPDATE STAFF =====================
        final docId = widget.staffDocId!;
        final currentDoc = await usersRef.doc(docId).get();
        final existing = currentDoc.data() ?? {};

        final photoUrl = await _uploadAvatar(docId);
        final bool isActive = _status == 'active';

        final data = <String, dynamic>{
          // nama
          'fullName': _nameCtrl.text.trim(),
          'name': _nameCtrl.text.trim(),

          // email
          'email': _emailCtrl.text.trim(),

          // id staff
          'staffId': _staffIdCtrl.text.trim(),
          'employeeId': _staffIdCtrl.text.trim().isEmpty
              ? existing['employeeId']
              : _staffIdCtrl.text.trim(),

          // jawatan
          'position': _positionCtrl.text.trim(),
          'roleTitle': _positionCtrl.text.trim(),

          // site
          'siteName': _siteCtrl.text.trim(),
          'site': _siteCtrl.text.trim(),

          // role & department
          'role': _role,
          'department': _role == 'hr'
              ? 'Human Resource'
              : (existing['department'] ?? 'General'),

          // employment type (HR set)
          'employmentType': _employmentType,

          // status / active
          'status': _status, // 'active' / 'inactive'
          'active': isActive,

          // join date
          if (_joinDate != null)
            'joinDate': Timestamp.fromDate(_joinDate!),
          if (_joinDate != null) 'joinDateString': _joinDateString(),

          // note
          'note': _noteCtrl.text.trim(),

          // photo
          if (photoUrl != null) 'photoUrl': photoUrl,

          'updatedAt': FieldValue.serverTimestamp(),
        };

        await usersRef.doc(docId).set(data, SetOptions(merge: true));
      } else {
        // ===================== CREATE STAFF (NEW) =====================
        final bool isActive = _status == 'active';
        final email = _emailCtrl.text.trim();

        // 1) create user dalam Firebase Auth (default password 123456)
        UserCredential userCred;
        try {
          userCred = await FirebaseAuth.instance
              .createUserWithEmailAndPassword(
            email: email,
            password: '123456',
          );
        } on FirebaseAuthException catch (e) {
          String msg = 'Failed to create staff account.';
          if (e.code == 'email-already-in-use') {
            msg = 'Email already in use. Please use another email.';
          }
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg)),
          );
          setState(() => _saving = false);
          return;
        }

        final staffUid = userCred.user!.uid;

        // 2) base data untuk Firestore
        final baseData = <String, dynamic>{
          'uid': staffUid,
          'fullName': _nameCtrl.text.trim(),
          'name': _nameCtrl.text.trim(),
          'email': email,
          'staffId': _staffIdCtrl.text.trim(),
          'employeeId': _staffIdCtrl.text.trim(),
          'position': _positionCtrl.text.trim(),
          'roleTitle': _positionCtrl.text.trim(),
          'siteName': _siteCtrl.text.trim(),
          'site': _siteCtrl.text.trim(),
          'role': _role, // 'staff' / 'hr'
          'department': _role == 'hr' ? 'Human Resource' : 'General',

          // employment type
          'employmentType': _employmentType,

          'status': _status, // 'active' / 'inactive'
          'active': isActive,
          if (_joinDate != null)
            'joinDate': Timestamp.fromDate(_joinDate!),
          if (_joinDate != null) 'joinDateString': _joinDateString(),
          'note': _noteCtrl.text.trim(),
          'hasDefaultPassword': true, // optional flag
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        // 3) simpan doc 'users/{uid}'
        final docRef = usersRef.doc(staffUid);
        await docRef.set(baseData);

        // 4) upload avatar kalau ada
        if (_pickedImageFile != null) {
          final photoUrl = await _uploadAvatar(staffUid);
          await docRef.set(
            {'photoUrl': photoUrl},
            SetOptions(merge: true),
          );
        }
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

                    // Site / Location
                    TextFormField(
                      controller: _siteCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Site / Location',
                        prefixIcon: Icon(Icons.location_city),
                        border: OutlineInputBorder(),
                      ),
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

                    // Employment Type (HR sahaja)
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
