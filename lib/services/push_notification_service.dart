import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'notification_service.dart';
import 'supabase_config.dart';

/// Registers this device for recruitment push notifications.
///
/// FCM is configured by native Firebase files, which keeps dev and production
/// device tokens in separate Firebase projects.
class PushNotificationService {
  PushNotificationService._();
  static final instance = PushNotificationService._();

  bool _ready = false;

  Future<void> initialize() async {
    if (_ready) return;
    try {
      await Firebase.initializeApp();
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      await _saveCurrentToken();
      messaging.onTokenRefresh.listen(_saveToken);
      FirebaseMessaging.onMessage.listen((message) {
        final notification = message.notification;
        if (notification == null) return;
        NotificationService.instance.showIncomingNotification(
          title: notification.title ?? '周末遊',
          body: notification.body ?? '',
        );
      });
      SupabaseConfig.client.auth.onAuthStateChange.listen((_) => _saveCurrentToken());
      _ready = true;
    } catch (e) {
      // Push delivery should never prevent the app from starting.
      debugPrint('Push notification setup failed: $e');
    }
  }

  Future<void> _saveCurrentToken() async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await _saveToken(token);
  }

  Future<void> _saveToken(String token) async {
    final userId = SupabaseConfig.userId;
    if (userId == null) return;
    try {
      await SupabaseConfig.client.rpc(
        'register_device_token',
        params: {
          'p_token': token,
          'p_platform': Platform.isIOS ? 'ios' : 'android',
        },
      );
    } catch (e) {
      debugPrint('Push token registration failed: $e');
    }
  }
}
