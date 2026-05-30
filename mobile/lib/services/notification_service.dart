import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Singleton service for local push notifications.
///
/// [NotificationService.init] must be called once in [main] before
/// [runApp] so the plugin is ready before any background event fires.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const _alertChannelId = 'traffic_alerts';
  static const _alertChannelName = 'Traffic Alerts';
  static const _monitoringChannelId = 'traffic_monitoring';
  static const _monitoringChannelName = 'Monitoring';
  static const _monitoringNotifId = 999;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  int _nextAlertId = 0;

  // ── Lifecycle ────────────────────────────────────────────────────────────

  static Future<void> init() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await instance._plugin.initialize(initSettings);

    final androidImpl = instance._plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidImpl?.createNotificationChannel(
      const AndroidNotificationChannel(
        _alertChannelId,
        _alertChannelName,
        description: 'Alerts when your route traffic status changes',
        importance: Importance.high,
      ),
    );

    await androidImpl?.createNotificationChannel(
      const AndroidNotificationChannel(
        _monitoringChannelId,
        _monitoringChannelName,
        description: 'Persistent notification shown while monitoring is active',
        importance: Importance.low,
      ),
    );

    debugPrint('[NotificationService] Initialised — channels created');
  }

  // ── Traffic alert ────────────────────────────────────────────────────────

  Future<void> showTrafficAlert(String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      _alertChannelId,
      _alertChannelName,
      channelDescription: 'Alerts when your route traffic status changes',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    await _plugin.show(
      _nextAlertId++,
      title,
      body,
      const NotificationDetails(android: androidDetails),
    );
  }

  // ── Persistent monitoring indicator ─────────────────────────────────────

  Future<void> showMonitoringActive() async {
    const androidDetails = AndroidNotificationDetails(
      _monitoringChannelId,
      _monitoringChannelName,
      channelDescription: 'Shown while Traffic Builder is monitoring your route',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      icon: '@mipmap/ic_launcher',
    );
    await _plugin.show(
      _monitoringNotifId,
      'Traffic Builder',
      'Monitoring your route home…',
      const NotificationDetails(android: androidDetails),
    );
  }

  Future<void> cancelMonitoringActive() async {
    await _plugin.cancel(_monitoringNotifId);
  }
}
