// lib/features/hr/hr_company_settings_page.dart
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/company_service.dart';

class HrCompanySettingsPage extends StatefulWidget {
  const HrCompanySettingsPage({super.key});

  @override
  State<HrCompanySettingsPage> createState() => _HrCompanySettingsPageState();
}

class _HrCompanySettingsPageState extends State<HrCompanySettingsPage> {
  final _formKey = GlobalKey<FormState>();

  final _companyNameCtrl = TextEditingController();
  final _siteNameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _regNoCtrl = TextEditingController();
  final _geoLatCtrl = TextEditingController();
  final _geoLngCtrl = TextEditingController();
  final _geoRadiusCtrl = TextEditingController();

  String? _logoUrl;
  bool _saving = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _companyNameCtrl.dispose();
    _siteNameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _websiteCtrl.dispose();
    _regNoCtrl.dispose();
    _geoLatCtrl.dispose();
    _geoLngCtrl.dispose();
    _geoRadiusCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    final snap = await FirebaseFirestore.instance
        .doc('app_config/company')
        .get();

    final data = (snap.data() ?? {}) as Map<String, dynamic>;
    final config = CompanyConfig.fromMap(data);

    _companyNameCtrl.text = config.companyName;
    _siteNameCtrl.text = config.siteName;
    _addressCtrl.text = config.address ?? '';
    _phoneCtrl.text = config.phone ?? '';
    _emailCtrl.text = config.email ?? '';
    _websiteCtrl.text = config.website ?? '';
    _regNoCtrl.text = config.registrationNo ?? '';
    _geoLatCtrl.text = config.geofenceLat.toString();
    _geoLngCtrl.text = config.geofenceLng.toString();
    _geoRadiusCtrl.text = config.geofenceMeters.toString();
    _logoUrl = config.logoUrl;

    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _pickLogo() async {
    final shot = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 512,
    );
    if (shot == null) return;

    setState(() => _saving = true);

    try {
      final file = File(shot.path);
      final ref = FirebaseStorage.instance
          .ref('company/logo_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
      final url = await ref.getDownloadURL();

      setState(() {
        _logoUrl = url;
        _saving = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload logo: $e')),
        );
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final config = CompanyConfig(
        companyName: _companyNameCtrl.text.trim(),
        siteName: _siteNameCtrl.text.trim(),
        logoUrl: _logoUrl,
        address: _addressCtrl.text.trim().isEmpty
            ? null
            : _addressCtrl.text.trim(),
        phone:
            _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        email:
            _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        website: _websiteCtrl.text.trim().isEmpty
            ? null
            : _websiteCtrl.text.trim(),
        registrationNo: _regNoCtrl.text.trim().isEmpty
            ? null
            : _regNoCtrl.text.trim(),
        geofenceLat: double.tryParse(_geoLatCtrl.text.trim()) ?? 2.428795,
        geofenceLng: double.tryParse(_geoLngCtrl.text.trim()) ?? 103.983596,
        geofenceMeters: int.tryParse(_geoRadiusCtrl.text.trim()) ?? 3000,
        raw: {},
      );

      await CompanyService.instance.save(config);

      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Company settings saved'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF102A43),
        title: const Text(
          'Company Settings',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save_rounded),
              tooltip: 'Save',
              onPressed: _save,
            ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- Logo ---
                    _SectionTitle('Company Logo'),
                    const SizedBox(height: 8),
                    Center(
                      child: GestureDetector(
                        onTap: _pickLogo,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFFE0E7FF),
                              width: 2,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x14000000),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: _logoUrl != null && _logoUrl!.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(18),
                                  child: Image.network(
                                    _logoUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _logoPlaceholder(),
                                  ),
                                )
                              : _logoPlaceholder(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Center(
                      child: Text(
                        'Tap to change logo',
                        style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // --- Company Details ---
                    _SectionTitle('Company Details'),
                    const SizedBox(height: 12),
                    _SettingsCard(
                      children: [
                        _field(
                          controller: _companyNameCtrl,
                          label: 'Company Name',
                          icon: Icons.business_rounded,
                          required: true,
                        ),
                        _field(
                          controller: _siteNameCtrl,
                          label: 'Site / Branch Name',
                          icon: Icons.location_city_rounded,
                          required: true,
                        ),
                        _field(
                          controller: _regNoCtrl,
                          label: 'Registration No (SSM)',
                          icon: Icons.badge_rounded,
                        ),
                        _field(
                          controller: _addressCtrl,
                          label: 'Address',
                          icon: Icons.place_rounded,
                          maxLines: 2,
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // --- Contact ---
                    _SectionTitle('Contact Information'),
                    const SizedBox(height: 12),
                    _SettingsCard(
                      children: [
                        _field(
                          controller: _phoneCtrl,
                          label: 'Phone',
                          icon: Icons.phone_rounded,
                          keyboard: TextInputType.phone,
                        ),
                        _field(
                          controller: _emailCtrl,
                          label: 'Email',
                          icon: Icons.email_rounded,
                          keyboard: TextInputType.emailAddress,
                        ),
                        _field(
                          controller: _websiteCtrl,
                          label: 'Website',
                          icon: Icons.language_rounded,
                          keyboard: TextInputType.url,
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // --- Geofence ---
                    _SectionTitle('Geofence Settings'),
                    const SizedBox(height: 4),
                    const Text(
                      'Staff must be within this radius to check in/out.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                    ),
                    const SizedBox(height: 12),
                    _SettingsCard(
                      children: [
                        _field(
                          controller: _geoLatCtrl,
                          label: 'Latitude',
                          icon: Icons.my_location_rounded,
                          keyboard: const TextInputType.numberWithOptions(
                              decimal: true, signed: true),
                          required: true,
                        ),
                        _field(
                          controller: _geoLngCtrl,
                          label: 'Longitude',
                          icon: Icons.my_location_rounded,
                          keyboard: const TextInputType.numberWithOptions(
                              decimal: true, signed: true),
                          required: true,
                        ),
                        _field(
                          controller: _geoRadiusCtrl,
                          label: 'Radius (meters)',
                          icon: Icons.radar_rounded,
                          keyboard: TextInputType.number,
                          required: true,
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),

                    // --- Save button ---
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: const Icon(Icons.save_rounded),
                        label: const Text(
                          'Save Settings',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _logoPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Icon(Icons.add_a_photo_rounded, size: 32, color: Color(0xFF9CA3AF)),
        SizedBox(height: 4),
        Text('Upload', style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
      ],
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool required = false,
    TextInputType? keyboard,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        maxLines: maxLines,
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
            : null,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          filled: true,
          fillColor: const Color(0xFFF9FAFB),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE0E7FF)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE0E7FF)),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1F2937),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E7FF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}
