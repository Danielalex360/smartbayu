import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../home/home_page.dart';
import 'reset_password_page.dart';
import '../../services/notification_service.dart';
import '../../services/supabase_service.dart';
import '../../services/company_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();

  bool _obscure = true;
  bool _loading = false;
  bool _sendingReset = false;

  late AnimationController _anim;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();

    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    final curved = CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic);

    _fade = Tween<double>(begin: 0, end: 1).animate(curved);
    _slide =
        Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero)
            .animate(curved);

    _anim.forward();
  }

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    _anim.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final email = emailCtrl.text.trim();
    final password = passCtrl.text.trim();

    setState(() => _loading = true);

    try {
      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (res.user == null) throw 'Login gagal.';

      // Load staff context (resolves auth.uid → staff record)
      final hasStaff = await SupabaseService.instance.loadUserContext();

      if (!hasStaff) {
        throw 'Akaun wujud tetapi rekod staff tidak dijumpai. Sila hubungi HR.';
      }

      final svc = SupabaseService.instance;

      // Check if staff is active
      final isActive = svc.staffData?['is_active'] as bool? ?? true;
      if (!isActive) {
        await SupabaseService.instance.signOut();
        throw 'Akaun ini tidak aktif.';
      }

      // Start notification listener
      if (svc.staffId != null) {
        await NotificationService.instance.startUserNotificationListener(svc.staffId!);
      }

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HomePage(
            isHr: svc.isHr,
            displayName: svc.fullName.isNotEmpty ? svc.fullName : email,
            roleTitle: svc.isHr ? 'HR / Manager' : 'Staff',
            siteName: CompanyService.instance.siteName,
            photoUrl: svc.photoUrl,
            onLogout: (ctx) async {
              await NotificationService.instance.disposeUserNotificationListener();
              await SupabaseService.instance.signOut();
              if (ctx.mounted) {
                Navigator.of(ctx).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (route) => false,
                );
              }
            },
          ),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login gagal: ${e.message}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login gagal: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendPasswordResetEmail() async {
    final email = emailCtrl.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sila masukkan email akaun dahulu.')),
      );
      return;
    }

    setState(() => _sendingReset = true);

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);

      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Link reset dihantar'),
          content: Text(
            'Kami telah menghantar link reset password ke:\n\n'
            '$email\n\n'
            'Sila buka email tersebut dan ikut arahan untuk set password baru.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal hantar link reset: $e')),
      );
    } finally {
      if (mounted) setState(() => _sendingReset = false);
    }
  }

  // UI unchanged from original
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset("assets/images/bg_ocean.png", fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.18)),
          ),
          Positioned(
            top: 110, left: 0, right: 0,
            child: Center(
              child: SizedBox(
                width: 240, height: 240,
                child: Image.asset("assets/logos/smartbayu_logo.png", fit: BoxFit.contain),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
                child: FadeTransition(
                  opacity: _fade,
                  child: SlideTransition(
                    position: _slide,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        children: [
                          const SizedBox(height: 210),
                          const SizedBox(height: 20),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.18),
                                  blurRadius: 18,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  children: [
                                    _IosTextField(
                                      controller: emailCtrl,
                                      label: "Email",
                                      keyboardType: TextInputType.emailAddress,
                                      validator: (v) {
                                        final value = v?.trim() ?? "";
                                        if (value.isEmpty) return "Email diperlukan";
                                        final ok = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value);
                                        if (!ok) return "Format email tidak sah";
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 14),
                                    _IosTextField(
                                      controller: passCtrl,
                                      label: "Password",
                                      obscure: _obscure,
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                          size: 20, color: Colors.grey.shade500,
                                        ),
                                        onPressed: () => setState(() => _obscure = !_obscure),
                                      ),
                                      validator: (v) {
                                        final value = v?.trim() ?? "";
                                        if (value.isEmpty) return "Password diperlukan";
                                        if (value.length < 6) return "Minimum 6 aksara";
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 18),
                                    SizedBox(
                                      height: 48,
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF0EA5A4),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                          elevation: 6,
                                        ),
                                        onPressed: _loading ? null : _login,
                                        child: _loading
                                            ? const SizedBox(
                                                height: 22, width: 22,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2.4,
                                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                ),
                                              )
                                            : const Text("Login", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextButton(
                                      onPressed: _sendingReset ? null : _sendPasswordResetEmail,
                                      child: _sendingReset
                                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                          : const Text("Forgot password?"),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.push(context, MaterialPageRoute(builder: (_) => const ResetPasswordPage()));
                                      },
                                      child: const Text("First-time login (default HR password)", style: TextStyle(fontSize: 12)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "Tip: sila hubungi HR untuk pendaftaran akaun",
                            style: TextStyle(color: Colors.black.withOpacity(0.7), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
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

class _IosTextField extends StatelessWidget {
  const _IosTextField({
    required this.controller,
    required this.label,
    this.obscure = false,
    this.suffixIcon,
    this.keyboardType,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final bool obscure;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }
}
