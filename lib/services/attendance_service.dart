// lib/services/attendance_service.dart
//
// Central service for all attendance / punch operations.
// Single source of truth for Firestore reads & writes.

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/attendance_models.dart';

class AttendanceService {
  AttendanceService._();
  static final instance = AttendanceService._();

  final _db = FirebaseFirestore.instance;

  // ─── Helpers ───

  String docIdForDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  DocumentReference<Map<String, dynamic>> _attendanceDoc(
      String uid, DateTime date) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('attendance')
        .doc(docIdForDate(date));
  }

  // ─── Load today's record ───

  Future<DayRecord?> loadDay(String uid, DateTime date) async {
    final snap = await _attendanceDoc(uid, date).get();
    if (!snap.exists || snap.data() == null) return null;
    return DayRecord.fromFirestore(snap.data()!);
  }

  // ─── Load today's punches (raw maps for check-in page) ───

  Future<List<Map<String, dynamic>>> loadTodayPunchMaps(String uid) async {
    final now = DateTime.now();
    final snap = await _attendanceDoc(uid, now).get();
    final data = snap.data();
    if (data == null) return [];

    if (data['punches'] != null) {
      return List<Map<String, dynamic>>.from(data['punches'] as List);
    }

    // Migrate old format
    final List<Map<String, dynamic>> migrated = [];
    final inAt = data['inAt'] as Timestamp?;
    final outAt = data['outAt'] as Timestamp?;
    if (inAt != null) {
      migrated.add({
        'type': PunchType.checkin.key,
        'time': inAt,
        'lat': data['inLat'],
        'lng': data['inLng'],
        'geoOk': data['geoOk'],
        'confidence': data['verifyConfidence'],
      });
    }
    if (outAt != null) {
      migrated.add({
        'type': PunchType.checkout.key,
        'time': outAt,
        'lat': data['outLat'],
        'lng': data['outLng'],
        'geoOk': data['geoOk'],
        'confidence': data['verifyConfidence'],
      });
    }
    return migrated;
  }

  // ─── Record a punch ───

  Future<List<Map<String, dynamic>>> recordPunch({
    required String uid,
    required PunchType type,
    required double lat,
    required double lng,
    required bool geoOk,
    required double? confidence,
    required List<Map<String, dynamic>> existingPunches,
  }) async {
    final now = DateTime.now();
    final docRef = _attendanceDoc(uid, now);
    final userDoc = _db.collection('users').doc(uid);
    final workDateMidnight = DateTime(now.year, now.month, now.day);

    final punchMap = {
      'type': type.key,
      'time': Timestamp.fromDate(now),
      'lat': lat,
      'lng': lng,
      'geoOk': geoOk,
      'confidence': confidence,
    };

    final punches = List<Map<String, dynamic>>.from(existingPunches);
    punches.add(punchMap);

    // Derive first-in and last-out for backward compat
    Timestamp? firstIn;
    Timestamp? lastOut;
    for (final p in punches) {
      final t = p['time'] as Timestamp;
      final pType = PunchType.fromKey(p['type'] as String?);
      if (pType == PunchType.checkin) {
        firstIn ??= t;
      }
      if (pType == PunchType.checkout) {
        lastOut = t;
      }
    }

    // Derive status from last punch
    final lastPunchType = PunchType.fromKey(punches.last['type'] as String?);
    String status;
    switch (lastPunchType) {
      case PunchType.breakStart:
        status = 'On Break';
        break;
      case PunchType.checkout:
        status = 'Present';
        break;
      case PunchType.checkin:
        status = 'Checked-in only';
        break;
    }

    await docRef.set({
      'uid': uid,
      'workDate': Timestamp.fromDate(workDateMidnight),
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
      'punches': punches,
      if (firstIn != null) 'inAt': firstIn,
      if (lastOut != null) 'outAt': lastOut,
      'geoOk': geoOk,
      'verifyConfidence': confidence,
    }, SetOptions(merge: true));

    // Update user-level lastIn / lastOut
    if (type == PunchType.checkin) {
      await userDoc
          .set({'lastIn': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    } else if (type == PunchType.checkout) {
      await userDoc.set(
          {'lastOut': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    }
    // break_start doesn't update lastIn/lastOut

    return punches;
  }

  // ─── Stream for attendance history ───

  Stream<QuerySnapshot<Map<String, dynamic>>> attendanceStream(
    String uid, {
    int limit = 120,
  }) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('attendance')
        .orderBy('workDate', descending: true)
        .limit(limit)
        .snapshots();
  }

  // ─── One-shot fetch for HR reports ───

  Future<List<DayRecord>> fetchAttendance(
    String uid, {
    int limit = 150,
    int? filterMonth,
    int? filterYear,
  }) async {
    final snap = await _db
        .collection('users')
        .doc(uid)
        .collection('attendance')
        .orderBy('workDate', descending: true)
        .limit(limit)
        .get();

    final records =
        snap.docs.map((d) => DayRecord.fromFirestore(d.data())).toList();

    if (filterMonth != null) {
      return records.where((r) {
        final match = r.workDate.month == filterMonth;
        if (filterYear != null) return match && r.workDate.year == filterYear;
        return match;
      }).toList();
    }

    return records;
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
      final time = ts is Timestamp ? ts.toDate() : DateTime.now();
      final type = PunchType.fromKey(p['type'] as String?);
      if (type == PunchType.checkin) {
        lastIn = time;
      } else if ((type == PunchType.breakStart ||
              type == PunchType.checkout) &&
          lastIn != null) {
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
      final time = ts is Timestamp ? ts.toDate() : DateTime.now();
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
}
