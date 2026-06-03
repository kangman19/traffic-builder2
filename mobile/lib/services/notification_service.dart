import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/traffic_condition.dart';

/// Singleton service for local push notifications.
///
/// Call [init] once in [main] before [runApp], then [requestPermission]
/// immediately after to satisfy Android 13+ runtime-permission requirements.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const _alertChannelId   = 'traffic_alerts_channel';
  static const _alertChannelName = 'Traffic Alerts';

  static const _monitoringChannelId   = 'traffic_monitoring';
  static const _monitoringChannelName = 'Monitoring';
  static const _monitoringNotifId     = 999;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  int _nextAlertId = 0;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

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
        description: 'Real-time traffic alerts for your route home',
        importance: Importance.max,
      ),
    );

    await androidImpl?.createNotificationChannel(
      const AndroidNotificationChannel(
        _monitoringChannelId,
        _monitoringChannelName,
        description: 'Shown while Traffic Builder is monitoring your route',
        importance: Importance.low,
      ),
    );

    debugPrint('[NotificationService] Initialised — channels created');
  }

  // ── Permissions (Android 13+) ─────────────────────────────────────────────

  Future<void> requestPermission() async {
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();
  }

  // ── Traffic alert ─────────────────────────────────────────────────────────

  /// Shows a heads-up notification using the copy engine keyed on [status].
  ///
  /// [etaText]      — human-readable travel time, e.g. "18 mins"
  /// [delayMinutes] — extra minutes vs. no-traffic journey (0 = on time)
  Future<void> showTrafficStatus(
    TrafficStatus status,
    String etaText,
    int delayMinutes,
  ) async {
    final (title, body) = _buildCopy(status, etaText, delayMinutes);
    const androidDetails = AndroidNotificationDetails(
      _alertChannelId,
      _alertChannelName,
      channelDescription: 'Real-time traffic alerts for your route home',
      importance: Importance.max,
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

  // ── Persistent monitoring indicator ──────────────────────────────────────

  Future<void> showMonitoringActive() async {
    await _showMonitoringNotif('Monitoring your route home…');
  }

  Future<void> updateMonitoringActive(TrafficCondition cond) async {
    final body =
        'ETA ${cond.etaMinutes}  ·  Delay ${cond.delayShort}  ·  Arrives ${cond.arrivalTime}';
    await _showMonitoringNotif(body);
  }

  Future<void> _showMonitoringNotif(String body) async {
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
      body,
      const NotificationDetails(android: androidDetails),
    );
  }

  Future<void> cancelMonitoringActive() async {
    await _plugin.cancel(_monitoringNotifId);
  }

  // ── Copy engine ───────────────────────────────────────────────────────────

  (String title, String body) _buildCopy(
    TrafficStatus status,
    String etaText,
    int delayMinutes,
  ) =>
      switch (status) {
        TrafficStatus.calm => (
          '🟢 All Clear',
          'Happy travels twin | ETA: $etaText (Delay: ${delayMinutes}m)',
        ),
        TrafficStatus.bookey => (
          '⚠️ Traffic Building',
          'Leave now or forever hold your peace | ETA: $etaText (+${delayMinutes}m)',
        ),
        TrafficStatus.ggs => (
          "GG's",
          'Yeah...just get cozy bro | ETA: $etaText (+${delayMinutes}m)',
        ),
      };
}
