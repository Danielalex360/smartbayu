// lib/features/profile/edit_profile_page.dart
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/supabase_service.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({
    super.key,
    required this.uid,
    required this.initialData,
  });

  final String uid;
  final Map<String, dynamic> initialData;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _deptCtrl;
  late TextEditingController _siteCtrl;

  String? _employmentType;
  String? _photoUrl; // existing url
  Uint8List? _pickedBytes;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.initialData;

    _nameCtrl = TextEditingController(
        text: (d['full_name'] ?? d['name'] ?? d['fullName'] ?? '') as String);
    _phoneCtrl =
        TextEditingController(text: (d['phone'] ?? '') as String);
    _deptCtrl =
        TextEditingController(text: (d['department'] ?? '') as String);
    _siteCtrl = TextEditingController(
        text: (d['site'] ?? d['siteName'] ?? '') as String);

    // Employment type: ensure String and not empty; otherwise null
    final rawEmpType = d['employment_type'] ?? d['employmentType'];
    if (rawEmpType is String && rawEmpType.isNotEmpty) {
      _employmentType = rawEmpType;
    } else {
      _employmentType = null;
    }

    _photoUrl =
    (d['photo_url'] ?? d['profile_photo_url'] ?? d['photoUrl'] ?? '') as String?;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _deptCtrl.dispose();
    _siteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 900,
      imageQuality: 80,
    );
    if (xfile == null) return;

    final bytes = await xfile.readAsBytes();
    setState(() {
      _pickedBytes = bytes;
    });
  }

  Future<String?> _uploadPhotoIfNeeded() async {
    if (_pickedBytes == null) return _photoUrl;

    final storage = Supabase.instance.client.storage.from('smartbayu');
    final filePath = 'profile-photos/${widget.uid}.jpg';
    final bytes = _pickedBytes!;

    // Upload (upsert to overwrite existing)
    await storage.uploadBinary(
      filePath,
      bytes,
      fileOptions: const FileOptions(
        contentType: 'image/jpeg',
        upsert: true,
      ),
    );

    // Get public URL
    final publicUrl = storage.getPublicUrl(filePath);
    return publicUrl;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final newPhotoUrl = await _uploadPhotoIfNeeded();

      // Update staff table in Supabase
      await Supabase.instance.client
          .from('staff')
          .update({
        'full_name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'department': _deptCtrl.text.trim(),
        'employment_type': _employmentType ?? '',
        'site': _siteCtrl.text.trim(),
        if (newPhotoUrl != null && newPhotoUrl.isNotEmpty)
          'photo_url': newPhotoUrl,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      })
          .eq('id', widget.uid);

      // Refresh cached staff data in SupabaseService
      await SupabaseService.instance.refreshStaffData();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPhotoWidget = _pickedBytes != null
        ? CircleAvatar(
      radius: 32,
      backgroundImage: MemoryImage(_pickedBytes!),
    )
        : CircleAvatar(
      radius: 32,
      backgroundImage:
      (_photoUrl != null && _photoUrl!.isNotEmpty)
          ? NetworkImage(_photoUrl!)
          : null,
      child: (_photoUrl == null || _photoUrl!.isEmpty)
          ? Text(
        _nameCtrl.text.isNotEmpty
            ? _nameCtrl.text[0].toUpperCase()
            : 'U',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      )
          : null,
    );

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FB),
        appBar: AppBar(
          title: const Text('Edit Profile'),
          backgroundColor: const Color(0xFFF5F7FB),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          actions: [
            TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Text(
                'Save',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // HEADER avatar + name
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF0EA5E9),
                        Color(0xFF2563EB),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x330064B5),
                        blurRadius: 18,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: _saving ? null : _pickImage,
                        child: Stack(
                          children: [
                            currentPhotoWidget,
                            Positioned(
                              bottom: -2,
                              right: -2,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  size: 14,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _nameCtrl,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Full name',
                            labelStyle: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                            ),
                            border: InputBorder.none,
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Name required';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // FORM CARD
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 16,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _EditField(
                        icon: Icons.phone_outlined,
                        label: 'Phone',
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                      ),
                      _EditField(
                        icon: Icons.apartment_outlined,
                        label: 'Department',
                        controller: _deptCtrl,
                      ),
                      _DropdownField<String>(
                        icon: Icons.group_outlined,
                        label: 'Employment Type',
                        value: _employmentType,
                        items: const [
                          'Full-time',
                          'Part-time',
                          'Contract',
                          'Intern',
                        ],
                        onChanged: (v) {
                          setState(() => _employmentType = v);
                        },
                      ),
                      _EditField(
                        icon: Icons.location_on_outlined,
                        label: 'Site',
                        controller: _siteCtrl,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),
                const Text(
                  'Note: Employee ID, role, join date & status hanya boleh diubah oleh HR melalui HR Panel.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
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

class _EditField extends StatelessWidget {
  const _EditField({
    required this.icon,
    required this.label,
    required this.controller,
    this.keyboardType,
  });

  final IconData icon;
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFE5ECF5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: Colors.grey.shade700),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: controller,
              keyboardType: keyboardType,
              decoration: InputDecoration(
                labelText: label,
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  const _DropdownField({
    required this.icon,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final T? value;
  final List<T> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    // Ensure value is valid; if not in items list, set to null
    final T? safeValue = items.contains(value) ? value : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFE5ECF5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: Colors.grey.shade700),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<T>(
              value: safeValue,
              decoration: InputDecoration(
                labelText: label,
                border: InputBorder.none,
              ),
              items: items
                  .map(
                    (e) => DropdownMenuItem<T>(
                  value: e,
                  child: Text(e.toString()),
                ),
              )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
