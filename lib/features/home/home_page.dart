// lib/features/home/home_page.dart
import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/supabase_service.dart';
import '../../services/company_service.dart';
import '../attendance/check_in_out_export.dart';
import '../attendance/my_attendance_page.dart';
import '../claims/apply_claim_page.dart';
import '../claims/my_claims_page.dart';
import '../hr/hr_dashboard_page.dart';
import '../leave/apply_leave_page.dart';
import '../leave/my_leave_list_page.dart';
import '../notifications/notification_page.dart';
import '../payslip/payslip_list_page.dart';
import '../profile/full_profile_page.dart';

// ============================= HOME PAGE =============================
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.isHr,
    required this.displayName,
    this.siteName = 'Pulau Besar Site',
    this.photoUrl,
    this.roleTitle,
    this.onLogout,
    this.insideGeofence = true,
    this.lastIn,
    this.lastOut,
  });

  // Fallbacks (first paint while Supabase loads)
  final bool isHr;
  final String displayName;
  final String siteName;
  final String? photoUrl;
  final String? roleTitle;

  final Future<void> Function(BuildContext ctx)? onLogout;
  final bool insideGeofence;
  final String? lastIn;
  final String? lastOut;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Timer _timer;
  DateTime _now = DateTime.now();

  String? _lastInStr;
  String? _lastOutStr;
  StreamSubscription? _staffSub;

  @override
  void initState() {
    super.initState();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });

    _listenUserLastTimes();
  }

  void _listenUserLastTimes() {
    final svc = SupabaseService.instance;
    final staffId = svc.staffId;
    if (staffId == null) return;

    _staffSub = Supabase.instance.client
        .from('staff')
        .stream(primaryKey: ['id'])
        .eq('id', staffId)
        .listen((rows) {
      if (rows.isEmpty) return;
      final data = rows.first;

      String? inStr;
      String? outStr;

      final lastIn = data['last_in'];
      final lastOut = data['last_out'];

      if (lastIn is String && lastIn.isNotEmpty) {
        inStr = _formatLastTime(DateTime.parse(lastIn));
      }
      if (lastOut is String && lastOut.isNotEmpty) {
        outStr = _formatLastTime(DateTime.parse(lastOut));
      }

      if (mounted) {
        setState(() {
          _lastInStr = inStr;
          _lastOutStr = outStr;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _staffSub?.cancel();
    super.dispose();
  }

  String _formatTime(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    final s = d.second.toString().padLeft(2, '0');
    final am = d.hour < 12 ? 'AM' : 'PM';
    return '$h:$m:$s $am';
  }

  String _formatLastTime(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    final am = d.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $am';
  }

  String _formatDate(DateTime d) {
    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${days[d.weekday % 7]}, ${d.day.toString().padLeft(2, '0')} '
        '${months[d.month - 1]} ${d.year}';
  }

  _LiveProfile _computeLiveProfile() {
    final svc = SupabaseService.instance;
    final data = svc.staffData;

    final fallbackName = widget.displayName.isNotEmpty
        ? widget.displayName
        : (svc.email ?? 'User');

    final nameRaw = (data?['full_name'] as String?)?.trim();
    final photoRaw = (data?['photo_url'] as String?)?.trim()
        ?? (data?['profile_photo_url'] as String?)?.trim();

    final roleRaw = (data?['app_role'] as String?)?.toLowerCase().trim();
    final positionRaw = (data?['position'] as String?)?.trim();

    final name = (nameRaw != null && nameRaw.isNotEmpty) ? nameRaw : fallbackName;
    final site = CompanyService.instance.siteName;
    final photoUrl = (photoRaw != null && photoRaw.isNotEmpty) ? photoRaw : widget.photoUrl;

    final r = (roleRaw ?? '');
    final isHr = widget.isHr ||
        r == 'hr' ||
        r == 'manager' ||
        r == 'admin' ||
        r.contains('hr') ||
        r.contains('manager') ||
        r.contains('admin');

    final roleText = (positionRaw != null && positionRaw.isNotEmpty)
        ? positionRaw
        : (isHr ? 'HR / Manager' : 'Staff');

    return _LiveProfile(
      name: name,
      roleText: roleText,
      site: site,
      photoUrl: photoUrl,
      isHr: isHr,
    );
  }

  void _openFullProfileLive(_LiveProfile p) {
    final svc = SupabaseService.instance;
    final uid = svc.staffId;

    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, anim, __) => FadeTransition(
          opacity: anim,
          child: FullProfilePage(
            uid: uid,
            prefill: ProfilePrefill(
              name: p.name,
              email: svc.email,
              role: p.roleText,
              site: p.site,
              photoUrl: p.photoUrl,
            ),
          ),
        ),
      ),
    );
  }

  void _openLeaveMenuSheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Leave options',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Apply for new leave or review your past requests.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF00A86B),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ApplyLeavePage()),
                    );
                  },
                  label: const Text('Apply New Leave',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.list_alt_rounded),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: Color(0xFF00A86B), width: 1.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const MyLeaveListPage()),
                    );
                  },
                  label: const Text('My Leave Requests',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: Color(0xFF00A86B),
                      )),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openClaimMenuSheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Claim options',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Submit a new claim or review your past submissions.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0EA5E9),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ApplyClaimPage()),
                    );
                  },
                  label: const Text('Apply New Claim',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.receipt_long_rounded),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: Color(0xFF0EA5E9), width: 1.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const MyClaimsPage()),
                    );
                  },
                  label: const Text('My Claims',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: Color(0xFF0EA5E9),
                      )),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = _formatTime(_now);
    final dateStr = _formatDate(_now);

    final lastInDisplay = _lastInStr ?? widget.lastIn ?? '--:--';
    final lastOutDisplay = _lastOutStr ?? widget.lastOut ?? '--:--';

    final svc = SupabaseService.instance;
    final staffId = svc.staffId;

    final p = _computeLiveProfile();

    return _buildScaffold(
      uid: staffId,
      timeStr: timeStr,
      dateStr: dateStr,
      lastInDisplay: lastInDisplay,
      lastOutDisplay: lastOutDisplay,
      profile: p,
    );
  }

  Scaffold _buildScaffold({
    required String? uid,
    required String timeStr,
    required String dateStr,
    required String lastInDisplay,
    required String lastOutDisplay,
    required _LiveProfile profile,
  }) {
    return Scaffold(
      backgroundColor: _Coastal.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.transparent,
            expandedHeight: 200,
            actions: [
              if (uid != null)
                _NotificationBellButton(staffId: uid),
              if (widget.onLogout != null)
                IconButton(
                  tooltip: 'Logout',
                  icon: const Icon(Icons.logout_rounded, color: Colors.white),
                  onPressed: () async {
                    final ok = await _confirmLogout(context);
                    if (!context.mounted) return;
                    if (ok) {
                      await widget.onLogout!(context);
                    }
                  },
                ),
            ],
            flexibleSpace: const FlexibleSpaceBar(
              background: _CoastalHeader(),
            ),
          ),

          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyHeaderDelegate(
              minExtent: 86,
              maxExtent: 86,
              child: Material(
                color: Colors.white,
                elevation: 1,
                child: _ProfileBar(
                  name: profile.name,
                  role: profile.roleText,
                  site: profile.site,
                  photoUrl: profile.photoUrl,
                  onTap: () => _openFullProfileLive(profile),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: _ClockCard(
                time: timeStr,
                date: dateStr,
                insideGeofence: widget.insideGeofence,
                lastIn: lastInDisplay,
                lastOut: lastOutDisplay,
                onPunchIn: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CheckInOutPage()),
                ),
                onPunchOut: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CheckInOutPage()),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
              child: SizedBox(
                height: 50,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _ActionChip(
                      label: 'My Attendance',
                      icon: Icons.schedule,
                      bgColor: const Color(0xFFE0F2FE),
                      iconColor: const Color(0xFF2563EB),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const MyAttendancePage()),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    _ActionChip(
                      label: 'Apply Leave',
                      icon: Icons.event_note_rounded,
                      bgColor: const Color(0xFFEDE9FE),
                      iconColor: const Color(0xFF7C3AED),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ApplyLeavePage()),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    _ActionChip(
                      label: 'My Leave',
                      icon: Icons.list_alt_rounded,
                      bgColor: const Color(0xFFE0F7EC),
                      iconColor: const Color(0xFF16A34A),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const MyLeaveListPage()),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    _ActionChip(
                      label: 'New Claim',
                      icon: Icons.receipt_long_rounded,
                      bgColor: const Color(0xFFFEF9C3),
                      iconColor: const Color(0xFFCA8A04),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ApplyClaimPage()),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    _ActionChip(
                      label: 'Payslips',
                      icon: Icons.picture_as_pdf_rounded,
                      bgColor: const Color(0xFFEFF6FF),
                      iconColor: const Color(0xFF1D4ED8),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const PayslipListPage()),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.0,
              ),
              delegate: SliverChildListDelegate([
                _FeatureCard(
                  icon: Icons.event_note_rounded,
                  title: 'Leave',
                  subtitle: 'Apply & track status',
                  iconBg: const Color(0xFFEEF2FF),
                  iconColor: const Color(0xFF4F46E5),
                  onTap: _openLeaveMenuSheet,
                ),
                _FeatureCard(
                  icon: Icons.receipt_long_rounded,
                  title: 'Claims',
                  subtitle: 'Submit & track claims',
                  iconBg: const Color(0xFFE0F2FE),
                  iconColor: const Color(0xFF0284C7),
                  onTap: _openClaimMenuSheet,
                ),
                _FeatureCard(
                  icon: Icons.picture_as_pdf_rounded,
                  title: 'Payslip',
                  subtitle: 'View monthly PDFs',
                  iconBg: const Color(0xFFFEF3C7),
                  iconColor: const Color(0xFFD97706),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PayslipListPage()),
                    );
                  },
                ),

                if (profile.isHr)
                  _HrPanelCard(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const HrDashboardPage()),
                      );
                    },
                  )
                else
                  const _SmartBayuLogoCard(),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ===================== Notification Bell (Supabase query) =====================
class _NotificationBellButton extends StatefulWidget {
  const _NotificationBellButton({required this.staffId});
  final String staffId;

  @override
  State<_NotificationBellButton> createState() => _NotificationBellButtonState();
}

class _NotificationBellButtonState extends State<_NotificationBellButton> {
  int _unseenCount = 0;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _loadCount();
    _listenChanges();
  }

  Future<void> _loadCount() async {
    try {
      final result = await Supabase.instance.client
          .from('staff_notifications')
          .select('id')
          .eq('staff_id', widget.staffId)
          .eq('is_read', false);
      if (mounted) {
        setState(() => _unseenCount = (result as List).length);
      }
    } catch (_) {}
  }

  void _listenChanges() {
    _sub = Supabase.instance.client
        .from('staff_notifications')
        .stream(primaryKey: ['id'])
        .eq('staff_id', widget.staffId)
        .listen((rows) {
      final unread = rows.where((r) => r['is_read'] == false).length;
      if (mounted) setState(() => _unseenCount = unread);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Notifications',
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NotificationPage()),
        );
      },
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_none_rounded, color: Colors.white),
          if (_unseenCount > 0)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(999),
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Center(
                  child: Text(
                    _unseenCount > 9 ? '9+' : _unseenCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LiveProfile {
  final String name;
  final String roleText;
  final String site;
  final String? photoUrl;
  final bool isHr;

  const _LiveProfile({
    required this.name,
    required this.roleText,
    required this.site,
    required this.photoUrl,
    required this.isHr,
  });
}

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  _StickyHeaderDelegate({
    required this.minExtent,
    required this.maxExtent,
    required this.child,
  });

  @override
  final double minExtent;
  @override
  final double maxExtent;
  final Widget child;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => child;

  @override
  bool shouldRebuild(covariant _StickyHeaderDelegate old) =>
      minExtent != old.minExtent || maxExtent != old.maxExtent || child != old.child;
}

class _CoastalHeader extends StatelessWidget {
  const _CoastalHeader();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset('assets/images/beach.png', fit: BoxFit.cover),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.05),
                Colors.black.withValues(alpha: 0.10),
              ],
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Spacer(),
                Image.asset('assets/logos/bayu_lestari_logo.png', height: 80),
                const SizedBox(height: 6),
                const Text(
                  'Welcome Back!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Poppins',
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileBar extends StatelessWidget {
  const _ProfileBar({
    required this.name,
    required this.role,
    required this.site,
    this.photoUrl,
    this.onTap,
  });

  final String name, role, site;
  final String? photoUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(
            children: [
              Hero(
                tag: 'avatar-hero',
                child: CircleAvatar(
                  radius: 26,
                  backgroundImage: (photoUrl != null && photoUrl!.isNotEmpty)
                      ? NetworkImage(photoUrl!)
                      : null,
                  backgroundColor: Colors.teal.shade100,
                  child: (photoUrl == null || photoUrl!.isEmpty)
                      ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  )
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$role • $site',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClockCard extends StatelessWidget {
  const _ClockCard({
    required this.time,
    required this.date,
    required this.insideGeofence,
    required this.onPunchIn,
    required this.onPunchOut,
    required this.lastIn,
    required this.lastOut,
  });

  final String time;
  final String date;
  final bool insideGeofence;
  final VoidCallback onPunchIn;
  final VoidCallback onPunchOut;
  final String lastIn;
  final String lastOut;

  @override
  Widget build(BuildContext context) {
    const navyDark = Color(0xFF172637);
    final primary = Theme.of(context).colorScheme.primary;

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Today', style: TextStyle(color: navyDark, fontWeight: FontWeight.w700)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: insideGeofence ? Colors.green.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    Icon(
                      insideGeofence ? Icons.location_on : Icons.error_outline,
                      size: 16,
                      color: insideGeofence ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      insideGeofence ? 'Within 50m' : 'Outside geofence',
                      style: TextStyle(
                        color: insideGeofence ? Colors.green.shade800 : Colors.orange.shade800,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            time,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: navyDark),
          ),
          const SizedBox(height: 6),
          Text(
            date,
            textAlign: TextAlign.center,
            style: TextStyle(color: navyDark.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPunchIn,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: primary, width: 1.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    backgroundColor: Colors.white,
                  ),
                  icon: Icon(Icons.login_rounded, color: primary),
                  label: Text('Punch In', style: TextStyle(color: primary, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPunchOut,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: primary, width: 1.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    backgroundColor: Colors.white,
                  ),
                  icon: Icon(Icons.logout_rounded, color: primary),
                  label: Text('Punch Out', style: TextStyle(color: primary, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Last In:  $lastIn', style: const TextStyle(color: _Coastal.muted)),
              Text('Last Out: $lastOut', style: const TextStyle(color: _Coastal.muted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconBg = const Color(0xFFE0F2FE),
    this.iconColor = const Color(0xFF0284C7),
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color iconBg;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 24, color: iconColor),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: _Coastal.muted, fontSize: 13)),
        ],
      ),
    );
  }
}

// ===================== HR Panel (kelabu biasa + badge HR ONLY) =====================
class _HrPanelCard extends StatelessWidget {
  const _HrPanelCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F7EC),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.dashboard_customize_rounded, color: Color(0xFF16A34A)),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F7EC),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'HR ONLY',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF166534),
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'HR Panel',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
          ),
          const SizedBox(height: 4),
          const Text('HR dashboard & tools', style: TextStyle(color: _Coastal.muted, fontSize: 13)),
        ],
      ),
    );
  }
}

// ===================== Staff tile: logo SmartBayu sahaja =====================
class _SmartBayuLogoCard extends StatelessWidget {
  const _SmartBayuLogoCard();

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      onTap: null,
      child: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final logoSize = (constraints.maxHeight * 0.55).clamp(60.0, 110.0);

            return Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Image.asset(
                'assets/logos/smartbayu_icon.png',
                height: logoSize,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.image_not_supported_rounded,
                    size: 48,
                    color: Colors.grey,
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}



class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.label,
    required this.icon,
    this.onTap,
    this.bgColor,
    this.iconColor,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final Color? bgColor;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor ?? Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _Coastal.cardBorder),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: iconColor ?? _Coastal.sea),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF111827))),
          ],
        ),
      ),
    );
  }
}

// ===================== Base card kelabu (standard SmartBayu) =====================
class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _Coastal.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _Coastal.cardBorder),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

Future<bool> _confirmLogout(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Logout?'),
      content: const Text('You will be returned to the login screen.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Logout'),
        ),
      ],
    ),
  );
  return result ?? false;
}

class _Coastal {
  static const surface = Color(0xFFFAFBFC);
  static const card = Color(0xFFE9F1F7);
  static const cardBorder = Color(0xFFD7E3EC);
  static const muted = Color(0xFF6E7F8A);
  static const sea = Color(0xFF0EA5A4);
}
