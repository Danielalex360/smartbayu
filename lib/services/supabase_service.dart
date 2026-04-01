import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Central Supabase service — caches auth→staff resolution after login.
///
/// Usage:
///   final svc = SupabaseService.instance;
///   svc.client          // SupabaseClient
///   svc.staffId         // current staff UUID
///   svc.companyId       // current company UUID
///   svc.isHr            // true if app_role = 'hr'
///   svc.staffData       // full staff row as Map
class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  SupabaseClient get client => Supabase.instance.client;

  // Cached user context (populated after login via loadUserContext)
  String? _staffId;
  String? _companyId;
  String? _userId;
  bool _isHr = false;
  Map<String, dynamic>? _staffData;

  String? get staffId => _staffId;
  String? get companyId => _companyId;
  String? get userId => _userId;
  bool get isHr => _isHr;
  Map<String, dynamic>? get staffData => _staffData;

  String get fullName => _staffData?['full_name'] as String? ?? '';
  String? get photoUrl => _staffData?['photo_url'] as String? ?? _staffData?['profile_photo_url'] as String?;
  String? get department => _staffData?['department'] as String?;
  String? get position => _staffData?['position'] as String?;
  String? get email => _staffData?['email'] as String?;
  String? get phone => _staffData?['phone'] as String?;
  String? get staffNumber => _staffData?['staff_number'] as String?;

  /// Call after successful login to resolve auth.uid → staff record.
  /// Returns true if staff record found, false otherwise.
  Future<bool> loadUserContext() async {
    final user = client.auth.currentUser;
    if (user == null) {
      clear();
      return false;
    }

    _userId = user.id;

    try {
      // Get company_id from public.users table
      final userRow = await client
          .from('users')
          .select('company_id')
          .eq('id', user.id)
          .maybeSingle();

      _companyId = userRow?['company_id'] as String?;

      // Get staff record linked to this auth user
      final staffRow = await client
          .from('staff')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (staffRow != null) {
        _staffId = staffRow['id'] as String;
        _staffData = staffRow;
        _companyId ??= staffRow['company_id'] as String?;

        final role = (staffRow['app_role'] as String?)?.toLowerCase() ?? 'staff';
        _isHr = role == 'hr' || role == 'admin' || role == 'manager';
      } else {
        // No staff record yet — might be first login, try email match
        if (_companyId != null) {
          final emailMatch = await client
              .from('staff')
              .select()
              .eq('company_id', _companyId!)
              .eq('email', user.email ?? '')
              .maybeSingle();

          if (emailMatch != null) {
            // Link this auth user to the staff record
            await client
                .from('staff')
                .update({'user_id': user.id})
                .eq('id', emailMatch['id']);

            _staffId = emailMatch['id'] as String;
            _staffData = emailMatch;
            final role = (emailMatch['app_role'] as String?)?.toLowerCase() ?? 'staff';
            _isHr = role == 'hr' || role == 'admin' || role == 'manager';
          }
        }
      }

      debugPrint('✅ SupabaseService: staffId=$_staffId, companyId=$_companyId, isHr=$_isHr');
      return _staffId != null;
    } catch (e) {
      debugPrint('❌ SupabaseService.loadUserContext error: $e');
      return false;
    }
  }

  /// Reload staff data (e.g. after profile edit)
  Future<void> refreshStaffData() async {
    if (_staffId == null) return;
    final row = await client
        .from('staff')
        .select()
        .eq('id', _staffId!)
        .maybeSingle();
    if (row != null) _staffData = row;
  }

  /// Clear cached context on logout
  void clear() {
    _staffId = null;
    _companyId = null;
    _userId = null;
    _isHr = false;
    _staffData = null;
  }

  /// Sign out and clear context
  Future<void> signOut() async {
    clear();
    await client.auth.signOut();
  }
}
