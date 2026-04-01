// lib/services/attendance_service.dart
//
// Central service for all attendance / punch operations.
// Single source of truth for Supabase reads & writes.

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/attendance_models.dart';
import 'supabase_service.dart';

class AttendanceService {
  AttendanceService._();
  static final instance = AttendanceService._();

  SupabaseClient get _db => SupabaseService.instance.client;

  // ─── Helpers ───

  String docIdForDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  // ─── Load today's record ───

  Future<DayRecord?> loadDay(String staffId, DateTime date) async {
    final dateStr = docIdForDate(date);
    final row = await _db
        .from('attendance')
        .select()
        .eq('staff_id', staffId)
        .eq('attendance_date', dateStr)
        .maybeSingle();

    if (row == null) return null;
    return DayRecord.fromSupabase(row);
  }

  // ─── Load today's punches (raw maps for check-in page) ───

  Future<List<Map<String, dynamic>>> loadTodayPunchMaps(String staffId) async {
    final now = DateTime.now();
    final dateStr = docIdForDate(now);
    final row = await _db
        .from('attendance')
        .select('punches, check_in_time, check_out_time')
        .eq('staff_id', staffId)
        .eq('attendance_date', dateStr)
        .maybeSingle();

    if (row == null) return [];

    final punches = row['punches'];
    if (punches != null && punches is List && punches.isNotEmpty) {
      return List<Map<String, dynamic>>.from(punches);
    }

    // Fallback: derive from flat columns
    final List<Map<String, dynamic>> migrated = [];
    final inAt = row['check_in_time'] as String?;
    if (inAt != null) {
      migrated.add({
        'type': PunchType.checkin.key,
        'time': inAt,
      });
    }
    final outAt = row['check_out_time'] as String?;
    if (outAt != null) {
      migrated.add({
        'type': PunchType.checkout.key,
        'time': outAt,
      });
    }
    return migrated;
  }

  // ─── Record a punch ───

  Future<List<Map<String, dynamic>>> recordPunch({
    required String staffId,
    required PunchType type,
    required double lat,
    required double lng,
    required bool geoOk,
    required double? confidence,
    required List<Map<String, dynamic>> existingPunches,
    String? deviceId,
  }) async {
    final now = DateTime.now();
    final dateStr = docIdForDate(now);
    final companyId = SupabaseService.instance.companyId;

    final punchMap = {
      'type': type.key,
      'time': now.toUtc().toIso8601String(),
      'lat': lat,
      'lng': lng,
      'geoOk': geoOk,
      'confidence': confidence,
    };

    final punches = List<Map<String, dynamic>>.from(existingPunches);
    punches.add(punchMap);

    // Derive first-in and last-out
    String? firstIn;
    String? lastOut;
    for (final p in punches) {
      final t = p['time'] as String?;
      final pType = PunchType.fromKey(p['type'] as String?);
      if (pType == PunchType.checkin) firstIn ??= t;
      if (pType == PunchType.checkout) lastOut = t;
    }

    // Derive status
    final lastPunchType = PunchType.fromKey(punches.last['type'] as String?);
    String status;
    switch (lastPunchType) {
      case PunchType.breakStart:
        status = 'present'; // on break but present
        break;
      case PunchType.checkout:
        status = 'present';
        break;
      case PunchType.checkin:
        status = 'present';
        break;
    }

    // Calculate hours worked
    double hoursWorked = 0;
    final workMins = workMinutesFromMaps(punches);
    hoursWorked = workMins / 60.0;

    // Update staff.last_in / last_out for home dashboard
    if (type == PunchType.checkin && firstIn != null) {
      await _db.from('staff').update({'last_in': firstIn}).eq('id', staffId);
    }
    if (type == PunchType.checkout && lastOut != null) {
      await _db.from('staff').update({'last_out': lastOut}).eq('id', staffId);
    }

    // Upsert attendance record
    await _db.from('attendance').upsert({
      'staff_id': staffId,
      'company_id': companyId,
      'attendance_date': dateStr,
      'status': status,
      'punches': punches,
      'check_in_time': firstIn,
      'check_out_time': lastOut,
      'clock_in_lat': type == PunchType.checkin ? lat : null,
      'clock_in_lng': type == PunchType.checkin ? lng : null,
      'clock_out_lat': type == PunchType.checkout ? lat : null,
      'clock_out_lng': type == PunchType.checkout ? lng : null,
      'face_verified': confidence != null && confidence > 0,
      'device_id': deviceId,
      'hours_worked': hoursWorked,
      'source': 'mobile',
    }, onConflict: 'staff_id,attendance_date');

    return punches;
  }

  // ─── Stream for attendance history ───

  Stream<List<Map<String, dynamic>>> attendanceStream(String staffId) {
    return _db
        .from('attendance')
        .stream(primaryKey: ['id'])
        .eq('staff_id', staffId)
        .order('attendance_date', ascending: false);
  }

  // ─── One-shot fetch for HR reports ───

  Future<List<DayRecord>> fetchAttendance(
    String staffId, {
    int limit = 150,
    int? filterMonth,
    int? filterYear,
  }) async {
    var query = _db
        .from('attendance')
        .select()
        .eq('staff_id', staffId)
        .order('attendance_date', ascending: false)
        .limit(limit);

    final rows = await query;
    final records = (rows as List).map((r) => DayRecord.fromSupabase(r)).toList();

    if (filterMonth != null) {
      return records.where((r) {
        final match = r.workDate.month == filterMonth;
        if (filterYear != null) return match && r.workDate.year == filterYear;
        return match;
      }).toList();
    }

    return records;
  }

  // ─── Fetch for HR: all staff in company ───

  Future<List<Map<String, dynamic>>> fetchCompanyAttendance({
    required String companyId,
    String? staffId,
    String? dateFrom,
    String? dateTo,
  }) async {
    var query = _db
        .from('attendance')
        .select('*, staff!inner(full_name, staff_number, department)')
        .eq('company_id', companyId);

    if (staffId != null) query = query.eq('staff_id', staffId);
    if (dateFrom != null) query = query.gte('attendance_date', dateFrom);
    if (dateTo != null) query = query.lte('attendance_date', dateTo);

    return await query.order('attendance_date', ascending: false);
  }

  // ─── Utility: derive WorkState from punch maps ───

  WorkState stateFromPunchMaps(List<Map<String, dynamic>> punches) {
    if (punches.isEmpty) return WorkState.idle;
    final lastType = PunchType.fromKey(punches.last['type'] as String?);
    switch (lastType) {
      case PunchType.checkin:
        return WorkState.working;
      case PunchType.breakStart:
        return WorkState.onBreak;
      case PunchType.checkout:
        return WorkState.done;
    }
  }

  // ─── Utility: calculate work/break minutes from punch maps ───

  int workMinutesFromMaps(List<Map<String, dynamic>> punches) {
    int total = 0;
    DateTime? lastIn;
    for (final p in punches) {
      final ts = p['time'];
      if (ts == null) continue;
      final time = _parseTime(ts);
      final type = PunchType.fromKey(p['type'] as String?);
      if (type == PunchType.checkin) {
        lastIn = time;
      } else if ((type == PunchType.breakStart || type == PunchType.checkout) && lastIn != null) {
        total += time.difference(lastIn).inMinutes;
        lastIn = null;
      }
    }
    if (lastIn != null) {
      total += DateTime.now().difference(lastIn).inMinutes;
    }
    return total;
  }

  int breakMinutesFromMaps(List<Map<String, dynamic>> punches) {
    int total = 0;
    DateTime? breakStart;
    for (final p in punches) {
      final ts = p['time'];
      if (ts == null) continue;
      final time = _parseTime(ts);
      final type = PunchType.fromKey(p['type'] as String?);
      if (type == PunchType.breakStart) {
        breakStart = time;
      } else if (type == PunchType.checkin && breakStart != null) {
        total += time.difference(breakStart).inMinutes;
        breakStart = null;
      }
    }
    if (breakStart != null) {
      total += DateTime.now().difference(breakStart).inMinutes;
    }
    return total;
  }

  /// Parse time from either ISO string or DateTime
  DateTime _parseTime(dynamic ts) {
    if (ts is DateTime) return ts;
    if (ts is String) return DateTime.parse(ts);
    return DateTime.now();
  }
}
