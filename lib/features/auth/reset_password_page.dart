import 'dart:ui'; // untuk BackdropFilter (blur)
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _loading = false;

  late AnimationController _anim;
  late Animation<Offset> _slide;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();

    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    final curved = CurvedAnimation(
      parent: _anim,
      curve: Curves.easeOutCirc,
    );

    _slide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(curved);

    _fade = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(curved);

    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    _emailCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailCtrl.text.trim();
    final newPass = _newPassCtrl.text.trim();

    setState(() => _loading = true);

    try {
      // 1) Cari user dalam Firestore ikut email
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        throw 'Akaun dengan email ini tidak wujud dalam rekod HR.';
      }

      final userDoc = query.docs.first;

      // 2) Ambil defaultPassword daripada Firestore (auto detect)
      final defaultPass =
      (userDoc.data()['defaultPassword'] as String?)?.trim();

      if (defaultPass == null || defaultPass.isEmpty) {
        throw 'Akaun ini tidak menggunakan password default HR.';
      }

      // 3) Login guna default password itu
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: defaultPass,
      );

      final user = cred.user;
      if (user == null) {
        throw 'Ralat dalaman: user tidak wujud.';
      }

      // 4) Tukar ke password baru
      await user.updatePassword(newPass);

      // 5) Opsyenal: padam defaultPassword & flag mustChangePassword
      await userDoc.reference.update({
        'defaultPassword': FieldValue.delete(),
        'mustChangePassword': false,
      });

      // 6) Sign out semula
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
          Text('Password berjaya ditetapkan semula. Sila login semula.'),
        ),
      );

      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      String msg = 'Gagal reset password: ${e.message}';
      if (e.code == 'user-not-found') {
        msg = 'Akaun dengan email ini tidak wujud.';
      } else if (e.code == 'wrong-password') {
        msg =
        'Reset gagal. Password default HR dalam rekod tidak sepadan. Sila hubungi HR.';
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal reset password: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.transparent,

      // Glass AppBar
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight + 8),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(22),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: AppBar(
              elevation: 0,
              backgroundColor: Colors.white.withOpacity(0.18),
              centerTitle: false,
              title: const Text(
                'Reset Password',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              iconTheme: const IconThemeData(
                color: Colors.black87,
              ),
            ),
          ),
        ),
      ),

      body: Stack(
        children: [
          // 🌴 Resort background (sama premium macam login)
          Positioned.fill(
            child: Image.asset(
              'assets/images/bg_resort.png',
              fit: BoxFit.cover,
            ),
          ),

          SafeArea(
            top: false,
            child: Center(
              child: SingleChildScrollView(
                padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: FadeTransition(
                  opacity: _fade,
                  child: SlideTransition(
                    position: _slide,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Card(
                        elevation: 10,
                        shadowColor: Colors.black.withOpacity(0.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(22),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Header icon + title
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(
                                      Icons.lock_reset_rounded,
                                      color: Color(0xFF2563EB),
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Tetapkan Semula Password',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1F2933),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),

                                // Pill info
                                Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE5F0FF),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: const Text(
                                      'Hanya untuk akaun dengan password default HR',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF1D4ED8),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),

                                const Text(
                                  'Masukkan email akaun dan password baru.\n'
                                      'Ciri ini akan guna password default HR yang direkodkan dalam sistem.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Email
                                TextFormField(
                                  controller: _emailCtrl,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: const InputDecoration(
                                    labelText: 'Email',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (v) {
                                    final value = v?.trim() ?? '';
                                    if (value.isEmpty) {
                                      return 'Email diperlukan';
                                    }
                                    final ok = RegExp(
                                        r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                        .hasMatch(value);
                                    if (!ok) return 'Format email tidak sah';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),

                                // Password baru
                                TextFormField(
                                  controller: _newPassCtrl,
                                  obscureText: _obscureNew,
                                  decoration: InputDecoration(
                                    labelText: 'Password baru',
                                    border: const OutlineInputBorder(),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscureNew
                                            ? Icons.visibility_rounded
                                            : Icons.visibility_off_rounded,
                                      ),
                                      onPressed: () {
                                        setState(() =>
                                        _obscureNew = !_obscureNew);
                                      },
                                    ),
                                  ),
                                  validator: (v) {
                                    final value = v ?? '';
                                    if (value.isEmpty) {
                                      return 'Password baru diperlukan';
                                    }
                                    if (value.length < 6) {
                                      return 'Minimum 6 aksara';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),

                                // Sahkan password
                                TextFormField(
                                  controller: _confirmPassCtrl,
                                  obscureText: _obscureConfirm,
                                  decoration: InputDecoration(
                                    labelText: 'Sahkan password baru',
                                    border: const OutlineInputBorder(),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscureConfirm
                                            ? Icons.visibility_rounded
                                            : Icons.visibility_off_rounded,
                                      ),
                                      onPressed: () {
                                        setState(() => _obscureConfirm =
                                        !_obscureConfirm);
                                      },
                                    ),
                                  ),
                                  validator: (v) {
                                    final value = v ?? '';
                                    if (value.isEmpty) {
                                      return 'Sila sahkan password baru';
                                    }
                                    if (value != _newPassCtrl.text) {
                                      return 'Password tidak sepadan';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 22),

                                // Button Reset
                                SizedBox(
                                  height: 48,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                      const Color(0xFF2563EB),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed:
                                    _loading ? null : _resetPassword,
                                    child: _loading
                                        ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child:
                                      CircularProgressIndicator(
                                        strokeWidth: 2.4,
                                        valueColor:
                                        AlwaysStoppedAnimation<
                                            Color>(Colors.white),
                                      ),
                                    )
                                        : const Text('Reset Password'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
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
