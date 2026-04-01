// lib/services/notification_service.dart
import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// NotificationService V3
/// - Handle FCM + Local Popup Notification
/// - Support method lama (push(), showLocal())
/// - Support notification center & popup real-time
///
/// Cara guna (WAJIB):
/// - Dalam main.dart → panggil sekali sahaja:
///   await NotificationService.instance.init();
///
/// - Untuk navigation bila user tap notification:
///   NotificationService.instance.init(context) (lepas login)

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _local =
  FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  BuildContext? _rootContext;

  // FCM push via Firestore-based notifications (no legacy server key needed).
  // Direct FCM v1 API calls should be done server-side (Cloud Functions),
  // not from the client app. The Firestore listener handles real-time popups.

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _userNotificationListener;

  // ================================================================
  // INIT (sudah optional context)
  // ================================================================
  Future<void> init([BuildContext? context]) async {
    if (context != null) _rootContext = context;

    if (_initialized) return;
    _initialized = true;

    // Init local notification channel
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings =
    InitializationSettings(android: androidInit, iOS: iosInit);

    await _local.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final data = jsonDecode(payload) as Map<String, dynamic>;
          _handleNavigationFromData(data);
        } catch (_) {}
      },
    );

    // Request Permission
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    // Foreground message → terus popup (kalau pakai FCM)
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // App dibuka dari notification (background)
    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      _handleNavigationFromData(msg.data);
    });

    // App launch dari terminate via notification
    final initialMsg = await messaging.getInitialMessage();
    if (initialMsg != null) _handleNavigationFromData(initialMsg.data);
  }

  // ================================================================
  // SEND NOTIFICATION VIA FIRESTORE (triggers real-time listener)
  // ================================================================
  /// Sends a notification to a specific user via Firestore.
  /// The real-time listener on the target user's device will pick it up
  /// and show a local popup automatically.
  Future<void> sendToUser({
    required String userId,
    required String title,
    required String body,
    required String type,
    String? docId,
  }) async {
    await FirebaseFirestore.instance.collection('notifications').add({
      'userId': userId,
      'title': title,
      'message': body,
      'type': type,
      if (docId != null) 'docId': docId,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Send notification to multiple users
  Future<void> sendToMultipleUsers({
    required List<String> userIds,
    required String title,
    required String body,
    required String type,
    String? docId,
  }) async {
    for (final uid in userIds) {
      await sendToUser(userId: uid, title: title, body: body, type: type, docId: docId);
    }
  }

  // ================================================================
  // FOREGROUND POPUP (LOCAL) – untuk mesej FCM
  // ================================================================
  Future<void> _onForegroundMessage(RemoteMessage msg) async =>
      _showLocalNotificationFromMessage(msg);

  Future<void> _showLocalNotificationFromMessage(RemoteMessage msg) async {
    final noti = msg.notification;
    final title = noti?.title ?? msg.data['title'] ?? 'SmartBayu';
    final body = noti?.body ?? msg.data['body'] ?? '';

    final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await _local.show(
      id,
      title,
      body,
      NotificationDetails(
        android: const AndroidNotificationDetails(
          'smartbayu_channel',
          'SmartBayu Notifications',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: jsonEncode(msg.data),
    );
  }

  // ================================================================
  // TAP ROUTE HANDLER
  // ================================================================
  void _handleNavigationFromData(Map<String, dynamic> data) {
    // Navigation is handled by the notification page itself when tapped.
    // FCM background/terminated taps land here but the app opens to home
    // which is the correct behaviour for now.
    final type = (data['type'] ?? data['screen'] ?? '') as String;
    debugPrint('🔔 Notification tapped: type=$type');
  }

  // ================================================================
  // LEGACY SUPPORT API (kod lama masih boleh jalan)
  // ================================================================
  Future<void> push({
    required String userId,
    required String title,
    required String message,
    required String type,
  }) async {
    await FirebaseFirestore.instance.collection('notifications').add({
      'userId': userId,
      'title': title,
      'message': message,
      'type': type,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> showLocal({
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _local.show(
      id,
      title,
      body,
      NotificationDetails(
        android: const AndroidNotificationDetails(
          'smartbayu_manual',
          'Local SmartBayu Noti',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: jsonEncode(data ?? {}),
    );
  }

  // ================================================================
  // REAL-TIME LISTENER UNTUK NOTI (BELL + POPUP STAFF)
  // ================================================================
  Future<void> startUserNotificationListener(String userId) async {
    // stop listener lama dulu
    await _userNotificationListener?.cancel();

    _userNotificationListener = FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        // hanya doc yang BARU ditambah
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data == null) continue;

          final title = (data['title'] ?? 'SmartBayu').toString();
          final message = (data['message'] ?? '').toString();
          final type = (data['type'] ?? 'general').toString();

          // 👉 Popup local notification
          showLocal(
            title: title,
            body: message,
            data: {
              'type': type,
            },
          );
        }
      }
    });
  }

  Future<void> disposeUserNotificationListener() async {
    await _userNotificationListener?.cancel();
    _userNotificationListener = null;
  }
}
