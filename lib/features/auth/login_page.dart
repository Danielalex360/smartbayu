import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../home/home_page.dart';
import 'reset_password_page.dart';
import '../../services/notification_service.dart'; // 🔔 NOTIFICATION SERVICE

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
  bool _sendingReset = false; // 🔹 status untuk reset via email

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

  String _titleCaseFromEmail(String email) {
    if (email.isEmpty) return 'Guest User';
    final raw = email.split('@').first.replaceAll('.', ' ');
    return raw
        .split(' ')
        .where((s) => s.trim().isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final email = emailCtrl.text.trim();
    final password = passCtrl.text.trim();

    setState(() => _loading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final authUser = FirebaseAuth.instance.currentUser;
      if (authUser == null) throw 'Ralat dalaman.';

      // 🔔 START REAL-TIME NOTIFICATION LISTENER UNTUK USER NI
      await NotificationService.instance.startUserNotificationListener(
        authUser.uid,
      );

      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(authUser.uid)
          .get();

      if (!mounted) return;

      String displayName = _titleCaseFromEmail(email);
      String? roleTitle;
      String siteName = "Bayu Lestari Resort Island";
      String? photoUrl;
      bool isHr = email.toLowerCase().startsWith('hr@');
      bool isActive = true;

      if (snap.exists) {
        final data = snap.data()!;
        final n = (data['name'] as String?)?.trim();
        if (n != null && n.isNotEmpty) displayName = n;

        final r = (data['role'] as String?)?.trim();
        if (r != null && r.isNotEmpty) {
          roleTitle = r;
          if (r.toLowerCase().contains("hr")) isHr = true;
        }

        final s = (data['site'] as String?)?.trim();
        if (s != null && s.isNotEmpty) siteName = s;

        final p = (data['photoUrl'] as String?)?.trim();
        if (p != null && p.isNotEmpty) photoUrl = p;

        final a = data['active'];
        if (a is bool) isActive = a;

        if (!isActive) throw "Akaun ini tidak aktif.";
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HomePage(
            isHr: isHr,
            displayName: displayName,
            roleTitle: roleTitle,
            siteName: siteName,
            photoUrl: photoUrl,
            onLogout: (ctx) async {
              // 🔕 STOP LISTENER BILA LOGOUT
              await NotificationService.instance
                  .disposeUserNotificationListener();

              await FirebaseAuth.instance.signOut();
              Navigator.of(ctx).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginPage()),
                    (route) => false,
              );
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Login gagal: $e")),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // 🔹 RESET PASSWORD VIA EMAIL (Firebase built-in)
  Future<void> _sendPasswordResetEmail() async {
    final email = emailCtrl.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sila masukkan email akaun dahulu.'),
        ),
      );
      return;
    }

    setState(() => _sendingReset = true);

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

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
    } on FirebaseAuthException catch (e) {
      String msg = 'Gagal hantar link reset password.';
      if (e.code == 'user-not-found') {
        msg = 'Akaun dengan email ini tidak wujud dalam sistem.';
      } else if (e.code == 'invalid-email') {
        msg = 'Format email tidak sah.';
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ralat tidak dijangka: $e')),
      );
    } finally {
      if (mounted) setState(() => _sendingReset = false);
    }
  }

  // ───────────────────────────────── UI ─────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // 🌊 FULL OCEAN BACKGROUND
          Positioned.fill(
            child: Image.asset(
              "assets/images/bg_ocean.png",
              fit: BoxFit.cover,
            ),
          ),

          // overlay gelap sikit
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.18),
            ),
          ),

          // ◆ TOP SMARTBAYU LOGO
          Positioned(
            top: 110,
            left: 0,
            right: 0,
            child: Center(
              child: SizedBox(
                width: 240,
                height: 240,
                child: Image.asset(
                  "assets/logos/smartbayu_logo.png",
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding:
                const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
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

                          // FORM CARD
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
                              padding:
                              const EdgeInsets.fromLTRB(18, 20, 18, 20),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  children: [
                                    _IosTextField(
                                      controller: emailCtrl,
                                      label: "Email",
                                      keyboardType:
                                      TextInputType.emailAddress,
                                      validator: (v) {
                                        final value = v?.trim() ?? "";
                                        if (value.isEmpty) {
                                          return "Email diperlukan";
                                        }
                                        final ok = RegExp(
                                          r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                        ).hasMatch(value);
                                        if (!ok) {
                                          return "Format email tidak sah";
                                        }
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
                                          _obscure
                                              ? Icons.visibility_rounded
                                              : Icons
                                              .visibility_off_rounded,
                                          size: 20,
                                          color: Colors.grey.shade500,
                                        ),
                                        onPressed: () {
                                          setState(
                                                  () => _obscure = !_obscure);
                                        },
                                      ),
                                      validator: (v) {
                                        final value = v?.trim() ?? "";
                                        if (value.isEmpty) {
                                          return "Password diperlukan";
                                        }
                                        if (value.length < 6) {
                                          return "Minimum 6 aksara";
                                        }
                                        return null;
                                      },
                                    ),

                                    const SizedBox(height: 18),

                                    // 🔹 LOGIN BUTTON – hijau laut + font putih
                                    SizedBox(
                                      height: 48,
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                          const Color(0xFF0EA5A4),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                            BorderRadius.circular(14),
                                          ),
                                          elevation: 6,
                                        ),
                                        onPressed: _loading ? null : _login,
                                        child: _loading
                                            ? const SizedBox(
                                          height: 22,
                                          width: 22,
                                          child:
                                          CircularProgressIndicator(
                                            strokeWidth: 2.4,
                                            valueColor:
                                            AlwaysStoppedAnimation<
                                                Color>(
                                              Colors.white,
                                            ),
                                          ),
                                        )
                                            : const Text(
                                          "Login",
                                          style: TextStyle(
                                            fontWeight:
                                            FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 8),

                                    // 🔹 FORGOT PASSWORD VIA EMAIL
                                    TextButton(
                                      onPressed: _sendingReset
                                          ? null
                                          : _sendPasswordResetEmail,
                                      child: _sendingReset
                                          ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child:
                                        CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                          : const Text("Forgot password?"),
                                    ),

                                    // 🔹 FIRST-TIME DEFAULT HR PASSWORD
                                    TextButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                            const ResetPasswordPage(),
                                          ),
                                        );
                                      },
                                      child: const Text(
                                        "First-time login (default HR password)",
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 10),

                          Text(
                            "Tip: sila hubungi HR untuk pendaftaran akaun",
                            style: TextStyle(
                              color: Colors.black.withOpacity(0.7),
                              fontSize: 12,
                            ),
                          )
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

/// 🔹 Reusable iOS-style text field
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
        border: Border.all(
          color: const Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }
}
