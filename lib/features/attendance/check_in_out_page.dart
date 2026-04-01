// lib/features/attendance/check_in_out_page.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants.dart';
import '../../models/attendance_models.dart';
import '../../services/attendance_service.dart';
import '../../services/supabase_service.dart';
import '../../services/face_service.dart';
import '../../services/company_service.dart';

/// Set true to skip geofence + face checks (dev mode)
const bool kTestMode = false;

/// Minimum GPS accuracy we accept (meters)
const double kRequiredAccuracyMeters = 50;

class CheckInOutPage extends StatefulWidget {
  const CheckInOutPage({super.key});

  @override
  State<CheckInOutPage> createState() => _CheckInOutPageState();
}

class _CheckInOutPageState extends State<CheckInOutPage> {
  final _svc = AttendanceService.instance;
  final _supabase = SupabaseService.instance;

  // --- Clock ---
  DateTime _now = DateTime.now();
  late Timer _clock;

  // --- Location (reads from CompanyService, falls back to constants) ---
  bool _locPermOk = false;
  Position? _pos;
  double? _distance;
  double? _accuracy;
  double get _geofenceLat => CompanyService.instance.config.geofenceLat;
  double get _geofenceLng => CompanyService.instance.config.geofenceLng;
  int get _geofenceRadius => CompanyService.instance.config.geofenceMeters;
  bool get _inside => (_distance ?? 9999) <= _geofenceRadius;

  // --- Face ---
  bool _faceOk = false;
  double? _confidence;

  // --- UI state ---
  bool _busy = false;
  String? _hint;

  // --- Today's punches (raw maps) ---
  List<Map<String, dynamic>> _punches = [];

  // --- Derived from _punches ---
  WorkState get _state => _svc.stateFromPunchMaps(_punches);
  int get _workMins => _svc.workMinutesFromMaps(_punches);
  int get _breakMins => _svc.breakMinutesFromMaps(_punches);

  // --- Google Maps ---
  GoogleMapController? _map;
  LatLng get _site => LatLng(_geofenceLat, _geofenceLng);
  LatLng? _me;

  Set<Marker> get _markers {
    final m = <Marker>{
      const Marker(
        markerId: MarkerId('site'),
        position: _site,
        infoWindow: InfoWindow(title: 'SmartBayu Site'),
      ),
    };
    if (_me != null) {
      m.add(Marker(
        markerId: const MarkerId('me'),
        position: _me!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: 'You'),
      ));
    }
    return m;
  }

  Set<Circle> get _circles => {
        Circle(
          circleId: const CircleId('geo'),
          center: _site,
          radius: _geofenceRadius.toDouble(),
          fillColor: Colors.teal.withValues(alpha: 0.12),
          strokeColor: Colors.teal.withValues(alpha: 0.40),
          strokeWidth: 2,
        ),
      };

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _now = DateTime.now());
    });
    _initFaceService();
    _loadToday();
  }

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
  }

  Future<void> _initFaceService() async {
    try {
      await FaceVerificationService.instance.init();
    } catch (e) {
      if (mounted) setState(() => _hint = 'Face model not loaded: $e');
    }
  }

  Future<void> _loadToday() async {
    final staffId = _supabase.staffId;
    if (staffId == null) return;
    final maps = await _svc.loadTodayPunchMaps(staffId);
    if (mounted) setState(() => _punches = maps);
  }

  // ========================= STEP 1: GPS =========================

  Future<void> _validateLocation() async {
    setState(() {
      _busy = true;
      _hint = 'Checking location service...';
    });

    final serviceOn = await Geolocator.isLocationServiceEnabled();
    if (!serviceOn) {
      setState(() {
        _busy = false;
        _hint = 'Location service is OFF. Turn on GPS.';
      });
      return;
    }

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever ||
        perm == LocationPermission.denied) {
      setState(() {
        _busy = false;
        _hint = 'Location permission denied.';
      });
      return;
    }
    _locPermOk = true;

    final position = await Geolocator.getCurrentPosition(
      locationSettings:
          const LocationSettings(accuracy: LocationAccuracy.high),
    );

    final d = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      _geofenceLat,
      _geofenceLng,
    );

    setState(() {
      _busy = false;
      _pos = position;
      _accuracy = position.accuracy;
      _distance = d;
      _me = LatLng(position.latitude, position.longitude);

      if (!_inside && !kTestMode) {
        _hint =
            'You are ${d.toStringAsFixed(1)} m from site (required <= $_geofenceRadius m).';
      } else if (!_isAccurateEnough() && !kTestMode) {
        _hint =
            'Accuracy too low: ${position.accuracy.toStringAsFixed(0)} m (required <= ${kRequiredAccuracyMeters.toStringAsFixed(0)} m).';
      } else {
        _hint = 'Location OK. Proceed to face verification.';
      }
    });

    if (_map != null && _me != null) {
      final sw = LatLng(
        _me!.latitude < _site.latitude ? _me!.latitude : _site.latitude,
        _me!.longitude < _site.longitude ? _me!.longitude : _site.longitude,
      );
      final ne = LatLng(
        _me!.latitude > _site.latitude ? _me!.latitude : _site.latitude,
        _me!.longitude > _site.longitude ? _me!.longitude : _site.longitude,
      );
      await _map!.animateCamera(
        CameraUpdate.newLatLngBounds(
            LatLngBounds(southwest: sw, northeast: ne), 60),
      );
    }
  }

  bool _isAccurateEnough() {
    if (kTestMode) return true;
    return (_accuracy ?? 999) <= kRequiredAccuracyMeters;
  }

  bool _locationReady() {
    if (kTestMode) return true;
    return _locPermOk &&
        _pos != null &&
        (_distance ?? 9999) <= _geofenceRadius &&
        _isAccurateEnough();
  }

  // ========================= STEP 2: FACE =========================

  Future<void> _verifyFace() async {
    if (!_locationReady() && !kTestMode) {
      setState(() => _hint = 'Location not ready. Validate location first.');
      return;
    }

    final staffId = _supabase.staffId;
    if (staffId == null) {
      setState(() => _hint = 'Session expired. Please log in again.');
      return;
    }

    if (!FaceVerificationService.instance.isReady) {
      setState(
          () => _hint = 'Face model not loaded. Please restart the app.');
      return;
    }

    setState(() {
      _busy = true;
      _hint = 'Opening camera...';
      _faceOk = false;
      _confidence = null;
    });

    try {
      final shot = await ImagePicker().pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 85,
      );
      if (shot == null) {
        setState(() => _busy = false);
        return;
      }

      final file = File(shot.path);

      setState(() => _hint = 'Analysing face on-device...');
      final result =
          await FaceVerificationService.instance.generateEmbedding(file);

      if (result == null || !result.ok) {
        setState(() {
          _busy = false;
          _faceOk = false;
          _hint = result?.errorMessage ?? 'Face detection failed.';
        });
        return;
      }

      final newEmbedding = result.embedding!;

      setState(() => _hint = 'Uploading selfie...');
      final url = await _uploadSelfie(file, staffId);

      // Read saved face embedding from staff data
      final staffData = _supabase.staffData;
      final savedEmbeddingRaw = staffData?['face_embedding'] as List?;

      if (savedEmbeddingRaw == null || savedEmbeddingRaw.isEmpty) {
        // First-time enrollment — save embedding to staff record
        await _supabase.client
            .from('staff')
            .update({
              'face_embedding': newEmbedding,
              'face_image_url': url,
            })
            .eq('id', staffId);

        // Update cached staff data
        if (staffData != null) {
          staffData['face_embedding'] = newEmbedding;
          staffData['face_image_url'] = url;
        }

        setState(() {
          _busy = false;
          _faceOk = true;
          _confidence = 1.0;
          _hint = 'Face enrolled. Next time we will verify your identity.';
        });
      } else {
        // Verify against stored embedding
        setState(() => _hint = 'Verifying identity...');
        final savedEmbedding =
            savedEmbeddingRaw.map((e) => (e as num).toDouble()).toList();
        final similarity = FaceVerificationService.cosineSimilarity(
            savedEmbedding, newEmbedding);

        if (similarity < SmartBayu.faceMatchThreshold) {
          setState(() {
            _busy = false;
            _faceOk = false;
            _confidence = similarity;
            _hint =
                'Face does not match (similarity ${similarity.toStringAsFixed(2)}).';
          });
          return;
        }

        // Update embedding with latest verified face
        await _supabase.client
            .from('staff')
            .update({
              'face_embedding': newEmbedding,
              'face_image_url': url,
            })
            .eq('id', staffId);

        if (staffData != null) {
          staffData['face_embedding'] = newEmbedding;
          staffData['face_image_url'] = url;
        }

        setState(() {
          _busy = false;
          _faceOk = true;
          _confidence = similarity;
          _hint = 'Face verified (${similarity.toStringAsFixed(2)}).';
        });
      }
    } catch (e) {
      setState(() {
        _busy = false;
        _faceOk = false;
        _hint = 'Error during face verification: $e';
      });
    }
  }

  Future<String> _uploadSelfie(File file, String staffId) async {
    final name = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final path = '${SmartBayu.tempSelfiePath}/$staffId/$name';
    final bytes = await file.readAsBytes();
    await Supabase.instance.client.storage
        .from('smartbayu')
        .uploadBinary(path, bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'));
    return Supabase.instance.client.storage
        .from('smartbayu')
        .getPublicUrl(path);
  }

  // ========================= STEP 3: PUNCH =========================

  Future<void> _punch(PunchType type) async {
    final messenger = ScaffoldMessenger.of(context);

    if (!_locationReady() && !kTestMode) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Validate location first.')));
      return;
    }
    if (!_faceOk && !kTestMode) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Verify face first.')));
      return;
    }
    if (_pos == null && !kTestMode) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Location not received.')));
      return;
    }

    final staffId = _supabase.staffId;
    if (staffId == null) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Session expired. Please login again.')));
      return;
    }

    setState(() => _busy = true);

    try {
      final updated = await _svc.recordPunch(
        staffId: staffId,
        type: type,
        lat: _pos?.latitude ?? 0,
        lng: _pos?.longitude ?? 0,
        geoOk: _inside || kTestMode,
        confidence: _confidence,
        existingPunches: _punches,
      );

      setState(() {
        _punches = updated;
        _busy = false;
      });

      if (!mounted) return;

      messenger.showSnackBar(SnackBar(
        content: Text('${type.label} recorded (#${updated.length})'),
        backgroundColor: _punchColor(type),
      ));
    } catch (e) {
      setState(() => _busy = false);
      if (!mounted) return;
      messenger.showSnackBar(
          SnackBar(content: Text('Failed to save: $e')));
    }
  }

  // ========================= BUILD =========================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Check In / Out')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ── Clock ──
            Text(
              TimeOfDay.fromDateTime(_now).format(context),
              style:
                  const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
                '${_now.year}-${_now.month.toString().padLeft(2, '0')}-${_now.day.toString().padLeft(2, '0')}'),

            const SizedBox(height: 12),

            // ── Status badge ──
            _StatusBadge(
              state: _state,
              workMins: _workMins,
              breakMins: _breakMins,
            ),

            const SizedBox(height: 12),

            // ── Geofence + Map card ──
            _GeofenceCard(
              inside: _inside,
              distance: _distance,
              accuracy: _accuracy,
              markers: _markers,
              circles: _circles,
              site: _site,
              radiusMeters: _geofenceRadius,
              onMapCreated: (c) => _map = c,
            ),

            const SizedBox(height: 10),

            // ── Hint ──
            if (_hint != null) _HintBox(hint: _hint!),

            const SizedBox(height: 12),

            // ── Action buttons ──
            _buildActions(),

            if (_busy)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: LinearProgressIndicator(minHeight: 3),
              ),

            const SizedBox(height: 16),

            // ── Today's timeline ──
            if (_punches.isNotEmpty) _buildTimeline(),
          ],
        ),
      ),
    );
  }

  // ── Action buttons based on state ──
  Widget _buildActions() {
    // Step 1: Location
    if (!_locPermOk || _pos == null) {
      return _ActionBtn(
        onPressed: _busy ? null : _validateLocation,
        icon: Icons.my_location,
        label: 'Validate Location',
        color: const Color(0xFF2563EB),
      );
    }

    // Step 2: Face
    if (!_faceOk && !kTestMode) {
      return _ActionBtn(
        onPressed: _busy ? null : _verifyFace,
        icon: Icons.face_rounded,
        label: 'Verify Face',
        color: const Color(0xFF7C3AED),
      );
    }

    // Step 3: Punch actions
    switch (_state) {
      case WorkState.idle:
        return _ActionBtn(
          onPressed: _busy ? null : () => _punch(PunchType.checkin),
          icon: Icons.play_arrow_rounded,
          label: 'Start Work',
          color: const Color(0xFF16A34A),
        );

      case WorkState.working:
        return Row(
          children: [
            Expanded(
              child: _ActionBtn(
                onPressed:
                    _busy ? null : () => _punch(PunchType.breakStart),
                icon: Icons.free_breakfast_rounded,
                label: 'Take Break',
                color: const Color(0xFFEA580C),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionBtn(
                onPressed:
                    _busy ? null : () => _punch(PunchType.checkout),
                icon: Icons.stop_rounded,
                label: 'End Work',
                color: const Color(0xFFDC2626),
              ),
            ),
          ],
        );

      case WorkState.onBreak:
        return Column(
          children: [
            _ActionBtn(
              onPressed: _busy ? null : () => _punch(PunchType.checkin),
              icon: Icons.play_arrow_rounded,
              label: 'Resume Work',
              color: const Color(0xFF16A34A),
            ),
            const SizedBox(height: 8),
            _ActionBtn(
              onPressed:
                  _busy ? null : () => _punch(PunchType.checkout),
              icon: Icons.stop_rounded,
              label: 'End Work',
              color: const Color(0xFFDC2626),
            ),
          ],
        );

      case WorkState.done:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: const Color(0xFF2563EB).withValues(alpha: 0.25)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_rounded,
                  color: Color(0xFF2563EB), size: 20),
              SizedBox(width: 8),
              Text(
                'Work day completed',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2563EB),
                  fontSize: 15,
                ),
              ),
            ],
          ),
        );
    }
  }

  // ── Punch timeline ──
  Widget _buildTimeline() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Today\'s Timeline',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${_punches.length} punches',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: Color(0xFF2563EB),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...List.generate(_punches.length, (i) {
          final p = _punches[i];
          final type = PunchType.fromKey(p['type'] as String?);
          final ts = p['time'];
          DateTime? time;
          if (ts is String) time = DateTime.tryParse(ts);
          if (ts is DateTime) time = ts;
          final geoOk = p['geoOk'] as bool? ?? false;
          final color = _punchColor(type);

          final timeStr = time != null
              ? '${time.toLocal().hour.toString().padLeft(2, '0')}:${time.toLocal().minute.toString().padLeft(2, '0')}'
              : '--:--';

          // Duration to next punch
          String? durationStr;
          if (i < _punches.length - 1 && time != null) {
            final nextTs = _punches[i + 1]['time'];
            DateTime? nextTime;
            if (nextTs is String) nextTime = DateTime.tryParse(nextTs);
            if (nextTs is DateTime) nextTime = nextTs;
            if (nextTime != null) {
              final mins = nextTime.difference(time).inMinutes;
              if (type == PunchType.checkin) {
                durationStr = 'Worked ${_fmtMins(mins)}';
              } else if (type == PunchType.breakStart) {
                durationStr = 'Break ${_fmtMins(mins)}';
              }
            }
          } else if (type == PunchType.checkin && time != null) {
            final mins = DateTime.now().difference(time).inMinutes;
            durationStr = 'Working for ${_fmtMins(mins)}...';
          } else if (type == PunchType.breakStart && time != null) {
            final mins = DateTime.now().difference(time).inMinutes;
            durationStr = 'On break for ${_fmtMins(mins)}...';
          }

          final label = PunchEntry(type: type).displayLabel(i);

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 30,
                child: Column(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color,
                        border: Border.all(
                            color: color.withValues(alpha: 0.3), width: 3),
                      ),
                    ),
                    if (i < _punches.length - 1)
                      Container(
                          width: 2, height: 36, color: Colors.grey.shade300),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(timeStr,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(label,
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                    color: color)),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            geoOk
                                ? Icons.location_on
                                : Icons.location_off,
                            size: 14,
                            color: geoOk ? Colors.green : Colors.red,
                          ),
                        ],
                      ),
                      if (durationStr != null) ...[
                        const SizedBox(height: 2),
                        Text(durationStr,
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600)),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  String _fmtMins(int mins) {
    final h = mins ~/ 60;
    final m = mins % 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }

  Color _punchColor(PunchType type) {
    switch (type) {
      case PunchType.checkin:
        return const Color(0xFF16A34A);
      case PunchType.breakStart:
        return const Color(0xFFEA580C);
      case PunchType.checkout:
        return const Color(0xFFDC2626);
    }
  }
}

// ═══════════════════════ Extracted Widgets ═══════════════════════

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.state,
    required this.workMins,
    required this.breakMins,
  });
  final WorkState state;
  final int workMins;
  final int breakMins;

  Color get _color {
    switch (state) {
      case WorkState.working:
        return const Color(0xFF16A34A);
      case WorkState.onBreak:
        return const Color(0xFFEA580C);
      case WorkState.done:
        return const Color(0xFF2563EB);
      case WorkState.idle:
        return const Color(0xFF6B7280);
    }
  }

  IconData get _icon {
    switch (state) {
      case WorkState.working:
        return Icons.work_rounded;
      case WorkState.onBreak:
        return Icons.free_breakfast_rounded;
      case WorkState.done:
        return Icons.check_circle_rounded;
      case WorkState.idle:
        return Icons.schedule_rounded;
    }
  }

  String _fmt(int mins) {
    final h = mins ~/ 60;
    final m = mins % 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 18, color: _color),
          const SizedBox(width: 8),
          Text(state.label,
              style: TextStyle(
                  fontWeight: FontWeight.w700, color: _color, fontSize: 14)),
          if (workMins > 0 || breakMins > 0) ...[
            const SizedBox(width: 12),
            Text('Work: ${_fmt(workMins)}',
                style: TextStyle(
                    fontSize: 12, color: _color, fontWeight: FontWeight.w600)),
            if (breakMins > 0) ...[
              const SizedBox(width: 8),
              Text('Break: ${_fmt(breakMins)}',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.w600)),
            ],
          ],
        ],
      ),
    );
  }
}

class _GeofenceCard extends StatelessWidget {
  const _GeofenceCard({
    required this.inside,
    required this.distance,
    required this.accuracy,
    required this.markers,
    required this.circles,
    required this.site,
    required this.radiusMeters,
    required this.onMapCreated,
  });

  final bool inside;
  final double? distance;
  final double? accuracy;
  final Set<Marker> markers;
  final Set<Circle> circles;
  final LatLng site;
  final int radiusMeters;
  final void Function(GoogleMapController) onMapCreated;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE1E8EF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Geofence',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text('Radius $radiusMeters m',
                        style: const TextStyle(color: Colors.black54)),
                  ],
                ),
              ),
              Chip(
                avatar: Icon(
                  inside ? Icons.check_circle : Icons.error_outline,
                  color: inside ? Colors.green : Colors.orange,
                  size: 18,
                ),
                label: Text(
                  inside ? 'Inside' : 'Outside',
                  style: TextStyle(
                    color: inside
                        ? Colors.green.shade800
                        : Colors.orange.shade800,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                backgroundColor:
                    inside ? Colors.green.shade50 : Colors.orange.shade50,
                side: BorderSide(
                    color: (inside ? Colors.green : Colors.orange)
                        .withValues(alpha: .3)),
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _InfoChip(
                  'Dist',
                  distance != null
                      ? '${distance!.toStringAsFixed(0)} m'
                      : '-'),
              const SizedBox(width: 16),
              _InfoChip('Acc',
                  accuracy != null ? '${accuracy!.toStringAsFixed(0)} m' : '-'),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 130,
              child: GoogleMap(
                initialCameraPosition:
                    CameraPosition(target: site, zoom: 16),
                onMapCreated: onMapCreated,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                liteModeEnabled: true,
                markers: markers,
                circles: circles,
                zoomControlsEnabled: false,
                compassEnabled: false,
                trafficEnabled: false,
                mapToolbarEnabled: false,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label,
            style: const TextStyle(color: Colors.black54, fontSize: 13)),
        const SizedBox(width: 6),
        Text(value,
            style:
                const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      ],
    );
  }
}

class _HintBox extends StatelessWidget {
  const _HintBox({required this.hint});
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE1E8EF)),
      ),
      child: Text(hint,
          style: const TextStyle(color: Colors.black54, fontSize: 13)),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.color,
  });
  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label,
            style:
                const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        style: FilledButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}
