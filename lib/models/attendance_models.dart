// lib/models/attendance_models.dart
//
// Shared attendance data models used across:
//   - check_in_out_page.dart
//   - attendance_history_page.dart
//   - hr_attendance_report_page.dart
//   - home_page.dart (clock card)

import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────── Punch Type ───────────────────────

/// Three distinct punch types:
///   checkin     - start work or resume after break
///   breakStart  - going on break
///   checkout    - end work for the day
enum PunchType {
  checkin,
  breakStart,
  checkout;

  /// Firestore string key
  String get key {
    switch (this) {
      case PunchType.checkin:
        return 'checkin';
      case PunchType.breakStart:
        return 'break_start';
      case PunchType.checkout:
        return 'checkout';
    }
  }

  static PunchType fromKey(String? key) {
    switch (key) {
      case 'checkin':
        return PunchType.checkin;
      case 'break_start':
      case 'break': // backward compat
        return PunchType.breakStart;
      case 'checkout':
        return PunchType.checkout;
      default:
        return PunchType.checkin;
    }
  }

  String get label {
    switch (this) {
      case PunchType.checkin:
        return 'Check In';
      case PunchType.breakStart:
        return 'Break';
      case PunchType.checkout:
        return 'Check Out';
    }
  }
}

// ─────────────────────── Work State ───────────────────────

/// Derived from the last punch in the day's punch list.
enum WorkState {
  idle,      // no punches yet
  working,   // last punch was checkin
  onBreak,   // last punch was break_start
  done;      // last punch was checkout

  String get label {
    switch (this) {
      case WorkState.idle:
        return 'Not Started';
      case WorkState.working:
        return 'Working';
      case WorkState.onBreak:
        return 'On Break';
      case WorkState.done:
        return 'Day Ended';
    }
  }
}

// ─────────────────────── Punch Entry ───────────────────────

class PunchEntry {
  final PunchType type;
  final DateTime? time;
  final double? lat;
  final double? lng;
  final bool geoOk;
  final double? confidence;

  const PunchEntry({
    required this.type,
    this.time,
    this.lat,
    this.lng,
    this.geoOk = false,
    this.confidence,
  });

  factory PunchEntry.fromMap(Map<String, dynamic> m) {
    final ts = m['time'];
    return PunchEntry(
      type: PunchType.fromKey(m['type'] as String?),
      time: ts is Timestamp ? ts.toDate() : null,
      lat: (m['lat'] as num?)?.toDouble(),
      lng: (m['lng'] as num?)?.toDouble(),
      geoOk: (m['geoOk'] as bool?) ?? false,
      confidence: (m['confidence'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
        'type': type.key,
        'time': time != null ? Timestamp.fromDate(time!) : null,
        'lat': lat,
        'lng': lng,
        'geoOk': geoOk,
        'confidence': confidence,
      };

  /// Human-friendly label for timeline display.
  String displayLabel(int index) {
    switch (type) {
      case PunchType.checkin:
        return index == 0 ? 'Start Work' : 'Resume Work';
      case PunchType.breakStart:
        return 'Break';
      case PunchType.checkout:
        return 'End Work';
    }
  }
}

// ─────────────────────── Day Record ───────────────────────

class DayRecord {
  final DateTime workDate;
  final String rawStatus;
  final List<PunchEntry> punches;
  final bool? geoOk;

  // Backward compat fields (old inAt/outAt format)
  final DateTime? legacyInAt;
  final DateTime? legacyOutAt;

  const DayRecord({
    required this.workDate,
    this.rawStatus = '',
    this.punches = const [],
    this.geoOk,
    this.legacyInAt,
    this.legacyOutAt,
  });

  // ─── Factory from Firestore doc ───

  factory DayRecord.fromFirestore(Map<String, dynamic> data) {
    final workDateTs = data['workDate'] as Timestamp?;
    final inTs = data['inAt'] as Timestamp?;
    final outTs = data['outAt'] as Timestamp?;
    final geoOk = data['geoOk'] as bool?;
    final rawStatus = (data['status'] ?? '').toString();

    List<PunchEntry> punches = [];
    if (data['punches'] != null) {
      punches = (data['punches'] as List)
          .map((e) => PunchEntry.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    } else {
      // Migrate old inAt/outAt format into punch entries
      if (inTs != null) {
        punches.add(PunchEntry(
          type: PunchType.checkin,
          time: inTs.toDate(),
          geoOk: geoOk ?? false,
        ));
      }
      if (outTs != null) {
        punches.add(PunchEntry(
          type: PunchType.checkout,
          time: outTs.toDate(),
          geoOk: geoOk ?? false,
        ));
      }
    }

    final workDate = workDateTs?.toDate() ??
        inTs?.toDate() ??
        outTs?.toDate() ??
        DateTime.now();

    return DayRecord(
      workDate: workDate,
      rawStatus: rawStatus,
      punches: punches,
      geoOk: geoOk,
      legacyInAt: inTs?.toDate(),
      legacyOutAt: outTs?.toDate(),
    );
  }

  // ─── Derived properties ───

  WorkState get state {
    if (punches.isEmpty) return WorkState.idle;
    switch (punches.last.type) {
      case PunchType.checkin:
        return WorkState.working;
      case PunchType.breakStart:
        return WorkState.onBreak;
      case PunchType.checkout:
        return WorkState.done;
    }
  }

  DateTime? get firstIn {
    for (final p in punches) {
      if (p.type == PunchType.checkin && p.time != null) return p.time;
    }
    return legacyInAt;
  }

  DateTime? get lastOut {
    for (int i = punches.length - 1; i >= 0; i--) {
      if (punches[i].type == PunchType.checkout && punches[i].time != null) {
        return punches[i].time;
      }
    }
    return legacyOutAt;
  }

  String get status {
    if (rawStatus.isNotEmpty) return rawStatus;
    final s = state;
    switch (s) {
      case WorkState.idle:
        return 'No record';
      case WorkState.working:
        return 'Checked-in only';
      case WorkState.onBreak:
        return 'On Break';
      case WorkState.done:
        return 'Present';
    }
  }

  String get geoText {
    if (geoOk == null) return 'Geofence: -';
    return geoOk! ? 'Geofence: OK (inside)' : 'Geofence: outside';
  }

  /// Total work minutes: sum of (checkin -> break_start) and (checkin -> checkout) spans.
  int? get totalWorkMinutes {
    if (punches.length < 2) return null;

    int total = 0;
    DateTime? lastIn;

    for (final p in punches) {
      if (p.time == null) continue;
      if (p.type == PunchType.checkin) {
        lastIn = p.time;
      } else if ((p.type == PunchType.breakStart ||
              p.type == PunchType.checkout) &&
          lastIn != null) {
        total += p.time!.difference(lastIn).inMinutes;
        lastIn = null;
      }
    }

    // Still working (last punch was checkin)
    if (lastIn != null) {
      total += DateTime.now().difference(lastIn).inMinutes;
    }

    return total > 0 ? total : null;
  }

  /// Total break minutes: sum of (break_start -> checkin) spans.
  int get totalBreakMinutes {
    int total = 0;
    DateTime? breakStart;

    for (final p in punches) {
      if (p.time == null) continue;
      if (p.type == PunchType.breakStart) {
        breakStart = p.time;
      } else if (p.type == PunchType.checkin && breakStart != null) {
        total += p.time!.difference(breakStart).inMinutes;
        breakStart = null;
      }
    }

    // Still on break
    if (breakStart != null) {
      total += DateTime.now().difference(breakStart).inMinutes;
    }

    return total;
  }
}
