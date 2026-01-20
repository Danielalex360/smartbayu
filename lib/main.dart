// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'features/auth/login_page.dart';
import 'features/home/home_page.dart';
import 'services/notification_service.dart';
import 'services/company_service.dart';

// ========================================================
// 🔥 GLOBAL NAVIGATION KEY (untuk buka page bila tap notif)
// ========================================================
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Init Firebase
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  // ⭐ Init Notification Service (FCM + local) sekali sahaja
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

      // 🔥 penting untuk buka page dari notification
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
// 🔥 AUTH GATE = tentukan login / home
// ========================================================
class _AuthGate extends StatelessWidget {
  const _AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snap.data;

        // Belum login
        if (user == null) {
          // pastikan listener lama clear kalau ada
          NotificationService.instance.disposeUserNotificationListener();
          return const LoginPage();
        }

        // 🔥 Start listener noti untuk user semasa
        NotificationService.instance.startUserNotificationListener(user.uid);

        // NOTE: buat masa ni isHr: false (nanti boleh baca dari Firestore)
        return HomePage(
          isHr: false,
          displayName: user.email ?? 'SmartBayu User',
          roleTitle: 'HR Admin Manager • Bayu Lestari',
          siteName: 'Resort Island',
          photoUrl: user.photoURL,
          onLogout: (ctx) async {
            await FirebaseAuth.instance.signOut();
            await NotificationService.instance
                .disposeUserNotificationListener();
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
      },
    );
  }
}
