import 'dart:async';
import 'package:flutter/foundation.dart';
import 'socket_service.dart';

/// Owns the periodic polling timer and handles dynamic interval re-configuration.
///
/// The UI pushes new interval values through [updateInterval]; the coordinator
/// streams the value to an internal listener that tears down the running [Timer]
/// and immediately creates a new one with the updated duration — no restart needed.
class TrackingCoordinator {
  final SocketService _socket;

  Timer? _timer;
  StreamSubscription<int>? _intervalSub;
  final _intervalUpdates = StreamController<int>.broadcast();
  String? _userId;

  TrackingCoordinator(this._socket);

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  void start(String userId, int intervalMinutes) {
    _userId = userId;
    _intervalSub = _intervalUpdates.stream.listen(_reschedule);
    _reschedule(intervalMinutes);
    debugPrint('[TrackingCoordinator] Started — interval: ${intervalMinutes}m');
  }

  /// Sends a new interval value to the active timer listener.
  /// The running timer is cancelled and replaced instantly.
  void updateInterval(int minutes) {
    if (_userId == null) return;
    _intervalUpdates.add(minutes);
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _intervalSub?.cancel();
    _intervalSub = null;
    _userId = null;
    debugPrint('[TrackingCoordinator] Stopped');
  }

  void dispose() {
    stop();
    _intervalUpdates.close();
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  void _reschedule(int minutes) {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(minutes: minutes), (_) {
      try {
        if (_userId != null) {
          debugPrint('[TrackingCoordinator] Tick — requesting traffic for $_userId');
          _socket.checkTraffic(_userId!);
        }
      } catch (e) {
        debugPrint('[TrackingCoordinator] Tick error: $e');
      }
    });
    debugPrint('[TrackingCoordinator] Timer rescheduled — interval: ${minutes}m');
  }
}
