// lib/features/hr/hr_staff_management_page.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/supabase_service.dart';
import '../../services/company_service.dart';
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

  List<Map<String, dynamic>> _allStaff = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStaff() async {
    try {
      final companyId = SupabaseService.instance.companyId;
      if (companyId == null) return;

      final rows = await Supabase.instance.client
          .from('staff')
          .select()
          .eq('company_id', companyId)
          .order('full_name', ascending: true);

      if (mounted) {
        setState(() {
          _allStaff = List<Map<String, dynamic>>.from(rows);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
      debugPrint('Error loading staff: $e');
    }
  }

  String _getPhotoUrl(Map<String, dynamic> data) {
    final dynamic url = data['photo_url'] ??
        data['profile_photo_url'];
    return (url ?? '').toString();
  }

  Future<void> _deleteStaff(
      String staffId, {
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
      await Supabase.instance.client
          .from('staff')
          .delete()
          .eq('id', staffId);

      // Try to delete photo from storage if exists
      if (photoUrl != null && photoUrl.contains('smartbayu')) {
        try {
          // Extract path from URL
          final uri = Uri.parse(photoUrl);
          final pathSegments = uri.pathSegments;
          final bucketIndex = pathSegments.indexOf('smartbayu');
          if (bucketIndex >= 0 && bucketIndex < pathSegments.length - 1) {
            final storagePath = pathSegments.sublist(bucketIndex + 1).join('/');
            await Supabase.instance.client.storage
                .from('smartbayu')
                .remove([storagePath]);
          }
        } catch (_) {
          // ignore storage deletion failures
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Staff deleted.')),
      );
      _loadStaff(); // refresh
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete staff: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                      hintText: 'Search by name or email...',
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
                ],
              ),
            ),
          ),

          // ─── STAFF LIST ──────────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _buildStaffList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const HrStaffFormPage(),
            ),
          );
          _loadStaff(); // refresh after return
        },
        icon: const Icon(Icons.person_add),
        label: const Text('Add Staff'),
      ),
    );
  }

  Widget _buildStaffList() {
    final q = _searchCtrl.text.trim().toLowerCase();
    final siteName = CompanyService.instance.siteName;

    final filtered = _allStaff.where((data) {
      final name = (data['full_name'] ?? 'Unnamed').toString();
      final email = (data['email'] ?? '-').toString();
      final position = (data['position'] ?? '').toString();

      final rawRole = (data['app_role'] ?? '').toString().toLowerCase();
      final department = (data['department'] ?? '').toString().toLowerCase();
      final isHrFlag = rawRole == 'hr' ||
          rawRole == 'admin' ||
          rawRole == 'manager' ||
          department.contains('human resource') ||
          position.toLowerCase().contains('hr');

      final roleType = isHrFlag ? 'hr' : 'staff';

      final isActive = data['is_active'] == true;
      final status = isActive ? 'active' : 'inactive';

      // Search filter
      final nameL = name.toLowerCase();
      final emailL = email.toLowerCase();
      if (q.isNotEmpty &&
          !nameL.contains(q) &&
          !emailL.contains(q)) {
        return false;
      }

      // Role filter
      if (_roleFilter != 'all' && roleType != _roleFilter) {
        return false;
      }

      // Status filter
      if (_statusFilter != 'all' && status != _statusFilter) {
        return false;
      }

      return true;
    }).toList();

    if (filtered.isEmpty) {
      return const Center(child: Text('No staff found.'));
    }

    return RefreshIndicator(
      onRefresh: _loadStaff,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder: (context, index) {
          final data = filtered[index];
          final staffId = data['id'].toString();

          final name = (data['full_name'] ?? 'Unnamed').toString();
          final email = (data['email'] ?? '-').toString();
          final siteName = CompanyService.instance.siteName;
          final staffNumber = (data['staff_number'] ?? '').toString();
          final position = (data['position'] ?? '').toString();

          final rawRole = (data['app_role'] ?? '').toString().toLowerCase();
          final department = (data['department'] ?? '').toString().toLowerCase();
          final isHrFlag = rawRole == 'hr' ||
              rawRole == 'admin' ||
              rawRole == 'manager' ||
              department.contains('human resource') ||
              position.toLowerCase().contains('hr');

          final roleLabel = isHrFlag ? 'HR' : 'STAFF';

          final isActive = data['is_active'] == true;
          final photoUrl = _getPhotoUrl(data);

          return InkWell(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => HrStaffFormPage(
                    staffDocId: staffId,
                    initialData: data,
                  ),
                ),
              );
              _loadStaff(); // refresh after return
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
                            if (staffNumber.isNotEmpty) '#$staffNumber',
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
                              staffId,
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
      ),
    );
  }
}
