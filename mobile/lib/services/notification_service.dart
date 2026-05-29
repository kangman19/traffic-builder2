import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static const _channelId = 'traffic_alerts';
  static const _channelName = 'Traffic Alerts';

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  int _nextId = 0;

  Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);

    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: 'Alerts when your route traffic changes',
            importance: Importance.high,
          ),
        );
  }

  Future<void> showTrafficNotification(String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Alerts when your route traffic changes',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    await _plugin.show(
      _nextId++,
      title,
      body,
      const NotificationDetails(android: androidDetails),
    );
  }

  Future<void> showMonitoringNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'traffic_monitoring',
      'Monitoring',
      channelDescription: 'Persistent notification while monitoring is active',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      icon: '@mipmap/ic_launcher',
    );
    await _plugin.show(
      999,
      'Traffic Builder',
      'Monitoring your route home…',
      const NotificationDetails(android: androidDetails),
    );
  }

  Future<void> cancelMonitoringNotification() async {
    await _plugin.cancel(999);
  }
}
