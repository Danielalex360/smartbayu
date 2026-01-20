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

  @override
  Widget build(BuildContext context) {
    // Mode guest: tiada uid -> render statik
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

    // Mode signed-in: stream Firestore
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

          final name = data['name'] as String? ??
              data['fullName'] as String? ??
              authUser?.displayName ??
              'Unnamed Staff';
          final email = data['email'] as String? ?? authUser?.email ?? '-';
          final role = data['role'] as String? ?? 'staff';
          final site =
              data['siteName'] as String? ?? data['site'] as String? ?? '-';
          final phone = data['phone'] as String? ?? '-';
          final empId = data['employeeId'] as String? ??
              data['staffId'] as String? ??
              '-';
          final dept = data['department'] as String? ?? '-';
          final empType = data['employmentType'] as String? ?? '-';

          final photo = data['photoUrl'] as String? ??
              data['faceImageUrl'] as String? ??
              authUser?.photoURL ??
              'https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&background=BAE6FD';

          // joinDate boleh String atau Timestamp
          String? joinDate;
          final rawJoinDate = data['joinDate'];
          if (rawJoinDate is String) {
            joinDate = rawJoinDate;
          } else if (rawJoinDate is Timestamp) {
            final dt = rawJoinDate.toDate();
            String two(int n) => n.toString().padLeft(2, '0');
            joinDate = '${two(dt.day)}.${two(dt.month)}.${dt.year}';
          }

          // status: guna data['status'] kalau ada, kalau tak, derive dari active
          String status;
          final rawStatus = data['status'];
          if (rawStatus is String && rawStatus.isNotEmpty) {
            status = rawStatus;
          } else if (data['active'] == false) {
            status = 'Inactive';
          } else {
            status = 'Active';
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              children: [
                // ─── HEADER CARD ala iOS ────────────────────────────────
                Hero(
                  tag: 'avatar-hero',
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
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
                        CircleAvatar(
                          radius: 32,
                          backgroundImage: NetworkImage(photo),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                role.toLowerCase() == 'hr'
                                    ? 'HR Admin Manager'
                                    : 'staff',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                site,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ─── INFO CARD ───────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 18,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _InfoTile(
                        icon: Icons.badge_outlined,
                        label: 'Employee ID',
                        value: empId,
                      ),
                      _InfoTile(
                        icon: Icons.apartment_outlined,
                        label: 'Department',
                        value: dept,
                      ),
                      _InfoTile(
                        icon: Icons.group_outlined,
                        label: 'Employment Type',
                        value: empType,
                      ),
                      _InfoTile(
                        icon: Icons.email_outlined,
                        label: 'Email',
                        value: email,
                      ),
                      _InfoTile(
                        icon: Icons.phone_outlined,
                        label: 'Phone',
                        value: phone,
                      ),
                      _InfoTile(
                        icon: Icons.location_on_outlined,
                        label: 'Site',
                        value: site,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // joined + status (bold)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Text(
                      [
                        if (joinDate != null && joinDate.isNotEmpty)
                          'Joined: $joinDate',
                        if (status.isNotEmpty) 'Status: $status',
                      ].join('   •   '),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade900,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ─── ACTION BUTTONS (Edit + Sign out) ───────────────────
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit profile'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: readOnly
                            ? null
                            : () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => EditProfilePage(
                                uid:
                                uid!, // kita dah confirm atas: uid != null
                                initialData:
                                data, // data dari Firestore users/{uid}
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
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          backgroundColor: const Color(0xFF2563EB),
                        ),
                        onPressed: () async {
                          await FirebaseAuth.instance.signOut();
                          if (context.mounted) {
                            Navigator.of(context)
                                .popUntil((route) => route.isFirst);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _GuestBody extends StatelessWidget {
  const _GuestBody({required this.prefill, required this.readOnly});
  final ProfilePrefill prefill;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final photo = prefill.photoUrl ??
        'https://ui-avatars.com/api/?name=${Uri.encodeComponent(prefill.name ?? "Guest")}&background=BAE6FD';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        children: [
          Hero(
            tag: 'avatar-hero',
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
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
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundImage: NetworkImage(photo),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          prefill.name ?? 'Guest',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          prefill.role ?? '-',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          prefill.site ?? '-',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                _InfoTile(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: prefill.email ?? '-',
                ),
                _InfoTile(
                  icon: Icons.location_on_outlined,
                  label: 'Site',
                  value: prefill.site ?? '-',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (!readOnly)
            ElevatedButton.icon(
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                padding: const EdgeInsets.symmetric(vertical: 14),
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
            ),
          if (readOnly)
            const Padding(
              padding: EdgeInsets.only(top: 8.0),
              child: Text(
                'Viewing local profile (not signed in).',
                style: TextStyle(color: Colors.grey),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFE5ECF5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: Colors.grey.shade700),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
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
  String? _photoUrl; // existing url
  File? _pickedImage;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.initialData;

    _nameCtrl = TextEditingController(
        text: (d['name'] ?? d['fullName'] ?? '') as String);
    _phoneCtrl =
        TextEditingController(text: (d['phone'] ?? '') as String);
    _deptCtrl =
        TextEditingController(text: (d['department'] ?? '') as String);
    _siteCtrl = TextEditingController(
        text: (d['siteName'] ?? d['site'] ?? '') as String);

    // Employment type: pastikan String dan bukan kosong; kalau tak, biar null
    final rawEmpType = d['employmentType'];
    if (rawEmpType is String && rawEmpType.isNotEmpty) {
      _employmentType = rawEmpType;
    } else {
      _employmentType = null;
    }

    _photoUrl =
    (d['photoUrl'] ?? d['faceImageUrl'] ?? '') as String?;
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
        // rekod bila profile di-update
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update FirebaseAuth display name & photo jika user sekarang sama uid
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
      Navigator.of(context).pop(); // kembali ke FullProfilePage
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
                // HEADER avatar + nama
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
    // pastikan value valid; kalau tak match dengan mana-mana item, biar null
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
