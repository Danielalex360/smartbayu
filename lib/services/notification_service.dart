// lib/services/notification_service.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

/// NotificationService V4 — Supabase Realtime + Local Notifications
///
/// Cara guna:
/// - main.dart → await NotificationService.instance.init();
/// - After login → NotificationService.instance.startUserNotificationListener(staffId);
/// - On logout → NotificationService.instance.disposeUserNotificationListener();
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  RealtimeChannel? _channel;

  // ================================================================
  // INIT (local notifications only — no FCM)
  // ================================================================
  Future<void> init([BuildContext? context]) async {
    if (_initialized) return;
    _initialized = true;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);

    await _local.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final data = jsonDecode(payload) as Map<String, dynamic>;
          debugPrint('🔔 Notification tapped: type=${data['type']}');
        } catch (_) {}
      },
    );
  }

  // ================================================================
  // SEND NOTIFICATION VIA SUPABASE (inserts into staff_notifications)
  // ================================================================
  Future<void> push({
    required String staffId,
    required String title,
    required String message,
    required String type,
    String? docId,
  }) async {
    final companyId = SupabaseService.instance.companyId;
    if (companyId == null) return;

    await Supabase.instance.client.from('staff_notifications').insert({
      'company_id': companyId,
      'staff_id': staffId,
      'title': title,
      'message': message,
      'type': type,
      if (docId != null) 'data': {'docId': docId},
    });
  }

  /// Send notification to multiple staff
  Future<void> sendToMultiple({
    required List<String> staffIds,
    required String title,
    required String message,
    required String type,
  }) async {
    for (final id in staffIds) {
      await push(staffId: id, title: title, message: message, type: type);
    }
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
          'smartbayu_channel',
          'SmartBayu Notifications',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: jsonEncode(data ?? {}),
    );
  }

  // ================================================================
  // REAL-TIME LISTENER (Supabase Realtime → local popup)
  // ================================================================
  Future<void> startUserNotificationListener(String staffId) async {
    await disposeUserNotificationListener();

    _channel = Supabase.instance.client
        .channel('staff_notifications_$staffId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'staff_notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'staff_id',
            value: staffId,
          ),
          callback: (payload) {
            final newRow = payload.newRecord;
            final title = (newRow['title'] ?? 'SmartBayu').toString();
            final message = (newRow['message'] ?? '').toString();
            final type = (newRow['type'] ?? 'general').toString();

            showLocal(
              title: title,
              body: message,
              data: {'type': type},
            );
          },
        )
        .subscribe();
  }

  Future<void> disposeUserNotificationListener() async {
    if (_channel != null) {
      await Supabase.instance.client.removeChannel(_channel!);
      _channel = null;
    }
  }
}
