// lib/models/attendance_models.dart
//
// Shared attendance data models used across:
//   - check_in_out_page.dart
//   - attendance_history_page.dart
//   - hr_attendance_report_page.dart
//   - home_page.dart (clock card)

// ─────────────────────── Punch Type ───────────────────────

/// Three distinct punch types:
///   checkin     - start work or resume after break
///   breakStart  - going on break
///   checkout    - end work for the day
enum PunchType {
  checkin,
  breakStart,
  checkout;

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
      case 'break':
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

enum WorkState {
  idle,
  working,
  onBreak,
  done;

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
    DateTime? time;
    if (ts is String) {
      time = DateTime.tryParse(ts);
    } else if (ts is DateTime) {
      time = ts;
    }

    return PunchEntry(
      type: PunchType.fromKey(m['type'] as String?),
      time: time,
      lat: (m['lat'] as num?)?.toDouble(),
      lng: (m['lng'] as num?)?.toDouble(),
      geoOk: (m['geoOk'] as bool?) ?? false,
      confidence: (m['confidence'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
        'type': type.key,
        'time': time?.toUtc().toIso8601String(),
        'lat': lat,
        'lng': lng,
        'geoOk': geoOk,
        'confidence': confidence,
      };

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

  /// Factory from Supabase row
  factory DayRecord.fromSupabase(Map<String, dynamic> data) {
    final dateStr = data['attendance_date'] as String?;
    final checkInStr = data['check_in_time'] as String?;
    final checkOutStr = data['check_out_time'] as String?;
    final rawStatus = (data['status'] ?? '').toString();

    DateTime workDate;
    if (dateStr != null) {
      workDate = DateTime.tryParse(dateStr) ?? DateTime.now();
    } else {
      workDate = DateTime.now();
    }

    final inAt = checkInStr != null ? DateTime.tryParse(checkInStr) : null;
    final outAt = checkOutStr != null ? DateTime.tryParse(checkOutStr) : null;
    final faceVerified = data['face_verified'] as bool?;

    List<PunchEntry> punches = [];
    final punchesRaw = data['punches'];
    if (punchesRaw != null && punchesRaw is List && punchesRaw.isNotEmpty) {
      punches = punchesRaw
          .map((e) => PunchEntry.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    } else {
      // Derive from flat columns
      if (inAt != null) {
        punches.add(PunchEntry(type: PunchType.checkin, time: inAt));
      }
      if (outAt != null) {
        punches.add(PunchEntry(type: PunchType.checkout, time: outAt));
      }
    }

    return DayRecord(
      workDate: workDate,
      rawStatus: rawStatus,
      punches: punches,
      geoOk: faceVerified,
      legacyInAt: inAt,
      legacyOutAt: outAt,
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

  int? get totalWorkMinutes {
    if (punches.length < 2) return null;
    int total = 0;
    DateTime? lastIn;
    for (final p in punches) {
      if (p.time == null) continue;
      if (p.type == PunchType.checkin) {
        lastIn = p.time;
      } else if ((p.type == PunchType.breakStart || p.type == PunchType.checkout) && lastIn != null) {
        total += p.time!.difference(lastIn).inMinutes;
        lastIn = null;
      }
    }
    if (lastIn != null) total += DateTime.now().difference(lastIn).inMinutes;
    return total > 0 ? total : null;
  }

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
    if (breakStart != null) total += DateTime.now().difference(breakStart).inMinutes;
    return total;
  }
}
