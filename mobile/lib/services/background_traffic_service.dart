import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../models/traffic_condition.dart';
import '../models/traffic_update.dart';

// ── Channel / notification constants (must match NotificationService) ─────────

const _monitoringChannelId   = 'traffic_monitoring';
const _alertChannelId        = 'traffic_alerts_channel';
const _alertChannelName      = 'Traffic Alerts';
const _monitoringNotifId     = 999;

// ── Service configuration (called once from main()) ───────────────────────────

Future<void> initBackgroundService() async {
  await FlutterBackgroundService().configure(
    androidConfiguration: AndroidConfiguration(
      onStart: _onServiceStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: _monitoringChannelId,
      initialNotificationTitle: 'Traffic Builder',
      initialNotificationContent: 'Monitoring your route home…',
      foregroundServiceNotificationId: _monitoringNotifId,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: _onServiceStart,
      onBackground: _onIosBackground,
    ),
  );
}

// ── iOS background handler (no-op stub) ──────────────────────────────────────

@pragma('vm:entry-point')
Future<bool> _onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

// ── Background isolate entry point ────────────────────────────────────────────
//
// Runs in a separate Dart isolate as an Android foreground service.
// Owns the Socket.io connection so it stays alive when the app is off-screen.

@pragma('vm:entry-point')
void _onServiceStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  // Alert notifications (separate from the foreground-service monitoring notif).
  final notifPlugin = FlutterLocalNotificationsPlugin();
  await notifPlugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );

  // Mutable service state — safe to capture in closures inside this function.
  io.Socket? socket;
  int        alertId      = 1000; // IDs above 999 (monitoring notif)
  String?    activeUserId;

  // ── Notification helpers ──────────────────────────────────────────────────

  void updateMonitoringNotif(String content) {
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: 'Traffic Builder',
        content: content,
      );
    }
  }

  Future<void> showAlert(
    TrafficStatus status,
    String etaText,
    int delayMins,
  ) async {
    final (title, body) = _copyForStatus(status, etaText, delayMins);
    await notifPlugin.show(
      alertId++,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _alertChannelId,
          _alertChannelName,
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }

  // ── Socket event handler ──────────────────────────────────────────────────

  void handleTrafficUpdate(TrafficUpdate update) {
    final c = update.condition;

    // 1. Update the persistent foreground-service notification.
    updateMonitoringNotif(
      'ETA ${c.etaMinutes}  ·  Delay ${c.delayShort}  ·  Arrives ${c.arrivalTime}',
    );

    // 2. Heads-up alert when traffic status changes.
    if (update.notification != null) {
      final delayMins =
          ((c.durationInTraffic - c.duration) / 60).round().clamp(0, 9999);
      showAlert(c.status, c.etaFormatted, delayMins);
    }

    // 3. Forward data to the main UI isolate (no-op when app is backgrounded).
    service.invoke('trafficUpdate', _encodeUpdate(update));
  }

  // ── Socket management ─────────────────────────────────────────────────────

  void connectSocket(String userId, String socketUrl) {
    socket?.disconnect();
    socket?.dispose();
    socket       = null;
    activeUserId = userId;

    socket = io.io(
      socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(999)
          .setReconnectionDelay(2000)
          .setReconnectionDelayMax(30000)
          .build(),
    );

    socket!.on('connect', (_) {
      debugPrint('[BGService] Socket connected — userId: $userId');
      service.invoke('socketStatus', {'connected': true});
      // Request fresh data immediately on every (re)connect.
      socket!.emit('check_traffic', {'userId': userId});
    });

    socket!.on('traffic_update', (rawData) {
      try {
        final data = rawData is List ? rawData[0] : rawData;
        final update = TrafficUpdate.fromJson(
          Map<String, dynamic>.from(data as Map),
        );
        if (update.userId == userId) handleTrafficUpdate(update);
      } catch (e) {
        debugPrint('[BGService] Failed to parse traffic_update: $e');
      }
    });

    socket!.on('disconnect', (reason) {
      debugPrint('[BGService] Socket disconnected: $reason');
      service.invoke('socketStatus', {'connected': false});
    });

    socket!.on('connect_error', (e) {
      debugPrint('[BGService] Connect error: $e');
    });

    socket!.connect();
  }

  // ── IPC from main UI isolate ──────────────────────────────────────────────

  // Start monitoring: connect socket with provided config.
  service.on('start').listen((data) {
    if (data == null) return;
    final userId    = data['userId']    as String;
    final socketUrl = data['socketUrl'] as String;
    debugPrint('[BGService] Starting — userId: $userId  url: $socketUrl');
    updateMonitoringNotif('Monitoring your route home…');
    connectSocket(userId, socketUrl);
  });

  // Force an immediate traffic check (e.g. app came to foreground).
  service.on('checkNow').listen((_) {
    if (socket?.connected == true && activeUserId != null) {
      debugPrint('[BGService] checkNow — requesting traffic for $activeUserId');
      socket!.emit('check_traffic', {'userId': activeUserId});
    }
  });

  // Stop monitoring: disconnect socket and kill the service.
  service.on('stop').listen((_) {
    debugPrint('[BGService] Stopping');
    socket?.disconnect();
    socket?.dispose();
    socket       = null;
    activeUserId = null;
    service.stopSelf();
  });
}

// ── Data serialization ─────────────────────────────────────────────────────────
//
// IPC between isolates uses plain Map<String, dynamic>, so we encode
// TrafficUpdate into primitives and decode it back in the main isolate.

Map<String, dynamic> _encodeUpdate(TrafficUpdate update) {
  final c = update.condition;
  return {
    'userId'           : update.userId,
    'status'           : _statusStr(c.status),
    'duration'         : c.duration,
    'durationInTraffic': c.durationInTraffic,
    'distance'         : c.distance,
    'timestamp'        : c.timestamp.toIso8601String(),
    'eta'              : c.eta.toIso8601String(),
    if (update.notification != null) ...{
      'notifType' : update.notification!.type,
      'notifETA'  : update.notification!.currentETA,
      'notifDelay': update.notification!.delay,
    },
  };
}

// Returns the server-side string value for a status so TrafficStatusX.fromString
// can decode it correctly in the main isolate.
String _statusStr(TrafficStatus s) => switch (s) {
  TrafficStatus.calm   => 'calm',
  TrafficStatus.bookey => 'bookey',
  TrafficStatus.ggs    => "GG's",
};

(String, String) _copyForStatus(
  TrafficStatus status,
  String etaText,
  int delayMins,
) =>
    switch (status) {
      TrafficStatus.calm => (
        '🟢 All Clear',
        'Happy travels twin | ETA: $etaText (Delay: ${delayMins}m)',
      ),
      TrafficStatus.bookey => (
        '⚠️ Traffic Building',
        'Leave now or forever hold your peace | ETA: $etaText (+${delayMins}m)',
      ),
      TrafficStatus.ggs => (
        "GG's",
        'Yeah...just get cozy bro | ETA: $etaText (+${delayMins}m)',
      ),
    };
