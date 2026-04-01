// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants.dart';
import 'features/auth/login_page.dart';
import 'features/home/home_page.dart';
import 'services/notification_service.dart';
import 'services/company_service.dart';
import 'services/supabase_service.dart';

// ========================================================
// GLOBAL NAVIGATION KEY (untuk buka page bila tap notif)
// ========================================================
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Init Supabase
  await Supabase.initialize(
    url: SmartBayu.supabaseUrl,
    anonKey: SmartBayu.supabaseAnonKey,
  );

  // Init Notification Service (local notifications only)
  await NotificationService.instance.init();

  // Start company config listener
  CompanyService.instance.startListening();

  // Transparent status bar
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  ));

  runApp(const SmartBayuApp());
}

class SmartBayuApp extends StatelessWidget {
  const SmartBayuApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF1E88E5);

    return MaterialApp(
      title: 'SmartBayu',
      debugShowCheckedModeBanner: false,

      navigatorKey: navigatorKey,

      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
        ),
      ),

      home: const _AuthGate(),
      routes: {
        '/login': (_) => const LoginPage(),
      },
      onUnknownRoute: (s) =>
          MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }
}

// ========================================================
// AUTH GATE = determine login / home
// ========================================================
class _AuthGate extends StatefulWidget {
  const _AuthGate({super.key});

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  bool _loading = true;
  bool _loggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkSession();

    // Listen for auth state changes
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.signedIn) {
        _onSignedIn();
      } else if (event == AuthChangeEvent.signedOut) {
        NotificationService.instance.disposeUserNotificationListener();
        SupabaseService.instance.clear();
        if (mounted) setState(() => _loggedIn = false);
      }
    });
  }

  Future<void> _checkSession() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      await _onSignedIn();
    } else {
      if (mounted) setState(() { _loading = false; _loggedIn = false; });
    }
  }

  Future<void> _onSignedIn() async {
    await SupabaseService.instance.loadUserContext();
    final staffId = SupabaseService.instance.staffId;
    if (staffId != null) {
      NotificationService.instance.startUserNotificationListener(staffId);
    }
    if (mounted) setState(() { _loading = false; _loggedIn = true; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_loggedIn) {
      return const LoginPage();
    }

    final svc = SupabaseService.instance;
    return HomePage(
      isHr: svc.isHr,
      displayName: svc.fullName.isNotEmpty ? svc.fullName : (svc.email ?? 'SmartBayu User'),
      roleTitle: svc.isHr ? 'HR / Manager' : 'Staff',
      siteName: CompanyService.instance.siteName,
      photoUrl: svc.photoUrl,
      onLogout: (ctx) async {
        await NotificationService.instance.disposeUserNotificationListener();
        await SupabaseService.instance.signOut();
        if (ctx.mounted) {
          Navigator.of(ctx).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginPage()),
            (_) => false,
          );
        }
      },
      insideGeofence: true,
      lastIn: '--:--',
      lastOut: '--:--',
    );
  }
}
