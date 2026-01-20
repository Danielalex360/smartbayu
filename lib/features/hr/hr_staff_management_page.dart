// lib/features/hr/hr_staff_management_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import 'hr_staff_form_page.dart';

class HrStaffManagementPage extends StatefulWidget {
  const HrStaffManagementPage({super.key});

  @override
  State<HrStaffManagementPage> createState() => _HrStaffManagementPageState();
}

class _HrStaffManagementPageState extends State<HrStaffManagementPage> {
  final TextEditingController _searchCtrl = TextEditingController();

  String _roleFilter = 'all';   // 'all' | 'staff' | 'hr'
  String _statusFilter = 'all'; // 'all' | 'active' | 'inactive'
  String _siteFilter = 'All';   // 'All' | specific site

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // Helper: ambil URL gambar staff dari pelbagai kemungkinan field
  String _getPhotoUrl(Map<String, dynamic> data) {
    final dynamic url = data['photoUrl'] ??
        data['photourl'] ??
        data['photoURL'] ??
        data['faceImageUrl'] ??
        data['imageUrl'] ??
        data['avatarUrl'] ??
        data['profilePic'];
    return (url ?? '').toString();
  }

  Future<void> _deleteStaff(
      String docId, {
        String? name,
        String? photoUrl,
      }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Staff'),
        content: Text(
          'Are you sure you want to delete staff "${name ?? ''}"?\n'
              'This will remove the profile from HR records.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final usersRef = FirebaseFirestore.instance.collection('users');
      await usersRef.doc(docId).delete();

      if (photoUrl != null && photoUrl.startsWith('http')) {
        try {
          final ref = FirebaseStorage.instance.refFromURL(photoUrl);
          await ref.delete();
        } catch (_) {
          // tak apa kalau gagal delete gambar
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Staff deleted.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete staff: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersRef = FirebaseFirestore.instance.collection('users');

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text('Staff Management'),
        backgroundColor: const Color(0xFFF5F7FB),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(
        children: [
          // ─── TOP FILTERS CARD ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                children: [
                  // Search bar
                  TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search by name, email or site…',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),

                  const SizedBox(height: 8),

                  // Filters row (Role + Status)
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _roleFilter,
                          decoration: const InputDecoration(
                            labelText: 'Role',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'all',
                              child: Text('All roles'),
                            ),
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
                            if (v != null) {
                              setState(() => _roleFilter = v);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _statusFilter,
                          decoration: const InputDecoration(
                            labelText: 'Status',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'all',
                              child: Text('All status'),
                            ),
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
                            if (v != null) {
                              setState(() => _statusFilter = v);
                            }
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Site filter – ambil list site dari data
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: usersRef.snapshots(),
                    builder: (context, snapshot) {
                      final docs = snapshot.data?.docs ?? [];
                      final sites = <String>{'All'};
                      for (final d in docs) {
                        final data = d.data();
                        final site = (data['siteName'] ??
                            data['site'] ??
                            '')
                            .toString();
                        if (site.isNotEmpty) sites.add(site);
                      }
                      final siteList = sites.toList()..sort();

                      if (!siteList.contains(_siteFilter)) {
                        _siteFilter = 'All';
                      }

                      return DropdownButtonFormField<String>(
                        value: _siteFilter,
                        decoration: const InputDecoration(
                          labelText: 'Site',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: siteList
                            .map(
                              (s) => DropdownMenuItem(
                            value: s,
                            child: Text(s == 'All' ? 'All sites' : s),
                          ),
                        )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _siteFilter = v);
                          }
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // ─── STAFF LIST ──────────────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream:
              usersRef.orderBy('name', descending: false).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error loading staff: ${snapshot.error}'),
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                final q = _searchCtrl.text.trim().toLowerCase();

                final filtered = docs.where((doc) {
                  final data = doc.data();

                  final name = (data['fullName'] ??
                      data['name'] ??
                      data['displayName'] ??
                      'Unnamed')
                      .toString();
                  final email = (data['email'] ?? '-').toString();
                  final site = (data['siteName'] ??
                      data['site'] ??
                      'Bayu Lestari Resort Island')
                      .toString();

                  final position =
                  (data['position'] ?? data['roleTitle'] ?? '')
                      .toString();

                  // --- determine role type (hr/staff) consistently ---
                  final rawRole = (data['role'] ?? '').toString().toLowerCase();
                  final department =
                  (data['department'] ?? '').toString().toLowerCase();
                  final isHrFlag = rawRole == 'hr' ||
                      data['isHr'] == true ||
                      department.contains('human resource') ||
                      position.toLowerCase().contains('hr');

                  final roleType = isHrFlag ? 'hr' : 'staff';

                  final boolActive = (data['active'] == true);
                  final status = (data['status'] ??
                      (boolActive ? 'active' : 'inactive'))
                      .toString()
                      .toLowerCase();

                  // --- Search filter ---
                  final nameL = name.toLowerCase();
                  final emailL = email.toLowerCase();
                  final siteL = site.toLowerCase();
                  if (q.isNotEmpty &&
                      !nameL.contains(q) &&
                      !emailL.contains(q) &&
                      !siteL.contains(q)) {
                    return false;
                  }

                  // --- Role filter ---
                  if (_roleFilter != 'all' && roleType != _roleFilter) {
                    return false;
                  }

                  // --- Status filter ---
                  if (_statusFilter != 'all' &&
                      status != _statusFilter.toLowerCase()) {
                    return false;
                  }

                  // --- Site filter ---
                  if (_siteFilter != 'All' && site != _siteFilter) {
                    return false;
                  }

                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text('No staff found.'),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final doc = filtered[index];
                    final data = doc.data();

                    final name = (data['fullName'] ??
                        data['name'] ??
                        data['displayName'] ??
                        'Unnamed')
                        .toString();
                    final email = (data['email'] ?? '-').toString();
                    final siteName = (data['siteName'] ??
                        data['site'] ??
                        'Bayu Lestari Resort Island')
                        .toString();
                    final staffId =
                    (data['staffId'] ?? data['employeeId'] ?? '')
                        .toString();
                    final position =
                    (data['position'] ?? data['roleTitle'] ?? '')
                        .toString();

                    final rawRole =
                    (data['role'] ?? '').toString().toLowerCase();
                    final department =
                    (data['department'] ?? '').toString().toLowerCase();
                    final isHrFlag = rawRole == 'hr' ||
                        data['isHr'] == true ||
                        department.contains('human resource') ||
                        position.toLowerCase().contains('hr');

                    final roleLabel = isHrFlag ? 'HR' : 'STAFF';

                    final boolActive = (data['active'] == true);
                    final status = (data['status'] ??
                        (boolActive ? 'active' : 'inactive'))
                        .toString()
                        .toLowerCase();

                    final photoUrl = _getPhotoUrl(data);
                    final isActive = status.startsWith('a');

                    return InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => HrStaffFormPage(
                              staffDocId: doc.id,
                              initialData: data,
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Avatar
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: Colors.blueGrey.shade100,
                              backgroundImage: photoUrl.isNotEmpty
                                  ? NetworkImage(photoUrl)
                                  : null,
                              child: photoUrl.isEmpty
                                  ? Text(
                                name.isNotEmpty
                                    ? name[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              )
                                  : null,
                            ),
                            const SizedBox(width: 14),

                            // Main text
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    email,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  if (siteName.isNotEmpty)
                                    Text(
                                      siteName,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  const SizedBox(height: 3),
                                  Text(
                                    [
                                      if (staffId.isNotEmpty) '#$staffId',
                                      if (position.isNotEmpty) position,
                                      roleLabel,
                                    ].join(' • '),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),

                            // Status + menu
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? Colors.green.withOpacity(0.15)
                                        : Colors.red.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    isActive ? 'Active' : 'Inactive',
                                    style: TextStyle(
                                      color: isActive
                                          ? Colors.green.shade800
                                          : Colors.red.shade800,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                PopupMenuButton<String>(
                                  padding: EdgeInsets.zero,
                                  onSelected: (value) {
                                    if (value == 'delete') {
                                      _deleteStaff(
                                        doc.id,
                                        name: name,
                                        photoUrl: photoUrl.isEmpty
                                            ? null
                                            : photoUrl,
                                      );
                                    }
                                  },
                                  itemBuilder: (ctx) => const [
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text(
                                        'Delete Staff',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                  child: const Icon(
                                    Icons.more_vert,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const HrStaffFormPage(),
            ),
          );
        },
        icon: const Icon(Icons.person_add),
        label: const Text('Add Staff'),
      ),
    );
  }
}
