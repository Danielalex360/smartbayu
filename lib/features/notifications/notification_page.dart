// lib/features/notifications/notification_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/supabase_service.dart';
import '../payslip/payslip_list_page.dart';
import '../claims/my_claims_page.dart';
import '../leave/my_leave_list_page.dart';

class NotificationPage extends StatelessWidget {
  const NotificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final staffId = SupabaseService.instance.staffId;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        elevation: 0.8,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: Colors.black,
        centerTitle: true,
        title: const Text(
          'Notifications',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: staffId == null
            ? const Center(child: Text('Not signed in'))
            : _NotificationListBody(staffId: staffId),
      ),
    );
  }
}

class _NotificationListBody extends StatelessWidget {
  const _NotificationListBody({required this.staffId});
  final String staffId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client
          .from('staff_notifications')
          .stream(primaryKey: ['id'])
          .eq('staff_id', staffId)
          .order('created_at', ascending: false),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }

        final rows = snap.data ?? [];
        if (rows.isEmpty) {
          return const _EmptyNotificationView();
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: rows.length,
          itemBuilder: (context, index) {
            final data = rows[index];
            final id = data['id'] as String;

            final title = (data['title'] ?? '').toString();
            final message = (data['message'] ?? '').toString();
            final type = (data['type'] ?? 'general').toString();
            final read = data['is_read'] == true;

            DateTime? created;
            final createdRaw = data['created_at'];
            if (createdRaw is String && createdRaw.isNotEmpty) {
              created = DateTime.tryParse(createdRaw);
            }

            return _NotificationTile(
              title: title,
              message: message,
              type: type,
              createdAt: created,
              read: read,
              onTap: () async {
                // Mark as read
                await Supabase.instance.client
                    .from('staff_notifications')
                    .update({'is_read': true})
                    .eq('id', id);

                if (!context.mounted) return;

                // Show detail bottom sheet
                _showNotificationDetailSheet(
                  context: context,
                  title: title,
                  message: message,
                  type: type,
                  createdAt: created,
                );
              },
            );
          },
        );
      },
    );
  }

  void _showNotificationDetailSheet({
    required BuildContext context,
    required String title,
    required String message,
    required String type,
    required DateTime? createdAt,
  }) {
    final visual = _visualForType(type);
    final createdText = createdAt == null
        ? '-'
        : '${createdAt.day.toString().padLeft(2, '0')}/'
        '${createdAt.month.toString().padLeft(2, '0')}/'
        '${createdAt.year} ${createdAt.hour.toString().padLeft(2, '0')}:'
        '${createdAt.minute.toString().padLeft(2, '0')}';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 50,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: visual.bgColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      visual.icon,
                      color: visual.iconColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                createdText,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _openRelatedPage(context, type);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    _buttonTextForType(type),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openRelatedPage(BuildContext context, String type) {
    if (_isLeaveType(type)) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const MyLeaveListPage()),
      );
    } else if (_isClaimType(type)) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const MyClaimsPage()),
      );
    } else if (_isPayslipType(type)) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PayslipListPage()),
      );
    } else {
      // default - stay on notification page
    }
  }
}

class _EmptyNotificationView extends StatelessWidget {
  const _EmptyNotificationView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: const BoxDecoration(
                color: Color(0xFFE0ECFF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 36,
                color: Color(0xFF2563EB),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No notifications yet',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Updates about your leave, claims and payslip will appear here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    required this.read,
    required this.onTap,
  });

  final String title;
  final String message;
  final String type;
  final DateTime? createdAt;
  final bool read;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visual = _visualForType(type);

    final timeText = createdAt == null
        ? ''
        : '${createdAt!.day.toString().padLeft(2, '0')}/'
        '${createdAt!.month.toString().padLeft(2, '0')}/'
        '${createdAt!.year} ${createdAt!.hour.toString().padLeft(2, '0')}:'
        '${createdAt!.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon circle
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: visual.bgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  visual.icon,
                  color: visual.iconColor,
                ),
              ),
              const SizedBox(width: 10),
              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontWeight:
                              read ? FontWeight.w500 : FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (!read)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(top: 6),
                            decoration: const BoxDecoration(
                              color: Color(0xFF2563EB),
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeText,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────── Visual helper for type ─────────────────

class _NotificationVisual {
  final IconData icon;
  final Color bgColor;
  final Color iconColor;

  _NotificationVisual({
    required this.icon,
    required this.bgColor,
    required this.iconColor,
  });
}

bool _isLeaveType(String type) {
  return type == 'leave' ||
      type == 'leave_request' ||
      type == 'leave_status';
}

bool _isClaimType(String type) {
  return type == 'claim' ||
      type == 'claim_request' ||
      type == 'claim_status';
}

bool _isPayslipType(String type) {
  return type == 'payslip';
}

_NotificationVisual _visualForType(String type) {
  if (_isLeaveType(type)) {
    return _NotificationVisual(
      icon: Icons.event_available_rounded,
      bgColor: const Color(0xFFE6F4EA),
      iconColor: const Color(0xFF16A34A),
    );
  } else if (_isClaimType(type)) {
    return _NotificationVisual(
      icon: Icons.request_page_rounded,
      bgColor: const Color(0xFFE0F2FE),
      iconColor: const Color(0xFF0284C7),
    );
  } else if (_isPayslipType(type)) {
    return _NotificationVisual(
      icon: Icons.picture_as_pdf_rounded,
      bgColor: const Color(0xFFFFF4E5),
      iconColor: const Color(0xFFEA580C),
    );
  } else {
    return _NotificationVisual(
      icon: Icons.notifications_rounded,
      bgColor: const Color(0xFFE5E7EB),
      iconColor: const Color(0xFF4B5563),
    );
  }
}

String _buttonTextForType(String type) {
  if (_isLeaveType(type)) {
    return 'Open Leave Page';
  } else if (_isClaimType(type)) {
    return 'Open Claims Page';
  } else if (_isPayslipType(type)) {
    return 'Open Payslips Page';
  } else {
    return 'Close';
  }
}
