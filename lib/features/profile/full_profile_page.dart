// lib/features/profile/full_profile_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/supabase_service.dart';
import 'edit_profile_page.dart';

class FullProfilePage extends StatelessWidget {
  const FullProfilePage({
    super.key,
    this.uid,
    this.prefill,
    this.readOnly = false,
  });

  /// If uid is provided, fetch from Supabase staff table; if null, use prefill.
  final String? uid;
  final ProfilePrefill? prefill;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    // Guest mode: no uid -> render static
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

    // Signed-in mode: fetch staff data from Supabase
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text('Staff Profile'),
        backgroundColor: const Color(0xFFF5F7FB),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: _SignedInProfileBody(
        uid: uid!,
        prefill: prefill,
        readOnly: readOnly,
      ),
    );
  }
}

class _SignedInProfileBody extends StatefulWidget {
  const _SignedInProfileBody({
    required this.uid,
    this.prefill,
    required this.readOnly,
  });

  final String uid;
  final ProfilePrefill? prefill;
  final bool readOnly;

  @override
  State<_SignedInProfileBody> createState() => _SignedInProfileBodyState();
}

class _SignedInProfileBodyState extends State<_SignedInProfileBody> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStaffData();
  }

  Future<void> _loadStaffData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final row = await Supabase.instance.client
          .from('staff')
          .select()
          .eq('id', widget.uid)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _data = row;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(child: Text('Error: $_error'));
    }

    if (_data == null) {
      final p = widget.prefill ?? const ProfilePrefill();
      return _GuestBody(prefill: p, readOnly: true);
    }

    final data = _data!;
    final svc = SupabaseService.instance;

    final name = data['full_name'] as String? ??
        svc.fullName;
    final email = data['email'] as String? ?? svc.email ?? '-';
    final role = data['app_role'] as String? ?? 'staff';
    final site = data['department'] as String? ?? '-';
    final phone = data['phone'] as String? ?? '-';
    final empId = data['staff_number'] as String? ?? '-';
    final dept = data['department'] as String? ?? '-';
    final empType = data['employment_type'] as String? ?? '-';

    final photo = data['photo_url'] as String? ??
        data['profile_photo_url'] as String? ??
        svc.photoUrl ??
        'https://ui-avatars.com/api/?name=${Uri.encodeComponent(name.isNotEmpty ? name : 'U')}&background=BAE6FD';

    // joinDate
    String? joinDate;
    final rawJoinDate = data['join_date'] ?? data['joined_at'];
    if (rawJoinDate is String && rawJoinDate.isNotEmpty) {
      final dt = DateTime.tryParse(rawJoinDate);
      if (dt != null) {
        String two(int n) => n.toString().padLeft(2, '0');
        joinDate = '${two(dt.day)}.${two(dt.month)}.${dt.year}';
      } else {
        joinDate = rawJoinDate;
      }
    }

    // status
    String status;
    final rawStatus = data['status'];
    if (rawStatus is String && rawStatus.isNotEmpty) {
      status = rawStatus;
    } else if (data['is_active'] == false) {
      status = 'Inactive';
    } else {
      status = 'Active';
    }

    // Only the profile owner can edit
    final canEdit = !widget.readOnly && svc.staffId == widget.uid;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        children: [
          // HEADER CARD
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
                          name.isNotEmpty ? name : 'Unnamed Staff',
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
                              : role,
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

          // INFO CARD
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

          // Joined + status
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

          // ACTION BUTTONS (Edit + Sign out)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(canEdit ? 'Edit profile' : 'View only'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: !canEdit
                      ? null
                      : () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => EditProfilePage(
                          uid: widget.uid,
                          initialData: data,
                        ),
                      ),
                    );
                    // Refresh after returning from edit
                    _loadStaffData();
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
                    await SupabaseService.instance.signOut();
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
                await SupabaseService.instance.signOut();
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

/// Data prefill when user is not signed in
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
