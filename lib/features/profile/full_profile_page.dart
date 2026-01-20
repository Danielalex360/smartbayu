// lib/features/profile/full_profile_page.dart
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class FullProfilePage extends StatelessWidget {
  const FullProfilePage({
    super.key,
    this.uid,
    this.prefill,
    this.readOnly = false,
  });

  /// Jika ada uid -> fetch Firestore; jika null -> guna prefill di bawah.
  final String? uid;
  final ProfilePrefill? prefill;
  final bool readOnly;

  // Helper untuk format joinDate yang mungkin Timestamp / String / null
  String _formatJoinDate(Map<String, dynamic> data) {
    final fromString = data['joinDateString'];
    if (fromString is String && fromString.trim().isNotEmpty) {
      // support data lama yang simpan string sendiri
      return fromString.trim();
    }

    final raw = data['joinDate'];
    if (raw is Timestamp) {
      final d = raw.toDate();
      final dd = d.day.toString().padLeft(2, '0');
      final mm = d.month.toString().padLeft(2, '0');
      final yy = d.year.toString();
      return '$dd.$mm.$yy';
    } else if (raw is String && raw.trim().isNotEmpty) {
      // just in case ada dokumen lama string direct
      return raw.trim();
    }

    return ''; // tiada tarikh
  }

  @override
  Widget build(BuildContext context) {
    // ───── MODE GUEST (tiada uid, guna prefill saja) ─────
    if (uid == null) {
      final p = prefill ?? const ProfilePrefill();
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FB),
        appBar: AppBar(
          title: const Text('Staff Profile'),
          backgroundColor: const Color(0xFFF5F7FB),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        body: _GuestBody(prefill: p, readOnly: true),
      );
    }

    // ───── MODE SIGNED-IN : baca Firestore users/{uid} ─────
    final docRef = FirebaseFirestore.instance.collection('users').doc(uid);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text('Staff Profile'),
        backgroundColor: const Color(0xFFF5F7FB),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: docRef.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || !snap.data!.exists) {
            // fallback gunakan prefill jika ada
            final p = prefill ?? const ProfilePrefill();
            return _GuestBody(prefill: p, readOnly: true);
          }

          final data = snap.data!.data()!;
          final authUser = FirebaseAuth.instance.currentUser;

          final name = (data['name'] as String?) ??
              authUser?.displayName ??
              'Unnamed Staff';
          final email =
              (data['email'] as String?) ?? authUser?.email ?? '-';
          final role = (data['role'] as String?) ?? '-';
          final site = (data['site'] as String?) ??
              (data['siteName'] as String?) ??
              '-';
          final phone = (data['phone'] as String?) ?? '-';
          final empId = (data['employeeId'] as String?) ?? '-';
          final dept = (data['department'] as String?) ?? '-';
          final empType = (data['employmentType'] as String?) ?? '-';

          // 🔥 ambil photo dari photoUrl atau faceImageUrl
          final firestorePhoto =
          (data['photoUrl'] ?? data['faceImageUrl']) as String?;
          String finalPhoto;
          if (firestorePhoto != null && firestorePhoto.trim().isNotEmpty) {
            finalPhoto = firestorePhoto;
          } else if (authUser?.photoURL != null &&
              authUser!.photoURL!.isNotEmpty) {
            finalPhoto = authUser.photoURL!;
          } else {
            finalPhoto =
            'https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&background=BAE6FD';
          }

          // ✅ joinDate sekarang support Timestamp / String / joinDateString
          final joinDateText = _formatJoinDate(data);

          // status (boleh kosong)
          final rawStatus = data['status'] as String?;
          final status =
              rawStatus ?? ((data['active'] == false) ? 'Inactive' : 'Active');

          // hanya owner profile sendiri yang boleh edit
          final canEdit =
              !readOnly && authUser != null && authUser.uid == uid;

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ─── Header card (avatar + nama) ───
                  _ProfileHeader(
                    name: name,
                    role: role,
                    site: site,
                    photoUrl: finalPhoto,
                  ),
                  const SizedBox(height: 16),

                  // ─── Info card iOS style ───
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                    child: Column(
                      children: [
                        _InfoTile(
                          icon: Icons.badge_rounded,
                          label: 'Employee ID',
                          value: empId,
                        ),
                        _Divider(),
                        _InfoTile(
                          icon: Icons.apartment_rounded,
                          label: 'Department',
                          value: dept,
                        ),
                        _Divider(),
                        _InfoTile(
                          icon: Icons.people_alt_rounded,
                          label: 'Employment Type',
                          value: empType,
                        ),
                        _Divider(),
                        _InfoTile(
                          icon: Icons.email_rounded,
                          label: 'Email',
                          value: email,
                        ),
                        _Divider(),
                        _InfoTile(
                          icon: Icons.phone_rounded,
                          label: 'Phone',
                          value: phone,
                        ),
                        _Divider(),
                        _InfoTile(
                          icon: Icons.location_on_rounded,
                          label: 'Site',
                          value: site,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  if (joinDateText.isNotEmpty || status.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 4,
                      ),
                      child: Text(
                        [
                          if (joinDateText.isNotEmpty)
                            'Joined: $joinDateText',
                          if (status.isNotEmpty) 'Status: $status',
                        ].join('   •   '),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4B5563),
                        ),
                      ),
                    ),

                  const SizedBox(height: 20),

                  // ─── Button row: Edit + Sign out ───
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.edit_rounded),
                          label: Text(canEdit ? 'Edit profile' : 'View only'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          // 🔗 Sini yang buat navigation ke EditProfilePage
                          onPressed: !canEdit
                              ? null
                              : () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => EditProfilePage(
                                  uid: uid!,
                                  initialData: data,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.logout_rounded),
                          label: const Text('Sign out'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () async {
                            await FirebaseAuth.instance.signOut();
                            if (context.mounted) {
                              Navigator.of(context)
                                  .popUntil((r) => r.isFirst);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ───────────────── Guest Body (kalau tak jumpa Firestore) ─────────────────
class _GuestBody extends StatelessWidget {
  const _GuestBody({required this.prefill, required this.readOnly});
  final ProfilePrefill prefill;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final displayName = prefill.name ?? 'Guest';
    final photo = (prefill.photoUrl != null &&
        prefill.photoUrl!.trim().isNotEmpty)
        ? prefill.photoUrl!
        : 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(displayName)}&background=BAE6FD';

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ProfileHeader(
              name: displayName,
              role: prefill.role ?? '-',
              site: prefill.site ?? '-',
              photoUrl: photo,
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Column(
                children: [
                  _InfoTile(
                    icon: Icons.email_rounded,
                    label: 'Email',
                    value: prefill.email ?? '-',
                  ),
                  _Divider(),
                  _InfoTile(
                    icon: Icons.location_on_rounded,
                    label: 'Site',
                    value: prefill.site ?? '-',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (!readOnly)
              ElevatedButton.icon(
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sign out'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) {
                    Navigator.of(context).popUntil((r) => r.isFirst);
                  }
                },
              )
            else
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text(
                  'Viewing local profile (not signed in).',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ───────────────── Small UI widgets ─────────────────

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.role,
    required this.site,
    required this.photoUrl,
  });

  final String name;
  final String role;
  final String site;
  final String photoUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE5F0FF),
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF38BDF8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: Row(
        children: [
          Hero(
            tag: 'avatar-hero',
            child: CircleAvatar(
              radius: 34,
              backgroundColor: Colors.white.withOpacity(0.2),
              backgroundImage: NetworkImage(photoUrl),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  role,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  site,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 12,
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

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 32,
          width: 32,
          decoration: BoxDecoration(
            color: const Color(0xFFE5E7EB),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 18,
            color: const Color(0xFF4B5563),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Color(0xFF111827),
          ),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Divider(
        height: 1,
        thickness: 0.6,
      ),
    );
  }
}

/// Data prefill bila user belum sign-in
class ProfilePrefill {
  final String? name;
  final String? email;
  final String? role;
  final String? site;
  final String? photoUrl;

  const ProfilePrefill({
    this.name,
    this.email,
    this.role,
    this.site,
    this.photoUrl,
  });
}

// ======================================================================
//                           EDIT PROFILE PAGE
// ======================================================================

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
  String? _photoUrl; // url sedia ada
  File? _pickedImage;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.initialData;

    _nameCtrl =
        TextEditingController(text: (d['name'] ?? d['fullName'] ?? '') as String);
    _phoneCtrl = TextEditingController(text: (d['phone'] ?? '') as String);
    _deptCtrl =
        TextEditingController(text: (d['department'] ?? '') as String);
    _siteCtrl =
        TextEditingController(text: (d['siteName'] ?? d['site'] ?? '') as String);

    _employmentType = (d['employmentType'] ?? '') as String?;
    _photoUrl = (d['photoUrl'] ?? d['faceImageUrl'] ?? '') as String?;
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

    setState(() {
      _pickedImage = File(xfile.path);
    });
  }

  Future<String?> _uploadPhotoIfNeeded() async {
    if (_pickedImage == null) return _photoUrl;

    final ref = FirebaseStorage.instance
        .ref()
        .child('staff_profile_photos')
        .child('${widget.uid}.jpg');

    await ref.putFile(_pickedImage!);
    return await ref.getDownloadURL();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final newPhotoUrl = await _uploadPhotoIfNeeded();

      final docRef =
      FirebaseFirestore.instance.collection('users').doc(widget.uid);

      await docRef.update({
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'department': _deptCtrl.text.trim(),
        'employmentType': _employmentType ?? '',
        'siteName': _siteCtrl.text.trim(),
        if (newPhotoUrl != null && newPhotoUrl.isNotEmpty)
          'photoUrl': newPhotoUrl,
      });

      // Sync sekali dengan FirebaseAuth (kalau user yg sama)
      final authUser = FirebaseAuth.instance.currentUser;
      if (authUser != null && authUser.uid == widget.uid) {
        await authUser.updateDisplayName(_nameCtrl.text.trim());
        if (newPhotoUrl != null && newPhotoUrl.isNotEmpty) {
          await authUser.updatePhotoURL(newPhotoUrl);
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
      );
      Navigator.of(context).pop(); // balik ke FullProfilePage
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
    final currentPhotoWidget = _pickedImage != null
        ? CircleAvatar(
      radius: 32,
      backgroundImage: FileImage(_pickedImage!),
    )
        : CircleAvatar(
      radius: 32,
      backgroundImage: (_photoUrl != null && _photoUrl!.isNotEmpty)
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
                // header gradient ala iOS
                Container(
                  width: double.infinity,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
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

                // card form
                Container(
                  width: double.infinity,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                        onChanged: (v) => setState(() => _employmentType = v),
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
              value: value,
              decoration: const InputDecoration(
                labelText: '',
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
