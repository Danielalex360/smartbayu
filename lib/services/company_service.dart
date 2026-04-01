import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

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
    // Support both flat columns and nested settings JSONB
    final settings = (data['settings'] as Map<String, dynamic>?) ?? {};
    return CompanyConfig(
      companyName: (data['name'] as String?) ?? (settings['companyName'] as String?) ?? 'Bayu Lestari Resort',
      siteName: (settings['siteName'] as String?) ?? (data['name'] as String?) ?? 'Pulau Besar Site',
      logoUrl: (settings['logoUrl'] as String?) ?? (data['logo_url'] as String?),
      address: (data['address'] as String?) ?? (settings['address'] as String?),
      phone: (data['phone'] as String?) ?? (settings['phone'] as String?),
      email: (data['email'] as String?) ?? (settings['email'] as String?),
      website: (data['website'] as String?) ?? (settings['website'] as String?),
      registrationNo: (data['registration_no'] as String?) ?? (settings['registrationNo'] as String?),
      geofenceLat: (settings['geofenceLat'] as num?)?.toDouble() ?? 2.428795,
      geofenceLng: (settings['geofenceLng'] as num?)?.toDouble() ?? 103.983596,
      geofenceMeters: (settings['geofenceMeters'] as num?)?.toInt() ?? 3000,
      raw: data,
    );
  }

  factory CompanyConfig.defaults() => CompanyConfig.fromMap({});

  Map<String, dynamic> toSettingsMap() => {
    'siteName': siteName,
    'logoUrl': logoUrl,
    'geofenceLat': geofenceLat,
    'geofenceLng': geofenceLng,
    'geofenceMeters': geofenceMeters,
  };
}

class CompanyService {
  CompanyService._();
  static final instance = CompanyService._();

  CompanyConfig _config = CompanyConfig.defaults();
  CompanyConfig get config => _config;
  String get siteName => _config.siteName;

  final _controller = StreamController<CompanyConfig>.broadcast();
  Stream<CompanyConfig> get stream => _controller.stream;

  /// Start listening — loads company config from Supabase.
  /// Call once at app start. Reloads when company_id is available.
  void startListening() {
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      final companyId = SupabaseService.instance.companyId;
      if (companyId == null) return;

      final row = await Supabase.instance.client
          .from('companies')
          .select()
          .eq('id', companyId)
          .maybeSingle();

      if (row != null) {
        _config = CompanyConfig.fromMap(row);
        _controller.add(_config);
      }
    } catch (e) {
      debugPrint('CompanyService error: $e');
    }
  }

  /// Reload config (e.g. after login when companyId becomes available)
  Future<void> reload() async => _loadConfig();

  /// Save company settings to Supabase
  Future<void> save(CompanyConfig config) async {
    final companyId = SupabaseService.instance.companyId;
    if (companyId == null) return;

    await Supabase.instance.client
        .from('companies')
        .update({
          'settings': config.toSettingsMap(),
        })
        .eq('id', companyId);

    _config = config;
    _controller.add(_config);
  }

  void dispose() {
    _controller.close();
  }
}
