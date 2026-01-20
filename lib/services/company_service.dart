import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

class CompanyConfig {
  final String companyName;
  final String siteName;
  final String? logoUrl;
  final String? address;
  final String? phone;
  final String? email;
  final String? website;
  final String? registrationNo;
  final double geofenceLat;
  final double geofenceLng;
  final int geofenceMeters;
  final Map<String, dynamic> raw;

  CompanyConfig({
    required this.companyName,
    required this.siteName,
    this.logoUrl,
    this.address,
    this.phone,
    this.email,
    this.website,
    this.registrationNo,
    required this.geofenceLat,
    required this.geofenceLng,
    required this.geofenceMeters,
    required this.raw,
  });

  factory CompanyConfig.fromMap(Map<String, dynamic> data) {
    return CompanyConfig(
      companyName: (data['companyName'] as String?) ?? 'Bayu Lestari Resort',
      siteName: (data['siteName'] as String?) ?? 'Pulau Besar Site',
      logoUrl: data['logoUrl'] as String?,
      address: data['address'] as String?,
      phone: data['phone'] as String?,
      email: data['email'] as String?,
      website: data['website'] as String?,
      registrationNo: data['registrationNo'] as String?,
      geofenceLat: (data['geofenceLat'] as num?)?.toDouble() ?? 2.428795,
      geofenceLng: (data['geofenceLng'] as num?)?.toDouble() ?? 103.983596,
      geofenceMeters: (data['geofenceMeters'] as num?)?.toInt() ?? 3000,
      raw: data,
    );
  }

  factory CompanyConfig.defaults() => CompanyConfig.fromMap({});

  Map<String, dynamic> toMap() => {
    'companyName': companyName,
    'siteName': siteName,
    'logoUrl': logoUrl,
    'address': address,
    'phone': phone,
    'email': email,
    'website': website,
    'registrationNo': registrationNo,
    'geofenceLat': geofenceLat,
    'geofenceLng': geofenceLng,
    'geofenceMeters': geofenceMeters,
  };
}

class CompanyService {
  CompanyService._();
  static final instance = CompanyService._();

  static const _docPath = 'app_config/company';

  CompanyConfig _config = CompanyConfig.defaults();
  CompanyConfig get config => _config;

  StreamSubscription? _sub;
  final _controller = StreamController<CompanyConfig>.broadcast();
  Stream<CompanyConfig> get stream => _controller.stream;

  DocumentReference get _docRef =>
      FirebaseFirestore.instance.doc(_docPath);

  /// Start listening to company config changes. Call once at app start.
  void startListening() {
    _sub?.cancel();
    _sub = _docRef.snapshots().listen((snap) {
      final data = (snap.data() as Map<String, dynamic>?) ?? {};
      _config = CompanyConfig.fromMap(data);
      _controller.add(_config);
    });
  }

  void dispose() {
    _sub?.cancel();
    _controller.close();
  }

  /// Save company config to Firestore.
  Future<void> save(CompanyConfig config) async {
    await _docRef.set(config.toMap(), SetOptions(merge: true));
  }

}
