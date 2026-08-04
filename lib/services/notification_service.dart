import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// 本地提醒服务:排程活动提醒。为了让 App 在未完成平台设定时仍能正常运行,
/// 所有对外方法都包了 try/catch,失败时静默降级(仅记录 debug 日志)。
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      // 未取得装置时区时退回台北时区(与目标使用者一致)。
      tz.setLocalLocation(tz.getLocation('Asia/Taipei'));

      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings();
      const settings = InitializationSettings(android: android, iOS: ios);
      await _plugin.initialize(settings);
      _ready = true;
    } catch (e) {
      debugPrint('NotificationService init failed (降级处理): $e');
    }
  }

  Future<void> requestPermissions() async {
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (e) {
      debugPrint('NotificationService requestPermissions failed: $e');
    }
  }

  /// 排程一则提醒。id 用行程项的雜凑,remindAt 为提醒时间。
  Future<void> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime remindAt,
  }) async {
    if (!_ready) return;
    // 过去时间不排程。
    if (remindAt.isBefore(DateTime.now())) return;
    try {
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'reminders',
          '活动提醒',
          channelDescription: '週末活动夥伴的行程提醒',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      );
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(remindAt, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('scheduleReminder failed: $e');
    }
  }

  Future<void> cancel(int id) async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id);
    } catch (e) {
      debugPrint('cancel notification failed: $e');
    }
  }
}